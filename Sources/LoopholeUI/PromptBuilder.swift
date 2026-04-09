import Foundation

enum PromptBuilder {
    static func legislatorPrompt(domain: String, principles: String, clarifications: [String]) -> String {
        let priorClarifications = clarifications.isEmpty
            ? "None yet."
            : clarifications.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        return """
        You are the Legislator in the Loophole framework.
        Turn a person's moral principles into a legal code for the domain of \(domain).

        Requirements:
        - Write a coherent legal code that could actually be applied.
        - Preserve the user's values, not your own.
        - Prefer clear definitions, exceptions, review standards, and due-process rules.
        - Incorporate prior user clarifications as binding precedent.
        - Return valid JSON only.

        JSON shape:
        {
          "title": "short title",
          "code_text": "full legal code in plain English",
          "changelog": "one-paragraph summary of what changed"
        }

        Moral principles:
        \(principles)

        Binding clarifications:
        \(priorClarifications)
        """
    }

    static func adversaryPrompt(kind: CaseKind, session: SessionRecord, casesPerAgent: Int) -> String {
        let attackGoal: String
        switch kind {
        case .loophole:
            attackGoal = "Find scenarios that are technically legal under the current code but morally wrong under the user's principles."
        case .overreach:
            attackGoal = "Find scenarios that the code forbids even though the user's principles would likely allow them."
        }

        return """
        You are the \(kind.displayName) Finder in the Loophole framework.
        \(attackGoal)

        Requirements:
        - Generate exactly \(casesPerAgent) strong test cases.
        - Use concrete, realistic situations rather than abstract puzzles.
        - Avoid repeating earlier cases unless a new angle makes the conflict sharper.
        - Return valid JSON only.

        JSON shape:
        {
          "cases": [
            {
              "title": "short label",
              "scenario": "specific fact pattern",
              "explanation": "why this is a failure of the code"
            }
          ]
        }

        Domain:
        \(session.domain)

        Moral principles:
        \(session.moralPrinciples)

        Current legal code:
        \(session.currentCode.text)

        Existing precedents:
        \(precedentText(from: session))
        """
    }

    static func judgePrompt(session: SessionRecord, caseRecord: CaseRecord) -> String {
        return """
        You are the Judge in the Loophole framework.
        Evaluate whether the following case can be resolved with a code revision that respects all prior precedents.

        Requirements:
        - If a consistent fix exists, mark it resolvable and explain the patch.
        - If any plausible fix would conflict with earlier rulings or principles, mark it not resolvable and explain the tension.
        - Return valid JSON only.

        JSON shape:
        {
          "resolvable": true,
          "reasoning": "short explanation",
          "resolution_summary": "what the fix would do",
          "proposed_revision": "one-paragraph drafting instruction",
          "conflict_explanation": "only if resolvable is false"
        }

        Domain:
        \(session.domain)

        Moral principles:
        \(session.moralPrinciples)

        Current legal code:
        \(session.currentCode.text)

        Existing precedents:
        \(precedentText(from: session))

        Case:
        Type: \(caseRecord.kind.displayName)
        Title: \(caseRecord.title)
        Scenario: \(caseRecord.scenario)
        Problem: \(caseRecord.explanation)
        """
    }

    static func validationPrompt(session: SessionRecord, candidateCode: String) -> String {
        return """
        You are validating a revised legal code against established precedents in the Loophole framework.

        Requirements:
        - Decide whether the revised code is consistent with every resolved case.
        - Return valid JSON only.

        JSON shape:
        {
          "passes": true,
          "details": "brief explanation"
        }

        Candidate code:
        \(candidateCode)

        Resolved precedents:
        \(precedentText(from: session))
        """
    }

    private static func precedentText(from session: SessionRecord) -> String {
        let precedents = session.cases.filter { $0.status == .autoResolved || $0.status == .userResolved }
        guard !precedents.isEmpty else { return "No precedents yet." }

        return precedents.map {
            "[Round \($0.round)] \($0.kind.displayName): \($0.title)\nScenario: \($0.scenario)\nResolution: \($0.resolutionSummary ?? $0.reasoning)"
        }
        .joined(separator: "\n\n")
    }
}
