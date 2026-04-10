import Foundation

protocol LoopholeClient {
    func draftInitialCode(domain: String, principles: String, clarifications: [String]) async throws -> LegalCode
    func findCases(kind: CaseKind, session: SessionRecord, casesPerAgent: Int) async throws -> [CaseRecord]
    func judge(caseRecord: CaseRecord, in session: SessionRecord) async throws -> JudgeDecision
    func reviseCode(for session: SessionRecord, dueTo caseRecord: CaseRecord) async throws -> LegalCode
    func validate(candidateCode: LegalCode, in session: SessionRecord) async throws -> ValidationResult
}

struct AnthropicClient: LoopholeClient {
    let apiKey: String
    let model: String

    func draftInitialCode(domain: String, principles: String, clarifications: [String]) async throws -> LegalCode {
        let payload: LegislatorPayload = try await requestJSON(
            system: "You faithfully convert moral principles into a legal code.",
            user: PromptBuilder.legislatorPrompt(domain: domain, principles: principles, clarifications: clarifications),
            temperature: 0.4
        )

        return LegalCode(version: 1, text: payload.codeText, changelog: payload.changelog)
    }

    func findCases(kind: CaseKind, session: SessionRecord, casesPerAgent: Int) async throws -> [CaseRecord] {
        let payload: CasesPayload = try await requestJSON(
            system: "You generate adversarial test cases for a legal code.",
            user: PromptBuilder.adversaryPrompt(kind: kind, session: session, casesPerAgent: casesPerAgent),
            temperature: 0.8
        )

        return payload.cases.enumerated().map { index, item in
            CaseRecord(
                id: "\(session.id)-r\(session.currentRound)-\(kind.rawValue)-\(index)",
                round: session.currentRound,
                kind: kind,
                status: .pending,
                title: item.title,
                scenario: item.scenario,
                explanation: item.explanation,
                reasoning: "",
                resolutionSummary: nil,
                proposedRevision: nil,
                conflictExplanation: nil,
                resolvedBy: nil,
                createdAt: Date()
            )
        }
    }

    func judge(caseRecord: CaseRecord, in session: SessionRecord) async throws -> JudgeDecision {
        let payload: JudgePayload = try await requestJSON(
            system: "You are a careful judge preserving precedent and consistency.",
            user: PromptBuilder.judgePrompt(session: session, caseRecord: caseRecord),
            temperature: 0.3
        )

        return JudgeDecision(
            resolvable: payload.resolvable,
            reasoning: payload.reasoning,
            resolutionSummary: payload.resolutionSummary,
            proposedRevision: payload.proposedRevision,
            conflictExplanation: payload.conflictExplanation
        )
    }

    func reviseCode(for session: SessionRecord, dueTo caseRecord: CaseRecord) async throws -> LegalCode {
        let instruction = caseRecord.resolutionSummary ?? caseRecord.proposedRevision ?? caseRecord.reasoning
        let payload: LegislatorPayload = try await requestJSON(
            system: "You revise an existing legal code while preserving precedent.",
            user: PromptBuilder.legislatorPrompt(
                domain: session.domain,
                principles: session.moralPrinciples,
                clarifications: session.userClarifications + ["Resolve case '\(caseRecord.title)' by incorporating this instruction: \(instruction)"]
            ) + "\n\nCurrent legal code to revise:\n\(session.currentCode.text)",
            temperature: 0.4
        )

        return LegalCode(
            version: session.currentCode.version + 1,
            text: payload.codeText,
            changelog: payload.changelog
        )
    }

    func validate(candidateCode: LegalCode, in session: SessionRecord) async throws -> ValidationResult {
        let payload: ValidationPayload = try await requestJSON(
            system: "You validate revisions against precedent.",
            user: PromptBuilder.validationPrompt(session: session, candidateCode: candidateCode.text),
            temperature: 0.2
        )

        return ValidationResult(passes: payload.passes, details: payload.details)
    }

    private func requestJSON<T: Decodable>(system: String, user: String, temperature: Double) async throws -> T {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LoopholeClientError.missingAPIKey
        }

        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: 4096,
            system: system,
            messages: [AnthropicMessage(role: "user", content: user)],
            temperature: temperature
        )

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LoopholeClientError.invalidState(String(data: data, encoding: .utf8) ?? "Live AI request failed.")
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.compactMap(\.text).joined(separator: "\n")
        let json = try extractJSONObject(from: text)
        let jsonData = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    private func extractJSONObject(from text: String) throws -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw LoopholeClientError.malformedResponse
        }

        return String(text[start...end])
    }
}

struct OpenAIClient: LoopholeClient {
    let apiKey: String
    let model: String

