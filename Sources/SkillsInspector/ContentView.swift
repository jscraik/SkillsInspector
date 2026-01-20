import SwiftUI
import SkillsCore
// NEW: Import aStudio modules
import AStudioFoundation
import AStudioThemes
import AStudioComponents

struct LegacyContentView: View {
    // AppDependencies with lazy initialization
    @StateObject private var dependencies: AppDependencies = AppDependencies()

    // Lightweight ViewModels that can initialize synchronously
    @StateObject private var viewModel = InspectorViewModel()
    @StateObject private var syncVM = SyncViewModel()
    @StateObject private var indexVM = IndexViewModel()

    // ViewModels created once when their views are first accessed
    @StateObject private var remoteVMFactory = RemoteViewModelFactory()
    @StateObject private var changelogVMFactory = ChangelogViewModelFactory()

    @State private var mode: AppMode = .validate
    @State private var severityFilter: Severity? = nil
    @State private var agentFilter: AgentKind? = nil
    @State private var searchText: String = ""
    @State private var showingRootError = false
    @State private var rootErrorMessage = ""
    @State private var sidebarWidth: CGFloat = 280
    @State private var sidebarDragStart: CGFloat?
    @State private var isSidebarResizerHover = false

    init() {
        let trustStoreVM = TrustStoreViewModel()
        let ledger = try? SkillLedger()
        let features = FeatureFlags.fromEnvironment()
        let telemetryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SkillsInspector", isDirectory: true)
            .appendingPathComponent("telemetry.jsonl")
        let telemetry = features.telemetryOptIn
            ? TelemetryClient.file(url: telemetryURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("telemetry.jsonl"))
            : .noop
        _trustStoreVM = StateObject(wrappedValue: trustStoreVM)
        _changelogVM = StateObject(wrappedValue: ChangelogViewModel(ledger: ledger))
        _remoteVM = StateObject(
            wrappedValue: RemoteViewModel(
                client: RemoteSkillClient.live(),
                ledger: ledger,
                telemetry: telemetry,
                features: features,
                trustStoreProvider: { trustStoreVM.trustStore },
                keysetUpdater: { keyset in
                    trustStoreVM.applyKeyset(keyset)
                }
            )
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)
                .background(DesignTokens.Colors.Background.secondary)
                .layoutPriority(1)

            sidebarResizer

            activeDetailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .background(DesignTokens.Colors.Background.primary)
        #if os(macOS)
        .background {
            WindowAccessor { window in
                configureWindow(window)
            }
        }
        #endif
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Spacer()
            }
            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    Text("SkillsInspector")
                        .heading3()
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(cleanToolbarStyle())
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
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(cleanToolbarStyle())
            }
        }
        .alert("Invalid Root Directory", isPresented: $showingRootError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(rootErrorMessage)
        }
    }

    // MARK: - Detail Content
    @ViewBuilder
    private var detailContent: some View {
        switch mode {
        case .validate:
            ValidateView(
                viewModel: viewModel,
                severityFilter: $severityFilter,
                agentFilter: $agentFilter,
                searchText: $searchText
            )
            .id("validate-view")
        case .stats:
            StatsView(
                viewModel: viewModel,
                mode: $mode,
                severityFilter: $severityFilter,
                agentFilter: $agentFilter
            )
            .id("stats-view")
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
            .id("sync-view")
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
            .id("index-view")
        case .remote:
            RemoteView(
                viewModel: remoteVMFactory.makeViewModel(dependencies: dependencies),
                trustStoreVM: dependencies.trustStoreVM
            )
            .id("remote-view")
        case .changelog:
            ChangelogView(viewModel: changelogVMFactory.makeViewModel(dependencies: dependencies))
            .id("changelog-view")
        }
    }

}

// MARK: - Subviews
private extension LegacyContentView {
    private var sidebarMinWidth: CGFloat { 240 }
    private var sidebarMaxWidth: CGFloat { 360 }

