import Foundation

/// Provides usage analytics queries with cache-first lookup
public actor UsageAnalytics {
    private let ledger: SkillLedger
    private let cache: AnalyticsCache

    /// Cache TTL in seconds (1 hour)
    private static let cacheTTL: TimeInterval = 3600

    /// Date formatter for cache keys
    private let cacheKeyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        return formatter
    }()

    public init(ledger: SkillLedger = try! SkillLedger(), cache: AnalyticsCache? = nil) {
        self.ledger = ledger
        // If cache is not provided, create one using the same ledger
        if let cache = cache {
            self.cache = cache
        } else {
            self.cache = AnalyticsCache(ledger: ledger)
        }
    }

    // MARK: - Scan Frequency

    /// Computes scan frequency metrics for the specified time range
    /// - Parameters:
    ///   - days: Number of days to look back (default: 30)
    ///   - offset: Number of events to skip for pagination (default: 0)
    ///   - limit: Maximum number of events to query (default: 1000)
    /// - Returns: ScanFrequencyMetrics containing total scans, daily counts, and trend
    public func scanFrequency(days: Int = 30, offset: Int = 0, limit: Int = 1000) async throws -> ScanFrequencyMetrics {
        let cacheKey = "scan_frequency_\(days)_\(offset)_\(limit)"
        if let cached = try? await cache.get(key: cacheKey) {
            if let data = cached.data(using: .utf8), let decoded = try? JSONDecoder().decode(ScanFrequencyMetrics.self, from: data) {
                return decoded
            }
        }

        let since = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let dailyCounts = try await ledger.fetchDailyEventCounts(
            limit: limit,
            offset: offset,
            since: since,
            eventTypes: [.verify, .sync]
        )
        let totalScans = dailyCounts.reduce(0) { $0 + $1.1 }
        let averageScansPerDay = dailyCounts.isEmpty ? 0.0 : Double(totalScans) / Double(days)

        // Calculate trend
        let trend = calculateTrend(dailyCounts: dailyCounts)

        let metrics = ScanFrequencyMetrics(
            totalScans: totalScans,
            averageScansPerDay: averageScansPerDay,
            dailyCounts: dailyCounts,
            trend: trend
        )

        // Cache the result
        let encoded = try JSONEncoder().encode(metrics)
        try await cache.set(
            key: cacheKey,
            value: String(data: encoded, encoding: .utf8)!,
            ttl: Int(Self.cacheTTL)
        )

        return metrics
    }

    // MARK: - Error Trends

    /// Computes error trends grouped by rule for the specified time range
    /// - Parameters:
    ///   - byRule: If true, group by rule ID extracted from note field
    ///   - days: Number of days to look back (default: 30)
    ///   - offset: Number of events to skip for pagination (default: 0)
    ///   - limit: Maximum number of events to query (default: 1000)
    /// - Returns: ErrorTrendsReport containing error statistics
    public func errorTrends(byRule: Bool = false, days: Int = 30, offset: Int = 0, limit: Int = 1000) async throws -> ErrorTrendsReport {
        let cacheKey = "error_trends_\(byRule)_\(days)_\(offset)_\(limit)"
        if let cached = try? await cache.get(key: cacheKey) {
            if let data = cached.data(using: .utf8), let decoded = try? JSONDecoder().decode(ErrorTrendsReport.self, from: data) {
                return decoded
            }
        }

        let since = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let events = try await ledger.fetchEvents(
            limit: limit,
            offset: offset,
            since: since,
            statuses: [.failure]
        )

        var errorsByRule: [String: Int] = [:]
        var errorsByAgent: [AgentKind: Int] = [:]

        for event in events {
            // Count by agent
            if let agent = event.agent {
                errorsByAgent[agent, default: 0] += 1
            }

            // Extract rule ID from note if available
            if byRule, let note = event.note {
                let ruleID = extractRuleID(from: note)
                errorsByRule[ruleID, default: 0] += 1
            }
        }

        let report = ErrorTrendsReport(
            totalErrors: events.count,
            errorsByRule: errorsByRule,
            errorsByAgent: errorsByAgent
        )

        // Cache the result
        let encoded = try JSONEncoder().encode(report)
        try await cache.set(
            key: cacheKey,
            value: String(data: encoded, encoding: .utf8)!,
            ttl: Int(Self.cacheTTL)
        )

        return report
    }

    // MARK: - Most Scanned Skills

    /// Ranks skills by scan count for the specified time range
    /// - Parameters:
    ///   - limit: Maximum number of skills to return
    ///   - days: Number of days to look back (default: 30)
    ///   - offset: Number of events to skip for pagination (default: 0)
    ///   - queryLimit: Maximum number of events to query from ledger (default: 1000)
    /// - Returns: Array of SkillUsageRanking sorted by scan count (descending)
    public func mostScannedSkills(limit: Int = 10, days: Int = 30, offset: Int = 0, queryLimit: Int = 1000) async throws -> [SkillUsageRanking] {
        let cacheKey = "most_scanned_\(limit)_\(days)_\(offset)_\(queryLimit)"
        if let cached = try? await cache.get(key: cacheKey) {
            if let data = cached.data(using: .utf8), let decoded = try? JSONDecoder().decode([SkillUsageRanking].self, from: data) {
                return decoded
            }
        }

        let since = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let events = try await ledger.fetchEvents(
            limit: queryLimit,
            offset: offset,
            since: since,
            eventTypes: [.verify, .sync]
        )

        // Group by skill name
        var skillData: [String: (count: Int, agent: AgentKind?, lastScanned: Date)] = [:]

        for event in events {
            let skillName = event.skillName
            let current = skillData[skillName] ?? (count: 0, agent: nil, lastScanned: Date.distantPast)
            skillData[skillName] = (
                count: current.count + 1,
                agent: event.agent ?? current.agent,
                lastScanned: max(current.lastScanned, event.timestamp)
            )
        }

        // Convert to rankings and sort by count
        let rankings = skillData.map { skill, data in
            SkillUsageRanking(
                skillName: skill,
                agent: data.agent,
                scanCount: data.count,
                lastScanned: data.lastScanned
            )
        }.sorted { $0.scanCount > $1.scanCount }
        .prefix(limit)
        .map { $0 }

        // Cache the result
        let encoded = try JSONEncoder().encode(rankings)
        try await cache.set(
            key: cacheKey,
            value: String(data: encoded, encoding: .utf8)!,
            ttl: Int(Self.cacheTTL)
        )

        return rankings
    }

    // MARK: - Helpers

    /// Calculates trend direction from daily counts
    private func calculateTrend(dailyCounts: [(Date, Int)]) -> TrendDirection {
        guard dailyCounts.count >= 2 else {
            return .unknown
        }

        // Compare first half to second half
        let midpoint = dailyCounts.count / 2
        let firstHalfSum = dailyCounts.prefix(midpoint).reduce(0) { $0 + $1.1 }
        let secondHalfSum = dailyCounts.suffix(midpoint).reduce(0) { $0 + $1.1 }

        if Double(secondHalfSum) > Double(firstHalfSum) * 1.1 {
            return .increasing
        } else if Double(secondHalfSum) < Double(firstHalfSum) * 0.9 {
            return .decreasing
        } else {
            return .stable
        }
    }

    /// Extracts rule ID from note field
    private func extractRuleID(from note: String) -> String {
        // Look for patterns like "Rule: rule-name" or "[rule-name]"
        let patterns = ["Rule:", "[", "rule:", "validation:"]
        let lowerNote = note.lowercased()

        for pattern in patterns {
            if let range = lowerNote.range(of: pattern.lowercased()) {
                let start = range.upperBound
                // Find the end of the rule ID (end of line, comma, or closing bracket)
                let remaining = String(note[start...])
                if let endRange = remaining.firstRange(of: ["\n", ",", "]", ")", "."]) {
                    let extracted = String(remaining[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // Also remove any brackets that might be at the start/end
                    return extracted.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                }
                // Take first word if no delimiter found
                let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if let spaceRange = trimmed.firstRange(of: " ") {
                    return String(trimmed[..<spaceRange.lowerBound])
                }
                return trimmed
            }
        }

        return "unknown"
    }
}

// MARK: - Models

/// Daily count wrapper for Codable support
public struct DailyCount: Sendable, Codable {
    public let date: Date
    public let count: Int

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

/// Scan frequency metrics
public struct ScanFrequencyMetrics: Sendable, Codable {
    public let totalScans: Int
    public let averageScansPerDay: Double
    public let dailyCounts: [DailyCount]
    public let trend: TrendDirection

    public init(totalScans: Int, averageScansPerDay: Double, dailyCounts: [(Date, Int)], trend: TrendDirection) {
        self.totalScans = totalScans
        self.averageScansPerDay = averageScansPerDay
        self.dailyCounts = dailyCounts.map { DailyCount(date: $0.0, count: $0.1) }
        self.trend = trend
    }

    /// Convenience accessor for tuple-based access
    public var dailyCountsAsTuples: [(Date, Int)] {
        dailyCounts.map { ($0.date, $0.count) }
    }
}

/// Trend direction indicator
public enum TrendDirection: String, Sendable, Codable {
    case increasing
    case decreasing
    case stable
    case unknown
}

/// Error trends report
public struct ErrorTrendsReport: Sendable, Codable {
    public let totalErrors: Int
    public let errorsByRule: [String: Int]
    public let errorsByAgent: [AgentKind: Int]

    public init(totalErrors: Int, errorsByRule: [String: Int], errorsByAgent: [AgentKind: Int]) {
        self.totalErrors = totalErrors
        self.errorsByRule = errorsByRule
        self.errorsByAgent = errorsByAgent
    }
}

/// Skill usage ranking
public struct SkillUsageRanking: Sendable, Codable {
    public let skillName: String
    public let agent: AgentKind?
    public let scanCount: Int
    public let lastScanned: Date

    public init(skillName: String, agent: AgentKind?, scanCount: Int, lastScanned: Date) {
        self.skillName = skillName
        self.agent = agent
        self.scanCount = scanCount
        self.lastScanned = lastScanned
    }
}

/// Comprehensive usage analytics report combining all analytics models
public struct UsageAnalyticsReport: Sendable, Codable {
    public let scanFrequency: ScanFrequencyMetrics
    public let errorTrends: ErrorTrendsReport
    public let topSkills: [SkillUsageRanking]
    public let generatedAt: Date

    public init(
        scanFrequency: ScanFrequencyMetrics,
        errorTrends: ErrorTrendsReport,
        topSkills: [SkillUsageRanking],
        generatedAt: Date = Date()
    ) {
        self.scanFrequency = scanFrequency
        self.errorTrends = errorTrends
        self.topSkills = topSkills
        self.generatedAt = generatedAt
    }
}
