import SwiftUI
import SkillsCore

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var report: MultiSyncReport = MultiSyncReport()
    @Published var isRunning = false
    @Published var selection: SyncSelection?
    @Published var syncError: String?
    @Published var syncSuccessMessage: String?
    private var currentTask: Task<MultiSyncReport, Never>?

    enum SyncSelection: Hashable {
        case missing(agent: AgentKind, name: String)
        case different(name: String)
    }

    func run(
        roots: [AgentKind: URL],
        recursive: Bool,
        maxDepth: Int?,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        // Check if we have valid roots to sync
        guard !roots.isEmpty else {
            syncError = "No valid roots configured for sync. Please check your root directories in the sidebar."
            syncSuccessMessage = nil
            return
        }

        isRunning = true
        syncError = nil
        syncSuccessMessage = nil
        currentTask?.cancel()
        currentTask = Task(priority: .userInitiated) {
            if Task.isCancelled { return MultiSyncReport() }
            let scans = roots.map { ScanRoot(agent: $0.key, rootURL: $0.value, recursive: recursive, maxDepth: maxDepth) }
            return SyncChecker.multiByName(
                roots: scans,
                recursive: recursive,
                excludeDirNames: Set(InspectorViewModel.defaultExcludes).union(Set(excludes)),
                excludeGlobs: excludeGlobs
            )
        }
        let result = await currentTask?.value ?? MultiSyncReport()
        guard !Task.isCancelled else {
            isRunning = false
            return
        }
        report = result

        // Set success message based on results
        let totalIssues = result.missingByAgent.values.reduce(0) { $0 + $1.count } + result.differentContent.count
        if totalIssues == 0 {
            syncSuccessMessage = "All skills are in sync across \(roots.count) roots!"
        } else {
            syncSuccessMessage = "Found \(totalIssues) difference\(totalIssues == 1 ? "" : "s") across \(roots.count) roots."
        }

        isRunning = false
        currentTask = nil
    }

    func cancel() {
        currentTask?.cancel()
        isRunning = false
    }

    func waitForCurrentTask() async -> MultiSyncReport? {
        let value = await currentTask?.value
        return value
    }
}

