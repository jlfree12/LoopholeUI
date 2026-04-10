import Foundation

enum SidebarItem: Hashable {
    case start
    case session(String)
    case settings
}

enum ProviderMode: String, Codable, CaseIterable, Identifiable {
    case guidedDemo = "Guided Demo"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .guidedDemo:
            return "Guided Demo"
        case .anthropic:
            return "Claude"
        case .openAI:
            return "ChatGPT"
        }
    }

    var subtitle: String {
        switch self {
        case .guidedDemo:
            return "Lets someone experience the full loop immediately with curated mock AI outputs."
        case .anthropic:
            return "Runs the live Loophole workflow with Claude so each round is generated fresh."
        case .openAI:
            return "Runs the live Loophole workflow with ChatGPT so each round is generated fresh."
        }
    }
}

enum LiveProvider: String, CaseIterable, Identifiable {
    case anthropic = "Claude"
    case openAI = "ChatGPT"

    var id: String { rawValue }

    var providerMode: ProviderMode {
        switch self {
        case .anthropic:
            return .anthropic
        case .openAI:
            return .openAI
        }
    }

    init(mode: ProviderMode) {
        switch mode {
        case .anthropic:
            self = .anthropic
        case .openAI:
            self = .openAI
        case .guidedDemo:
            self = .anthropic
        }
    }
}

enum WorkflowStage: String, Codable, CaseIterable {
    case onboarding
    case drafting
    case findingLoopholes
    case findingOverreach
    case judging
    case waitingForDecision
    case roundComplete
    case completed

    var title: String {
        switch self {
        case .onboarding:
            return "Principles"
        case .drafting:
            return "Legislator"
        case .findingLoopholes:
            return "Loophole Finder"
        case .findingOverreach:
            return "Overreach Finder"
        case .judging:
            return "Judge"
        case .waitingForDecision:
            return "Your Decision"
        case .roundComplete:
            return "Round Review"
        case .completed:
            return "Finished"
        }
    }

    var explanation: String {
        switch self {
        case .onboarding:
            return "Capture the user’s domain and moral principles in plain language."
        case .drafting:
            return "Turn the principles into a formal legal code."
        case .findingLoopholes:
            return "Search for conduct that is legal under the code but morally wrong."
        case .findingOverreach:
            return "Search for conduct the code blocks even though it feels morally acceptable."
        case .judging:
            return "Try to patch the code without breaking previous decisions."
        case .waitingForDecision:
            return "Escalate true tensions in the user’s framework back to the user."
        case .roundComplete:
            return "Summarize what changed and invite the next round."
        case .completed:
            return "Wrap up the session and preserve the final code and precedents."
        }
    }
}

enum CaseKind: String, Codable, CaseIterable {
    case loophole
    case overreach

    var displayName: String {
        switch self {
        case .loophole:
            return "Loophole"
        case .overreach:
            return "Overreach"
        }
    }

    var userLabel: String {
        switch self {
        case .loophole:
            return "Legal but morally wrong"
        case .overreach:
            return "Illegal but morally acceptable"
        }
    }
}

enum CaseStatus: String, Codable {
    case pending
    case autoResolved
    case escalated
    case userResolved
}

struct LegalCode: Codable, Equatable {
    var version: Int
    var text: String
    var changelog: String
}

struct CaseRecord: Codable, Identifiable, Equatable {
    var id: String
    var round: Int
    var kind: CaseKind
    var status: CaseStatus
    var title: String
    var scenario: String
    var explanation: String
    var reasoning: String
    var resolutionSummary: String?
    var proposedRevision: String?
    var conflictExplanation: String?
    var resolvedBy: String?
    var createdAt: Date
}