    @ViewBuilder
    private var activeDetailView: some View {
        switch mode {
        case .validate:
            ValidateView(
                viewModel: viewModel,
                severityFilter: $severityFilter,
                agentFilter: $agentFilter,
                searchText: $searchText
            )
            .onAppear {
                // Cancel any stray scan that might have started during init
                viewModel.cancelScan()

                // Wait for UI to fully render before marking app ready
                Task {
                    // Yield to let UI finish rendering
                    await Task.yield()
                    // Short delay to ensure UI is interactive
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    await MainActor.run {
                        viewModel.markAppReady()
                    }
                }
            }
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
            RemoteView(viewModel: remoteVM, trustStoreVM: trustStoreVM)
        case .changelog:
            ChangelogView(viewModel: changelogVM)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar Header / Branding
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [DesignTokens.Colors.Accent.blue, DesignTokens.Colors.Accent.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("SkillsInspector")
                    .font(.system(size: 18, weight: .black))
                    .tracking(-0.5)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.top, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.xs)
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    // Analysis Section
                    sidebarSection(title: "Analysis") {
                        VStack(spacing: DesignTokens.Spacing.micro) {
                            sidebarRow(title: "Validate", icon: "checkmark.seal.fill", value: .validate, tint: DesignTokens.Colors.Accent.blue) {
                                if !viewModel.findings.isEmpty {
                                    let errorCount = viewModel.findings.filter { $0.severity == .error }.count
                                    if errorCount > 0 {
                                        badge(text: "\(errorCount)", color: DesignTokens.Colors.Status.error)
                                    }
                                }
                            }
                            
                            sidebarRow(title: "Statistics", icon: "chart.bar.xaxis", value: .stats, tint: DesignTokens.Colors.Accent.pink)
                        }
                    }
                    
                    // Management Section
                    sidebarSection(title: "Management") {
                        VStack(spacing: DesignTokens.Spacing.micro) {
                            sidebarRow(title: "Sync", icon: "arrow.triangle.2.circlepath", value: .sync, tint: DesignTokens.Colors.Accent.green)
                            sidebarRow(title: "Index", icon: "text.book.closed.fill", value: .index, tint: DesignTokens.Colors.Accent.blue)
                            sidebarRow(title: "Remote", icon: "network", value: .remote, tint: DesignTokens.Colors.Accent.purple)
                            sidebarRow(title: "Changelog", icon: "clock.badge.checkmark.fill", value: .changelog, tint: DesignTokens.Colors.Accent.orange)
                        }
                    }
                    
                    // Scan Roots Section
                    sidebarSection(title: "Scan Roots") {
                        VStack(spacing: DesignTokens.Spacing.xxs) {
                            // Codex Roots
                            ForEach(Array(viewModel.codexRoots.enumerated()), id: \.offset) { index, url in
                                rootCard(
                                    title: viewModel.codexRoots.count > 1 ? "Codex \(index + 1)" : "Codex",
                                    url: url,
                                    tint: DesignTokens.Colors.Accent.blue,
                                    menu: {
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
                                    }
                                )
                            }
                            
                            addRootButton {
                                if let picked = pickFolder() {
                                    applyRootChange(index: viewModel.codexRoots.count, newURL: picked, isClaude: false, allowAppend: true)
                                }
                            }
                            .padding(.top, DesignTokens.Spacing.hair)
                            
                            // Claude Root
                            rootCard(
                                title: "Claude",
                                url: viewModel.claudeRoot,
                                tint: DesignTokens.Colors.Accent.purple,
                                menu: {
                                    Button("Change Location...") {
                                        if let picked = pickFolder() {
                                            applyRootChange(index: 0, newURL: picked, isClaude: true)
                                        }
                                    }
                                }
                            )
                            
                            // Copilot Root
                            rootCard(
                                title: "Copilot",
                                url: viewModel.copilotRoot,
                                tint: DesignTokens.Colors.Accent.orange,
                                menu: {
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
                                }
                            )
                            
                            // CodexSkillManager Root
                            rootCard(
                                title: "CodexSkillManager",
                                url: viewModel.codexSkillManagerRoot,
                                tint: DesignTokens.Colors.Accent.green,
                                menu: {
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
                                }
                            )
                        }
                    }
                    
                    // Options Section
                    sidebarSection(title: "Options") {
                        HStack {
                            Label("Recursive Scan", systemImage: "arrow.down.right.and.arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            Spacer()
                            Toggle("", isOn: $viewModel.recursive)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .scaleEffect(0.7)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.hair)
                        .background(DesignTokens.Colors.Background.primary)
                        .cornerRadius(DesignTokens.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
                        )
                    }
                    
                    // Filters Section
                    if mode == .validate {
                        sidebarSection(title: "Filters") {
                            VStack(spacing: DesignTokens.Spacing.xxs) {
                                filterPicker(title: "Severity", icon: "exclamationmark.triangle", selection: $severityFilter) {
                                    Text("All Severities").tag(Severity?.none)
                                    Divider()
                                    Text("Errors Only").tag(Severity?.some(.error))
                                    Text("Warnings").tag(Severity?.some(.warning))
                                    Text("Info").tag(Severity?.some(.info))
                                }
                                
                                filterPicker(title: "Agent", icon: "person.2", selection: $agentFilter) {
                                    Text("All Agents").tag(AgentKind?.none)
                                    Divider()
                                    ForEach(AgentKind.allCases, id: \.self) { agent in
                                        Text(agent.displayName).tag(AgentKind?.some(agent))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .background(DesignTokens.Colors.Background.secondary.ignoresSafeArea())
    }

    private var sidebarResizer: some View {
        let baseColor = DesignTokens.Colors.Border.light
        let strokeColor = isSidebarResizerHover ? baseColor.opacity(0.9) : baseColor.opacity(0.6)
        return Rectangle()
            .fill(strokeColor)
            .frame(width: 1)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                if sidebarDragStart == nil {
                                    sidebarDragStart = sidebarWidth
                                }
                                let start = sidebarDragStart ?? sidebarWidth
                                let proposed = start + value.translation.width
                                sidebarWidth = min(max(proposed, sidebarMinWidth), sidebarMaxWidth)
                            }
                            .onEnded { _ in
                                sidebarDragStart = nil
                            }
                    )
            )
            .onHover { hovering in
                isSidebarResizerHover = hovering
            }
    }

    // MARK: - Private Sidebar Components

    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, DesignTokens.Spacing.hair)
                .padding(.bottom, 4)

            content()
        }
        .padding(.top, DesignTokens.Spacing.xs)
        .padding(.bottom, DesignTokens.Spacing.xs)
        .overlay(
            // Bottom border for section separation
            Rectangle()
                .fill(DesignTokens.Colors.Border.light)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func sidebarRow<V: View>(title: String, icon: String, value: AppMode, tint: Color, @ViewBuilder trailing: () -> V = { EmptyView() }) -> some View {
        Button {
            mode = value
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mode == value ? .white : tint)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: mode == value ? .semibold : .medium))
                    .foregroundColor(mode == value ? .white : DesignTokens.Colors.Text.primary)

                Spacer()

                trailing()
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background {
                if mode == value {
                    HStack(spacing: 0) {
                        // 3px accent border on left
                        Rectangle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 3)

                        // Subtle gradient background
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.15),
                                        tint.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    private func rootCard<M: View>(title: String, url: URL?, tint: Color, @ViewBuilder menu: () -> M) -> some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            // Status indicator - simple circle
            Circle()
                .fill(url != nil ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Icon.tertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.Text.primary)

                Group {
                    if let url = url {
                        Text(shortenPath(url.path))
                    } else {
                        Text("Not configured")
                            .italic()
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.Text.secondary)
                .lineLimit(1)
            }

            Spacer()

            Menu {
                menu()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.Text.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.primary)
                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
        )
    }

    private func addRootButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("Add Root")
                    .font(.system(size: 13, weight: .medium))

                Spacer()
            }
            .foregroundStyle(DesignTokens.Colors.Accent.blue)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(DesignTokens.Colors.Accent.blue, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for url: URL?) -> Color {
        guard let url = url else { return DesignTokens.Colors.Accent.gray }
        return FileManager.default.fileExists(atPath: url.path) ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Status.error
    }

