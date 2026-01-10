import SwiftUI
import SkillsCore

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var report: SyncReport = SyncReport()
    @Published var isRunning = false
    @Published var selection: SyncSelection?

    enum SyncSelection: Hashable {
        case onlyCodex(String)
        case onlyClaude(String)
        case different(String)
    }

    func run(
        codexRoot: URL,
        claudeRoot: URL,
        recursive: Bool,
        maxDepth: Int?,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        isRunning = true
        let result = await Task(priority: .userInitiated) {
            if Task.isCancelled { return SyncReport() }
            let codexScan = ScanRoot(agent: .codex, rootURL: codexRoot, recursive: recursive, maxDepth: maxDepth)
            let claudeScan = ScanRoot(agent: .claude, rootURL: claudeRoot, recursive: recursive, maxDepth: maxDepth)
            return SyncChecker.byName(
                codexRoot: codexScan.rootURL,
                claudeRoot: claudeScan.rootURL,
                recursive: recursive,
                excludeDirNames: Set([".git", ".system", "__pycache__", ".DS_Store"]).union(Set(excludes)),
                excludeGlobs: excludeGlobs
            )
        }.value
        if Task.isCancelled {
            isRunning = false
            return
        }
        report = result
        isRunning = false
    }
}

struct SyncView: View {
    @ObservedObject var viewModel: SyncViewModel
    let codexRoot: URL
    let claudeRoot: URL
    @State private var recursive = false
    @State private var maxDepth: Int?
    @State private var excludeInput: String = ""
    @State private var excludeGlobInput: String = ""

    var body: some View {
        let rootsValid = PathUtil.existsDir(codexRoot) && PathUtil.existsDir(claudeRoot)
        VStack(spacing: 0) {
        HStack(spacing: 16) {
            Button {
                guard rootsValid else { return }
                Task {
                    await viewModel.run(
                        codexRoot: codexRoot,
                            claudeRoot: claudeRoot,
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
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Toggle(isOn: $recursive) {
                    Text("Recursive")
                        .fixedSize()
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!rootsValid || viewModel.isRunning)

                Spacer()
                
                HStack(spacing: 8) {
                    Text("Depth:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", value: $maxDepth, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!rootsValid || viewModel.isRunning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Excludes:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("dir1, dir2", text: $excludeInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(viewModel.isRunning)
                }
                
                HStack(spacing: 4) {
                    Text("Globs:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("*.tmp, test_*", text: $excludeGlobInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(viewModel.isRunning)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .regular))

            HStack(spacing: 0) {
                // Sync results list (fixed width, non-resizable)
                Group {
                    if viewModel.isRunning {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Syncing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.report.onlyInCodex.isEmpty && 
                              viewModel.report.onlyInClaude.isEmpty && 
                              viewModel.report.differentContent.isEmpty {
                        EmptyStateView(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Ready to Sync",
                            message: rootsValid ? "Press Sync to compare Codex and Claude skills." : "Configure valid roots in the sidebar to begin.",
                            action: rootsValid ? {
                                Task {
                                    await viewModel.run(
                                        codexRoot: codexRoot,
                                        claudeRoot: claudeRoot,
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
                        SyncDetailView(selection: selection, codexRoot: codexRoot, claudeRoot: claudeRoot)
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
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.report.onlyInCodex.isEmpty {
                    sectionHeader(title: "Only in Codex", count: viewModel.report.onlyInCodex.count, icon: "cpu", tint: .blue)
                    ForEach(viewModel.report.onlyInCodex, id: \.self) { name in
                        syncCard(
                            title: name,
                            icon: "doc.badge.plus",
                            tint: .blue,
                            selection: .onlyCodex(name)
                        )
                    }
                }

                if !viewModel.report.onlyInClaude.isEmpty {
                    sectionHeader(title: "Only in Claude", count: viewModel.report.onlyInClaude.count, icon: "brain", tint: .purple)
                    ForEach(viewModel.report.onlyInClaude, id: \.self) { name in
                        syncCard(
                            title: name,
                            icon: "doc.badge.plus",
                            tint: .purple,
                            selection: .onlyClaude(name)
                        )
                    }
                }

                if !viewModel.report.differentContent.isEmpty {
                    sectionHeader(title: "Different content", count: viewModel.report.differentContent.count, icon: "doc.badge.gearshape", tint: .orange)
                    ForEach(viewModel.report.differentContent, id: \.self) { name in
                        syncCard(
                            title: name,
                            icon: "doc.badge.gearshape",
                            tint: .orange,
                            selection: .different(name)
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            if viewModel.selection == nil {
                if let first = viewModel.report.onlyInCodex.first {
                    viewModel.selection = .onlyCodex(first)
                } else if let first = viewModel.report.onlyInClaude.first {
                    viewModel.selection = .onlyClaude(first)
                } else if let first = viewModel.report.differentContent.first {
                    viewModel.selection = .different(first)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, count: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            Text("(\(count))")
                .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: DesignTokens.Typography.BodySmall.weight))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func syncCard(title: String, icon: String, tint: Color, selection: SyncViewModel.SyncSelection) -> some View {
        Button {
            viewModel.selection = selection
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(tint)
                            .font(.caption)
                    )
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
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
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a skill to view details")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Click a skill from the list to compare content")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var parsedExcludes: [String] {
        excludeInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var parsedGlobExcludes: [String] {
        excludeGlobInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
