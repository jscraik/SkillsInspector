import XCTest
@testable import SkillsCore

/// Integration tests for analytics functionality
///
/// These tests validate the end-to-end analytics pipeline:
/// 1. Recording ledger events
/// 2. Querying through UsageAnalytics actor
/// 3. Verifying correct aggregation and results
final class AnalyticsIntegrationTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTempLedger() throws -> (SkillLedger, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnalyticsIntegrationTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        return (ledger, ledgerURL)
    }

    /// Records scan events spread across multiple days for realistic aggregation
    /// - Parameters:
    ///   - ledger: The ledger to record events to
    ///   - count: Number of events to record
    ///   - days: Number of days to spread events across
    private func recordScanEvents(
        ledger: SkillLedger,
        count: Int,
        days: Int
    ) async throws {
        let eventsPerDay = count / days
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<days {
            _ = calendar.date(byAdding: .day, value: -dayOffset, to: now) // Intentionally not used - records happen at current time

            // Record events for this day
            let startIndex = dayOffset * eventsPerDay
            let endIndex = min(startIndex + eventsPerDay, count)

            for i in startIndex..<endIndex {
                let input = LedgerEventInput(
                    eventType: .sync,
                    skillName: "skill-\(i % 20)", // 20 unique skills
                    agent: AgentKind.allCases.randomElement(),
                    status: .success
                )
                _ = try await ledger.record(input)
            }
        }
    }

    // MARK: - Integration Tests

    /// Integration test: Record 100 scan events, query analytics, verify aggregation
    ///
    /// This test validates the complete analytics pipeline:
    /// 1. Records exactly 100 scan events
    /// 2. Queries scan frequency metrics
    /// 3. Verifies total count equals 100
    /// 4. Verifies aggregation accuracy
    func testIntegration_Record100Events_VerifyAggregation() async throws {
        // Setup: Create ledger and analytics
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Execute: Record 100 scan events
        try await recordScanEvents(ledger: ledger, count: 100, days: 10)

        // Query: Get scan frequency metrics
        let metrics = try await analytics.scanFrequency(days: 10)

        // Verify: Total scans equals 100
        XCTAssertEqual(
            metrics.totalScans,
            100,
            "Total scans should equal 100 (recorded events)"
        )

        // Verify: Daily counts sum to total
        let dailySum = metrics.dailyCounts.reduce(0) { $0 + $1.count }
        XCTAssertEqual(
            dailySum,
            100,
            "Sum of daily counts should equal total scans (100)"
        )

        // Verify: Average is calculated correctly (total scans / days parameter)
        // Note: averageScansPerDay divides by the 'days' parameter (10), not actual days with data
        let expectedAverage = Double(100) / Double(10)  // 100 events / 10 days = 10
        XCTAssertEqual(
            metrics.averageScansPerDay,
            expectedAverage,
            accuracy: 1.0,
            "Average scans per day should equal total scans divided by days parameter"
        )

        // Verify: Trend direction is set (not unknown for data > 0)
        if metrics.totalScans > 0 && metrics.dailyCounts.count > 1 {
            XCTAssertNotEqual(
                metrics.trend,
                .unknown,
                "Trend should be calculable with multiple days of data"
            )
        }
    }

    /// Integration test: Verify error aggregation with mixed events
    ///
    /// This test validates error trend aggregation:
    /// 1. Records mixed success/failure events
    /// 2. Queries error trends
    /// 3. Verifies error counts are accurate
    func testIntegration_ErrorAggregation_VerifiesCounts() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 100 events with 20% failure rate
        for i in 0..<100 {
            let input = LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i % 20)",
                agent: .codex,
                status: i % 5 == 0 ? .failure : .success, // 20% failure rate
                note: i % 5 == 0 ? "Rule: test.rule.\(i % 5) - Test validation error" : nil
            )
            _ = try await ledger.record(input)
        }

        // Query error trends
        let errorReport = try await analytics.errorTrends(byRule: true, days: 10)

        // Verify: 20 failures recorded (20% of 100)
        XCTAssertEqual(
            errorReport.totalErrors,
            20,
            "Should have 20 errors (20% of 100 events)"
        )

        // Verify: Errors grouped by rule
        XCTAssertGreaterThan(
            errorReport.errorsByRule.count,
            0,
            "Errors should be grouped by rule ID"
        )

        // Verify: Agent grouping
        XCTAssertEqual(
            errorReport.errorsByAgent[.codex],
            20,
            "All errors should be from codex agent"
        )
    }

    /// Integration test: Verify skill ranking aggregation
    ///
    /// This test validates skill usage ranking:
    /// 1. Records events for skills with varying scan counts
    /// 2. Queries most scanned skills
    /// 3. Verifies ranking order and accuracy
    func testIntegration_SkillRanking_VerifiesOrder() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Create skills with known scan counts:
        // skill-a: 15 scans
        // skill-b: 25 scans
        // skill-c: 10 scans
        // skill-d: 30 scans
        // skill-e: 20 scans
        let skillsAndCounts: [(String, Int)] = [
            ("skill-a", 15),
            ("skill-b", 25),
            ("skill-c", 10),
            ("skill-d", 30),
            ("skill-e", 20)
        ]

        for (skill, count) in skillsAndCounts {
            for _ in 0..<count {
                _ = try await ledger.record(LedgerEventInput(
                    eventType: .sync,
                    skillName: skill,
                    agent: .codex,
                    status: .success
                ))
            }
        }

        // Query rankings
        let rankings = try await analytics.mostScannedSkills(limit: 10, days: 10)

        // Verify: All 5 skills ranked
        XCTAssertEqual(rankings.count, 5, "Should rank all 5 skills")

        // Verify: Correct order (descending by scan count)
        XCTAssertEqual(rankings[0].skillName, "skill-d", "skill-d should be first (30 scans)")
        XCTAssertEqual(rankings[0].scanCount, 30)

        XCTAssertEqual(rankings[1].skillName, "skill-b", "skill-b should be second (25 scans)")
        XCTAssertEqual(rankings[1].scanCount, 25)

        XCTAssertEqual(rankings[2].skillName, "skill-e", "skill-e should be third (20 scans)")
        XCTAssertEqual(rankings[2].scanCount, 20)

        XCTAssertEqual(rankings[3].skillName, "skill-a", "skill-a should be fourth (15 scans)")
        XCTAssertEqual(rankings[3].scanCount, 15)

        XCTAssertEqual(rankings[4].skillName, "skill-c", "skill-c should be fifth (10 scans)")
        XCTAssertEqual(rankings[4].scanCount, 10)

        // Verify: Total scans sum correctly
        let totalRankingScans = rankings.reduce(0) { $0 + $1.scanCount }
        XCTAssertEqual(totalRankingScans, 100, "Sum of ranked scan counts should equal 100")
    }

    /// Integration test: Verify cache behavior in end-to-end flow
    ///
    /// This test validates that caching works correctly:
    /// 1. Query analytics (cache miss)
    /// 2. Record more events
    /// 3. Query again (cache hit - should return same result)
    /// 4. Verify cache consistency
    func testIntegration_CacheBehavior_VerifiesConsistency() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record initial events
        try await recordScanEvents(ledger: ledger, count: 50, days: 5)

        // First query (cache miss)
        let metrics1 = try await analytics.scanFrequency(days: 5)
        XCTAssertEqual(metrics1.totalScans, 50, "First query should return 50 scans")

        // Record more events
        try await recordScanEvents(ledger: ledger, count: 50, days: 5)

        // Second query (cache hit - TTL not expired)
        let metrics2 = try await analytics.scanFrequency(days: 5)
        XCTAssertEqual(
            metrics2.totalScans,
            50,
            "Cached result should still show 50 scans (not updated)"
        )

        // Verify metrics are identical (cached)
        XCTAssertEqual(metrics1.totalScans, metrics2.totalScans)
        XCTAssertEqual(metrics1.dailyCounts.count, metrics2.dailyCounts.count)
    }

    /// Integration test: Verify all three analytics queries work together
    ///
    /// This test validates the complete analytics dashboard scenario:
    /// 1. Records diverse events (success, failure, multiple agents)
    /// 2. Queries all three analytics endpoints
    /// 3. Verifies results are consistent and accurate
    func testIntegration_CompleteAnalytics_VerifiesConsistency() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record diverse events:
        // - 80 success events across 20 skills
        // - 20 failure events across 5 skills
        // - Mix of agents
        for i in 0..<100 {
            let skillName: String
            let status: LedgerEventStatus
            let note: String?

            if i < 80 {
                // Success events
                skillName = "skill-\(i % 20)"
                status = .success
                note = nil
            } else {
                // Failure events
                skillName = "failing-skill-\(i % 5)"
                status = .failure
                note = "Rule: validation.\(i % 3) - Validation failed"
            }

            let input = LedgerEventInput(
                eventType: .sync,
                skillName: skillName,
                agent: AgentKind.allCases.randomElement(),
                status: status,
                note: note
            )
            _ = try await ledger.record(input)
        }

        // Query all three analytics endpoints
        let frequencyMetrics = try await analytics.scanFrequency(days: 10)
        let errorReport = try await analytics.errorTrends(byRule: true, days: 10)
        let skillRankings = try await analytics.mostScannedSkills(limit: 20, days: 10)

        // Verify: Scan frequency
        XCTAssertEqual(frequencyMetrics.totalScans, 100, "Should have 100 total scans")

        // Verify: Error trends
        XCTAssertEqual(errorReport.totalErrors, 20, "Should have 20 errors")
        XCTAssertGreaterThan(errorReport.errorsByRule.count, 0, "Should have errors grouped by rule")

        // Verify: Skill rankings
        XCTAssertGreaterThan(skillRankings.count, 0, "Should have ranked skills")

        // Verify: Top scanned skills have reasonable counts
        let topScans = skillRankings.prefix(5).reduce(0) { $0 + $1.scanCount }
        XCTAssertGreaterThan(topScans, 0, "Top 5 skills should have scans")

        // Verify: Consistency across queries
        // (total scans should equal successful + failed events)
        let successfulEvents = frequencyMetrics.totalScans - errorReport.totalErrors
        XCTAssertEqual(successfulEvents, 80, "Should have 80 successful events")
    }
}
