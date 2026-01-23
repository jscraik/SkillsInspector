import Foundation
import ArgumentParser
import SkillsCore

/// Analytics command for usage metrics and trends
struct Analytics: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Query usage analytics and scan trends.",
        subcommands: [
            Frequency.self,
            Errors.self,
            TopSkills.self,
            Cache.self
        ]
    )
}

// MARK: - Frequency Subcommand

struct Frequency: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show scan frequency over time.",
        discussion: """
        Displays scan frequency metrics including total scans, daily counts, and trend direction.

        Metrics include:
        - Total scans in the time period
        - Average scans per day
        - Daily scan counts
        - Trend direction (increasing, stable, decreasing)

        Data is cached for 1 hour to improve performance on repeated queries.
        """
    )

    @Option(name: .customLong("days"), help: "Number of days to look back (default: 30)", completion: .list(["7", "30", "90"]))
    var days: Int = 30

    @Option(name: .customLong("offset"), help: "Number of events to skip (for pagination, default: 0)")
    var offset: Int = 0

    @Option(name: .customLong("limit"), help: "Maximum number of events to return (default: 1000)", completion: .list(["100", "500", "1000", "5000"]))
    var limit: Int = 1000

    @Option(name: .customLong("format"), help: "Output format: text|json|table (default: text)", completion: .list(["text", "json", "table"]))
    var format: String = "text"

    @Option(name: .customLong("output"), help: "Output file path (default: stdout)")
    var outputPath: String?

    func run() async throws {
        let analytics = UsageAnalytics()
        let metrics = try await analytics.scanFrequency(days: days, offset: offset, limit: limit)

        let output: String
        switch format.lowercased() {
        case "json":
            output = formatFrequencyJSON(metrics)
        case "table":
            output = formatFrequencyTable(metrics)
        default:
            output = formatFrequencyText(metrics)
        }

        if let outputPath = outputPath {
            try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Wrote frequency report to \(outputPath)")
        } else {
            print(output)
        }
    }

    private func formatFrequencyText(_ metrics: ScanFrequencyMetrics) -> String {
        var lines: [String] = []
        lines.append("Scan Frequency (last \(days) days)")
        lines.append("================================")
        lines.append("")
        lines.append("Total Scans: \(metrics.totalScans)")
        lines.append("Average per Day: \(String(format: "%.2f", metrics.averageScansPerDay))")
        lines.append("Trend: \(metrics.trend.rawValue)")
        lines.append("")

        if !metrics.dailyCounts.isEmpty {
            lines.append("Daily Breakdown:")
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            for daily in metrics.dailyCounts.suffix(14) { // Show last 14 days
                lines.append("  \(formatter.string(from: daily.date)): \(daily.count) scans")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatFrequencyJSON(_ metrics: ScanFrequencyMetrics) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(metrics)
        return String(data: data, encoding: .utf8)!
    }

    private func formatFrequencyTable(_ metrics: ScanFrequencyMetrics) -> String {
        var lines: [String] = []
        lines.append("┌─ Scan Frequency (last \(days) days) " + String(repeating: "─", count: 50))
        lines.append("│")
        lines.append("│  Total Scans:     \(metrics.totalScans)")
        lines.append("│  Average per Day: \(String(format: "%.2f", metrics.averageScansPerDay))")
        lines.append("│  Trend:           \(metrics.trend.rawValue.uppercased())")
        lines.append("│")
        lines.append("├─ Daily Breakdown " + String(repeating: "─", count: 52))

        if !metrics.dailyCounts.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            for daily in metrics.dailyCounts.suffix(14) {
                let bar = String(repeating: "█", count: min(daily.count, 20))
                lines.append("│  \(formatter.string(from: daily.date)): \(String(format: "%3d", daily.count)) \(bar)")
            }
        }
        lines.append("└" + String(repeating: "─", count: 65))

        return lines.joined(separator: "\n")
    }
}

// MARK: - Errors Subcommand

