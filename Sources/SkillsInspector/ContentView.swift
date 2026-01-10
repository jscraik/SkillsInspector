import SwiftUI
import SkillsCore

struct ContentView: View {
    @StateObject private var viewModel = InspectorViewModel()
    @StateObject private var syncVM = SyncViewModel()
    @StateObject private var indexVM = IndexViewModel()
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
            case .stats:
                StatsView(viewModel: viewModel)
            case .sync:
                SyncView(
                    viewModel: syncVM,
                    codexRoot: viewModel.codexRoots.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills"),
                    claudeRoot: viewModel.claudeRoot
                )
            case .index:
                IndexView(
                    viewModel: indexVM,
                    codexRoots: viewModel.codexRoots,
                    claudeRoot: viewModel.claudeRoot
                )
            }
        }
        .navigationSplitViewColumnWidth(ideal: 240)
        .alert("Invalid Root Directory", isPresented: $showingRootError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(rootErrorMessage)
        }
    }

    private var sidebar: some View {
        List(selection: $mode) {
            Section {
                NavigationLink(value: AppMode.validate) {
                    Label("Validate", systemImage: "checkmark.circle")
                }
                .padding(.leading, 4)
                NavigationLink(value: AppMode.stats) {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .padding(.leading, 4)
                NavigationLink(value: AppMode.sync) {
                    Label("Sync", systemImage: "arrow.2.squarepath")
                }
                .padding(.leading, 4)
                NavigationLink(value: AppMode.index) {
                    Label("Index", systemImage: "doc.text")
                }
                .padding(.leading, 4)
            } header: {
                Text("Mode")
                    .padding(.leading, 4)
            }

            Section {
                ForEach(Array(viewModel.codexRoots.enumerated()), id: \.offset) { _, url in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 16)
                        Text(url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: FileManager.default.fileExists(atPath: url.path) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(FileManager.default.fileExists(atPath: url.path) ? .green : .red)
                            .font(.caption2)
                    }
                    .padding(.leading, 4)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 16)
                    Text(viewModel.claudeRoot.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: FileManager.default.fileExists(atPath: viewModel.claudeRoot.path) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(FileManager.default.fileExists(atPath: viewModel.claudeRoot.path) ? .green : .red)
                        .font(.caption2)
                }
                .padding(.leading, 4)
            } header: {
                Text("Scan Roots")
                    .padding(.leading, 4)
            }
            
            Section {
                Toggle("Recursive", isOn: $viewModel.recursive)
                    .toggleStyle(.switch)
                    .padding(.leading, 4)
            } header: {
                Text("Options")
                    .padding(.leading, 4)
            }

            if mode == .validate {
                Section {
                    Picker(selection: $severityFilter) {
                        Text("All").tag(Severity?.none)
                        Text("Error").tag(Severity?.some(.error))
                        Text("Warning").tag(Severity?.some(.warning))
                        Text("Info").tag(Severity?.some(.info))
                    } label: {
                        Label("Severity", systemImage: "exclamationmark.triangle")
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 4)

                    Picker(selection: $agentFilter) {
                        Text("All").tag(AgentKind?.none)
                        Text("Codex").tag(AgentKind?.some(.codex))
                        Text("Claude").tag(AgentKind?.some(.claude))
                    } label: {
                        Label("Agent", systemImage: "person.2")
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 4)
                } header: {
                    Text("Filters")
                        .padding(.leading, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 350)
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
