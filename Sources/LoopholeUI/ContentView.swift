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
        List(selection: $model.selection) {
            Section("Workspace") {
                Label("New Session", systemImage: "sparkles.rectangle.stack")
                    .tag(Optional.some(SidebarItem.start))
                Label("Settings", systemImage: "gearshape")
                    .tag(Optional.some(SidebarItem.settings))
            }

            Section("Saved Sessions") {
                if model.sessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                            Text("Round \(session.currentRound) of \(session.maxRounds)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional.some(SidebarItem.session(session.id)))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Loophole")
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
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.98, green: 0.95, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stress-test a moral framework without touching Terminal")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text("This app walks the user through the full Loophole method: write principles, convert them into a legal code, attack that code with loophole and overreach cases, then resolve or escalate the hardest tensions.")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(WorkflowStage.allCases.filter { $0 != .onboarding && $0 != .completed }, id: \.rawValue) { stage in
                    StageChip(title: stage.title, isActive: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                            Text(template.prompt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(template.domain.capitalized)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                                Text(mode.rawValue).tag(mode)
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
                        .font(.body)
                        .frame(minHeight: 250)
                        .padding(12)
                        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            HStack(spacing: 12) {
                MetaBadge(text: session.domain.capitalized)
                MetaBadge(text: "Round \(session.currentRound) of \(session.maxRounds)")
                MetaBadge(text: session.providerMode.rawValue)
                MetaBadge(text: "\(session.autoResolvedCount) auto-resolved")
                MetaBadge(text: "\(session.userResolvedCount) user decisions")
            }
            Text("The app is following the original Loophole loop: principles to legislator, adversarial attacks, judge review, then resolution or escalation.")
                .foregroundStyle(.secondary)
        }
    }

    private var stageBoard: some View {
        HStack(spacing: 12) {
            ForEach([
                WorkflowStage.drafting,
                .findingLoopholes,
                .findingOverreach,
                .judging,
                .waitingForDecision,
                .roundComplete
            ], id: \.rawValue) { stage in
                StageChip(title: stage.title, isActive: session.stage == stage)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var actionPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.stage == .completed ? "Session complete" : "Continue the loop")
                    .font(.title3.weight(.semibold))
                Text(session.stage == .completed
                     ? "The code has been tightened through every planned round. Review the final code, cases, and precedents below."
                     : "Run the next step to let the adversarial agents search for new failures and send them to the Judge.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(model.isWorking ? "Working…" : session.currentRound == 0 ? "Start First Review" : "Continue Review") {
                model.runNextStep()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isWorking || session.stage == .completed)
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                .frame(minHeight: 130)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Resolved Cases")
                        .font(.headline)
                    ForEach(session.cases.filter { $0.status == .autoResolved || $0.status == .userResolved }) { item in
                        Text("\(item.title): \(item.resolutionSummary ?? item.reasoning)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Guided Demo mode works immediately. Live Anthropic mode lets the app generate fresh legislators, adversaries, and judges inside the app without Python or Terminal.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Live AI")
                        .font(.title3.weight(.semibold))
                    SecureField("Anthropic API Key", text: $model.anthropicAPIKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: $model.anthropicModel)
                        .textFieldStyle(.roundedBorder)
                    Stepper(value: $model.casesPerAgent, in: 1...4) {
                        Text("Cases per finder: \(model.casesPerAgent)")
                    }

                    Button("Save Settings") {
                        model.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(28)
        }
    }
}

private struct StageChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(isActive ? Color.white : Color.primary)
    }
}

private struct MetaBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
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
                .font(.headline)
            Text(caseRecord.scenario)
            Text(caseRecord.explanation)
                .foregroundStyle(.secondary)

            if let summary = caseRecord.resolutionSummary {
                Divider()
                Text(summary)
                    .font(.subheadline)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(18)
        }
        .frame(minHeight: 260)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
