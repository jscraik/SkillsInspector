import SwiftUI
import SkillsCore

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var report: MultiSyncReport = MultiSyncReport()
    @Published var isRunning = false
    @Published var selection: SyncSelection?
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
        isRunning = true
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
    @State private var expandedMissing: Set<AgentKind> = []

    var body: some View {
        let rootsValid = PathUtil.existsDir(activeCodexRoot) && PathUtil.existsDir(claudeRoot)
        VStack(spacing: 0) {
        HStack(spacing: DesignTokens.Spacing.xs) {
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
                    Label(viewModel.isRunning ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isRunning || !rootsValid)
                .buttonStyle(.borderedProminent)

                if !rootsValid {
                    Label("Set roots in sidebar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.warning)
                        .captionText()
                }

                Toggle(isOn: $recursive) {
                    Text("Recursive")
                        .fixedSize()
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!rootsValid || viewModel.isRunning)

                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text("Depth:")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    TextField("", value: $maxDepth, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!rootsValid || viewModel.isRunning)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xxxs)
            .background(glassBarStyle())
            
            HStack(spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Text("Excludes:")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    TextField("dir1, dir2", text: $excludeInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(viewModel.isRunning)
                }
                
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Text("Globs:")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    TextField("*.tmp, test_*", text: $excludeGlobInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(viewModel.isRunning)
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
            .background(glassBarStyle())
            .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .regular))
            .onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
                guard rootsValid else { return }
                Task {
                    viewModel.cancel()
                    await viewModel.run(
                        roots: activeRoots,
                        recursive: recursive,
                        maxDepth: maxDepth,
                        excludes: parsedExcludes,
                        excludeGlobs: parsedGlobExcludes
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
                Task {
                    viewModel.cancel()
                    _ = await viewModel.waitForCurrentTask()
                }
            }

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
    }
    
    private var syncResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button("Expand All") {
                        expandedMissing = Set(AgentKind.allCases)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Collapse All") {
                        expandedMissing.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.hair)

                ForEach(AgentKind.allCases, id: \.self) { agent in
                    let names = viewModel.report.missingByAgent[agent] ?? []
                    if !names.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
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
                                    Image(systemName: expandedMissing.contains(agent) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Colors.Text.primary)
                                        .accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
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
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.hair)
                    }
                }

                if !viewModel.report.differentContent.isEmpty {
                    sectionHeader(title: "Different content", count: viewModel.report.differentContent.count, icon: "doc.badge.gearshape", tint: DesignTokens.Colors.Accent.orange)
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
            .padding(.vertical, DesignTokens.Spacing.xxxs)
        }
        .onAppear {
            if viewModel.selection == nil {
                // Find first missing skill from any agent
                for agent in AgentKind.allCases {
                    if let names = viewModel.report.missingByAgent[agent], let first = names.first {
                        viewModel.selection = .missing(agent: agent, name: first)
                        return
                    }
                }
                // Fall back to different content
                if let first = viewModel.report.differentContent.first {
                    viewModel.selection = .different(name: first.name)
                }
            }
        }
        .onChange(of: viewModel.report) { _, _ in
            // Collapse sections by default on a new report to reduce scrolling.
            expandedMissing.removeAll()
        }
    }

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
        .cardStyle(selected: viewModel.selection == selection, tint: tint)
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
}

extension SyncViewModel.SyncSelection {
    var name: String {
        switch self {
        case .missing(_, let name): return name
        case .different(let name): return name
        }
    }
}
