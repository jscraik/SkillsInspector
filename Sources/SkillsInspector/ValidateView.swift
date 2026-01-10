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
                print("Exported to \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
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
        HStack(spacing: 12) {
            Button(viewModel.isScanning ? "Scanning…" : "Scan") {
                Task { await viewModel.scan() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isScanning)
            
            Button("Cancel") { viewModel.cancelScan() }
                .disabled(!viewModel.isScanning)
            
            Toggle("Watch", isOn: $viewModel.watchMode)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Automatically re-scan when files change")
            
            Divider()
                .frame(height: 20)
            
            Button {
                showingExportDialog = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.findings.isEmpty)
            .help("Export validation results")

            // Progress indicator when scanning
            if viewModel.isScanning {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    if viewModel.totalFiles > 0 {
                        Text("\(viewModel.filesScanned)/\(viewModel.totalFiles)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Cache stats
            if viewModel.cacheHits > 0 && viewModel.filesScanned > 0 {
                let hitRate = Int(Double(viewModel.cacheHits) / Double(viewModel.filesScanned) * 100)
                Text("Cache: \(viewModel.cacheHits)/\(viewModel.filesScanned)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help("Cache hit rate: \(hitRate)%")
            }

            // Stats badges
            HStack(spacing: 12) {
                let errors = viewModel.findings.filter { $0.severity == .error }.count
                let warnings = viewModel.findings.filter { $0.severity == .warning }.count
                
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(errors > 0 ? .red : .secondary)
                    Text("\(errors)")
                }
                .font(.callout)
                .help("Errors")
                
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(warnings > 0 ? .orange : .secondary)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .regular))
    }

    private var content: some View {
        let filtered = filteredFindings(viewModel.findings)
        
        return HStack(spacing: 0) {
            // Findings list panel (fixed width, non-resizable)
            Group {
                if viewModel.isScanning && viewModel.findings.isEmpty {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a finding to view details")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Click a finding from the list or use ↑↓ arrow keys")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func findingsList(_ findings: [Finding]) -> some View {
        List(findings, selection: $selectedFinding) { finding in
            FindingRowView(finding: finding)
                .tag(finding)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .contextMenu {
                    contextMenuItems(for: finding)
                }
                .cardStyle(selected: finding.id == selectedFinding?.id, tint: finding.severity == .error ? .red : .orange)
        }
        .listStyle(.inset)
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
            baselineMessage = "Added to baseline:\n\(baselineURL.path)"
            showingBaselineSuccess = true
            
            // Refresh the scan to apply the new baseline
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                await viewModel.scan()
            }
        } catch {
            baselineMessage = "Failed to add to baseline:\n\(error.localizedDescription)"
            showingBaselineSuccess = true
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
