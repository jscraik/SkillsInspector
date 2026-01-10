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
        let result = await Task.detached(priority: .userInitiated) {
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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(viewModel.isRunning ? "Syncing…" : "Sync Check") {
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
                }
                .disabled(viewModel.isRunning)
                .accessibilityLabel(viewModel.isRunning ? "Syncing" : "Start sync check")

                Toggle("Recursive", isOn: $recursive)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Recursive scan")
                    .accessibilityHint("Include subdirectories when comparing skills")

                TextField("Max depth", value: $maxDepth, format: .number)
                    .frame(width: 80)
                    .accessibilityLabel("Maximum scan depth")

                TextField("Excludes (comma)", text: $excludeInput)
                    .frame(width: 200)
                    .accessibilityLabel("Directory names to exclude")

                TextField("Glob excludes (comma)", text: $excludeGlobInput)
                    .frame(width: 200)
                    .accessibilityLabel("Glob patterns to exclude")

                Spacer()
            }
            .padding(8)
            .background(.thickMaterial)

            NavigationSplitView {
                List(selection: $viewModel.selection) {
                    Section("Only in Codex") {
                        ForEach(viewModel.report.onlyInCodex, id: \.self) { name in
                            Text(name)
                                .tag(SyncViewModel.SyncSelection.onlyCodex(name))
                                .accessibilityLabel("Skill: \(name)")
                        }
                    }
                    .accessibilityLabel("Skills only in Codex")

                    Section("Only in Claude") {
                        ForEach(viewModel.report.onlyInClaude, id: \.self) { name in
                            Text(name)
                                .tag(SyncViewModel.SyncSelection.onlyClaude(name))
                                .accessibilityLabel("Skill: \(name)")
                        }
                    }
                    .accessibilityLabel("Skills only in Claude")

                    Section("Different content") {
                        ForEach(viewModel.report.differentContent, id: \.self) { name in
                            Text(name)
                                .tag(SyncViewModel.SyncSelection.different(name))
                                .accessibilityLabel("Skill: \(name)")
                        }
                    }
                    .accessibilityLabel("Skills with different content")
                }
                .listStyle(.inset)
                .accessibilityLabel("Sync results list")
            } detail: {
                if let selection = viewModel.selection {
                    SyncDetailView(selection: selection, codexRoot: codexRoot, claudeRoot: claudeRoot)
                } else {
                    Text("Select a skill to view details")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var parsedExcludes: [String] {
        excludeInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var parsedGlobExcludes: [String] {
        excludeGlobInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