    func draftInitialCode(domain: String, principles: String, clarifications: [String]) async throws -> LegalCode {
        let payload: LegislatorPayload = try await requestJSON(
            system: "You faithfully convert moral principles into a legal code.",
            user: PromptBuilder.legislatorPrompt(domain: domain, principles: principles, clarifications: clarifications),
            temperature: 0.4
        )

        return LegalCode(version: 1, text: payload.codeText, changelog: payload.changelog)
    }

    func findCases(kind: CaseKind, session: SessionRecord, casesPerAgent: Int) async throws -> [CaseRecord] {
        let payload: CasesPayload = try await requestJSON(
            system: "You generate adversarial test cases for a legal code.",
            user: PromptBuilder.adversaryPrompt(kind: kind, session: session, casesPerAgent: casesPerAgent),
            temperature: 0.8
        )

        return payload.cases.enumerated().map { index, item in
            CaseRecord(
                id: "\(session.id)-r\(session.currentRound)-\(kind.rawValue)-openai-\(index)",
                round: session.currentRound,
                kind: kind,
                status: .pending,
                title: item.title,
                scenario: item.scenario,
                explanation: item.explanation,
                reasoning: "",
                resolutionSummary: nil,
                proposedRevision: nil,
                conflictExplanation: nil,
                resolvedBy: nil,
                createdAt: Date()
            )
        }
    }

    func judge(caseRecord: CaseRecord, in session: SessionRecord) async throws -> JudgeDecision {
        let payload: JudgePayload = try await requestJSON(
            system: "You are a careful judge preserving precedent and consistency.",
            user: PromptBuilder.judgePrompt(session: session, caseRecord: caseRecord),
            temperature: 0.3
        )

        return JudgeDecision(
            resolvable: payload.resolvable,
            reasoning: payload.reasoning,
            resolutionSummary: payload.resolutionSummary,
            proposedRevision: payload.proposedRevision,
            conflictExplanation: payload.conflictExplanation
        )
    }

    func reviseCode(for session: SessionRecord, dueTo caseRecord: CaseRecord) async throws -> LegalCode {
        let instruction = caseRecord.resolutionSummary ?? caseRecord.proposedRevision ?? caseRecord.reasoning
        let payload: LegislatorPayload = try await requestJSON(
            system: "You revise an existing legal code while preserving precedent.",
            user: PromptBuilder.legislatorPrompt(
                domain: session.domain,
                principles: session.moralPrinciples,
                clarifications: session.userClarifications + ["Resolve case '\(caseRecord.title)' by incorporating this instruction: \(instruction)"]
            ) + "\n\nCurrent legal code to revise:\n\(session.currentCode.text)",
            temperature: 0.4
        )

        return LegalCode(
            version: session.currentCode.version + 1,
            text: payload.codeText,
            changelog: payload.changelog
        )
    }

    func validate(candidateCode: LegalCode, in session: SessionRecord) async throws -> ValidationResult {
        let payload: ValidationPayload = try await requestJSON(
            system: "You validate revisions against precedent.",
            user: PromptBuilder.validationPrompt(session: session, candidateCode: candidateCode.text),
            temperature: 0.2
        )

        return ValidationResult(passes: payload.passes, details: payload.details)
    }

    private func requestJSON<T: Decodable>(system: String, user: String, temperature: Double) async throws -> T {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LoopholeClientError.missingAPIKey
        }

        let combinedPrompt = """
        System instructions:
        \(system)

        User request:
        \(user)

        Return only valid JSON.
        """

        let requestBody = OpenAIResponsesRequest(
            model: model,
            input: combinedPrompt,
            temperature: temperature,
            maxOutputTokens: 4096
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LoopholeClientError.invalidState(String(data: data, encoding: .utf8) ?? "Live AI request failed.")
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        let text = decoded.outputText ?? decoded.output.compactMap { item in
            item.content.compactMap(\.text).joined(separator: "\n")
        }.joined(separator: "\n")
        let json = try extractJSONObject(from: text)
        let jsonData = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    private func extractJSONObject(from text: String) throws -> String {
        guard let objectStart = text.firstIndex(of: "{"),
              let objectEnd = text.lastIndex(of: "}") else {
            throw LoopholeClientError.malformedResponse
        }

        return String(text[objectStart...objectEnd])
    }
}

struct DemoClient: LoopholeClient {
    func draftInitialCode(domain: String, principles: String, clarifications: [String]) async throws -> LegalCode {
        let clauses = principles
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { "Section \($0.offset + 1). \($0.element)" }
            .joined(separator: "\n\n")

        let clarificationText = clarifications.isEmpty ? "" : "\n\nPrecedent Notes:\n" + clarifications.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        return LegalCode(
            version: 1,
            text: """
            Code for \(domain.capitalized)

            Purpose
            This code operationalizes the user's moral principles for \(domain).

            Core Rules
            \(clauses)

            Procedure
            Institutions applying this code must document reasons, use narrow interventions, and preserve review rights.
            \(clarificationText)
            """,
            changelog: "Created the initial code from the user’s stated moral principles."
        )
    }