struct SessionRecord: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var domain: String
    var moralPrinciples: String
    var providerMode: ProviderMode
    var hasReviewedDraft: Bool
    var currentRound: Int
    var maxRounds: Int
    var stage: WorkflowStage
    var currentCode: LegalCode
    var codeHistory: [LegalCode]
    var cases: [CaseRecord]
    var queuedCaseIDs: [String]
    var currentQueueIndex: Int
    var userClarifications: [String]
    var createdAt: Date
    var updatedAt: Date

    var activeEscalation: CaseRecord? {
        cases.first(where: { $0.status == .escalated })
    }

    var autoResolvedCount: Int {
        cases.filter { $0.status == .autoResolved }.count
    }

    var userResolvedCount: Int {
        cases.filter { $0.status == .userResolved }.count
    }

    var hasPendingQueue: Bool {
        currentQueueIndex < queuedCaseIDs.count
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case domain
        case moralPrinciples
        case providerMode
        case hasReviewedDraft
        case currentRound
        case maxRounds
        case stage
        case currentCode
        case codeHistory
        case cases
        case queuedCaseIDs
        case currentQueueIndex
        case userClarifications
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        title: String,
        domain: String,
        moralPrinciples: String,
        providerMode: ProviderMode,
        hasReviewedDraft: Bool,
        currentRound: Int,
        maxRounds: Int,
        stage: WorkflowStage,
        currentCode: LegalCode,
        codeHistory: [LegalCode],
        cases: [CaseRecord],
        queuedCaseIDs: [String],
        currentQueueIndex: Int,
        userClarifications: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.domain = domain
        self.moralPrinciples = moralPrinciples
        self.providerMode = providerMode
        self.hasReviewedDraft = hasReviewedDraft
        self.currentRound = currentRound
        self.maxRounds = maxRounds
        self.stage = stage
        self.currentCode = currentCode
        self.codeHistory = codeHistory
        self.cases = cases
        self.queuedCaseIDs = queuedCaseIDs
        self.currentQueueIndex = currentQueueIndex
        self.userClarifications = userClarifications
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        domain = try container.decode(String.self, forKey: .domain)
        moralPrinciples = try container.decode(String.self, forKey: .moralPrinciples)
        providerMode = try container.decode(ProviderMode.self, forKey: .providerMode)
        hasReviewedDraft = try container.decodeIfPresent(Bool.self, forKey: .hasReviewedDraft) ?? false
        currentRound = try container.decode(Int.self, forKey: .currentRound)
        maxRounds = try container.decode(Int.self, forKey: .maxRounds)
        stage = try container.decode(WorkflowStage.self, forKey: .stage)
        currentCode = try container.decode(LegalCode.self, forKey: .currentCode)
        codeHistory = try container.decode([LegalCode].self, forKey: .codeHistory)
        cases = try container.decode([CaseRecord].self, forKey: .cases)
        queuedCaseIDs = try container.decode([String].self, forKey: .queuedCaseIDs)
        currentQueueIndex = try container.decode(Int.self, forKey: .currentQueueIndex)
        userClarifications = try container.decode([String].self, forKey: .userClarifications)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct SessionDraft {
    var title: String = ""
    var domain: String = ""
    var principles: String = ""
    var maxRounds: Int = 5
}

struct PrincipleTemplate: Identifiable {
    let id: String
    let title: String
    let domain: String
    let prompt: String
    let principles: String
}

struct JudgeDecision {
    var resolvable: Bool
    var reasoning: String
    var resolutionSummary: String?
    var proposedRevision: String?
    var conflictExplanation: String?
}

struct ValidationResult {
    var passes: Bool
    var details: String
}

enum LoopholeClientError: LocalizedError {
    case missingAPIKey
    case malformedResponse
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add the selected live AI API key in Settings before starting a live session."
        case .malformedResponse:
            return "The AI response could not be understood. Try the round again."
        case .invalidState(let message):
            return message
        }
    }
}

extension PrincipleTemplate {
    static let all: [PrincipleTemplate] = [
        PrincipleTemplate(
            id: "privacy",
            title: "Data Privacy",
            domain: "privacy",
            prompt: "A student wants to test principles about consent, surveillance, and data sale.",
            principles: """
            People should have meaningful control over personal data about them.
            Organizations should not collect more data than they genuinely need.
            Sensitive data should never be sold, traded, or reused for unrelated purposes without explicit and informed consent.
            Emergency use of data can be justified, but only when the emergency is concrete, urgent, and narrowly documented.
            The law should protect people who report abuse, discrimination, or public danger even if an institution would prefer secrecy.
            """
        ),
        PrincipleTemplate(
            id: "speech",
            title: "Campus Speech",
            domain: "speech",
            prompt: "A law major wants to stress-test a policy balancing expression, harassment, and institutional safety.",
            principles: """
            People should be free to express unpopular political and moral views without punishment.
            Targeted harassment, credible threats, and coordinated intimidation should not be protected.
            Rules should distinguish between offense and genuine coercion.
            Institutions may place narrow time, place, and manner limits when they are viewpoint neutral and clearly justified.
            Emergency interventions should expire quickly and remain subject to review.
            """
        ),
        PrincipleTemplate(
            id: "policing",
            title: "Protest Policing",
            domain: "public order",
            prompt: "A social science student wants to examine protest rights, policing limits, and emergency powers.",
            principles: """
            Peaceful protest should be strongly protected even when it is disruptive or unpopular.
            Police powers should be limited, reviewable, and proportionate.
            Property damage and direct violence may justify intervention, but broad crackdowns on bystanders should be avoided.
            Surveillance of protest activity should require a strong justification and should not be used to chill dissent.
            Emergency powers should be temporary, documented, and harder to use against marginalized groups.
            """
        ),
        PrincipleTemplate(
            id: "migration",
            title: "Migration Ethics",
            domain: "migration",
            prompt: "A student wants to test moral principles about borders, asylum, family unity, and public safety.",
            principles: """
            People fleeing violence or persecution should have a real opportunity to seek protection.
            Families should not be separated except in narrowly justified and reviewable circumstances.
            States may regulate borders, but enforcement should respect dignity and due process.
            Administrative convenience alone should not justify severe hardship.
            Public safety risks matter, but restrictions should be individualized and evidence based rather than collective or indefinite.
            """
        )
    ]
}
