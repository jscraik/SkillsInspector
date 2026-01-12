import SwiftUI
import SkillsCore

struct ValidateView: View {
    @ObservedObject var viewModel: InspectorViewModel
    @Binding var severityFilter: Severity?
    @Binding var agentFilter: AgentKind?
    @Binding var searchText: String
    @State private var selectedFinding: Finding?
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
            Task { await viewModel.scan() }
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
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            // Main toolbar
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Primary actions group
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button(viewModel.isScanning ? "Scanning…" : "Scan") {
                        Task { await viewModel.scan() }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isScanning)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    
                    Button("Cancel") { 
                        viewModel.cancelScan() 
                    }
                    .disabled(!viewModel.isScanning)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                Divider()
                    .frame(height: 24)
                
                // Watch mode toggle
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Label("Watch Mode", systemImage: "eye")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(viewModel.watchMode ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Icon.secondary)
                    Toggle("", isOn: $viewModel.watchMode)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .help("Automatically re-scan when files change")
                
                Spacer()
                
                // Progress and stats
                if viewModel.isScanning {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(DesignTokens.Colors.Accent.blue)
                        if viewModel.totalFiles > 0 {
                            Text("\(viewModel.filesScanned)/\(viewModel.totalFiles)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
                
                // Cache stats
                if viewModel.cacheHits > 0 && viewModel.filesScanned > 0 {
                    let hitRate = Int(Double(viewModel.cacheHits) / Double(viewModel.filesScanned) * 100)
                    HStack(spacing: DesignTokens.Spacing.hair) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(DesignTokens.Colors.Accent.green)
                            .font(.caption2)
                        Text("\(hitRate)%")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(DesignTokens.Colors.Accent.green.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.sm)
                    .help("Cache hit rate: \(hitRate)%")
                }
                
                // Export button
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
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.findings.isEmpty)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Export validation results")
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(glassBarStyle(cornerRadius: 0))
            
            // Stats summary bar
            if !viewModel.findings.isEmpty || viewModel.filesScanned > 0 {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    // Severity badges
                    let errors = viewModel.findings.filter { $0.severity == .error }.count
                    let warnings = viewModel.findings.filter { $0.severity == .warning }.count
                    let infos = viewModel.findings.filter { $0.severity == .info }.count
                    
                    severityBadge(count: errors, severity: .error, isActive: severityFilter == .error)
                    severityBadge(count: warnings, severity: .warning, isActive: severityFilter == .warning)
                    severityBadge(count: infos, severity: .info, isActive: severityFilter == .info)
                    
                    Spacer()
                    
                    // Scan timing
                    if let duration = viewModel.lastScanDuration {
                        HStack(spacing: DesignTokens.Spacing.hair) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(String(format: "%.2fs", duration))
                                .font(.system(.caption, design: .monospaced))
                        }
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    }
                    
                    if let lastScan = viewModel.lastScanAt {
                        Text(lastScan.formatted(date: .omitted, time: .shortened))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
            }
        }
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
                
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(errors > 0 ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Icon.secondary)
                    Text("\(errors)")
                }
                .font(.callout)
                .help("Errors")
                
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(warnings > 0 ? DesignTokens.Colors.Status.warning : DesignTokens.Colors.Icon.secondary)
                    Text("\(warnings)")
                }
                .font(.callout)
                .help("Warnings")
            }
            
            if let dur = viewModel.lastScanDuration {
                Text(String(format: "%.2fs", dur))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help("Scan duration")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.xxxs)
        .background(glassBarStyle(tint: DesignTokens.Colors.Accent.blue.opacity(0.05)))
        .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .regular))
    }

    private var content: some View {
        let filtered = filteredFindings(viewModel.findings)
        
        return HStack(spacing: 0) {
            // Findings list panel (fixed width, non-resizable)
            Group {
                if viewModel.isScanning && viewModel.findings.isEmpty {
                    // Loading state with skeletons
                    List {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonFindingRow()
                                .listRowBackground(glassPanelStyle(cornerRadius: 12, tint: Color.primary.opacity(0.05)))
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.inset)
                } else if viewModel.findings.isEmpty && viewModel.lastScanAt != nil {
                    // Empty state after scan
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "No Issues Found",
                        message: "All skill files pass validation.",
                        action: { Task { await viewModel.scan() } },
                        actionLabel: "Scan Again"
                    )
                } else if viewModel.findings.isEmpty {
                    // Initial state
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Ready to Scan",
                        message: "Press Scan or ⌘R to validate skill files.",
                        action: { Task { await viewModel.scan() } },
                        actionLabel: "Scan Now"
                    )
                } else if filtered.isEmpty {
                    // Filter produced no results
                    EmptyStateView(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "No Matching Findings",
                        message: "Try adjusting your filters or search query."
                    )
                } else {
                    // Normal list
                    findingsList(filtered)
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(glassPanelStyle(cornerRadius: 0, tint: Color.primary.opacity(0.04)))
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 440)
            .animation(.easeInOut(duration: 0.2), value: viewModel.findings.count)
            .animation(.easeInOut(duration: 0.2), value: filtered.count)
            
            Divider()
            
            // Detail panel (flexible)
            Group {
                if let finding = selectedFinding {
                    FindingDetailView(finding: finding)
                } else {
                    emptyDetailState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        List(findings, selection: $selectedFinding) { finding in
            FindingRowView(finding: finding)
                .tag(finding)
                .listRowBackground(glassPanelStyle(cornerRadius: 12, tint: finding.severity.color.opacity(0.08)))
                .listRowInsets(EdgeInsets())
                .contextMenu {
                    contextMenuItems(for: finding)
                }
                .cardStyle(selected: finding.id == selectedFinding?.id, tint: finding.severity == .error ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Status.warning)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSeparator(.hidden)
        .background(glassPanelStyle(cornerRadius: 10, tint: DesignTokens.Colors.Accent.blue.opacity(0.03)))
        .accessibilityLabel("Findings list")
        .onAppear {
            // Auto-select first finding if none selected
            if selectedFinding == nil && !findings.isEmpty {
                selectedFinding = findings.first
            }
        }
        .onChange(of: findings) { _, newFindings in
            // Clear selection if current finding no longer exists
            if let current = selectedFinding, !newFindings.contains(where: { $0.id == current.id }) {
                selectedFinding = newFindings.first
            }
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
        guard let current = selectedFinding,
              let index = findings.firstIndex(where: { $0.id == current.id }) else {
            selectedFinding = findings.first
            return
        }
        let newIndex = index + direction
        if newIndex >= 0 && newIndex < findings.count {
            selectedFinding = findings[newIndex]
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
    
    private func addToBaseline(_ finding: Finding) {
        // Determine baseline URL (prefer repo root if available)
        let baselineURL: URL
        if let repoRoot = findRepoRoot(from: finding.fileURL) {
            baselineURL = repoRoot.appendingPathComponent(".skillsctl/baseline.json")
        } else {
            // Fall back to home directory
            let home = FileManager.default.homeDirectoryForCurrentUser
            baselineURL = home.appendingPathComponent(".skillsctl/baseline.json")
        }
        
        do {
            try FindingActions.addToBaseline(finding, baselineURL: baselineURL)
            toastMessage = ToastMessage(style: .success, message: "Added to baseline")
            
            // Refresh the scan to apply the new baseline
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                await viewModel.scan()
            }
        } catch {
            toastMessage = ToastMessage(style: .error, message: "Failed to add to baseline: \(error.localizedDescription)")
        }
    }
    
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

    private func color(for severity: Severity) -> Color {
        severity.color
    }
}