    private func statusIcon(for url: URL?) -> String {
        guard let url = url else { return "questionmark" }
        return FileManager.default.fileExists(atPath: url.path) ? "checkmark" : "exclamationmark"
    }

    private func filterPicker<S: View>(title: String, icon: String, selection: Binding<Severity?>, @ViewBuilder content: () -> S) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.hair)
            .background(DesignTokens.Colors.Background.primary)
            .cornerRadius(DesignTokens.Spacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func filterPicker<S: View>(title: String, icon: String, selection: Binding<AgentKind?>, @ViewBuilder content: () -> S) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.hair)
            .background(DesignTokens.Colors.Background.primary)
            .cornerRadius(DesignTokens.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Actions
private extension LegacyContentView {

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

}

// MARK: - Helpers
private extension LegacyContentView {
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

    private var cleanBackground: some View {
        DesignTokens.Colors.Background.primary
    }

    private var cleanSidebarBackground: some View {
        DesignTokens.Colors.Background.secondary
    }
    
    #if os(macOS)
    /// Configures the NSWindow to enforce minimum size constraints and bump undersized windows.
    /// This ensures the window never opens below 1200×800, even if macOS restores a smaller saved frame.
    private func configureWindow(_ window: NSWindow) {
        // Set minimum size to prevent users from resizing window too small
        window.minSize = NSSize(width: 1200, height: 800)
        
        // If current content size is below minimum, bump it up
        let currentSize = window.contentRect(forFrameRect: window.frame).size
        if currentSize.width < 1200 || currentSize.height < 800 {
            let targetSize = NSSize(
                width: max(currentSize.width, 1200),
                height: max(currentSize.height, 800)
            )
            // setContentSize adjusts the window frame to accommodate the new content size
            window.setContentSize(targetSize)
        }
    }
    #endif
}

// Alias for backward compatibility
typealias ContentView = LegacyContentView