    func findCases(kind: CaseKind, session: SessionRecord, casesPerAgent: Int) async throws -> [CaseRecord] {
        let seeds: [(String, String, String)] = kind == .loophole
            ? [
                (
                    "Institutional Workaround",
                    "An institution re-labels a harmful practice as a temporary pilot program so it fits outside the code's current definitions.",
                    "The code protects the principle in spirit, but the definitions leave room for semantic relabeling."
                ),
                (
                    "Emergency Exception Drift",
                    "Officials invoke an emergency exception for a routine administrative problem and keep using it for months.",
                    "The code allows flexibility in emergencies, but it may not cabin what counts as urgent or temporary."
                )
            ]
            : [
                (
                    "Helpful Technical Violation",
                    "A person shares restricted information with an oversight body to expose abuse, even though the act technically violates the code.",
                    "The code may be overbroad because it blocks principled whistleblowing that the user likely wants to protect."
                ),
                (
                    "Good Samaritan Constraint",
                    "A bystander breaks a procedural rule to prevent imminent harm and then reports the action immediately afterward.",
                    "The code may punish responsible emergency action that aligns with the user's deeper values."
                )
            ]

        return seeds.prefix(casesPerAgent).enumerated().map { index, item in
            CaseRecord(
                id: "\(session.id)-r\(session.currentRound)-\(kind.rawValue)-demo-\(index)",
                round: session.currentRound,
                kind: kind,
                status: .pending,
                title: item.0,
                scenario: item.1,
                explanation: item.2,
                reasoning: "",
                resolutionSummary: nil,
                proposedRevision: nil,
                conflictExplanation: nil,
                resolvedBy: nil,
                createdAt: Date()
            )
        }
    }

    func judge(caseRecord: CaseRecord, in session: SessionRecord) async throws -> JudgeDecision {
        if caseRecord.title.contains("Emergency") || caseRecord.title.contains("Good Samaritan") {
            return JudgeDecision(
                resolvable: false,
                reasoning: "A simple patch risks either making the exception too broad or punishing acts the user likely values.",
                resolutionSummary: nil,
                proposedRevision: nil,
                conflictExplanation: "This case exposes a real tension between flexibility in emergencies and fear of abuse. The app should ask the user which value takes priority and under what constraints."
            )
        }

        let fix = caseRecord.kind == .loophole
            ? "Tighten definitions, require documented justification, and add an anti-evasion clause."
            : "Add a narrow public-interest and emergency-defense exception with review."

        return JudgeDecision(
            resolvable: true,
            reasoning: "The case can be handled with a targeted amendment that preserves prior precedents.",
            resolutionSummary: fix,
            proposedRevision: fix,
            conflictExplanation: nil
        )
    }

    func reviseCode(for session: SessionRecord, dueTo caseRecord: CaseRecord) async throws -> LegalCode {
        let revision = caseRecord.resolutionSummary ?? caseRecord.reasoning

        return LegalCode(
            version: session.currentCode.version + 1,
            text: """
            \(session.currentCode.text)

            Amendment v\(session.currentCode.version + 1)
            \(revision)
            """,
            changelog: "Updated the code in response to '\(caseRecord.title)'."
        )
    }

    func validate(candidateCode: LegalCode, in session: SessionRecord) async throws -> ValidationResult {
        ValidationResult(passes: true, details: "The revised code remains consistent with the precedents recorded so far.")
    }
}

private struct LegislatorPayload: Decodable {
    let title: String
    let codeText: String
    let changelog: String

    private enum CodingKeys: String, CodingKey {
        case title
        case codeText = "code_text"
        case changelog
    }
}

private struct CasesPayload: Decodable {
    let cases: [GeneratedCase]
}

private struct GeneratedCase: Decodable {
    let title: String
    let scenario: String
    let explanation: String
}

private struct JudgePayload: Decodable {
    let resolvable: Bool
    let reasoning: String
    let resolutionSummary: String?
    let proposedRevision: String?
    let conflictExplanation: String?

    private enum CodingKeys: String, CodingKey {
        case resolvable
        case reasoning
        case resolutionSummary = "resolution_summary"
        case proposedRevision = "proposed_revision"
        case conflictExplanation = "conflict_explanation"
    }
}

private struct ValidationPayload: Decodable {
    let passes: Bool
    let details: String
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let temperature: Double

    private enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case temperature
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String?
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: String
    let temperature: Double
    let maxOutputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case model
        case input
        case temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct OpenAIResponsesResponse: Decodable {
    let outputText: String?
    let output: [OpenAIOutputItem]

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIOutputContent]
}

private struct OpenAIOutputContent: Decodable {
    let text: String?
}
