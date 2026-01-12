import SwiftUI
import SkillsCore

struct ContentView: View {
    @StateObject private var viewModel = InspectorViewModel()
    @StateObject private var syncVM = SyncViewModel()
    @StateObject private var indexVM = IndexViewModel()
    @StateObject private var remoteVM = RemoteViewModel(client: RemoteSkillClient.live())
    @State private var mode: AppMode = .validate
    @State private var severityFilter: Severity? = nil
    @State private var agentFilter: AgentKind? = nil
    @State private var searchText: String = ""
    @State private var showingRootError = false
    @State private var rootErrorMessage = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
                StatsView(
                    viewModel: viewModel,
                    mode: $mode,
                    severityFilter: $severityFilter,
                    agentFilter: $agentFilter
                )
            case .sync:
                SyncView(
                    viewModel: syncVM,
                    codexRoots: $viewModel.codexRoots,
                    claudeRoot: $viewModel.claudeRoot,
                    copilotRoot: $viewModel.copilotRoot,
                    codexSkillManagerRoot: $viewModel.codexSkillManagerRoot,
                    recursive: $viewModel.recursive,
                    maxDepth: $viewModel.maxDepth,
                    excludeInput: $viewModel.excludeInput,
                    excludeGlobInput: $viewModel.excludeGlobInput
                )
            case .index:
                IndexView(
                    viewModel: indexVM,
                    codexRoots: viewModel.codexRoots,
                    claudeRoot: viewModel.claudeRoot,
                    codexSkillManagerRoot: viewModel.codexSkillManagerRoot,
                    copilotRoot: viewModel.copilotRoot,
                    recursive: $viewModel.recursive,
                    excludes: viewModel.effectiveExcludes,
                    excludeGlobs: viewModel.effectiveGlobExcludes
                )
            case .remote:
                RemoteView(viewModel: remoteVM)
            case .changelog:
                ChangelogView(viewModel: indexVM)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(appGlassBackground)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Spacer()
            }
            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    Text("sTools")
                        .heading3()
                }
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
                .background(glassBarStyle(tint: DesignTokens.Colors.Accent.blue.opacity(0.05)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            ToolbarItemGroup(placement: .automatic) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "bell")
                        .accessibilityLabel("Notifications")
                    Divider()
                        .frame(height: 18)
                    Image(systemName: "magnifyingglass")
                        .accessibilityLabel("Search")
                }
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
                .background(glassBarStyle(tint: DesignTokens.Colors.Accent.blue.opacity(0.05)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            // Analysis Operations Section
            Section {
                NavigationLink(value: AppMode.validate) {
                    Label {
                        HStack {
                            Text("Validate")
                                .fontWeight(mode == .validate ? .medium : .regular)
                            Spacer()
                            if !viewModel.findings.isEmpty {
                                let errorCount = viewModel.findings.filter { $0.severity == .error }.count
                                if errorCount > 0 {
                                    Text("\(errorCount)")
                                        .captionText(emphasis: true)
                                        .foregroundStyle(DesignTokens.Colors.Status.error)
                                        .padding(.horizontal, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
                                        .padding(.vertical, DesignTokens.Spacing.micro)
                                        .background(DesignTokens.Colors.Status.error.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(mode == .validate ? .accentColor : DesignTokens.Colors.Icon.secondary)
                    }
                }
                NavigationLink(value: AppMode.stats) {
                    Label("Statistics", systemImage: "chart.bar.fill")
                        .fontWeight(mode == .stats ? .medium : .regular)
                        .foregroundStyle(mode == .stats ? .accentColor : DesignTokens.Colors.Icon.secondary, .primary)
                }
            } header: {
                Text("Analysis")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .textCase(.uppercase)
                    .padding(.bottom, DesignTokens.Spacing.hair)
            }
            
            // Management Operations Section  
            Section {
                NavigationLink(value: AppMode.sync) {
                    Label("Sync", systemImage: "arrow.2.squarepath")
                        .fontWeight(mode == .sync ? .medium : .regular)
                        .foregroundStyle(mode == .sync ? .accentColor : DesignTokens.Colors.Icon.secondary, .primary)
                }
                NavigationLink(value: AppMode.index) {
                    Label("Index", systemImage: "doc.text")
                        .fontWeight(mode == .index ? .medium : .regular)
                        .foregroundStyle(mode == .index ? .accentColor : DesignTokens.Colors.Icon.secondary, .primary)
                }
                NavigationLink(value: AppMode.remote) {
                    Label("Remote", systemImage: "globe")
                        .fontWeight(mode == .remote ? .medium : .regular)
                        .foregroundStyle(mode == .remote ? .accentColor : DesignTokens.Colors.Icon.secondary, .primary)
                }
                NavigationLink(value: AppMode.changelog) {
                    Label("Changelog", systemImage: "doc.append")
                        .fontWeight(mode == .changelog ? .medium : .regular)
                        .foregroundStyle(mode == .changelog ? .accentColor : DesignTokens.Colors.Icon.secondary, .primary)
                }
            } header: {
                Text("Management")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .textCase(.uppercase)
                    .padding(.bottom, DesignTokens.Spacing.hair)
            }

            // Scan Roots Section
            Section {
                // Codex Roots
                ForEach(Array(viewModel.codexRoots.enumerated()), id: \.offset) { index, url in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            statusDot(for: url)
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                                Text("Codex \(index + 1)")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(shortenPath(url.path))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Menu {
                                Button("Change Location...") {
                                    if let picked = pickFolder() {
                                        applyRootChange(index: index, newURL: picked, isClaude: false)
                                    }
                                }
                                if viewModel.codexRoots.count > 1 {
                                    Divider()
                                    Button("Remove", role: .destructive) {
                                        viewModel.codexRoots.remove(at: index)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                            }
                            .buttonStyle(.borderless)
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.hair)
                }

                Button {
                    if let picked = pickFolder() {
                        applyRootChange(index: viewModel.codexRoots.count, newURL: picked, isClaude: false, allowAppend: true)
                    }
                } label: {
                    Label("Add Codex Root", systemImage: "plus.circle")
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.hair)
                
                // Claude Root
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        statusDot(for: viewModel.claudeRoot, tint: DesignTokens.Colors.Accent.purple)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                            Text("Claude")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(shortenPath(viewModel.claudeRoot.path))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            if let picked = pickFolder() {
                                applyRootChange(index: 0, newURL: picked, isClaude: true)
                            }
                        } label: {
                            Image(systemName: "folder")
                                .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Change Claude root location")
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.hair)

                // Copilot Root
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        statusDot(for: viewModel.copilotRoot)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                            Text("Copilot")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(viewModel.copilotRoot != nil ? shortenPath(viewModel.copilotRoot!.path) : "Not configured")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(viewModel.copilotRoot != nil ? DesignTokens.Colors.Text.secondary : DesignTokens.Colors.Text.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Menu {
                            Button(viewModel.copilotRoot == nil ? "Set Location..." : "Change Location...") {
                                if let picked = pickFolder() {
                                    applyCopilotRoot(picked)
                                }
                            }
                            if viewModel.copilotRoot != nil {
                                Divider()
                                Button("Clear", role: .destructive) {
                                    viewModel.copilotRoot = nil
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.copilotRoot == nil ? "plus.circle" : "ellipsis.circle")
                                .foregroundStyle(viewModel.copilotRoot == nil ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Icon.secondary)
                        }
                        .buttonStyle(.borderless)
                        .menuStyle(.borderlessButton)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.hair)

                // CodexSkillManager Root
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        statusDot(for: viewModel.codexSkillManagerRoot)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                            Text("CodexSkillManager")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(viewModel.codexSkillManagerRoot != nil ? shortenPath(viewModel.codexSkillManagerRoot!.path) : "Not configured")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(viewModel.codexSkillManagerRoot != nil ? DesignTokens.Colors.Text.secondary : DesignTokens.Colors.Text.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Menu {
                            Button(viewModel.codexSkillManagerRoot == nil ? "Set Location..." : "Change Location...") {
                                if let picked = pickFolder() {
                                    applyCSMRoot(picked)
                                }
                            }
                            if viewModel.codexSkillManagerRoot != nil {
                                Divider()
                                Button("Clear", role: .destructive) {
                                    viewModel.codexSkillManagerRoot = nil
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.codexSkillManagerRoot == nil ? "plus.circle" : "ellipsis.circle")
                                .foregroundStyle(viewModel.codexSkillManagerRoot == nil ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Icon.secondary)
                        }
                        .buttonStyle(.borderless)
                        .menuStyle(.borderlessButton)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.hair)
            } header: {
                Text("Scan Roots")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .textCase(.uppercase)
                    .padding(.bottom, DesignTokens.Spacing.hair)
            }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .listRowBackground(glassPanelStyle(cornerRadius: 10, tint: Color.primary.opacity(0.05)))
        .background(sidebarGlassBackground)
            
            // Options Section
            Section {
                HStack {
                    Label("Recursive", systemImage: "arrow.down.right.and.arrow.up.left")
                        .foregroundStyle(DesignTokens.Colors.Icon.primary, DesignTokens.Colors.Text.primary)
                    Spacer()
                    Toggle("", isOn: $viewModel.recursive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.vertical, DesignTokens.Spacing.hair)
            } header: {
                Text("Options")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .textCase(.uppercase)
                    .padding(.bottom, DesignTokens.Spacing.hair)
            }

            // Filters Section (only show for validate mode)
            if mode == .validate {
                Section {
                    HStack {
                        Label("Severity", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(DesignTokens.Colors.Icon.primary, DesignTokens.Colors.Text.primary)
                        Spacer()
                        Picker("", selection: $severityFilter) {
                            Text("All").tag(Severity?.none)
                            Text("Error").tag(Severity?.some(.error))
                            Text("Warning").tag(Severity?.some(.warning))
                            Text("Info").tag(Severity?.some(.info))
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.vertical, DesignTokens.Spacing.hair)

                    HStack {
                        Label("Agent", systemImage: "person.2")
                            .foregroundStyle(DesignTokens.Colors.Icon.primary, DesignTokens.Colors.Text.primary)
                        Spacer()
                        Picker("", selection: $agentFilter) {
                            Text("All").tag(AgentKind?.none)
                            Text("Codex").tag(AgentKind?.some(.codex))
                            Text("Claude").tag(AgentKind?.some(.claude))
                            Text("CodexSkillManager").tag(AgentKind?.some(.codexSkillManager))
                            Text("Copilot").tag(AgentKind?.some(.copilot))
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.vertical, DesignTokens.Spacing.hair)
                } header: {
                    Text("Filters")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, DesignTokens.Spacing.hair)
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 36)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        .scrollIndicators(.visible)
        .listRowSpacing(DesignTokens.Spacing.hair)
    }

    private func applyRootChange(index: Int, newURL: URL, isClaude: Bool, allowAppend: Bool = false) {
        guard viewModel.validateRoot(newURL) else {
            rootErrorMessage = "The selected path is not a valid skills directory:\n\(newURL.path)"
            showingRootError = true
            return
        }
        if isClaude {
            viewModel.claudeRoot = newURL
            return
        }
        if allowAppend && index >= viewModel.codexRoots.count {
            viewModel.codexRoots.append(newURL)
        } else if index < viewModel.codexRoots.count {
            viewModel.codexRoots[index] = newURL
        }
    }

    private func applyCSMRoot(_ newURL: URL) {
        guard viewModel.validateRoot(newURL) else {
            rootErrorMessage = "The selected CodexSkillManager path is not a valid directory:\n\(newURL.path)"
            showingRootError = true
            return
        }
        viewModel.codexSkillManagerRoot = newURL
    }

    private func applyCopilotRoot(_ newURL: URL) {
        guard viewModel.validateRoot(newURL) else {
            rootErrorMessage = "The selected Copilot path is not a valid directory:\n\(newURL.path)"
            showingRootError = true
            return
        }
        viewModel.copilotRoot = newURL
    }
    
    private func statusDot(for url: URL?, tint: Color = DesignTokens.Colors.Accent.orange) -> some View {
        guard let url else {
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DesignTokens.Colors.Accent.gray)
                .help("Not configured")
                .font(.caption)
        }
        let exists = FileManager.default.fileExists(atPath: url.path)
        return Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(exists ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Status.error)
            .help(exists ? "Directory exists" : "Directory not found")
            .font(.caption)
    }
    
    private func shortenPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let shortened = path.replacingOccurrences(of: homePath, with: "~")
        
        // If path is still too long, show just the last few components
        let components = shortened.components(separatedBy: "/")
        if components.count > 3 && shortened.count > 40 {
            let lastComponents = components.suffix(2).joined(separator: "/")
            return ".../" + lastComponents
        }
        
        return shortened
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

    private var appGlassBackground: some View {
        Group {
            if #available(iOS 26, macOS 15, *) {
                Color.clear
                    .glassEffect(.regular.tint(Color.primary.opacity(0.06)))
            } else {
                Color(.windowBackgroundColor)
                    .opacity(0.35)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var sidebarGlassBackground: some View {
        Group {
            if #available(iOS 26, macOS 15, *) {
                Color.clear
                    .glassEffect(.regular.tint(Color.primary.opacity(0.08)), in: .rect(cornerRadius: 0))
            } else {
                Color(.underPageBackgroundColor)
                    .opacity(0.45)
                    .background(.thinMaterial)
            }
        }
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
