import SwiftUI
import SkillsCore

struct ValidateView: View {
    @ObservedObject var viewModel: InspectorViewModel
    @Binding var severityFilter: Severity?
    @Binding var agentFilter: AgentKind?
    @Binding var searchText: String
    @State private var selectedFindingID: Finding.ID?
    @State private var showingBaselineSuccess = false
    @State private var baselineMessage = ""
    @State private var showingExportDialog = false
    @State private var exportFormat: ExportFormat = .json
    @State private var toastMessage: ToastMessage? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .searchable(text: $searchText, placement: .toolbar)
        .alert("Baseline Updated", isPresented: $showingBaselineSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(baselineMessage)
        }
        .fileExporter(isPresented: $showingExportDialog, document: ExportDocument(findings: viewModel.findings, format: exportFormat), contentType: exportFormat.contentType, defaultFilename: "validation-report.\(exportFormat.fileExtension)") { result in
            switch result {
            case .success(let url):
                toastMessage = ToastMessage(style: .success, message: "Exported to \(url.lastPathComponent)")
            case .failure(let error):
                toastMessage = ToastMessage(style: .error, message: "Export failed: \(error.localizedDescription)")
            }
        }
        .toast($toastMessage)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            exportFormat = format
                            showingExportDialog = true
                        } label: {
                            Label(format.rawValue, systemImage: format.icon)
                        }
                    }
                } label: {
                    Label("Export Format", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
            Task { await viewModel.scan(userInitiated: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
            viewModel.cancelScan()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleWatch)) { _ in
            viewModel.watchMode.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCache)) { _ in
            Task { await viewModel.clearCache() }
        }
        .onChange(of: viewModel.scanError) { _, error in
            if let error = error {
                toastMessage = ToastMessage(style: .error, message: error)
            }
        }
        .onChange(of: viewModel.scanSuccessMessage) { _, message in
            if let message = message {
                toastMessage = ToastMessage(style: .success, message: message)
            }
        }
    }
}

// MARK: - Subviews
private extension ValidateView {
    @ViewBuilder
    private var toolbar: some View {
        VStack(spacing: 0) {
            // Main Action Toolbar
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Primary Action Group
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        Task { await viewModel.scan(userInitiated: true) }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            if viewModel.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                            Text(viewModel.isScanning ? "Scanning…" : "Scan Rules")
                                .fontWeight(.semibold)
                        }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isScanning)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help("Validate skill files against all rules (⌘R)")
                    
