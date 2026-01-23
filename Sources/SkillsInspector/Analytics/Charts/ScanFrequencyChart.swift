import SwiftUI
import Charts
import SkillsCore
import AppKit

/// A line chart displaying scan frequency over time
public struct ScanFrequencyChart: View {
    let metrics: ScanFrequencyMetrics
    @State private var selectedDate: Date?
    @State private var isExporting = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    public init(metrics: ScanFrequencyMetrics) {
        self.metrics = metrics
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Header with trend indicator
            header

            // Chart
            chart
        }
        .padding(DesignTokens.Spacing.xs)
        .background(
            glassPanelStyle(cornerRadius: DesignTokens.Radius.lg)
        )
    }
}

// MARK: - Subviews
private extension ScanFrequencyChart {

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        .font(.title3)
                    Text("Scan Frequency")
                        .heading3()
                }

                // Summary metrics
                HStack(spacing: DesignTokens.Spacing.md) {
                    metricItem(label: "Total Scans", value: "\(metrics.totalScans)")
                    metricItem(label: "Avg/Day", value: String(format: "%.1f", metrics.averageScansPerDay))
                    trendIndicator
                }
            }

            Spacer()

            // Export PNG button
            Button(action: exportToPNG) {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(isExporting ? DesignTokens.Colors.Icon.tertiary : DesignTokens.Colors.Accent.blue)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(DesignTokens.Colors.Accent.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Chart {
                // Gradient area under the line
                ForEach(metrics.dailyCounts, id: \.date) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Scans", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.Accent.blue.opacity(0.3),
                                DesignTokens.Colors.Accent.blue.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Main line
                ForEach(metrics.dailyCounts, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Scans", item.count)
                    )
                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        if let selectedDate, Calendar.current.isDate(selectedDate, inSameDayAs: item.date) {
                            Circle()
                                .fill(DesignTokens.Colors.Accent.blue)
                                .frame(width: 12, height: 12)
                        } else {
                            Circle()
                                .fill(DesignTokens.Colors.Accent.blue.opacity(0.6))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                        .foregroundStyle(DesignTokens.Colors.Border.light)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dateFormatter.string(from: date))
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
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
            .accessibilityLabel("Scan frequency chart showing \(metrics.totalScans) total scans over \(metrics.dailyCounts.count) days")

            // Selected date info
            if let selectedDate,
               let selectedItem = metrics.dailyCounts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(dateFormatter.string(from: selectedItem.date))
                        .captionText(emphasis: true)
                    Text("•")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    Text("\(selectedItem.count) scans")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Colors.Accent.blue.opacity(0.1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
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

    private var trendIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            Image(systemName: metrics.trend.icon)
                .font(.caption)
            Text(metrics.trend.rawValue.capitalized)
                .captionText(emphasis: true)
        }
        .foregroundStyle(metrics.trend.color)
        .padding(.horizontal, DesignTokens.Spacing.xxxs)
        .padding(.vertical, DesignTokens.Spacing.micro)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(metrics.trend.color.opacity(0.15))
        )
    }

    private func updateSelection(at location: CGPoint, in geometry: GeometryProxy, using chartProxy: ChartProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }

        let plotArea = geometry[plotFrame]
        let xPosition = location.x - plotArea.minX
        guard xPosition >= 0, xPosition <= plotArea.width else {
            selectedDate = nil
            return
        }

        // Find closest date
        let chartWidth = plotArea.width
        let itemCount = metrics.dailyCounts.count
        guard itemCount > 0 else { return }

        let index = Int((xPosition / chartWidth) * CGFloat(itemCount - 1))
        let clampedIndex = max(0, min(itemCount - 1, index))

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedDate = metrics.dailyCounts[clampedIndex].date
        }
    }
}

// MARK: - PNG Export
private extension ScanFrequencyChart {
    /// Exports the chart as a PNG image
    func exportToPNG() {
        isExporting = true
        defer { isExporting = false }

        // Create a capture of the chart view
        let chartView = VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            header
            chart
        }
        .padding(DesignTokens.Spacing.xs)
        .frame(width: 500, height: 350)
        .background(Color(NSColor.windowBackgroundColor))

        // Use ImageRenderer to capture the view (available on macOS 14+)
        if #available(macOS 14.0, *) {
            let renderer = ImageRenderer(content: chartView)
            renderer.scale = 2.0  // Retina quality

            if let tiffData = renderer.nsImage?.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
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
        savePanel.nameFieldStringValue = "scan-frequency-\(timestamp).png"
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

// MARK: - Trend Direction Extensions
private extension TrendDirection {
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "minus"
        case .unknown: return "questionmark"
        }
    }

    var color: Color {
        switch self {
        case .increasing: return DesignTokens.Colors.Accent.green
        case .decreasing: return DesignTokens.Colors.Accent.red
        case .stable: return DesignTokens.Colors.Accent.gray
        case .unknown: return DesignTokens.Colors.Text.secondary
        }
    }
}

// MARK: - Sample Data
extension ScanFrequencyChart {
    public static let sampleMetrics: ScanFrequencyMetrics = {
        let calendar = Calendar.current
        let now = Date()
        var dailyCounts: [(Date, Int)] = []

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: now) {
                // Simulate realistic scan patterns with some variance
                let baseCount = 10
                let variance = Int.random(in: -5...10)
                let weekendBonus = calendar.isDateInWeekend(date) ? 5 : 0
                dailyCounts.append((date, max(0, baseCount + variance + weekendBonus)))
            }
        }

        dailyCounts.reverse()

        return ScanFrequencyMetrics(
            totalScans: dailyCounts.reduce(0) { $0 + $1.1 },
            averageScansPerDay: Double(dailyCounts.reduce(0) { $0 + $1.1 }) / Double(dailyCounts.count),
            dailyCounts: dailyCounts,
            trend: .increasing
        )
    }()

    public static let emptyMetrics = ScanFrequencyMetrics(
        totalScans: 0,
        averageScansPerDay: 0,
        dailyCounts: [],
        trend: .unknown
    )

    public static let singleDayMetrics = ScanFrequencyMetrics(
        totalScans: 15,
        averageScansPerDay: 15.0,
        dailyCounts: [(Date(), 15)],
        trend: .stable
    )
}

// MARK: - Preview
#Preview("With Data") {
    ScanFrequencyChart(metrics: ScanFrequencyChart.sampleMetrics)
        .frame(width: 500, height: 350)
        .padding()
}

#Preview("Empty Data") {
    ScanFrequencyChart(metrics: ScanFrequencyChart.emptyMetrics)
        .frame(width: 500, height: 350)
        .padding()
}

#Preview("Single Day") {
    ScanFrequencyChart(metrics: ScanFrequencyChart.singleDayMetrics)
        .frame(width: 500, height: 350)
        .padding()
}
