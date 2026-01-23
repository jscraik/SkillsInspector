import SwiftUI
import Charts
import SkillsCore
import UniformTypeIdentifiers

/// Time range options for analytics queries
public enum AnalyticsTimeRange: String, CaseIterable, Sendable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case all = "all"

    public var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        case .all: return "All Time"
        }
    }

    public var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .all: return nil
        }
    }
}

/// Analytics dashboard displaying scan frequency, error trends, and top skills
public struct AnalyticsDashboardView: View {
    @State private var selectedTimeRange: AnalyticsTimeRange = .thirtyDays
    @State private var scanFrequencyMetrics: ScanFrequencyMetrics?
    @State private var errorTrendsReport: ErrorTrendsReport?
    @State private var topSkills: [SkillUsageRanking]?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var showExportSuccess = false

    private let analytics = UsageAnalytics()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public init() {}

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Header with time range picker
            header

            if isLoading {
                loadingState
            } else if let error = errorMessage {
                errorState(error)
            } else {
                dashboardContent
            }
        }
        .padding(DesignTokens.Spacing.md)
        .task {
            await loadAnalyticsData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            Task {
                await loadAnalyticsData()
            }
        }
    }
}

// MARK: - Header
private extension AnalyticsDashboardView {
    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        .font(.title2)
                    Text("Usage Analytics")
                        .heading2()
                }

                Text("Track scan patterns, error trends, and most-used skills")
                    .bodyText()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }

            Spacer()

            HStack(spacing: DesignTokens.Spacing.sm) {
                // Export button
                Button(action: exportCSV) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: DesignTokens.Typography.Body.size))
                        Text("Export CSV")
                            .font(.system(size: DesignTokens.Typography.Body.size))
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Colors.Accent.blue.opacity(0.1))
                    )
                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    .overlay(
                        Capsule()
                            .stroke(DesignTokens.Colors.Accent.blue, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || (scanFrequencyMetrics == nil && errorTrendsReport == nil))

                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                        Text(range.displayName)
                            .tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {
                exportMessage = nil
            }
        } message: {
            if let message = exportMessage {
                Text(message)
            }
        }
    }
}

// MARK: - Dashboard Content
private extension AnalyticsDashboardView {
    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Scan Frequency and Error Trends in a row
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Scan Frequency Chart
                    if let metrics = scanFrequencyMetrics {
                        ScanFrequencyChart(metrics: metrics)
                            .frame(maxWidth: .infinity)
                    } else {
                        placeholderCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Scan Frequency",
                            message: "No scan data available for the selected time range."
                        )
                        .frame(maxWidth: .infinity)
                    }

                    // Error Trends Chart
                    if let report = errorTrendsReport {
                        ErrorTrendsChart(report: report)
                            .frame(maxWidth: .infinity)
                    } else {
                        placeholderCard(
                            icon: "checkmark.circle",
                            title: "Error Trends",
                            message: "No errors recorded in the selected time range."
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                // Top Skills List
                if let rankings = topSkills, !rankings.isEmpty {
                    topSkillsList(rankings)
                } else {
                    placeholderCard(
                        icon: "doc.text",
                        title: "Top Skills",
                        message: "No skill scan data available for the selected time range."
                    )
                }
            }
        }
    }

    private func topSkillsList(_ rankings: [SkillUsageRanking]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: "star.fill")
                    .foregroundStyle(DesignTokens.Colors.Accent.yellow)
                    .font(.title3)
                Text("Top Skills")
                    .heading3()
            }

            VStack(spacing: DesignTokens.Spacing.xxxs) {
                ForEach(Array(rankings.enumerated()), id: \.element.skillName) { index, ranking in
                    SkillRankingRow(
                        ranking: ranking,
                        rank: index + 1
                    )
                }
            }
            .padding(DesignTokens.Spacing.xxxs)
            .background(
                glassPanelStyle(cornerRadius: DesignTokens.Radius.lg)
            )
        }
    }

    private func placeholderCard(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: icon)
                    .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                    .font(.title3)
                Text(title)
                    .heading3()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }

            Text(message)
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.xs)
        .background(
            glassPanelStyle(cornerRadius: DesignTokens.Radius.lg)
        )
    }

    private var loadingState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                SkeletonScanFrequencyChart()
                    .frame(maxWidth: .infinity)

                SkeletonErrorTrendsChart()
                    .frame(maxWidth: .infinity)
            }

            SkeletonTopSkillsList()
        }
    }

    private func errorState(_ message: String) -> some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Analytics Unavailable",
            message: message,
            action: {
                Task {
                    await loadAnalyticsData()
                }
            },
            actionLabel: "Retry"
        )
    }
}

