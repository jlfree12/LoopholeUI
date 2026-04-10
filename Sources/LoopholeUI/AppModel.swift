import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    @Published var selection: SidebarItem? = .start
    @Published var draft = SessionDraft()
    @Published var providerMode: ProviderMode = .guidedDemo
    @Published var anthropicAPIKey: String = ""
    @Published var anthropicModel: String = "claude-sonnet-4-20250514"
    @Published var openAIAPIKey: String = ""
    @Published var openAIModel: String = "gpt-4.1-mini"
    @Published var liveProvider: LiveProvider = .anthropic
    @Published var casesPerAgent: Int = 2
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let store = SessionStore()

    init() {
        anthropicAPIKey = SecretsStore.loadAnthropicKey()
        openAIAPIKey = SecretsStore.loadOpenAIKey()
        sessions = store.loadSessions()
    }

    var selectedSession: SessionRecord? {
        guard case let .session(id) = selection else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    func applyTemplate(_ template: PrincipleTemplate) {
        draft.title = template.title
        draft.domain = template.domain
        draft.principles = template.principles
    }

    func saveSettings() {
        SecretsStore.saveAnthropicKey(anthropicAPIKey)
        SecretsStore.saveOpenAIKey(openAIAPIKey)
    }

    func showNewSession() {
        selection = .start
    }

    func showSettings() {
        selection = .settings
    }

    func showSession(id: String) {
        selection = .session(id)
    }

    func markDraftReviewed() {
        guard var session = selectedSession else { return }
        guard !session.hasReviewedDraft else { return }
        session.hasReviewedDraft = true
        persist(session)
    }

    func startSession() {
        Task {
            await runStartSession()
        }
    }

    func runNextStep() {
        Task {
            await continueSession()
        }
    }

    func resolveEscalation(with decision: String) {
        Task {
            await applyEscalationDecision(decision)
        }
    }

    private func client(for mode: ProviderMode) -> LoopholeClient {
        switch mode {
        case .guidedDemo:
            return DemoClient()
        case .anthropic:
            return AnthropicClient(apiKey: anthropicAPIKey, model: anthropicModel)
        case .openAI:
            return OpenAIClient(apiKey: openAIAPIKey, model: openAIModel)
        }
    }

    private func runStartSession() async {
        guard !draft.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a domain before starting. Examples: privacy, speech, migration."
            return
        }

        guard !draft.principles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add the user’s moral principles so the Legislator has something to draft from."
            return
        }

        isWorking = true
        errorMessage = nil

        do {
            var session = SessionRecord(
                id: sessionID(for: draft.domain),
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draft.domain.capitalized : draft.title,
                domain: draft.domain.trimmingCharacters(in: .whitespacesAndNewlines),
                moralPrinciples: draft.principles.trimmingCharacters(in: .whitespacesAndNewlines),
                providerMode: providerMode,
                hasReviewedDraft: false,
                currentRound: 0,
                maxRounds: draft.maxRounds,
                stage: .drafting,
                currentCode: LegalCode(version: 0, text: "Drafting in progress…", changelog: ""),
                codeHistory: [],
                cases: [],
                queuedCaseIDs: [],
                currentQueueIndex: 0,
                userClarifications: [],
                createdAt: Date(),
                updatedAt: Date()
            )

            let initialCode = try await client(for: session.providerMode).draftInitialCode(
                domain: session.domain,
                principles: session.moralPrinciples,
                clarifications: []
            )

            session.currentCode = initialCode
            session.codeHistory = [initialCode]
            session.stage = .drafting
            persist(session)
            resetDraft()
            selection = .session(session.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    private func continueSession() async {
        guard var session = selectedSession else { return }
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil

        do {
            if session.activeEscalation != nil {
                throw LoopholeClientError.invalidState("This round is waiting for the user's decision before it can continue.")
            }

            if session.hasPendingQueue {
                try await processQueuedCases(for: &session)
            } else {
                guard session.currentRound < session.maxRounds else {
                    session.stage = .completed
                    persist(session)
                    isWorking = false
                    return
                }

                session.currentRound += 1
                session.stage = .findingLoopholes

                let loopholes = try await client(for: session.providerMode).findCases(kind: .loophole, session: session, casesPerAgent: casesPerAgent)
                session.stage = .findingOverreach
                let overreaches = try await client(for: session.providerMode).findCases(kind: .overreach, session: session, casesPerAgent: casesPerAgent)

                session.cases.append(contentsOf: loopholes + overreaches)
                session.queuedCaseIDs = (loopholes + overreaches).map(\.id)
                session.currentQueueIndex = 0
                persist(session)

                try await processQueuedCases(for: &session)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    private func processQueuedCases(for session: inout SessionRecord) async throws {
        while session.currentQueueIndex < session.queuedCaseIDs.count {
            guard let queuedCase = session.cases.first(where: { $0.id == session.queuedCaseIDs[session.currentQueueIndex] }) else {
                session.currentQueueIndex += 1
                continue
            }

            session.stage = .judging
            persist(session)

            let decision = try await client(for: session.providerMode).judge(caseRecord: queuedCase, in: session)

            updateCase(in: &session, queuedCase.id) { current in
                current.reasoning = decision.reasoning
                current.resolutionSummary = decision.resolutionSummary
                current.proposedRevision = decision.proposedRevision
                current.conflictExplanation = decision.conflictExplanation
            }

            if decision.resolvable {
                var resolvedCase = session.cases.first(where: { $0.id == queuedCase.id })!
                resolvedCase.status = .autoResolved
                resolvedCase.resolvedBy = "judge"

                let revised = try await client(for: session.providerMode).reviseCode(for: session, dueTo: resolvedCase)
                let validation = try await client(for: session.providerMode).validate(candidateCode: revised, in: session)

                if validation.passes {
                    updateCase(in: &session, queuedCase.id) { current in
                        current.status = .autoResolved
                        current.resolvedBy = "judge"
                    }
                    session.currentCode = revised
                    session.codeHistory.append(revised)
                } else {
                    updateCase(in: &session, queuedCase.id) { current in
                        current.status = .escalated
                        current.conflictExplanation = validation.details
                    }
                    session.stage = .waitingForDecision
                    persist(session)
                    return
                }
            } else {
                updateCase(in: &session, queuedCase.id) { current in
                    current.status = .escalated
                    current.resolvedBy = nil
                }
                session.stage = .waitingForDecision
                persist(session)
                return
            }

            session.currentQueueIndex += 1
            persist(session)
        }

        session.queuedCaseIDs = []
        session.currentQueueIndex = 0
        session.stage = session.currentRound >= session.maxRounds ? .completed : .roundComplete
        persist(session)
    }

    private func applyEscalationDecision(_ decision: String) async {
        guard var session = selectedSession else { return }
        guard let escalation = session.activeEscalation else { return }
        guard !decision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a short decision so the app can convert it into binding precedent."
            return
        }

        isWorking = true
        errorMessage = nil

        do {
            let precedent = "[Case \(escalation.title)] \(decision.trimmingCharacters(in: .whitespacesAndNewlines))"
            session.userClarifications.append(precedent)

            updateCase(in: &session, escalation.id) { current in
                current.status = .userResolved
                current.resolvedBy = "user"
                current.resolutionSummary = decision.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let resolvedCase = session.cases.first(where: { $0.id == escalation.id })!
            let revised = try await client(for: session.providerMode).reviseCode(for: session, dueTo: resolvedCase)
            session.currentCode = revised
            session.codeHistory.append(revised)
            session.currentQueueIndex += 1

            persist(session)
            try await processQueuedCases(for: &session)
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    private func persist(_ session: SessionRecord) {
        var updated = session
        updated.updatedAt = Date()

        if let index = sessions.firstIndex(where: { $0.id == updated.id }) {
            sessions[index] = updated
        } else {
            sessions.insert(updated, at: 0)
        }

        try? store.save(updated)
    }

    private func updateCase(in session: inout SessionRecord, _ id: String, change: (inout CaseRecord) -> Void) {
        guard let index = session.cases.firstIndex(where: { $0.id == id }) else { return }
        change(&session.cases[index])
    }

    private func sessionID(for domain: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(domain.replacingOccurrences(of: " ", with: "_"))_\(formatter.string(from: Date()))"
    }

    private func resetDraft() {
        draft = SessionDraft()
    }
}
