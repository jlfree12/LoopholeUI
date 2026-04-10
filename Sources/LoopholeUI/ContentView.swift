import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Something needs attention", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var sidebar: some View {
        List {
            Section("Workspace") {
                sidebarButton(
                    title: "New Session",
                    subtitle: "Start a new Loophole analysis",
                    systemImage: "square.and.pencil",
                    selection: .start
                ) {
                    model.showNewSession()
                }
                sidebarButton(
                    title: "Settings",
                    subtitle: "Live AI and app preferences",
                    systemImage: "gearshape",
                    selection: .settings
                ) {
                    model.showSettings()
                }
            }

            Section("Saved Sessions") {
                if model.sessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.sessions) { session in
                        sidebarButton(
                            title: session.title,
                            subtitle: "Round \(session.currentRound) of \(session.maxRounds)",
                            systemImage: "doc.text",
                            selection: .session(session.id)
                        ) {
                            model.showSession(id: session.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Loophole")
    }

    private func sidebarButton(
        title: String,
        subtitle: String,
        systemImage: String,
        selection: SidebarItem,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected(selection) ? Color.white : AppPalette.ink)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected(selection) ? Color.white.opacity(0.85) : .secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected(selection) ? AppPalette.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ item: SidebarItem) -> Bool {
        model.selection == item
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection ?? .start {
        case .start:
            NewSessionView(model: model)
        case .settings:
            SettingsView(model: model)
        case .session(let id):
            if let session = model.sessions.first(where: { $0.id == id }) {
                SessionDetailView(model: model, session: session)
            } else {
                EmptyStateView(
                    title: "Session not found",
                    subtitle: "Pick another saved session or start a new one."
                )
            }
        }
    }
}

private struct NewSessionView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                templates
                principleGuidance
                composer
            }
            .padding(28)
        }
        .background(AppPalette.canvas)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stress-test a moral framework without touching Terminal")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(AppPalette.ink)
            Text("This app walks the user through the full Loophole method: write principles, convert them into a legal code, attack that code with loophole and overreach cases, then resolve or escalate the hardest tensions.")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(WorkflowStage.allCases.filter { $0 != .onboarding && $0 != .completed }, id: \.rawValue) { stage in
                    StageChip(title: stage.title, subtitle: stagePreview(stage), state: .upcoming)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Starter Templates")
                .font(.title2.weight(.semibold))
            Text("These are written for non-technical users so they can begin with a real domain and edit from there.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(PrincipleTemplate.all) { template in
                    Button {
                        model.applyTemplate(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(template.title)
                                .font(.headline)
                                .foregroundStyle(AppPalette.ink)
                            Text(template.prompt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(template.domain.capitalized)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppPalette.accent.opacity(0.10), in: Capsule())
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                        .padding(18)
                        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppPalette.rule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Session Builder")
                .font(.title2.weight(.semibold))

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField("Session Title") {
                        TextField("Example: Campus Speech Stress Test", text: $model.draft.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    labeledField("Domain") {
                        TextField("Example: privacy, speech, public order, migration", text: $model.draft.domain)
                            .textFieldStyle(.roundedBorder)
                    }

                    labeledField("How many rounds should the app run?") {
                        Picker("Rounds", selection: $model.draft.maxRounds) {
                            ForEach([3, 4, 5, 6, 8], id: \.self) { value in
                                Text("\(value) rounds").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    labeledField("AI Mode") {
                        Picker("Mode", selection: $model.providerMode) {
                            ForEach(ProviderMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(model.providerMode.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 320)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Moral Principles")
                        .font(.headline)
                    Text("Write the user’s principles in plain language. The app will pass them into the Legislator exactly as written, so specificity helps.")
                        .foregroundStyle(.secondary)
                    TextEditor(text: $model.draft.principles)
                        .font(AppTypography.documentBody)
                        .frame(minHeight: 250)
                        .padding(12)
                        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppPalette.rule, lineWidth: 1)
                        )
                }
            }

            HStack {
                Button(model.isWorking ? "Starting…" : "Start Session") {
                    model.startSession()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)

                Text("The user will move into a guided round-by-round workspace after the first draft is ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private var principleGuidance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing Good Principles")
                .font(.title3.weight(.semibold))
            Text("These guidelines mirror the original Loophole project, but in a friendlier format.")
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                guidanceCard(
                    title: "Be specific enough",
                    detail: "Instead of 'I believe in fairness,' say what actors may or may not do, under what conditions, and why."
                )
                guidanceCard(
                    title: "Cover tensions",
                    detail: "Include multiple values that can collide, like privacy and emergency access, or speech and intimidation."
                )
                guidanceCard(
                    title: "Be honest",
                    detail: "The best escalations come from principles the user actually believes, not what sounds ideal in the abstract."
                )
            }
        }
        .padding(24)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func guidanceCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppPalette.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func stagePreview(_ stage: WorkflowStage) -> String {
        switch stage {
        case .drafting:
            return "Legislator"
        case .findingLoopholes:
            return "Legal but wrong"
        case .findingOverreach:
            return "Illegal but okay"
        case .judging:
            return "Repair or reject"
        case .waitingForDecision:
            return "Escalate"
        case .roundComplete:
            return "Review"
        case .onboarding, .completed:
            return ""
        }
    }
}

private struct SessionDetailView: View {
    @ObservedObject var model: AppModel
    let session: SessionRecord
    @State private var decisionText = ""
    @State private var selectedPanel = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                loopNarrative
                stageBoard
                if let escalation = session.activeEscalation {
                    escalationPanel(escalation)
                } else {
                    actionPanel
                }
                panelPicker
                panelContent
            }
            .padding(28)
        }
        .background(AppPalette.canvas)
        .onAppear {
            if session.currentRound == 0 && selectedPanel == 0 {
                selectedPanel = session.hasReviewedDraft ? 0 : 2
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.title)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(AppPalette.ink)
            HStack(spacing: 12) {
                MetaBadge(text: session.domain.capitalized)
                MetaBadge(text: "Round \(session.currentRound) of \(session.maxRounds)")
                MetaBadge(text: session.providerMode.displayName)
                MetaBadge(text: "\(session.autoResolvedCount) auto-resolved")
                MetaBadge(text: "\(session.userResolvedCount) user decisions")
            }
            Text("The app is following the original Loophole loop: principles to legislator, adversarial attacks, judge review, then resolution or escalation.")
                .foregroundStyle(.secondary)
        }
    }

    private var loopNarrative: some View {
        let summary = guidanceSummary
        return HStack(alignment: .top, spacing: 20) {
            NarrativeBlock(title: "Previous", text: summary.previous)
            NarrativeBlock(title: "Current", text: summary.current)
            NarrativeBlock(title: "Next", text: summary.next)
        }
    }

    private var stageBoard: some View {
        HStack(spacing: 12) {
            ForEach(loopStages, id: \.rawValue) { stage in
                StageChip(
                    title: stage.title,
                    subtitle: stageSubtitle(stage),
                    state: chipState(for: stage)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.sheet)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private var actionPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(actionHeadline)
                    .font(.title3.weight(.semibold))
                Text(actionDescription)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(primaryActionLabel) {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking || session.stage == .completed)

                if shouldShowShortcut {
                    Button(model.isWorking ? "Working…" : "Skip Ahead") {
                        model.runNextStep()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .disabled(model.isWorking || session.stage == .completed)
                    .help("Shortcut: skip the guided pacing and jump directly into adversarial review.")
                }
            }
        }
        .padding(22)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private func escalationPanel(_ escalation: CaseRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This round needs the user’s judgment")
                .font(.title3.weight(.semibold))
            Text("The Judge could not patch this case without creating a conflict. The app should now collect a plain-language decision and turn it into binding precedent.")
                .foregroundStyle(.secondary)

            CaseCard(caseRecord: escalation, emphasize: true)

            if let conflict = escalation.conflictExplanation {
                Text(conflict)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            TextEditor(text: $decisionText)
                .font(AppTypography.documentBody)
                .frame(minHeight: 130)
                .padding(12)
                .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.rule, lineWidth: 1)
                )

            HStack {
                Button(model.isWorking ? "Applying…" : "Use This Decision") {
                    model.resolveEscalation(with: decisionText)
                    decisionText = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)

                Text("Example: Emergency exceptions should be allowed only for imminent, documented threats and must expire quickly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var panelPicker: some View {
        Picker("Panel", selection: $selectedPanel) {
            Text("Overview").tag(0)
            Text("Cases").tag(1)
            Text("Current Code").tag(2)
            Text("Precedents").tag(3)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch selectedPanel {
        case 0:
            overviewPanel
        case 1:
            casesPanel
        case 2:
            codePanel
        default:
            precedentsPanel
        }
    }

    private var overviewPanel: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Moral Principles")
                    .font(.headline)
                ReadableDocument(text: session.moralPrinciples)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Latest Code Summary")
                    .font(.headline)
                ReadableDocument(text: session.currentCode.changelog.isEmpty ? "No updates yet." : session.currentCode.changelog)
                Text("Code version v\(session.currentCode.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var casesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.cases.isEmpty {
                EmptyStateView(title: "No cases yet", subtitle: "Run the first round to let the loophole and overreach finders attack the code.")
            } else {
                ForEach(Array(session.cases.reversed())) { item in
                    CaseCard(caseRecord: item, emphasize: false)
                }
            }
        }
    }

    private var codePanel: some View {
        ReadableDocument(text: session.currentCode.text)
    }

    private var precedentsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.userClarifications.isEmpty && session.autoResolvedCount == 0 {
                EmptyStateView(title: "No precedents yet", subtitle: "Resolved cases and user decisions will accumulate here as the code gets tighter.")
            } else {
                if !session.userClarifications.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("User Decisions")
                            .font(.headline)
                        ForEach(Array(session.userClarifications.enumerated()), id: \.offset) { _, note in
                            Text(note)
                                .font(AppTypography.documentBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppPalette.rule, lineWidth: 1)
                                )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Resolved Cases")
                        .font(.headline)
                    ForEach(session.cases.filter { $0.status == .autoResolved || $0.status == .userResolved }) { item in
                        Text("\(item.title): \(item.resolutionSummary ?? item.reasoning)")
                            .font(AppTypography.documentBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppPalette.rule, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                Text("Guided Demo mode works immediately. Live AI mode lets the app generate fresh legislators, adversaries, and judges inside the app without Python or Terminal.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Live AI")
                        .font(.title3.weight(.semibold))
                    Picker("Provider", selection: $model.liveProvider) {
                        ForEach(LiveProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    if model.liveProvider == .anthropic {
                        SecureField("Claude API Key", text: $model.anthropicAPIKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Claude model", text: $model.anthropicModel)
                            .textFieldStyle(.roundedBorder)
                        Text("Claude keys remain saved even if you switch this toggle to ChatGPT.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        SecureField("ChatGPT API Key", text: $model.openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("ChatGPT model", text: $model.openAIModel)
                            .textFieldStyle(.roundedBorder)
                        Text("ChatGPT keys remain saved even if you switch this toggle back to Claude.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $model.casesPerAgent, in: 1...4) {
                        Text("Cases per finder: \(model.casesPerAgent)")
                    }

                    Button("Save Settings") {
                        model.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.rule, lineWidth: 1)
                )
            }
            .padding(28)
        }
        .background(AppPalette.canvas)
    }
}

private struct StageChip: View {
    let title: String
    let subtitle: String
    let state: StageChipState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(state == .current ? Color.white.opacity(0.86) : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(state == .current ? Color.white : AppPalette.ink)
    }

    private var backgroundColor: Color {
        switch state {
        case .current:
            return AppPalette.accent
        case .complete:
            return AppPalette.complete
        case .upcoming:
            return AppPalette.card
        }
    }
}

private struct MetaBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppPalette.card, in: Capsule())
    }
}

private struct CaseCard: View {
    let caseRecord: CaseRecord
    let emphasize: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(caseRecord.kind.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chipColor.opacity(0.14), in: Capsule())

                Text(caseRecord.status.rawValue.replacingOccurrences(of: "Resolved", with: " Resolved").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Round \(caseRecord.round)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(caseRecord.title)
                .font(AppTypography.cardTitle)
            Text(caseRecord.scenario)
                .font(AppTypography.documentBody)
            Text(caseRecord.explanation)
                .font(AppTypography.documentBody)
                .foregroundStyle(.secondary)

            if let summary = caseRecord.resolutionSummary {
                Divider()
                Text(summary)
                    .font(AppTypography.documentBody)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private var chipColor: Color {
        caseRecord.kind == .loophole ? .red : .orange
    }

    private var backgroundColor: Color {
        emphasize ? chipColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor)
    }
}

private struct ReadableDocument: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(AppTypography.documentBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(18)
        }
        .frame(minHeight: 260)
        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }
}

private struct NarrativeBlock: View {
    let title: String
    let text: String

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(text)
                .font(AppTypography.documentBody)
                .foregroundStyle(AppPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    var body: some View {
        bodyView
    }
}

private enum StageChipState: Equatable {
    case complete
    case current
    case upcoming
}

private enum AppPalette {
    static let canvas = Color(nsColor: NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.92, alpha: 1))
    static let sheet = Color(nsColor: NSColor(calibratedRed: 0.985, green: 0.98, blue: 0.965, alpha: 1))
    static let paper = Color.white
    static let card = Color(nsColor: NSColor(calibratedWhite: 0.93, alpha: 1))
    static let rule = Color(nsColor: NSColor(calibratedWhite: 0.80, alpha: 1))
    static let accent = Color(nsColor: NSColor(calibratedRed: 0.17, green: 0.23, blue: 0.33, alpha: 1))
    static let complete = Color(nsColor: NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.85, alpha: 1))
    static let ink = Color(nsColor: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1))
}

private enum AppTypography {
    static let documentBody = serif(size: 17)
    static let cardTitle = serif(size: 19, weight: .semibold)

    private static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if NSFont(name: "Times New Roman", size: size) != nil {
            return .custom("Times New Roman", size: size).weight(weight)
        }

        if NSFont(name: "Times", size: size) != nil {
            return .custom("Times", size: size).weight(weight)
        }

        return .system(size: size, weight: weight, design: .serif)
    }
}

private extension SessionDetailView {
    var loopStages: [WorkflowStage] {
        [.onboarding, .drafting, .findingLoopholes, .findingOverreach, .judging, .waitingForDecision]
    }

    var actionHeadline: String {
        if session.stage == .completed {
            return "Session complete"
        }
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return "Begin with the Legislator's draft"
        }
        if session.currentRound == 0 && session.stage == .drafting {
            return "Continue into the first adversarial round"
        }
        if session.stage == .roundComplete {
            return "Round complete"
        }
        return "Continue the loop"
    }

    var actionDescription: String {
        if session.stage == .completed {
            return "The code has been tightened through every planned round. Review the final code, cases, and precedents below."
        }
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return "The user should first read the legislation the app produced from their moral principles. After that, the app can begin testing it for loopholes and overreach."
        }
        if session.currentRound == 0 && session.stage == .drafting {
            return "Next, the Loophole Finder and Overreach Finder will probe this code. The Judge will then decide whether each failure can be fixed or must be escalated."
        }
        if session.stage == .roundComplete {
            return "This round's fixes are in place. The next round will search for new edge cases under the revised code."
        }
        return "Proceed through the next step of the Loophole loop."
    }

    var primaryActionLabel: String {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return "Start First Review"
        }
        if session.currentRound == 0 && session.stage == .drafting {
            return model.isWorking ? "Working…" : "Continue to Loophole Finder"
        }
        return model.isWorking ? "Working…" : "Continue Review"
    }

    var shouldShowShortcut: Bool {
        session.currentRound == 0 && !session.hasReviewedDraft
    }

    func primaryAction() {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            selectedPanel = 2
            model.markDraftReviewed()
            return
        }

        model.runNextStep()
    }

    var guidanceSummary: (previous: String, current: String, next: String) {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return (
                previous: "The user entered moral principles and the app converted them into a draft legal code.",
                current: "You are now reading the Legislator's draft so you can see exactly what rules were created.",
                next: "After this, the Loophole Finder will search for legal-but-wrong conduct, and the Overreach Finder will search for forbidden-but-acceptable conduct."
            )
        }

        switch session.stage {
        case .drafting:
            return (
                previous: "The Legislator has produced a first-pass code from the user's principles.",
                current: "You are at the handoff between the drafted code and the first adversarial test round.",
                next: "The app will generate loophole and overreach cases, then send them to the Judge."
            )
        case .findingLoopholes:
            return (
                previous: "The user reviewed the drafted code.",
                current: "The Loophole Finder is searching for conduct that remains legal even though it violates the user's values.",
                next: "The Overreach Finder will then look for conduct the code wrongly prohibits."
            )
        case .findingOverreach:
            return (
                previous: "The Loophole Finder generated adversarial edge cases.",
                current: "The Overreach Finder is searching for morally acceptable conduct the code blocks.",
                next: "The Judge will examine whether these failures can be repaired without contradiction."
            )
        case .judging:
            return (
                previous: "Both adversarial finders have completed their challenge cases.",
                current: "The Judge is deciding whether each problem can be patched consistently.",
                next: "Resolvable cases will update the code. Conflicts will be escalated back to the user."
            )
        case .waitingForDecision:
            return (
                previous: "The Judge found a conflict that could not be cleanly resolved.",
                current: "The user must now make a plain-language policy choice that becomes precedent.",
                next: "That decision will be folded back into the code before the loop continues."
            )
        case .roundComplete:
            return (
                previous: "This round's cases were reviewed and the code was revised where possible.",
                current: "You are reviewing the updated state of the code, cases, and precedents.",
                next: session.currentRound >= session.maxRounds ? "The workflow will end after this review." : "The next round will launch another set of loophole and overreach challenges."
            )
        case .completed:
            return (
                previous: "All planned rounds are complete.",
                current: "You are looking at the final record of principles, code, cases, and precedents.",
                next: "No further automated steps remain unless you start a new session."
            )
        case .onboarding:
            return (
                previous: "The user has not yet started a session.",
                current: "The app is waiting for moral principles.",
                next: "The Legislator will draft the initial code."
            )
        }
    }

    func chipState(for stage: WorkflowStage) -> StageChipState {
        let currentIndex = currentLoopIndex
        let stageIndex = loopStages.firstIndex(of: stage) ?? 0
        if stageIndex < currentIndex {
            return .complete
        }
        if stageIndex == currentIndex {
            return .current
        }
        return .upcoming
    }

    var currentLoopIndex: Int {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return 1
        }

        switch session.stage {
        case .onboarding:
            return 0
        case .drafting:
            return 1
        case .findingLoopholes:
            return 2
        case .findingOverreach:
            return 3
        case .judging, .roundComplete, .completed:
            return 4
        case .waitingForDecision:
            return 5
        }
    }

    func stageSubtitle(_ stage: WorkflowStage) -> String {
        switch stage {
        case .onboarding:
            return "Principles"
        case .drafting:
            return "Legislator"
        case .findingLoopholes:
            return "Legal but wrong"
        case .findingOverreach:
            return "Illegal but okay"
        case .judging:
            return "Repair or reject"
        case .waitingForDecision:
            return "Escalate"
        case .roundComplete:
            return "Review"
        case .completed:
            return "Done"
        }
    }
}
