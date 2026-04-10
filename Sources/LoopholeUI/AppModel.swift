import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private enum SettingsKeys {
        static let anthropicModel = "settings.anthropicModel"
        static let openAIModel = "settings.openAIModel"
        static let maxTokens = "settings.maxTokens"
        static let legislatorTemperature = "settings.legislatorTemperature"
        static let loopholeFinderTemperature = "settings.loopholeFinderTemperature"
        static let overreachFinderTemperature = "settings.overreachFinderTemperature"
        static let judgeTemperature = "settings.judgeTemperature"
        static let defaultMaxRounds = "settings.defaultMaxRounds"
        static let casesPerAgent = "settings.casesPerAgent"
    }

    @Published var sessions: [SessionRecord] = []
    @Published var selection: SidebarItem? = .start
    @Published var sessionSearchText: String = ""
    @Published var draft = SessionDraft()
    @Published var providerMode: ProviderMode = .guidedDemo
    @Published var anthropicAPIKey: String = ""
    @Published var anthropicModel: String = "claude-sonnet-4-6"
    @Published var openAIAPIKey: String = ""
    @Published var openAIModel: String = "gpt-5.4-mini"
    @Published var maxTokens: Int = 4096
    @Published var legislatorTemperature: Double = 0.4
    @Published var loopholeFinderTemperature: Double = 0.9
    @Published var overreachFinderTemperature: Double = 0.9
    @Published var judgeTemperature: Double = 0.3
    @Published var defaultMaxRounds: Int = 10
    @Published var casesPerAgent: Int = 3
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let store = SessionStore()

    init() {
        let defaults = UserDefaults.standard
        anthropicAPIKey = SecretsStore.loadAnthropicKey()
        openAIAPIKey = SecretsStore.loadOpenAIKey()
        anthropicModel = defaults.string(forKey: SettingsKeys.anthropicModel) ?? anthropicModel
        openAIModel = defaults.string(forKey: SettingsKeys.openAIModel) ?? openAIModel
        let storedMaxTokens = defaults.integer(forKey: SettingsKeys.maxTokens)
        if storedMaxTokens > 0 {
            maxTokens = storedMaxTokens
        }
        if defaults.object(forKey: SettingsKeys.legislatorTemperature) != nil {
            legislatorTemperature = defaults.double(forKey: SettingsKeys.legislatorTemperature)
        }
        if defaults.object(forKey: SettingsKeys.loopholeFinderTemperature) != nil {
            loopholeFinderTemperature = defaults.double(forKey: SettingsKeys.loopholeFinderTemperature)
        }
        if defaults.object(forKey: SettingsKeys.overreachFinderTemperature) != nil {
            overreachFinderTemperature = defaults.double(forKey: SettingsKeys.overreachFinderTemperature)
        }
        if defaults.object(forKey: SettingsKeys.judgeTemperature) != nil {
            judgeTemperature = defaults.double(forKey: SettingsKeys.judgeTemperature)
        }
        let storedDefaultMaxRounds = defaults.integer(forKey: SettingsKeys.defaultMaxRounds)
        if storedDefaultMaxRounds > 0 {
            defaultMaxRounds = storedDefaultMaxRounds
        }
        let storedCasesPerAgent = defaults.integer(forKey: SettingsKeys.casesPerAgent)
        if storedCasesPerAgent > 0 {
            casesPerAgent = storedCasesPerAgent
        }

        draft.maxRounds = defaultMaxRounds
        sessions = sortedSessions(store.loadSessions())
    }

    var selectedSession: SessionRecord? {
        guard case let .session(id) = selection else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    var visibleActiveSessions: [SessionRecord] {
        filterSessions(isArchived: false)
    }

    var visibleArchivedSessions: [SessionRecord] {
        filterSessions(isArchived: true)
    }

    func applyTemplate(_ template: PrincipleTemplate) {
        draft.title = template.title
        draft.domain = template.domain
        draft.principles = template.principles
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        SecretsStore.saveAnthropicKey(anthropicAPIKey)
        SecretsStore.saveOpenAIKey(openAIAPIKey)
        defaults.set(anthropicModel, forKey: SettingsKeys.anthropicModel)
        defaults.set(openAIModel, forKey: SettingsKeys.openAIModel)
        defaults.set(maxTokens, forKey: SettingsKeys.maxTokens)
        defaults.set(legislatorTemperature, forKey: SettingsKeys.legislatorTemperature)
        defaults.set(loopholeFinderTemperature, forKey: SettingsKeys.loopholeFinderTemperature)
        defaults.set(overreachFinderTemperature, forKey: SettingsKeys.overreachFinderTemperature)
        defaults.set(judgeTemperature, forKey: SettingsKeys.judgeTemperature)
        defaults.set(defaultMaxRounds, forKey: SettingsKeys.defaultMaxRounds)
        defaults.set(casesPerAgent, forKey: SettingsKeys.casesPerAgent)

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.principles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.maxRounds = defaultMaxRounds
        }
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

    func beginFirstReview() {
        Task {
            guard var session = selectedSession else { return }
            guard !session.hasReviewedDraft else { return }
            session.hasReviewedDraft = true
            persist(session)
            await continueSession(skipCaseReviewGate: false)
        }
    }

    func skipAheadFromDraft() {
        Task {
            guard var session = selectedSession else { return }
            guard !session.hasReviewedDraft else { return }
            session.hasReviewedDraft = true
            persist(session)
            await continueSession(skipCaseReviewGate: true)
        }
    }

    func renameSession(id: String, to title: String) {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.title = trimmed
        persist(session)
    }

    func duplicateSession(id: String) {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        session.id = sessionID(for: session.domain)
        session.title = session.title + " Copy"
        session.createdAt = Date()
        session.updatedAt = Date()
        persist(session)
        selection = .session(session.id)
    }

    func togglePinned(id: String) {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        session.isPinned.toggle()
        persist(session)
    }

    func toggleArchived(id: String) {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        session.isArchived.toggle()
        persist(session)
        if session.isArchived, selection == .session(id) {
            selection = .start
        }
    }

    func deleteSession(id: String) {
        sessions.removeAll { $0.id == id }
        try? store.delete(id: id)
        if selection == .session(id) {
            selection = .start
        }
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

    func openSavedSessionsFolder() {
        NSWorkspace.shared.open(store.folderURL)
    }

    private func client(for mode: ProviderMode) -> LoopholeClient {
        let settings = LiveModelSettings(
            maxTokens: maxTokens,
            legislatorTemperature: legislatorTemperature,
            loopholeFinderTemperature: loopholeFinderTemperature,
            overreachFinderTemperature: overreachFinderTemperature,
            judgeTemperature: judgeTemperature,
            validationTemperature: 0.2
        )

        switch mode {
        case .guidedDemo:
            return DemoClient()
        case .anthropic:
            return AnthropicClient(apiKey: anthropicAPIKey, model: anthropicModel, settings: settings)
        case .openAI:
            return OpenAIClient(apiKey: openAIAPIKey, model: openAIModel, settings: settings)
        }
    }

    private func runStartSession() async {
        guard !draft.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a domain before starting. Examples: privacy, speech, migration."
            return
        }

        guard !draft.principles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add your moral principles so the Legislator has something concrete to draft from."
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
                isPinned: false,
                isArchived: false,
                hasReviewedDraft: false,
                currentRound: 0,
                maxRounds: draft.maxRounds,
                stage: .drafting,
                currentCode: LegalCode(version: 0, text: "Drafting in progress…", changelog: ""),
                codeHistory: [],
                cases: [],
                queuedCaseIDs: [],
                currentQueueIndex: 0,
                awaitingCaseReview: false,
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

    private func continueSession(skipCaseReviewGate: Bool = false) async {
        guard var session = selectedSession else { return }
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil

        do {
            if session.activeEscalation != nil {
                throw LoopholeClientError.invalidState("This round is waiting for the user's decision before it can continue.")
            }

            if session.awaitingCaseReview {
                session.awaitingCaseReview = false
                persist(session)
                try await processQueuedCases(for: &session)
            } else if session.hasPendingQueue {
                try await processQueuedCases(for: &session)
            } else {
                try await launchRound(for: &session, skipCaseReviewGate: skipCaseReviewGate)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    private func launchRound(for session: inout SessionRecord, skipCaseReviewGate: Bool) async throws {
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
        session.awaitingCaseReview = !skipCaseReviewGate
        persist(session)

        if !session.awaitingCaseReview {
            try await processQueuedCases(for: &session)
        }
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
        session.awaitingCaseReview = false
        session.stage = session.currentRound >= session.maxRounds ? .completed : .roundComplete
        persist(session)
    }

    private func applyEscalationDecision(_ decision: String) async {
        guard var session = selectedSession else { return }
        guard let escalation = session.activeEscalation else { return }
        guard !decision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a short ruling so the app can turn it into a precedent for later rounds."
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
            session.awaitingCaseReview = false

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
        sessions = sortedSessions(sessions)
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
        draft = SessionDraft(maxRounds: defaultMaxRounds)
    }

    private func filterSessions(isArchived: Bool) -> [SessionRecord] {
        let trimmedQuery = sessionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return sortedSessions(sessions)
            .filter { $0.isArchived == isArchived }
            .filter { session in
                guard !trimmedQuery.isEmpty else { return true }
                let haystacks = [
                    session.title,
                    session.domain,
                    session.moralPrinciples
                ]
                return haystacks.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            }
    }

    private func sortedSessions(_ records: [SessionRecord]) -> [SessionRecord] {
        records.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