                    if viewModel.isScanning {
                        Button("Stop") { 
                            viewModel.cancelScan() 
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                
                Divider()
                    .frame(height: 28)
                
                // Configuration Shortcuts
                HStack(spacing: DesignTokens.Spacing.xs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch Mode")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        Toggle("", isOn: $viewModel.watchMode)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .help("Automatically re-scan when files change")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        Button {
                            viewModel.recursive.toggle()
                        } label: {
                            Label("Recursive", systemImage: viewModel.recursive ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.down.right.and.arrow.up.left.circle")
                                .foregroundStyle(viewModel.recursive ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Icon.tertiary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .help("Recursive search: \(viewModel.recursive ? "On" : "Off")")
                    }
                }
                
                Spacer()
                
                // Dynamic Progress / Stats
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if viewModel.isScanning {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("SCANNING")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            if viewModel.totalFiles > 0 {
                                Text("\(viewModel.filesScanned) / \(viewModel.totalFiles)")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                            } else {
                                Text("Starting…")
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                    } else if let lastScanAt = viewModel.lastScanAt {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("LAST RUN")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            Text(lastScanAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }

                    if viewModel.cacheHits > 0 && viewModel.filesScanned > 0 {
                        let hitRate = Int(Double(viewModel.cacheHits) / Double(viewModel.filesScanned) * 100)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("CACHE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            Text("\(hitRate)%")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignTokens.Colors.Accent.green)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.Accent.green.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                        .help("Cache hit rate: \(hitRate)%")
                    }
                }
                
                Divider()
                    .frame(height: 28)

                // Global Export
                Menu {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            exportFormat = format
                            showingExportDialog = true
                        } label: {
                            Label(format.rawValue, systemImage: format.icon)
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
                .disabled(viewModel.findings.isEmpty)
                .buttonStyle(.plain)
                .help("Export validation results")
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(cleanToolbarStyle(cornerRadius: 0))
            
            Divider()

            // Severity Filtering Bar
            if !viewModel.findings.isEmpty || viewModel.isScanning {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        
                        let errors = viewModel.findings.filter { $0.severity == .error }.count
                        let warnings = viewModel.findings.filter { $0.severity == .warning }.count
                        let infos = viewModel.findings.filter { $0.severity == .info }.count
                        
                        severityBadge(count: errors, severity: .error, isActive: severityFilter == .error)
                        severityBadge(count: warnings, severity: .warning, isActive: severityFilter == .warning)
                        severityBadge(count: infos, severity: .info, isActive: severityFilter == .info)
                    }

                    Spacer()

                    if let duration = viewModel.lastScanDuration {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: "timer")
                            Text(String(format: "%.2fs", duration))
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(cleanToolbarStyle(cornerRadius: 0))
            }
        }
        // Previous implementation had these auto-scan triggers:
        // .task(id: viewModel.recursive) { try? await Task.sleep(nanoseconds: 800_000_000); await autoScanIfReady() }
        // .task(id: viewModel.effectiveExcludes) { try? await Task.sleep(nanoseconds: 1_200_000_000); await autoScanIfReady() }
        // These caused immediate scans on view appearance, triggering "Scanning..." state before UI was responsive.
        // Scan control is now explicit: users click "Scan Rules" button (⌘R) or enable watch mode for automatic re-scanning on file changes.
    }

    private func severityBadge(count: Int, severity: Severity, isActive: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if severityFilter == severity {
                    severityFilter = nil
                } else {
                    severityFilter = severity
                    agentFilter = nil
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.hair) {
                Image(systemName: severity.icon)
                    .font(.caption2)
                Text("\(count)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(count > 0 ? .medium : .regular)
            }
            .foregroundStyle(count > 0 ? severity.color : DesignTokens.Colors.Text.tertiary)
            .padding(.horizontal, DesignTokens.Spacing.xxxs)
            .padding(.vertical, DesignTokens.Spacing.hair)
            .background(
                Group {
                    if isActive {
                        severity.color.opacity(0.2)
                    } else if count > 0 {
                        severity.color.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(DesignTokens.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(isActive ? severity.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("\(severity.rawValue.capitalized): \(count) findings")
    }

    @ViewBuilder
    private var content: some View {
        let filtered = filteredFindings(viewModel.findings)
        let currentFinding = resolvedFinding(in: filtered)
        HStack(spacing: 0) {
            // Left Pane: Findings List
            VStack(spacing: 0) {
                // Scanning Progress Indicator
                if viewModel.isScanning {
                    ProgressView(value: viewModel.scanProgress)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .tint(DesignTokens.Colors.Accent.blue)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.isScanning && viewModel.findings.isEmpty {
                    List {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonFindingRow()
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                } else if viewModel.findings.isEmpty {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                        
                        VStack(spacing: DesignTokens.Spacing.xxxs) {
                            Text("No findings yet")
                                .font(.headline)
                            Text("Run a scan to validate your skills")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        }
                        
                        Button("Start Scan") {
                            Task { await viewModel.scan(userInitiated: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                        Text("No results match your filters")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        Button("Clear Filters") {
                            severityFilter = nil
                            agentFilter = nil
                            searchText = ""
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        let autoFixableCount = viewModel.findings.filter { $0.suggestedFix?.automated == true }.count
                        if autoFixableCount > 1 {
                            Button {
                                fixAllAutomated()
                            } label: {
                                Label("Apply \(autoFixableCount) Auto-Fixes", systemImage: "wand.and.stars.inverse")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.cleanProminent)
                            .tint(DesignTokens.Colors.Accent.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(DesignTokens.Colors.Accent.green.opacity(0.05))
                            .transition(.move(edge: .top))
                        }
                        
                        findingsList(filtered)
                    }
                }
            }
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)
            .background(DesignTokens.Colors.Background.secondary.opacity(0.15))
            
            Divider()
            
            // Right Pane: Detail View
            ZStack {
                if let finding = currentFinding {
                    FindingDetailView(finding: finding)
                        .id(finding.id) // Force refresh on selection change
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                        Text("Select a finding to details")
                            .font(.headline)
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.Background.primary)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentFinding?.id)
        }
    }
    
    private var emptyDetailState: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
            Text("Select a finding to view details")
                .heading3()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
            Text("Click a finding from the list or use ↑↓ arrow keys")
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func findingsList(_ findings: [Finding]) -> some View {
        List(findings, selection: $selectedFindingID) { finding in
            FindingRowView(finding: finding)
                .tag(finding.id)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .contextMenu {
                    contextMenuItems(for: finding)
                }
                .cardStyle(selected: finding.id == selectedFindingID, tint: finding.severity == .error ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Status.warning)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSeparator(.hidden)
        .accessibilityLabel("Findings list")
        .onAppear {
            reconcileSelection(with: findings)
        }
        .onChange(of: findings.map(\.id)) {
            reconcileSelection(with: findings)
        }
        .onChange(of: selectedFindingID) {
            reconcileSelection(with: findings)
        }
        .onKeyPress(.upArrow) {
            navigateFindings(findings, direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateFindings(findings, direction: 1)
            return .handled
        }
    }
    
    private func navigateFindings(_ findings: [Finding], direction: Int) {
        guard let currentID = selectedFindingID,
              let index = findings.firstIndex(where: { $0.id == currentID }) else {
            selectedFindingID = findings.first?.id
            return
        }
        let newIndex = index + direction
        if newIndex >= 0 && newIndex < findings.count {
            selectedFindingID = findings[newIndex].id
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for finding: Finding) -> some View {
        Menu("Open in Editor") {
            ForEach(EditorIntegration.installedEditors, id: \.self) { editor in
                Button {
                    FindingActions.openInEditor(finding.fileURL, line: finding.line, editor: editor)
                } label: {
                    Label(editor.rawValue, systemImage: editor.icon)
                }
            }
        }
        
        Button("Show in Finder") {
            FindingActions.showInFinder(finding.fileURL)
        }
        
        Divider()
        
        Button("Add to Baseline") {
            addToBaseline(finding)
        }
        
        Divider()
        
        Button("Copy Rule ID") {
            FindingActions.copyToClipboard(finding.ruleID)
        }
        
        Button("Copy File Path") {
            FindingActions.copyToClipboard(finding.fileURL.path)
        }
        
        Button("Copy Message") {
            FindingActions.copyToClipboard(finding.message)
        }
    }
}

// MARK: - Actions
private extension ValidateView {
    // Auto-scan on settings changes has been disabled to prevent launch flicker/unresponsiveness.
    // Users can now trigger scans explicitly via:
    // - "Scan Rules" button (⌘R)
    // - "Run Scan" menu command (⌘R)
    // - Enabling watch mode (⌘⇧W) for automatic re-scanning on file changes

    private func addToBaseline(_ finding: Finding) {
        let baselineURL: URL
        if let repoRoot = findRepoRoot(from: finding.fileURL) {
            baselineURL = repoRoot.appendingPathComponent(".skillsctl/baseline.json")
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            baselineURL = home.appendingPathComponent(".skillsctl/baseline.json")
        }
        
        do {
            try FindingActions.addToBaseline(finding, baselineURL: baselineURL)
            toastMessage = ToastMessage(style: .success, message: "Added to baseline")
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await viewModel.scan(userInitiated: true)
            }
        } catch {
            toastMessage = ToastMessage(style: .error, message: "Failed to add to baseline")
        }
    }

    private func fixAllAutomated() {
        let autoFixes = viewModel.findings.compactMap { $0.suggestedFix }.filter { $0.automated }
        guard !autoFixes.isEmpty else { return }
        
        var successCount = 0
        for fix in autoFixes {
            if case .success = FixEngine.applyFix(fix) {
                successCount += 1
            }
        }
        
        toastMessage = ToastMessage(style: .success, message: "Applied \(successCount) fixes successfully! Re-scanning...")
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await viewModel.scan(userInitiated: true)
        }
    }
}

// MARK: - Helpers
private extension ValidateView {
    private func findRepoRoot(from url: URL) -> URL? {
        var current = url.deletingLastPathComponent()
        while current.path != "/" {
            let gitPath = current.appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: gitPath) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private func resolvedFinding(in findings: [Finding]) -> Finding? {
        guard let selectedFindingID else { return findings.first }
        return findings.first(where: { $0.id == selectedFindingID }) ?? findings.first
    }

    private func reconcileSelection(with findings: [Finding]) {
        guard !findings.isEmpty else {
            selectedFindingID = nil
            return
        }
        if let selectedFindingID,
           findings.contains(where: { $0.id == selectedFindingID }) {
            return
        }
        selectedFindingID = findings.first?.id
    }

    private func filteredFindings(_ findings: [Finding]) -> [Finding] {
        findings.filter { f in
            if let sev = severityFilter, f.severity != sev { return false }
            if let agent = agentFilter, f.agent != agent { return false }
            if !searchText.isEmpty {
                let hay = "\(f.ruleID) \(f.message) \(f.fileURL.path)".lowercased()
                if !hay.contains(searchText.lowercased()) { return false }
            }
            return true
        }
    }
}