// MARK: - Data Loading
private extension AnalyticsDashboardView {
    private func loadAnalyticsData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Determine days to query
            let days = selectedTimeRange.days ?? 365  // Use 365 days for "all"

            // Load all analytics data in parallel
            async let frequency = analytics.scanFrequency(days: days)
            async let errors = analytics.errorTrends(byRule: true, days: days)
            async let skills = analytics.mostScannedSkills(limit: 10, days: days)

            // Wait for all data to load
            let (metrics, report, rankings) = try await (frequency, errors, skills)

            await MainActor.run {
                scanFrequencyMetrics = metrics
                errorTrendsReport = report
                topSkills = rankings
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - CSV Export
private extension AnalyticsDashboardView {
    /// Exports analytics data to CSV files
    func exportCSV() {
        guard let metrics = scanFrequencyMetrics, let errors = errorTrendsReport else {
            exportMessage = "No data available to export"
            showExportSuccess = true
            return
        }

        do {
            // Generate filename with timestamp
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "+", with: "-")
            let baseFilename = "analytics-\(selectedTimeRange.displayName.lowercased().replacingOccurrences(of: " ", with: "-"))"

            // Create save panel for frequency data
            let frequencyCSV = generateScanFrequencyCSV(metrics: metrics)
            let frequencyURL = try saveFile(
                content: frequencyCSV,
                defaultFilename: "\(baseFilename)-frequency-\(timestamp).csv"
            )

            // Create save panel for error data
            let errorsCSV = generateErrorTrendsCSV(report: errors)
            let errorsURL = try saveFile(
                content: errorsCSV,
                defaultFilename: "\(baseFilename)-errors-\(timestamp).csv"
            )

            exportMessage = "Exported 2 files:\n• \(frequencyURL.lastPathComponent)\n• \(errorsURL.lastPathComponent)"
            showExportSuccess = true
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
            showExportSuccess = true
        }
    }

    /// Generates CSV content for scan frequency metrics
    /// Format: date,scan_count
    private func generateScanFrequencyCSV(metrics: ScanFrequencyMetrics) -> String {
        var lines: [String] = []
        lines.append("date,scan_count")

        for dailyCount in metrics.dailyCounts {
            let dateString = dateFormatter.string(from: dailyCount.date)
            lines.append("\(dateString),\(dailyCount.count)")
        }

        return lines.joined(separator: "\n")
    }

    /// Generates CSV content for error trends
    /// Format: rule,error_count
    private func generateErrorTrendsCSV(report: ErrorTrendsReport) -> String {
        var lines: [String] = []
        lines.append("rule,error_count")

        // Sort by error count (descending)
        let sortedErrors = report.errorsByRule.sorted { $0.value > $1.value }

        for (rule, count) in sortedErrors {
            // Escape rule name if it contains commas or quotes
            let escapedRule = rule.contains(",") || rule.contains("\"")
                ? "\"\(rule.replacingOccurrences(of: "\"", with: "\"\""))\""
                : rule
            lines.append("\(escapedRule),\(count)")
        }