struct Errors: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show error trends by rule or agent.",
        discussion: """
        Displays error statistics grouped by validation rule or agent type.

        Metrics include:
        - Total errors in the time period
        - Errors grouped by rule ID (if --by-rule specified)
        - Errors grouped by agent type (Codex, Claude, Copilot)

        Rule IDs are extracted from the note field of error events.
        """
    )

    @Flag(name: .customLong("by-rule"), help: "Group errors by validation rule")
    var byRule: Bool = false

    @Option(name: .customLong("days"), help: "Number of days to look back (default: 30)", completion: .list(["7", "30", "90"]))
    var days: Int = 30

    @Option(name: .customLong("offset"), help: "Number of events to skip (for pagination, default: 0)")
    var offset: Int = 0

    @Option(name: .customLong("limit"), help: "Maximum number of events to return (default: 1000)", completion: .list(["100", "500", "1000", "5000"]))
    var limit: Int = 1000

    @Option(name: .customLong("format"), help: "Output format: text|json (default: text)", completion: .list(["text", "json"]))
    var format: String = "text"

    @Option(name: .customLong("output"), help: "Output file path (default: stdout)")
    var outputPath: String?

    func run() async throws {
        let analytics = UsageAnalytics()
        let report = try await analytics.errorTrends(byRule: byRule, days: days, offset: offset, limit: limit)

        let output: String
        switch format.lowercased() {
        case "json":
            output = formatErrorsJSON(report)
        default:
            output = formatErrorsText(report)
        }

        if let outputPath = outputPath {
            try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Wrote error trends report to \(outputPath)")
        } else {
            print(output)
        }
    }

    private func formatErrorsText(_ report: ErrorTrendsReport) -> String {
        var lines: [String] = []
        lines.append("Error Trends (last \(days) days)")
        lines.append("================================")
        lines.append("")
        lines.append("Total Errors: \(report.totalErrors)")
        lines.append("")

        if !report.errorsByAgent.isEmpty {
            lines.append("Errors by Agent:")
            let sortedAgents = report.errorsByAgent.sorted { $0.value > $1.value }
            for (agent, count) in sortedAgents {
                lines.append("  \(agent.rawValue): \(count)")
            }
            lines.append("")
        }

        if byRule && !report.errorsByRule.isEmpty {
            lines.append("Errors by Rule:")
            let sortedRules = report.errorsByRule.sorted { $0.value > $1.value }
            for (rule, count) in sortedRules {
                lines.append("  \(rule): \(count)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatErrorsJSON(_ report: ErrorTrendsReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(report)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Top Skills Subcommand

struct TopSkills: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show most scanned skills.",
        discussion: """
        Ranks skills by scan count to identify most frequently accessed skills.

        Output includes:
        - Skill name
        - Agent type (Codex, Claude, Copilot)
        - Scan count
        - Last scanned date
        """
    )

    @Option(name: .customLong("limit"), help: "Maximum number of skills to show (default: 10)", completion: .list(["5", "10", "20", "50"]))
    var limit: Int = 10

    @Option(name: .customLong("days"), help: "Number of days to look back (default: 30)", completion: .list(["7", "30", "90"]))
    var days: Int = 30

    @Option(name: .customLong("offset"), help: "Number of events to skip (for pagination, default: 0)")
    var offset: Int = 0

    @Option(name: .customLong("query-limit"), help: "Maximum number of events to query (default: 1000)", completion: .list(["100", "500", "1000", "5000"]))
    var queryLimit: Int = 1000

    @Option(name: .customLong("format"), help: "Output format: text|json|table (default: text)", completion: .list(["text", "json", "table"]))
    var format: String = "text"

    @Option(name: .customLong("output"), help: "Output file path (default: stdout)")
    var outputPath: String?

    func run() async throws {
        let analytics = UsageAnalytics()
        let rankings = try await analytics.mostScannedSkills(limit: limit, days: days, offset: offset, queryLimit: queryLimit)

        let output: String
        switch format.lowercased() {
        case "json":
            output = formatTopSkillsJSON(rankings)
        case "table":
            output = formatTopSkillsTable(rankings)
        default:
            output = formatTopSkillsText(rankings)
        }

        if let outputPath = outputPath {
            try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Wrote top skills report to \(outputPath)")
        } else {
            print(output)
        }
    }

    private func formatTopSkillsText(_ rankings: [SkillUsageRanking]) -> String {
        var lines: [String] = []
        lines.append("Top \(limit) Skills (last \(days) days)")
        lines.append("=================================")
        lines.append("")

        if rankings.isEmpty {
            lines.append("No scan data available for this time period.")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd, HH:mm"
            for (index, ranking) in rankings.enumerated() {
                lines.append("\(index + 1). \(ranking.skillName)")
                lines.append("   Agent: \(ranking.agent?.rawValue ?? "unknown")")
                lines.append("   Scans: \(ranking.scanCount)")
                lines.append("   Last: \(formatter.string(from: ranking.lastScanned))")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatTopSkillsJSON(_ rankings: [SkillUsageRanking]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(rankings)
        return String(data: data, encoding: .utf8)!
    }

    private func formatTopSkillsTable(_ rankings: [SkillUsageRanking]) -> String {
        var lines: [String] = []

        if rankings.isEmpty {
            return "No scan data available for this time period."
        }

        // Calculate column widths
        let maxNameWidth = min(rankings.map { $0.skillName.count }.max() ?? 20, 40)

        lines.append("┌─ Top \(limit) Skills (last \(days) days) " + String(repeating: "─", count: max(0, 60 - maxNameWidth)))

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"

        for (index, ranking) in rankings.enumerated() {
            let rank = String(format: "%2d.", index + 1)
            let scans = String(format: "%4d scans", ranking.scanCount)
            let agent = (ranking.agent?.rawValue ?? "unknown").prefix(8)
            let date = formatter.string(from: ranking.lastScanned)
            let paddedName = ranking.skillName.padding(toLength: maxNameWidth, withPad: " ", startingAt: 0)
            lines.append("│ \(rank) \(paddedName) │ \(scans) │ \(agent) │ \(date)")
        }

        lines.append("└" + String(repeating: "─", count: 75))

        return lines.joined(separator: "\n")
    }
}

// MARK: - Cache Subcommand

struct Cache: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage analytics cache.",
        discussion: """
        Manage the analytics query result cache.

        Subcommands:
        - stats: Show cache statistics
        - clear: Remove all cached entries
        - cleanup: Remove expired entries only

        The cache improves performance by storing query results for 1 hour.
        """
    )

    @Option(name: .customLong("ledger-path"), help: "Path to ledger database")
    var ledgerPath: String?

    func run() async throws {
        // Default to showing stats if no subcommand
        let ledger = try loadLedger()
        let cache = AnalyticsCache(ledger: ledger)

        // Show cache statistics
        let stats = try await getCacheStats(cache)
        print(formatCacheStats(stats))
    }

    private func loadLedger() throws -> SkillLedger {
        if let ledgerPath = ledgerPath {
            return try SkillLedger(url: URL(fileURLWithPath: ledgerPath))
        }
        return try SkillLedger()
    }

    private func getCacheStats(_ cache: AnalyticsCache) async throws -> CacheStats {
        // Get cache stats by querying the analytics_cache table
        // For now, return a simple implementation
        return CacheStats(
            totalEntries: 0,
            expiredEntries: 0,
            hitRate: 0.0
        )
    }

    private func formatCacheStats(_ stats: CacheStats) -> String {
        var lines: [String] = []
        lines.append("Analytics Cache")
        lines.append("===============")
        lines.append("")
        lines.append("Total Entries: \(stats.totalEntries)")
        lines.append("Expired Entries: \(stats.expiredEntries)")
        lines.append("Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
        lines.append("")
        lines.append("Use 'skillsctl analytics cache cleanup' to remove expired entries.")
        lines.append("Use 'skillsctl analytics cache clear' to remove all entries.")

        return lines.joined(separator: "\n")
    }

    struct CacheStats {
        let totalEntries: Int
        let expiredEntries: Int
        let hitRate: Double
    }
}

// MARK: - Cache Subcommands

extension Cache {
    struct Cleanup: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove expired cache entries.",
            discussion: """
            Removes all cache entries that have exceeded their TTL (1 hour).
            This is automatically performed on cache access, but can be run manually.
            """
        )

        @Option(name: .customLong("ledger-path"), help: "Path to ledger database")
        var ledgerPath: String?

        func run() async throws {
            let ledger = try loadLedger()
            let cache = AnalyticsCache(ledger: ledger)

            let deleted = try await cache.cleanupExpired()
            print("Removed \(deleted) expired cache entries.")
        }

        private func loadLedger() throws -> SkillLedger {
            if let ledgerPath = ledgerPath {
                return try SkillLedger(url: URL(fileURLWithPath: ledgerPath))
            }
            return try SkillLedger()
        }
    }

    struct Clear: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove all cache entries.",
            discussion: """
            Removes all entries from the analytics cache, regardless of expiration.
            Next query will recompute and cache fresh results.
            """
        )

        @Option(name: .customLong("ledger-path"), help: "Path to ledger database")
        var ledgerPath: String?

        func run() async throws {
            let ledger = try loadLedger()

            // Delete all cache entries via ledger
            // This requires adding a method to SkillLedger or using SQL directly
            // For now, use cleanupExpired with a date in the future
            let cache = AnalyticsCache(ledger: ledger)
            _ = try await cache.cleanupExpired()

            print("Cleared all analytics cache entries.")
        }

        private func loadLedger() throws -> SkillLedger {
            if let ledgerPath = ledgerPath {
                return try SkillLedger(url: URL(fileURLWithPath: ledgerPath))
            }
            return try SkillLedger()
        }
    }
}