struct SyncView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Binding var codexRoots: [URL]
    @Binding var claudeRoot: URL
    @Binding var copilotRoot: URL?
    @Binding var codexSkillManagerRoot: URL?
    @Binding var recursive: Bool
    @Binding var maxDepth: Int?
    @Binding var excludeInput: String
    @Binding var excludeGlobInput: String
    @AppStorage("useSharedSkillsRoot") private var useSharedSkillsRoot = false
    @State private var expandedMissing: Set<AgentKind> = []
    @State private var toastMessage: ToastMessage? = nil

    var body: some View {
        let rootsValid = useSharedSkillsRoot ? PathUtil.existsDir(activeCodexRoot) : (PathUtil.existsDir(activeCodexRoot) && PathUtil.existsDir(claudeRoot))
        VStack(spacing: 0) {
            // Main Sync Toolbar
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Primary Action Group
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        guard rootsValid else { return }
                        Task {
                            await viewModel.run(
                                roots: activeRoots,
                                recursive: recursive,
                                maxDepth: maxDepth,
                                excludes: parsedExcludes,
                                excludeGlobs: parsedGlobExcludes
                            )
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            if viewModel.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(viewModel.isRunning ? "Syncing…" : "Sync Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isRunning || !rootsValid)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help("Compare content across all active skill roots")
                }

                Divider()
                    .frame(height: 28)

                // Configuration Group
                HStack(spacing: DesignTokens.Spacing.xs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search Mode")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Button {
                                recursive.toggle()
                            } label: {
                                Label("Recursive", systemImage: recursive ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.down.right.and.arrow.up.left.circle")
                                    .foregroundStyle(recursive ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Icon.tertiary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .help("Recursive search: \(recursive ? "On" : "Off")")
                            
                            HStack(spacing: DesignTokens.Spacing.hair) {
                                Text("Depth:")
                                    .captionText()
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                TextField("", value: $maxDepth, format: .number)
                                    .frame(width: 44)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exclusions")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            TextField("Folders (dir1, dir2)", text: $excludeInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                                .controlSize(.small)
                            
                            TextField("Globs (*.tmp)", text: $excludeGlobInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                                .controlSize(.small)
                        }
                    }
                }

                Spacer()
                
                if !rootsValid {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Check scan roots")
                    }
                    .foregroundStyle(DesignTokens.Colors.Status.warning)
                    .captionText()
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Colors.Status.warning.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(cleanToolbarStyle(cornerRadius: 0))
            
            Divider()

            // Previous implementation had these auto-sync triggers:
            // .task(id: recursive) { try? await Task.sleep(nanoseconds: 500_000_000); await autoSyncIfReady() }
            // .task(id: maxDepth) { try? await Task.sleep(nanoseconds: 800_000_000); await autoSyncIfReady() }
            // .task(id: excludeInput) { try? await Task.sleep(nanoseconds: 1_200_000_000); await autoSyncIfReady() }
            // .task(id: excludeGlobInput) { try? await Task.sleep(nanoseconds: 1_200_000_000); await autoSyncIfReady() }
            // .onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in Task { await autoSyncIfReady() } }
            // These caused immediate sync runs on view appearance or settings changes, blocking UI responsiveness.
            // Sync control is now explicit: users must click "Sync Now" button to trigger comparison.

            HStack(spacing: 0) {
                // Sync results list (fixed width, non-resizable)
                VStack {
                    if viewModel.isRunning {
                        ScrollView {
                            VStack(spacing: DesignTokens.Spacing.xxxs) {
                                ForEach(0..<6, id: \.self) { _ in SkeletonSyncRow() }
                            }
                            .padding(.vertical, DesignTokens.Spacing.xxxs)
                        }
                    } else if isReportEmpty {
                        EmptyStateView(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Ready to Sync",
                            message: rootsValid ? "Press Sync to compare skill roots." : "Configure valid roots in the sidebar to begin.",
                            action: rootsValid ? {
                                Task {
                                    await viewModel.run(
                                        roots: activeRoots,
                                        recursive: recursive,
                                        maxDepth: maxDepth,
                                        excludes: parsedExcludes,
                                        excludeGlobs: parsedGlobExcludes
                                    )
                                }
                            } : nil,
                            actionLabel: "Sync Now"
                        )
                    } else {
                        syncResultsList
                    }
                }
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 440)
                
                Divider()
                    
                // Detail panel (flexible)
                Group {
                    if let selection = viewModel.selection {
                        SyncDetailView(
                            selection: selection,
                            rootsByAgent: activeRoots,
                            diffDetail: viewModel.report.differentContent.first(where: { $0.name == selection.name })
                        )
                    } else {
                        emptyDetailState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
            viewModel.cancel()
        }
    }
}

// MARK: - Subviews
private extension SyncView {
    private var syncResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Header with actions
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack {
                        Image(systemName: "list.bullet.indent")
                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        Text("Comparison Results")
                            .heading3()
                        Spacer()
                    }
                    
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                expandedMissing = Set(AgentKind.allCases)
                            }
                        } label: {
                            Label("Expand All", systemImage: "plus.square")
                                .captionText()
                        }
                        .buttonStyle(.clean)
                        .controlSize(.small)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                expandedMissing.removeAll()
                            }
                        } label: {
                            Label("Collapse", systemImage: "minus.square")
                                .captionText()
                        }
                        .buttonStyle(.clean)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.hair)
                .padding(.top, DesignTokens.Spacing.hair)

                Divider()
                    .padding(.horizontal, DesignTokens.Spacing.hair)

                // Missing Skills Sections
                ForEach(AgentKind.allCases, id: \.self) { agent in
                    let names = viewModel.report.missingByAgent[agent] ?? []
                    if !names.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedMissing.contains(agent) {
                                        expandedMissing.remove(agent)
                                    } else {
                                        expandedMissing.insert(agent)
                                    }
                                }
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.xxxs) {
                                    Image(systemName: agent.icon)
                                        .foregroundStyle(agent.color)
                                    Text("Missing in \(agent.displayName)")
                                        .heading3()
                                    Text("(\(names.count))")
                                        .bodySmall()
                                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    Spacer(minLength: DesignTokens.Spacing.xs)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                        .rotationEffect(.degrees(expandedMissing.contains(agent) ? 90 : 0))
                                }
                                .padding(DesignTokens.Spacing.xxxs)
                                .background(DesignTokens.Colors.Background.tertiary.opacity(0.3))
                                .cornerRadius(DesignTokens.Radius.sm)
                            }
                            .buttonStyle(.plain)

                            if expandedMissing.contains(agent) {
                                VStack(spacing: DesignTokens.Spacing.xxxs) {
                                    ForEach(names, id: \.self) { name in
                                        syncCard(
                                            title: name,
                                            icon: "doc.badge.plus",
                                            tint: agent.color,
                                            selection: .missing(agent: agent, name: name)
                                        )
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.leading, DesignTokens.Spacing.hair)
                            }
                        }
                    }
                }

                // Different Content Section
                if !viewModel.report.differentContent.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        sectionHeader(title: "Content Differences", count: viewModel.report.differentContent.count, icon: "doc.badge.gearshape", tint: DesignTokens.Colors.Accent.orange)
                            .padding(.vertical, DesignTokens.Spacing.hair)
                        
                        VStack(spacing: DesignTokens.Spacing.xxxs) {
                            ForEach(viewModel.report.differentContent, id: \.name) { diff in
                                syncCard(
                                    title: diff.name,
                                    icon: "doc.badge.gearshape",
                                    tint: DesignTokens.Colors.Accent.orange,
                                    selection: .different(name: diff.name)
                                )
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xs)
        }
        .onAppear {
            if viewModel.selection == nil {
                // Find first missing skill from any agent
                viewModel.selection = firstSelection(in: viewModel.report)
            }
        }
        .onChange(of: viewModel.report) { _, _ in
            // Collapse sections by default on a new report to reduce scrolling.
            expandedMissing.removeAll()
            guard let selection = viewModel.selection else {
                viewModel.selection = firstSelection(in: viewModel.report)
                return
            }
            if !selectionExists(selection, in: viewModel.report) {
                viewModel.selection = firstSelection(in: viewModel.report)
            }
        }
    }

    private var emptyDetailState: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
            Text("Select a skill to view details")
                .heading3()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
            Text("Click a skill from the list to compare content")
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Actions
private extension SyncView {
    private func autoSyncIfReady() async {
        guard !viewModel.isRunning else { return }
        let rootsValid = useSharedSkillsRoot ? PathUtil.existsDir(activeCodexRoot) : (PathUtil.existsDir(activeCodexRoot) && PathUtil.existsDir(claudeRoot))
        guard rootsValid else { return }
        
        await viewModel.run(
            roots: activeRoots,
            recursive: recursive,
            maxDepth: maxDepth,
            excludes: parsedExcludes,
            excludeGlobs: parsedGlobExcludes
        )
    }
}

