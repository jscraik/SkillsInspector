import SwiftUI
import SkillsCore

/// Security scan view displaying security findings with filtering and false positive management
struct SecurityScanView: View {
    @ObservedObject var viewModel: SecurityScanViewModel
    @State private var selectedSeverity: SeverityFilter = .all
    @State private var searchText: String = ""
    @State private var scanner: SecurityScanner

    init(viewModel: SecurityScanViewModel) {
        self.viewModel = viewModel
        self._scanner = State(initialValue: SecurityScanner())
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Findings list
            if filteredFindings.isEmpty {
                emptyState
            } else {
                findingsList
            }
        }
        .frame(minHeight: 200)
        .task {
            await runScanIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Title and status
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("Security Scan")
                    .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))

                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Circle()
                        .fill(scanStatusColor)
                        .frame(width: 8, height: 8)

                    Text(scanStatusText)
                        .font(.system(size: DesignTokens.Typography.Caption.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Severity filter
                Picker("", selection: $selectedSeverity) {
                    Text("All").tag(SeverityFilter.all)
                    Text("Errors").tag(SeverityFilter.error)
                    Text("Warnings").tag(SeverityFilter.warning)
                    Text("Info").tag(SeverityFilter.info)
                }
                .pickerStyle(.menu)
                .frame(width: 80)

                // Search
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)

                TextField("Search findings...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 150)
                    .font(.system(size: DesignTokens.Typography.Body.size))

                // Scan button
                Button {
                    Task {
                        await viewModel.runSecurityScan()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .help("Run security scan")

                // Clear button
                if !viewModel.securityFindings.isEmpty {
                    Button(action: {
                        viewModel.securityFindings = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear findings")
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary)
    }

    // MARK: - Findings List

    private var findingsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedFindings.keys.sorted(), id: \.self) { filePath in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                        // File header
                        Text(filePath)
                            .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.top, DesignTokens.Spacing.sm)

                        // Findings for this file
                        ForEach(groupedFindings[filePath] ?? []) { finding in
                            SecurityFindingRowView(
                                finding: finding,
                                scanner: scanner,
                                onRefresh: {
                                    Task {
                                        await viewModel.runSecurityScan()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Icon.statusSuccess)

            Text("No security issues found")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            Text("Run a scan to check for vulnerabilities")
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            Button("Run Scan") {
                Task {
                    await viewModel.runSecurityScan()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    // MARK: - Computed Properties

    private var filteredFindings: [Finding] {
        viewModel.securityFindings.filter { finding in
            // Filter by severity
            let severityMatch = selectedSeverity == .all || selectedSeverity.matches(finding.severity)

            // Filter by search text
            let searchMatch = searchText.isEmpty ||
                finding.message.localizedCaseInsensitiveContains(searchText) ||
                finding.ruleID.localizedCaseInsensitiveContains(searchText)

            return severityMatch && searchMatch
        }
    }

    private var groupedFindings: [String: [Finding]] {
        Dictionary(grouping: filteredFindings) { $0.fileURL.path }
    }

    private var scanStatusColor: Color {
        if viewModel.securityFindings.isEmpty {
            return DesignTokens.Colors.Icon.statusSuccess
        } else {
            return DesignTokens.Colors.Icon.statusError
        }
    }

    private var scanStatusText: String {
        if viewModel.securityFindings.isEmpty {
            return "No issues"
        } else {
            let errorCount = viewModel.securityFindings.filter { $0.severity == .error }.count
            let warningCount = viewModel.securityFindings.filter { $0.severity == .warning }.count
            let infoCount = viewModel.securityFindings.filter { $0.severity == .info }.count

            var parts: [String] = []
            if errorCount > 0 { parts.append("\(errorCount) error" + (errorCount == 1 ? "" : "s")) }
            if warningCount > 0 { parts.append("\(warningCount) warning" + (warningCount == 1 ? "" : "s")) }
            if infoCount > 0 { parts.append("\(infoCount) info") }

            return parts.joined(separator: ", ")
        }
    }

    // MARK: - Helpers

    private func runScanIfNeeded() async {
        if viewModel.securityFindings.isEmpty {
            await viewModel.runSecurityScan()
        }
    }
}

// MARK: - Severity Filter

enum SeverityFilter: String, CaseIterable {
    case all
    case error
    case warning
    case info

    func matches(_ severity: Severity) -> Bool {
        switch self {
        case .all: return true
        case .error: return severity == .error
        case .warning: return severity == .warning
        case .info: return severity == .info
        }
    }
}

// MARK: - Finding Row View

struct SecurityFindingRowView: View {
    let finding: Finding
    let scanner: SecurityScanner
    let onRefresh: () -> Void

    @State private var isIgnored: Bool = false

    init(finding: Finding, scanner: SecurityScanner, onRefresh: @escaping () -> Void) {
        self.finding = finding
        self.scanner = scanner
        self.onRefresh = onRefresh
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            // Severity icon
            severityIcon
                .frame(width: 20)

            // Finding details
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                // Rule ID and line
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text(finding.ruleID)
                        .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .semibold))
                        .foregroundStyle(severityColor)

                    if let line = finding.line {
                        Text(":\(line)")
                            .font(.system(size: DesignTokens.Typography.Caption.size))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }

                    Spacer()

                    // False positive feedback menu
                    FalsePositiveFeedbackView(
                        finding: finding,
                        isIgnored: isIgnored,
                        onIgnore: {
                            Task {
                                await ignoreFinding()
                            }
                        },
                        onUnignore: {
                            Task {
                                await unignoreFinding()
                            }
                        }
                    )
                }

                // Message
                Text(finding.message)
                    .font(.system(size: DesignTokens.Typography.Body.size))
                    .fixedSize(horizontal: false, vertical: true)

                // Suggested fix
                if let fix = finding.suggestedFix {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: DesignTokens.Typography.Caption.size))
                            .foregroundStyle(DesignTokens.Colors.Icon.accent)

                        Text(fix.description)
                            .font(.system(size: DesignTokens.Typography.Caption.size))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                }

                // File location
                Text(finding.fileURL.path)
                    .font(.system(size: DesignTokens.Typography.Caption.size))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.tertiary.opacity(isIgnored ? 0.3 : 0.0))
        .cornerRadius(DesignTokens.Radius.sm)
        .task {
            await checkIgnoredStatus()
        }
    }

    private var severityIcon: some View {
        Image(systemName: iconName)
            .foregroundColor(severityColor)
            .frame(width: 16, height: 16)
    }

    private var iconName: String {
        switch finding.severity {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch finding.severity {
        case .error: return DesignTokens.Colors.Icon.statusError
        case .warning: return DesignTokens.Colors.Icon.statusWarning
        case .info: return DesignTokens.Colors.Icon.primary
        }
    }

    // MARK: - Actions

    private func checkIgnoredStatus() async {
        isIgnored = await scanner.isIgnored(finding)
    }

    private func ignoreFinding() async {
        await scanner.ignoreFinding(finding)
        isIgnored = true
        onRefresh()
    }

    private func unignoreFinding() async {
        await scanner.unignoreFinding(finding)
        isIgnored = false
        onRefresh()
    }
}

// MARK: - Preview

class SecurityScanViewModel: ObservableObject {
    @Published var securityFindings: [Finding] = []

    func runSecurityScan() async {
        // No-op for preview
    }
}

/*
#Preview("Security Scan View - With Findings") {
    let viewModel: SecurityScanViewModel = SecurityScanViewModel()
    viewModel.securityFindings = [
        Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/path/to/skill.swift"),
            message: "Hardcoded API key detected",
            line: 42,
            suggestedFix: SuggestedFix(
                ruleID: "security.hardcoded_secret",
                description: "Use environment variables",
                automated: false,
                changes: []
            )
        ),
        Finding(
            ruleID: "security.command_injection",
            severity: .warning,
            agent: .claude,
            fileURL: URL(fileURLWithPath: "/path/to/script.sh"),
            message: "Potential command injection via shell()",
            line: 15,
            suggestedFix: SuggestedFix(
                ruleID: "security.command_injection",
                description: "Use Process class with proper argument escaping",
                automated: false,
                changes: []
            )
        )
    ]
}

    SecurityScanView(viewModel: viewModel)
}
*/