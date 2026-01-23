import Foundation

/// CSV exporter for analytics metrics
public struct AnalyticsCSVExporter {

    // MARK: - Scan Frequency Export

    /// Exports scan frequency metrics to CSV format
    /// - Parameter metrics: The scan frequency metrics to export
    /// - Returns: CSV string with headers and daily scan counts
    public static func exportScanFrequency(_ metrics: ScanFrequencyMetrics) -> String {
        var lines: [String] = []

        // Header
        lines.append("date,scan_count")

        // Data rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for dailyCount in metrics.dailyCounts {
            let dateString = dateFormatter.string(from: dailyCount.date)
            let countString = "\(dailyCount.count)"
            lines.append("\(dateString),\(countString)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Error Trends Export

    /// Exports error trends to CSV format
    /// - Parameter report: The error trends report to export
    /// - Returns: CSV string with headers and error counts by rule
    public static func exportErrorTrends(_ report: ErrorTrendsReport) -> String {
        var lines: [String] = []

        // Header
        lines.append("rule,error_count")

        // Sort by error count (descending) and create data rows
        let sortedRules = report.errorsByRule.sorted { $0.value > $1.value }
        for (rule, count) in sortedRules {
            // Escape rule name if it contains commas or quotes
            let escapedRule = escapeCSVField(rule)
            lines.append("\(escapedRule),\(count)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Top Skills Export

    /// Exports top skills rankings to CSV format
    /// - Parameter rankings: Array of skill usage rankings
    /// - Returns: CSV string with headers and skill rankings
    public static func exportTopSkills(_ rankings: [SkillUsageRanking]) -> String {
        var lines: [String] = []

        // Header
        lines.append("skill_name,agent,scan_count,last_scanned")

        // Data rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for ranking in rankings {
            let skillName = escapeCSVField(ranking.skillName)
            let agent = ranking.agent?.displayLabel ?? "unknown"
            let count = "\(ranking.scanCount)"
            let lastScanned = dateFormatter.string(from: ranking.lastScanned)
            lines.append("\(skillName),\(agent),\(count),\(lastScanned)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Combined Export

    /// Exports all analytics data to a single CSV document with sections
    /// - Parameters:
    ///   - frequencyMetrics: Scan frequency metrics
    ///   - errorReport: Error trends report
    ///   - skillRankings: Top skills rankings
    /// - Returns: Multi-section CSV string with all data
    public static func exportAll(
        frequencyMetrics: ScanFrequencyMetrics?,
        errorReport: ErrorTrendsReport?,
        skillRankings: [SkillUsageRanking]?
    ) -> String {
        var sections: [String] = []

        // Section 1: Scan Frequency
        if let metrics = frequencyMetrics {
            sections.append("# Scan Frequency")
            sections.append(exportScanFrequency(metrics))
        }

        // Section 2: Error Trends
        if let report = errorReport {
            if !sections.isEmpty { sections.append("") } // Empty line between sections
            sections.append("# Error Trends")
            sections.append(exportErrorTrends(report))
        }

        // Section 3: Top Skills
        if let rankings = skillRankings, !rankings.isEmpty {
            if !sections.isEmpty { sections.append("") } // Empty line between sections
            sections.append("# Top Skills")
            sections.append(exportTopSkills(rankings))
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Escapes a CSV field value if it contains special characters
    /// - Parameter field: The field value to escape
    /// - Returns: Escaped field value wrapped in quotes if necessary
    private static func escapeCSVField(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape internal quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// MARK: - File Save Extension

extension AnalyticsCSVExporter {
    /// Saves CSV content to a file in the Documents directory
    /// - Parameters:
    ///   - content: CSV string content
    ///   - filename: Desired filename (without .csv extension)
    /// - Returns: URL of the saved file
    /// - Throws: File writing errors
    public static func saveToDocuments(
        content: String,
        filename: String
    ) throws -> URL {
        // Ensure .csv extension
        let safeFilename = filename.hasSuffix(".csv") ? filename : "\(filename).csv"

        // Get Documents directory
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsURL = urls.first!

        let fileURL = documentsURL.appendingPathComponent(safeFilename)

        // Write content
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    /// Generates a filename with timestamp for analytics export
    /// - Parameter dataType: Type of data being exported (e.g., "scan-frequency", "errors", "all")
    /// - Returns: Filename string with timestamp
    public static func timestampedFilename(for dataType: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        return "analytics_\(dataType)_\(timestamp)"
    }
}
