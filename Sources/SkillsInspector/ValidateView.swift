import SwiftUI
import SkillsCore

struct ValidateView: View {
    @ObservedObject var viewModel: InspectorViewModel
    @Binding var severityFilter: Severity?
    @Binding var agentFilter: AgentKind?
    @Binding var searchText: String
    @State private var selectedFinding: Finding?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .searchable(text: $searchText, placement: .toolbar)
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

            let errors = viewModel.findings.filter { $0.severity == .error }.count
            let warnings = viewModel.findings.filter { $0.severity == .warning }.count
            Text("Errors: \(errors)  Warnings: \(warnings)")
                .font(.system(.callout, design: .monospaced))
                .accessibilityLabel("Errors: \(errors), Warnings: \(warnings)")
            if let ts = viewModel.lastScanAt {
                Text("Last: \(ts.formatted(date: .abbreviated, time: .standard))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Last scan: \(ts.formatted(date: .abbreviated, time: .standard))")
            }
            if let dur = viewModel.lastScanDuration {
                Text(String(format: "Duration: %.2fs", dur))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Scan duration: \(String(format: "%.1f", dur)) seconds")
            }
        }
        .padding(8)
        .background(.thickMaterial)
    }

    private var content: some View {
        NavigationSplitView {
            List(filteredFindings(viewModel.findings), selection: $selectedFinding) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    Text("[\(finding.severity.rawValue.uppercased())] \(finding.agent.rawValue)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(color(for: finding.severity))
                        .accessibilityLabel("\(finding.severity.rawValue) for \(finding.agent.rawValue)")
                    Text(finding.message)
                        .accessibilityLabel(finding.message)
                    Text(finding.fileURL.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("File: \(finding.fileURL.path)")
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
            .accessibilityLabel("Findings list")
        } detail: {
            if let finding = selectedFinding {
                FindingDetailView(finding: finding)
            } else {
                Text("Select a finding to view details")
                    .foregroundStyle(.secondary)
            }
        }
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
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .secondary
        }
    }
}
