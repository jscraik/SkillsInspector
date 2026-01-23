import SwiftUI
import Charts
import SkillsCore
import AppKit

/// A bar chart displaying error trends grouped by rule
public struct ErrorTrendsChart: View {
    let report: ErrorTrendsReport
    @State private var selectedRule: String?
    @State private var isExporting = false

    public init(report: ErrorTrendsReport) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Header
            header

            // Chart content
            if report.errorsByRule.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(
            glassPanelStyle(cornerRadius: DesignTokens.Radius.lg)
        )
    }
}

// MARK: - Subviews
private extension ErrorTrendsChart {

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(DesignTokens.Colors.Accent.red)
                        .font(.title3)
                    Text("Error Trends")
                        .heading3()
                }

                // Summary metrics
                HStack(spacing: DesignTokens.Spacing.md) {
                    metricItem(label: "Total Errors", value: "\(report.totalErrors)")
                    metricItem(label: "Rules", value: "\(report.errorsByRule.count)")
                }
            }

            Spacer()

            // Export PNG button
            Button(action: exportToPNG) {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(isExporting ? DesignTokens.Colors.Icon.tertiary : DesignTokens.Colors.Accent.red)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(DesignTokens.Colors.Accent.red.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Chart {
                // Bar marks for each rule
                ForEach(sortedRules, id: \.key) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("Rule", truncatedRuleName(item.key))
                    )
                    .foregroundStyle(barColor(for: item.value))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
            }
            .frame(height: max(200, CGFloat(sortedRules.count) * 30))
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(DesignTokens.Colors.Border.light)
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(DesignTokens.Colors.Border.light)
                    AxisValueLabel {
                        if let ruleName = value.as(String.self) {
                            Text(ruleName)
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .chartOverlay { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, in: geometry, using: chartProxy)
                                }
                        )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Error trends chart showing \(report.totalErrors) errors across \(report.errorsByRule.count) rules")

            // Selected rule info
            if let selectedRule,
               let count = report.errorsByRule[selectedRule] {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(truncatedRuleName(selectedRule))
                        .captionText(emphasis: true)
                    Text("•")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    Text("\(count) errors")
                        .captionText()
                        .foregroundStyle(barColor(for: count))
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(barColor(for: count).opacity(0.1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Status.success)

            Text("No Errors Found")
                .heading3()

            Text("No validation errors have been recorded in the selected time range.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
            Text(label)
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
        }
    }

    // MARK: - Helpers

    private var sortedRules: [(key: String, value: Int)] {
        report.errorsByRule.sorted { $0.value > $1.value }
    }

    private func truncatedRuleName(_ name: String) -> String {
        if name.count > 25 {
            return name.prefix(22) + "..."
        }
        return name
    }

    private func barColor(for count: Int) -> Color {
        // Color coding by severity (based on error count)
        switch count {
        case 0..<5:
            return DesignTokens.Colors.Accent.yellow  // Low severity
        case 5..<15:
            return DesignTokens.Colors.Accent.orange  // Medium severity
        default:
            return DesignTokens.Colors.Accent.red     // High severity
        }
    }

    private func updateSelection(at location: CGPoint, in geometry: GeometryProxy, using chartProxy: ChartProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }

        let plotArea = geometry[plotFrame]
        let yPosition = location.y - plotArea.minY
        guard yPosition >= 0, yPosition <= plotArea.height else {
            selectedRule = nil
            return
        }

        // Find closest rule
        let chartHeight = plotArea.height
        let ruleCount = sortedRules.count
        guard ruleCount > 0 else { return }

        let index = Int((yPosition / chartHeight) * CGFloat(ruleCount))
        let clampedIndex = max(0, min(ruleCount - 1, index))

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedRule = sortedRules[clampedIndex].key
        }
    }
}

// MARK: - PNG Export
private extension ErrorTrendsChart {
    /// Exports the chart as a PNG image
    func exportToPNG() {
        isExporting = true
        defer { isExporting = false }

        // Create a capture of the chart view
        let chartView = VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            header
            if report.errorsByRule.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .frame(width: 500, height: max(350, CGFloat(sortedRules.count) * 30 + 100))
        .background(Color(NSColor.windowBackgroundColor))

        // Use ImageRenderer to capture the view (available on macOS 14+)
        if #available(macOS 14.0, *) {
            let renderer = ImageRenderer(content: chartView)
            renderer.scale = 2.0  // Retina quality

            if let tiffData = renderer.nsImage?.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                savePNG(data: pngData)
            }
        } else {
            // Fallback for older macOS versions - show alert
            let alert = NSAlert()
            alert.messageText = "Export Unavailable"
            alert.informativeText = "PNG export requires macOS 14.0 or later."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Saves PNG data to a user-selected file
    func savePNG(data: Data) {
        let savePanel = NSSavePanel()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "-")
        savePanel.nameFieldStringValue = "error-trends-\(timestamp).png"
        savePanel.allowedContentTypes = [.png]
        savePanel.title = "Export Chart as PNG"

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else {
            return
        }

        do {
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Sample Data
extension ErrorTrendsChart {
    /// Sample error trends report for preview/testing
    public static let sampleReport: ErrorTrendsReport = {
        let errorsByRule: [String: Int] = [
            "missing-frontmatter": 18,
            "invalid-yaml-syntax": 12,
            "unknown-agent": 8,
            "malformed-markdown": 5,
            "missing-skill-metadata": 3,
            "category-not-found": 2,
            "empty-description": 1
        ]

        let errorsByAgent: [AgentKind: Int] = [
            .codex: 25,
            .claude: 15,
            .codexSkillManager: 8,
            .copilot: 1
        ]

        return ErrorTrendsReport(
            totalErrors: 49,
            errorsByRule: errorsByRule,
            errorsByAgent: errorsByAgent
        )
    }()

    /// Empty report for preview
    public static let emptyReport = ErrorTrendsReport(
        totalErrors: 0,
        errorsByRule: [:],
        errorsByAgent: [:]
    )

    /// Single error report
    public static let singleErrorReport = ErrorTrendsReport(
        totalErrors: 1,
        errorsByRule: ["missing-frontmatter": 1],
        errorsByAgent: [.codex: 1]
    )

    /// High severity report (many errors)
    public static let highSeverityReport: ErrorTrendsReport = {
        let errorsByRule: [String: Int] = [
            "critical-security-rule": 42,
            "severe-validation-failure": 28,
            "breaking-pattern-detected": 15
        ]

        return ErrorTrendsReport(
            totalErrors: 85,
            errorsByRule: errorsByRule,
            errorsByAgent: [.codex: 50, .claude: 35]
        )
    }()
}

// MARK: - Preview
#Preview("With Data") {
    ErrorTrendsChart(report: ErrorTrendsChart.sampleReport)
        .frame(width: 500, height: 400)
        .padding()
}

#Preview("Empty Data") {
    ErrorTrendsChart(report: ErrorTrendsChart.emptyReport)
        .frame(width: 500, height: 400)
        .padding()
}

#Preview("Single Error") {
    ErrorTrendsChart(report: ErrorTrendsChart.singleErrorReport)
        .frame(width: 500, height: 300)
        .padding()
}

#Preview("High Severity") {
    ErrorTrendsChart(report: ErrorTrendsChart.highSeverityReport)
        .frame(width: 500, height: 350)
        .padding()
}