// MARK: - Helpers
private extension SyncView {
    @ViewBuilder
    private func sectionHeader(title: String, count: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .heading3()
            Text("(\(count))")
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.hair)
    }

    private func syncCard(title: String, icon: String, tint: Color, selection: SyncViewModel.SyncSelection) -> some View {
        Button {
            viewModel.selection = selection
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(tint)
                            .captionText()
                    )
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DesignTokens.Colors.Text.primary)
                    .lineLimit(2)
                Spacer()
                if viewModel.selection == selection {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                }
            }
        }
        .buttonStyle(.plain)
        .cardStyle(selected: viewModel.selection == selection, tint: .accentColor) // Use default/neutral accent unless selected
    }
    
    private var parsedExcludes: [String] {
        excludeInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var parsedGlobExcludes: [String] {
        excludeGlobInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var activeCodexRoot: URL {
        codexRoots.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills")
    }

    private var activeRoots: [AgentKind: URL] {
        if useSharedSkillsRoot {
            // Single source of truth mode: all agents point to the same root (no-op comparisons)
            return [
                .codex: activeCodexRoot,
                .claude: activeCodexRoot,
                .copilot: activeCodexRoot,
                .codexSkillManager: activeCodexRoot
            ].filter { PathUtil.existsDir($0.value) }
        }
        
        // Multi-root mode: compare all configured roots
        var roots: [AgentKind: URL] = [
            .codex: activeCodexRoot,
            .claude: claudeRoot
        ]
        if let copilotRoot, PathUtil.existsDir(copilotRoot) {
            roots[.copilot] = copilotRoot
        }
        if let codexSkillManagerRoot, PathUtil.existsDir(codexSkillManagerRoot) {
            roots[.codexSkillManager] = codexSkillManagerRoot
        }
        return roots
    }

    private var isReportEmpty: Bool {
        let missingEmpty = viewModel.report.missingByAgent.values.allSatisfy { $0.isEmpty }
        let diffEmpty = viewModel.report.differentContent.isEmpty
        return missingEmpty && diffEmpty
    }

    private func selectionExists(_ selection: SyncViewModel.SyncSelection, in report: MultiSyncReport) -> Bool {
        switch selection {
        case .missing(let agent, let name):
            return report.missingByAgent[agent]?.contains(name) ?? false
        case .different(let name):
            return report.differentContent.contains(where: { $0.name == name })
        }
    }

    private func firstSelection(in report: MultiSyncReport) -> SyncViewModel.SyncSelection? {
        for agent in AgentKind.allCases {
            if let names = report.missingByAgent[agent], let first = names.first {
                return .missing(agent: agent, name: first)
            }
        }
        if let first = report.differentContent.first {
            return .different(name: first.name)
        }
        return nil
    }
}

extension SyncViewModel.SyncSelection {
    var name: String {
        switch self {
        case .missing(_, let name): return name
        case .different(let name): return name
        }
    }
}
