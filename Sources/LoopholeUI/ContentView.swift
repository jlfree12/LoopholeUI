import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var renameTarget: SessionRecord?
    @State private var renameDraftTitle = ""
    @State private var deleteTarget: SessionRecord?
    @State private var showingAPIHelp = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $renameTarget) { session in
            RenameSessionSheet(
                currentTitle: session.title,
                draftTitle: $renameDraftTitle,
                onCancel: {
                    renameTarget = nil
                    renameDraftTitle = ""
                },
                onSave: {
                    model.renameSession(id: session.id, to: renameDraftTitle)
                    renameTarget = nil
                    renameDraftTitle = ""
                }
            )
        }
        .sheet(isPresented: $showingAPIHelp) {
            APIInstructionsSheet()
        }
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
        .alert("Delete Session?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), actions: {
            Button("Delete", role: .destructive) {
                guard let session = deleteTarget else { return }
                model.deleteSession(id: session.id)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        }, message: {
            Text("This permanently removes the saved session from this Mac.")
        })
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

            Section("Find a Saved Session") {
                SearchField(text: $model.sessionSearchText, placeholder: "Search sessions")
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            }

            Section("Saved Sessions") {
                if model.visibleActiveSessions.isEmpty && model.visibleArchivedSessions.isEmpty {
                    Text("No saved analyses yet")
                        .foregroundStyle(.secondary)
                } else if model.visibleActiveSessions.isEmpty {
                    Text("No active sessions match this search.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.visibleActiveSessions) { session in
                        sessionSidebarButton(session)
                    }
                }
            }

            if !model.visibleArchivedSessions.isEmpty {
                Section("Archived") {
                    ForEach(model.visibleArchivedSessions) { session in
                        sessionSidebarButton(session)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Loophole")
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
    }

    private func sessionSidebarButton(_ session: SessionRecord) -> some View {
        sidebarButton(
            title: session.title,
            subtitle: session.isPinned ? "Pinned • Round \(session.currentRound) of \(session.maxRounds)" : "Round \(session.currentRound) of \(session.maxRounds)",
            systemImage: session.isPinned ? "pin.fill" : "doc.text",
            selection: .session(session.id)
        ) {
            model.showSession(id: session.id)
        }
        .contextMenu {
            Button("Rename") {
                renameDraftTitle = session.title
                renameTarget = session
            }
            Button("Duplicate") {
                model.duplicateSession(id: session.id)
            }
            Button(session.isPinned ? "Unpin" : "Pin") {
                model.togglePinned(id: session.id)
            }
            Button(session.isArchived ? "Restore" : "Archive") {
                model.toggleArchived(id: session.id)
            }
            Divider()
            Button("Delete", role: .destructive) {
                deleteTarget = session
            }
        }
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
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(isSelected(selection) ? AppPalette.ink.opacity(0.72) : .secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected(selection) ? AppPalette.ink.opacity(0.55) : AppPalette.ink.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected(selection) ? AppPalette.selection : AppPalette.card.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected(selection) ? AppPalette.ink.opacity(0.18) : AppPalette.rule.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            SettingsView(model: model, onShowAPIHelp: {
                showingAPIHelp = true
            })
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
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero(width: geometry.size.width)
                    templates
                    principleGuidance(width: geometry.size.width)
                    composer(width: geometry.size.width)
                }
                .padding(28)
            }
            .background(AppPalette.canvas)
        }
    }

    private func hero(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stress-test a moral framework in a structured workspace")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(AppPalette.ink)
            Text(.init("LoopholeUI guides you through the full method: write principles, turn them into a code, challenge that code with hard cases, then revise or escalate the deepest conflicts. Original model by [brendanhogan](https://github.com/brendanhogan/loophole), UI by jlfree."))
                .font(.title3)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: width > 980 ? 150 : 180), spacing: 12)], spacing: 12) {
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
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Text("Use Template")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(AppPalette.accent)
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

    private func composer(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Session Builder")
                .font(.title2.weight(.semibold))

            Group {
                if width > 980 {
                    HStack(alignment: .top, spacing: 24) {
                        composerControls
                        principlesEditor
                    }
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        composerControls
                        principlesEditor
                    }
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 16) {
                Button(model.isWorking ? "Starting…" : "Start Session") {
                    model.startSession()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)

                Text("You’ll move into the guided review workspace as soon as the first draft is ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private func principleGuidance(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing Good Principles")
                .font(.title3.weight(.semibold))
            Text("These guidelines keep the analysis concrete, balanced, and easier to test.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: width > 980 ? 220 : 260), spacing: 16)], spacing: 16) {
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
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(16)
        .background(AppPalette.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var composerControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeledField("Session Title") {
                TextField("Example: Campus Speech Stress Test", text: $model.draft.title)
                    .textFieldStyle(.roundedBorder)
            }

            labeledField("Domain") {
                TextField("Example: privacy, speech, public order, migration", text: $model.draft.domain)
                    .textFieldStyle(.roundedBorder)
            }

            labeledField("How many rounds should run?") {
                Picker("How many rounds should run?", selection: $model.draft.maxRounds) {
                    ForEach([3, 4, 5, 6, 8, 10, 12], id: \.self) { value in
                        Text("\(value) rounds").tag(value)
                    }
                }
                .pickerStyle(.menu)

                Text("Use fewer rounds for a quicker seminar exercise, or more rounds for a deeper stress test.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 320, alignment: .topLeading)
        .padding(20)
        .background(AppPalette.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }

    private var principlesEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Moral Principles")
                .font(.headline)
            Text("Write your principles in plain language. The Legislator will turn them into the first draft, so concrete details help.")
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
            if session.awaitingCaseReview {
                selectedPanel = 1
            } else if session.currentRound == 0 && selectedPanel == 0 {
                selectedPanel = session.hasReviewedDraft ? 0 : 2
            }
        }
        .onChange(of: session.hasReviewedDraft) { hasReviewedDraft in
            if hasReviewedDraft, selectedPanel == 2, session.currentRound == 0 {
                selectedPanel = 1
            }
        }
        .onChange(of: session.awaitingCaseReview) { awaitingCaseReview in
            if awaitingCaseReview {
                selectedPanel = 1
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
            Text("This analysis follows Brendan Hogan’s Loophole method: principles, legislator, adversarial cases, judge review, then revision or escalation.")
                .foregroundStyle(.secondary)
            Text("Read the draft, review the cases, and use each round to see where your principles hold firm or need clarification.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loopNarrative: some View {
        let summary = guidanceSummary
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                NarrativeBlock(title: "Previous", text: summary.previous)
                NarrativeBlock(title: "Current", text: summary.current)
                NarrativeBlock(title: "Next", text: summary.next)
            }

            VStack(alignment: .leading, spacing: 12) {
                NarrativeBlock(title: "Previous", text: summary.previous)
                NarrativeBlock(title: "Current", text: summary.current)
                NarrativeBlock(title: "Next", text: summary.next)
            }
        }
    }

    private var stageBoard: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
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
                    Button(model.isWorking ? "Working…" : "Skip to Later Review") {
                        selectedPanel = 3
                        model.skipAheadFromDraft()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .disabled(model.isWorking || session.stage == .completed)
                    .help("Shortcut: move past the guided case-reading step and jump toward later-round review.")
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
            Text("This round needs your judgment")
                .font(.title3.weight(.semibold))
            Text("The Judge could not patch this case without creating a conflict. Write a short ruling in plain language and the app will carry it forward as precedent.")
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
        ViewThatFit(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                overviewColumn(title: "Moral Principles", text: session.moralPrinciples)
                overviewColumn(title: "Latest Code Summary", text: session.currentCode.changelog.isEmpty ? "No updates yet." : session.currentCode.changelog)
            }

            VStack(alignment: .leading, spacing: 16) {
                overviewColumn(title: "Moral Principles", text: session.moralPrinciples)
                overviewColumn(title: "Latest Code Summary", text: session.currentCode.changelog.isEmpty ? "No updates yet." : session.currentCode.changelog)
            }
        }
    }

    private var casesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isWorking && session.cases.isEmpty {
                StatusCallout(
                    title: "Preparing the first cases",
                    subtitle: "The Loophole Finder and Overreach Finder are assembling examples for you to review."
                )
            if session.cases.isEmpty {
                EmptyStateView(title: "No cases yet", subtitle: "Begin the first review to generate cases, then read them here before moving to the next step.")
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

    private func overviewColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ReadableDocument(text: text)
            if title == "Latest Code Summary" {
                Text("Code version v\(session.currentCode.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    let onShowAPIHelp: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                Text("Guided Demo works immediately. Live AI lets you run fresh Loophole rounds with your own Claude or ChatGPT account details.")
                    .foregroundStyle(.secondary)
                Text("You still choose Guided Demo, Claude, or ChatGPT in the Session Builder. This page stores your account details, model choices, and loop defaults.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Claude")
                        .font(.title3.weight(.semibold))
                    SecureField("Claude API Key", text: $model.anthropicAPIKey)
                        .textFieldStyle(.roundedBorder)
                    labeledMenu(
                        title: "Claude model",
                        helper: "Recommendation dated April 2026: Claude Sonnet 4.6 is the best starting point for most classroom and policy analysis work. If you want the strongest reasoning and do not mind higher cost, try Claude Opus 4.6."
                    ) {
                        Picker("Claude model", selection: anthropicModelSelection) {
                            ForEach(ModelCatalog.anthropic) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if anthropicModelSelection.wrappedValue == ModelCatalog.customID {
                        TextField("Enter a Claude model name", text: $model.anthropicModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    Text("ChatGPT")
                        .font(.title3.weight(.semibold))
                    SecureField("ChatGPT API Key", text: $model.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                    labeledMenu(
                        title: "ChatGPT model",
                        helper: "Recommendation dated April 2026: GPT-5.4 mini is the safest everyday choice if you want a balance of quality, speed, and cost. If quality matters most, move up to GPT-5.4."
                    ) {
                        Picker("ChatGPT model", selection: openAIModelSelection) {
                            ForEach(ModelCatalog.openAI) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if openAIModelSelection.wrappedValue == ModelCatalog.customID {
                        TextField("Enter a ChatGPT model name", text: $model.openAIModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("How do API keys work?") {
                        onShowAPIHelp()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
                .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.rule, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 18) {
                    Text("Loophole Method Settings")
                        .font(.title3.weight(.semibold))

                    settingsStepper(
                        title: "Maximum response length",
                        helper: "Higher values let the AI write longer drafts and decisions, but they can also cost more.",
                        valueText: "\(model.maxTokens) tokens"
                    ) {
                        Stepper(value: $model.maxTokens, in: 1024...8192, step: 256) {
                            EmptyView()
                        }
                    }

                    settingsSlider(
                        title: "Legislator creativity",
                        helper: "Lower values make the drafted code more steady and literal. Higher values make it more exploratory.",
                        value: $model.legislatorTemperature
                    )

                    settingsSlider(
                        title: "Loophole Finder creativity",
                        helper: "Higher values push the Loophole Finder toward sharper, more adversarial edge cases.",
                        value: $model.loopholeFinderTemperature
                    )

                    settingsSlider(
                        title: "Overreach Finder creativity",
                        helper: "Higher values push the Overreach Finder toward broader tests of where the rules may go too far.",
                        value: $model.overreachFinderTemperature
                    )

                    settingsSlider(
                        title: "Judge creativity",
                        helper: "Lower values make the Judge more conservative and precedent-focused.",
                        value: $model.judgeTemperature
                    )

                    settingsStepper(
                        title: "Default rounds for a new session",
                        helper: "This sets the starting rounds value in the Session Builder. You can still change it before starting any new session.",
                        valueText: "\(model.defaultMaxRounds) rounds"
                    ) {
                        Stepper(value: $model.defaultMaxRounds, in: 3...12) {
                            EmptyView()
                        }
                    }

                    settingsStepper(
                        title: "Cases per finder",
                        helper: "This controls how many loophole and overreach cases are generated in each round.",
                        valueText: "\(model.casesPerAgent) cases"
                    ) {
                        Stepper(value: $model.casesPerAgent, in: 1...5) {
                            EmptyView()
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Saved sessions")
                                .font(.headline)
                            Text("Open the folder on this Mac where your saved analyses are stored.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Open Saved Sessions Folder") {
                            model.openSavedSessionsFolder()
                        }
                        .buttonStyle(.bordered)
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

                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text(.init("Original Loophole model by [brendanhogan](https://github.com/brendanhogan/loophole)."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .background(AppPalette.canvas)
    }

    private var anthropicModelSelection: Binding<String> {
        Binding(
            get: { ModelCatalog.containsAnthropic(model.anthropicModel) ? model.anthropicModel : ModelCatalog.customID },
            set: { selection in
                if selection == ModelCatalog.customID {
                    if ModelCatalog.containsAnthropic(model.anthropicModel) {
                        model.anthropicModel = ""
                    }
                } else {
                    model.anthropicModel = selection
                }
            }
        )
    }

    private var openAIModelSelection: Binding<String> {
        Binding(
            get: { ModelCatalog.containsOpenAI(model.openAIModel) ? model.openAIModel : ModelCatalog.customID },
            set: { selection in
                if selection == ModelCatalog.customID {
                    if ModelCatalog.containsOpenAI(model.openAIModel) {
                        model.openAIModel = ""
                    }
                } else {
                    model.openAIModel = selection
                }
            }
        )
    }

    private func labeledMenu<Content: View>(title: String, helper: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
            Text(helper)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func settingsStepper<Content: View>(title: String, helper: String, valueText: String, @ViewBuilder control: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            control()
            Text(helper)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func settingsSlider(title: String, helper: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0.0...1.0, step: 0.1)
            Text(helper)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(caseRecord.kind.userLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chipColor.opacity(0.14), in: Capsule())

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Round \(caseRecord.round)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(caseRecord.title)
                .font(AppTypography.cardTitle)
            caseSection(label: "Scenario", text: caseRecord.scenario)
            caseSection(label: "Why it matters", text: caseRecord.explanation, secondary: true)

            if let summary = caseRecord.resolutionSummary {
                Divider()
                caseSection(label: "Resolution", text: summary)
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

    private var statusLabel: String {
        switch caseRecord.status {
        case .pending:
            return "Awaiting review"
        case .autoResolved:
            return "Judge resolved"
        case .escalated:
            return "Needs your ruling"
        case .userResolved:
            return "Resolved by you"
        }
    }

    private func caseSection(label: String, text: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(text)
                .font(AppTypography.documentBody)
                .foregroundStyle(secondary ? AppPalette.ink.opacity(0.8) : AppPalette.ink)
        }
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

private struct StatusCallout: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }
}

private struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppPalette.sheet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.rule, lineWidth: 1)
        )
    }
}

private struct RenameSessionSheet: View {
    let currentTitle: String
    @Binding var draftTitle: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename Session")
                .font(.title2.weight(.semibold))
            Text("Choose a clear title so you can find this session again later.")
                .foregroundStyle(.secondary)

            TextField("Session title", text: $draftTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save Title") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftTitle == currentTitle)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(AppPalette.canvas)
    }
}

private struct APIInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Using Claude or ChatGPT with LoopholeUI")
                    .font(.system(size: 28, weight: .semibold, design: .serif))

                Text("This app can run the Loophole framework with live AI. To do that, it needs permission to send your prompts to the AI service you choose.")
                    .foregroundStyle(.secondary)

                helpSection(
                    title: "What is an API key?",
                    body: "An API key is a private passcode that tells Claude or ChatGPT that the request is really coming from your account. Think of it as a password for the app, not a password you would use to sign in every day."
                )

                helpSection(
                    title: "Why does the app need one?",
                    body: "When you use Guided Demo, the app uses example outputs. When you choose Claude or ChatGPT, the app needs your API key so it can request a fresh Legislator draft, fresh loophole cases, fresh overreach cases, and fresh judging decisions."
                )

                helpSection(
                    title: "How to get a Claude key",
                    body: "Go to the Anthropic Console in your web browser, sign in or create an account, open the API or developer area, and create a new API key. Copy the key and paste it into the Claude API Key box in Settings."
                )

                helpSection(
                    title: "How to get a ChatGPT key",
                    body: "Go to the OpenAI Platform in your web browser, sign in or create an account, open the API keys area, create a new secret key, copy it once, and paste it into the ChatGPT API Key box in Settings."
                )

                helpSection(
                    title: "Free usage and paid usage",
                    body: "These limits can change, so it is best to treat them as rough starting points. Claude and OpenAI sometimes give new users a small amount of trial usage, but many people will need to add billing before they can use the API reliably. In practice, expect that you may need to add a payment method or prepay credits if you want more than a short test."
                )

                helpSection(
                    title: "Where to add money or refill",
                    body: "For Claude, billing is usually managed in the Anthropic Console. For ChatGPT API use, billing is usually managed in the OpenAI Platform billing area. If your live runs stop working after a few tries, the first thing to check is whether your account needs billing enabled."
                )

                helpSection(
                    title: "What to paste into this app",
                    body: "Paste only the API key itself into the matching key box. You do not need to paste a whole webpage, account password, or billing receipt. If you are unsure about the model field, you can leave the default value unless you have a specific reason to change it."
                )

                helpSection(
                    title: "Basic safety advice",
                    body: "Do not post your API key in email, class notes, screenshots, GitHub, or shared documents. Anyone with the key can use your account credits. If you think you exposed the key by accident, delete it in the provider dashboard and make a new one."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Helpful links")
                        .font(.headline)
                    Link("Anthropic Console", destination: URL(string: "https://console.anthropic.com")!)
                    Link("Anthropic Pricing", destination: URL(string: "https://www.anthropic.com/pricing")!)
                    Link("OpenAI Platform", destination: URL(string: "https://platform.openai.com")!)
                    Link("OpenAI Billing Help", destination: URL(string: "https://help.openai.com")!)
                }

                HStack {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
        }
        .frame(minWidth: 640, minHeight: 720)
        .background(AppPalette.canvas)
    }

    private func helpSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
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
    static let selection = Color(nsColor: NSColor(calibratedRed: 0.74, green: 0.80, blue: 0.85, alpha: 1))
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
        if session.awaitingCaseReview {
            return "Review the cases before judgment"
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
            return "Open the first case set and read through it before asking the Judge to rule on the problems it reveals."
        }
        if session.awaitingCaseReview {
            return "The Loophole Finder and Overreach Finder have finished this round. Read the cases first, then continue when you want the Judge to resolve them."
        }
        if session.currentRound == 0 && session.stage == .drafting {
            return "Next, the Loophole Finder and Overreach Finder will probe this code. The Judge will then decide whether each problem can be fixed or must be escalated."
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
        if session.awaitingCaseReview {
            return model.isWorking ? "Working…" : "Continue to Judge"
        }
        if session.currentRound == 0 && session.stage == .drafting {
            return model.isWorking ? "Working…" : "Continue to First Case Round"
        }
        return model.isWorking ? "Working…" : "Continue Review"
    }

    var shouldShowShortcut: Bool {
        session.currentRound == 0 && !session.hasReviewedDraft
    }

    func primaryAction() {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            selectedPanel = 1
            model.beginFirstReview()
            return
        }

        if session.awaitingCaseReview {
            selectedPanel = 1
        }

        model.runNextStep()
    }

    var guidanceSummary: (previous: String, current: String, next: String) {
        if session.currentRound == 0 && !session.hasReviewedDraft {
            return (
                previous: "You entered moral principles and the Legislator turned them into a first draft.",
                current: "You are about to open the first case set and read how the draft behaves under pressure.",
                next: "After you review the cases, the Judge will decide which problems can be repaired and which need your ruling."
            )
        }

        if session.awaitingCaseReview {
            return (
                previous: "The Loophole Finder and Overreach Finder have already generated this round's cases.",
                current: "You are in the guided case-reading step before judgment begins.",
                next: "When you continue, the Judge will review these cases and either resolve them or escalate a real conflict back to you."
            )
        }

        switch session.stage {
        case .drafting:
            return (
                previous: "The Legislator has produced a first-pass code from your principles.",
                current: "You are at the handoff between the drafted code and the first adversarial test round.",
                next: "LoopholeUI will generate loophole and overreach cases, then send them to the Judge."
            )
        case .findingLoopholes:
            return (
                previous: "You reviewed the drafted code.",
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
                current: "You now need to make a plain-language policy choice that becomes precedent.",
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
                previous: "No session has started yet.",
                current: "LoopholeUI is ready for your moral principles.",
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
        if session.awaitingCaseReview {
            return 3
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
