import SwiftUI
import SkillsCore

struct ContentView: View {
    @StateObject private var viewModel = InspectorViewModel()
    @StateObject private var syncVM = SyncViewModel()
    @State private var mode: AppMode = .validate
    @State private var severityFilter: Severity? = nil
    @State private var agentFilter: AgentKind? = nil
    @State private var searchText: String = ""
    @State private var showingRootError = false
    @State private var rootErrorMessage = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch mode {
            case .validate:
                ValidateView(
                    viewModel: viewModel,
                    severityFilter: $severityFilter,
                    agentFilter: $agentFilter,
                    searchText: $searchText
                )
            case .sync:
                SyncView(
                    viewModel: syncVM,
                    codexRoot: viewModel.codexRoot,
                    claudeRoot: viewModel.claudeRoot
                )
            case .index:
                IndexPlaceholderView()
            }
        }
        .alert("Invalid Root Directory", isPresented: $showingRootError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(rootErrorMessage)
        }
    }

    private var sidebar: some View {
        List(selection: $mode) {
            Section("Mode") {
                NavigationLink(value: AppMode.validate) {
                    Label("Validate", systemImage: "checkmark.circle")
                        .accessibilityLabel("Validate mode")
                }
                NavigationLink(value: AppMode.sync) {
                    Label("Sync", systemImage: "arrow.2.squarepath")
                        .accessibilityLabel("Sync mode")
                }
                NavigationLink(value: AppMode.index) {
                    Label("Index", systemImage: "doc.text")
                        .accessibilityLabel("Index mode")
                }
            }

            Section("Workspace") {
                RootRow(
                    title: "Codex root",
                    url: viewModel.codexRoot,
                    onPick: { url in
                        if validateRoot(url) {
                            viewModel.codexRoot = url
                        }
                    }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Codex root directory")

                RootRow(
                    title: "Claude root",
                    url: viewModel.claudeRoot,
                    onPick: { url in
                        if validateRoot(url) {
                            viewModel.claudeRoot = url
                        }
                    }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Claude root directory")

                Toggle("Recursive", isOn: $viewModel.recursive)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Recursive scan")
                    .accessibilityHint("Include subdirectories when scanning")
            }

            if mode == .validate {
                Section("Filters") {
                    Picker("Severity", selection: $severityFilter) {
                        Text("All").tag(Severity?.none)
                        Text("Errors").tag(Severity?.some(.error))
                        Text("Warnings").tag(Severity?.some(.warning))
                        Text("Info").tag(Severity?.some(.info))
                    }
                    .accessibilityLabel("Filter by severity")

                    Picker("Agent", selection: $agentFilter) {
                        Text("All").tag(AgentKind?.none)
                        Text("Codex").tag(AgentKind?.some(.codex))
                        Text("Claude").tag(AgentKind?.some(.claude))
                    }
                    .accessibilityLabel("Filter by agent type")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Sidebar navigation")
    }

    private func validateRoot(_ url: URL) -> Bool {
        // Check if URL points to a valid directory
        guard PathUtil.existsDir(url) else {
            rootErrorMessage = "The selected path is not a valid directory:\n\n\(url.path)\n\nPlease select an existing directory."
            showingRootError = true
            return false
        }

        // Check if URL is within expected bounds (prevent accidentally selecting system paths)
        let path = url.path
        let suspiciousPaths = ["/System", "/Library", "/usr", "/bin", "/sbin"]
        for suspicious in suspiciousPaths {
            if path.hasPrefix(suspicious) {
                rootErrorMessage = "The selected path appears to be a system directory:\n\n\(url.path)\n\nThis is likely not a skills root directory."
                showingRootError = true
                return false
            }
        }

        return true
    }
}

struct RootRow: View {
    let title: String
    let url: URL
    let onPick: (URL) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Select") {
                if let picked = pickFolder() {
                    onPick(picked)
                }
            }
            .accessibilityLabel("Select \(title) folder")
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(url.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.canCreateDirectories = false
        panel.title = "Select Skills Root Directory"
        panel.prompt = "Select"
        panel.message = "Choose the root directory containing skill folders (SKILL.md files)"

        return panel.runModal() == .OK ? panel.url : nil
    }
}