        return lines.joined(separator: "\n")
    }

    /// Presents a save panel and writes content to the selected file
    private func saveFile(content: String, defaultFilename: String) throws -> URL {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Analytics CSV"
        savePanel.allowedContentTypes = [.commaSeparatedText]

        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else {
            throw NSError(domain: "Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save cancelled"])
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - UTType Extension
extension UTType {
    static let commaSeparatedText = UTType(filenameExtension: "csv") ?? UTType.plainText
    static let png = UTType(filenameExtension: "png") ?? UTType.image
}

// MARK: - Skill Ranking Row
private struct SkillRankingRow: View {
    let ranking: SkillUsageRanking
    let rank: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Rank badge
            Text("\(rank)")
                .font(.system(.body, design: .rounded, weight: .bold))
                .frame(width: 32, height: 32)
                .background(rankColor)
                .foregroundStyle(.white)
                .clipShape(Circle())

            // Skill info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                Text(ranking.skillName)
                    .bodyText(emphasis: true)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    if let agent = ranking.agent {
                        Image(systemName: agent.icon)
                            .font(.caption2)
                            .foregroundStyle(agent.color)
                        Text(agent.displayName)
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }

                    Spacer()

                    // Scan count
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "chart.bar")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        Text("\(ranking.scanCount)")
                            .captionText(emphasis: true)
                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    }

                    // Last scanned
                    Text(ranking.lastScanned.formatted(date: .abbreviated, time: .omitted))
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.tertiary.opacity(0.5))
        )
    }

    private var rankColor: Color {
        switch rank {
        case 1: return DesignTokens.Colors.Accent.yellow
        case 2: return DesignTokens.Colors.Accent.gray
        case 3: return DesignTokens.Colors.Accent.orange
        default: return DesignTokens.Colors.Icon.tertiary
        }
    }
}

// MARK: - Skeleton Loading Views
private struct SkeletonScanFrequencyChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(width: 150, height: 20)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(height: 200)
        }
        .padding(DesignTokens.Spacing.xs)
        .shimmer()
    }
}

private struct SkeletonErrorTrendsChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(width: 150, height: 20)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(height: 200)
        }
        .padding(DesignTokens.Spacing.xs)
        .shimmer()
    }
}

private struct SkeletonTopSkillsList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(width: 120, height: 20)

            ForEach(0..<5) { _ in
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Circle()
                        .fill(DesignTokens.Colors.Background.secondary)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .fill(DesignTokens.Colors.Background.secondary)
                            .frame(width: 180, height: 14)

                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .fill(DesignTokens.Colors.Background.secondary)
                            .frame(width: 120, height: 10)
                    }

                    Spacer()
                }
                .padding(DesignTokens.Spacing.xs)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .shimmer()
    }
}

// MARK: - Sample Data
extension AnalyticsDashboardView {
    /// Sample rankings for preview
    public static let sampleRankings: [SkillUsageRanking] = {
        let calendar = Calendar.current
        let now = Date()

        return [
            SkillUsageRanking(
                skillName: "code-review",
                agent: .claude,
                scanCount: 47,
                lastScanned: calendar.date(byAdding: .hour, value: -2, to: now)!
            ),
            SkillUsageRanking(
                skillName: "refactor",
                agent: .codex,
                scanCount: 35,
                lastScanned: calendar.date(byAdding: .hour, value: -5, to: now)!
            ),
            SkillUsageRanking(
                skillName: "debug-session",
                agent: .claude,
                scanCount: 28,
                lastScanned: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            SkillUsageRanking(
                skillName: "test-generator",
                agent: .codexSkillManager,
                scanCount: 21,
                lastScanned: calendar.date(byAdding: .hour, value: -12, to: now)!
            ),
            SkillUsageRanking(
                skillName: "documentation",
                agent: .copilot,
                scanCount: 18,
                lastScanned: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
        ]
    }()
}

// MARK: - Preview
#Preview("Analytics Dashboard") {
    AnalyticsDashboardView()
        .frame(width: 1000, height: 700)
}

#Preview("Analytics Dashboard - Dark Mode") {
    AnalyticsDashboardView()
        .frame(width: 1000, height: 700)
        .preferredColorScheme(.dark)
}
