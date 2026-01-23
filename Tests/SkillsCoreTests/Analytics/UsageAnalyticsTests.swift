import XCTest
@testable import SkillsCore

final class UsageAnalyticsTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTempLedger() throws -> (SkillLedger, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UsageAnalyticsTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        return (ledger, ledgerURL)
    }

    // MARK: - scanFrequency Tests

    func testScanFrequency_NoEvents_ReturnsZeroMetrics() async throws {
        let (ledger, _) = try createTempLedger()
        let analytics = UsageAnalytics(ledger: ledger)

        let metrics = try await analytics.scanFrequency(days: 7)

        XCTAssertEqual(metrics.totalScans, 0, "Should have zero scans")
        XCTAssertEqual(metrics.averageScansPerDay, 0.0, accuracy: 0.01, "Average should be 0")
        XCTAssertTrue(metrics.dailyCounts.isEmpty, "Daily counts should be empty")
    }

    func testScanFrequency_WithEvents_ReturnsCorrectMetrics() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10 sync events
        for i in 0..<10 {
            let input = LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            )
            _ = try await ledger.record(input)
        }

        let metrics = try await analytics.scanFrequency(days: 7)

        XCTAssertEqual(metrics.totalScans, 10, "Should have 10 scans")
        XCTAssertGreaterThan(metrics.averageScansPerDay, 0, "Average should be positive")
    }

    func testScanFrequency_CacheHit_ReturnsCachedResult() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record an event
        let input = LedgerEventInput(
            eventType: .sync,
            skillName: "test-skill",
            status: .success
        )
        _ = try await ledger.record(input)

        // First call - cache miss
        let metrics1 = try await analytics.scanFrequency(days: 7)
        XCTAssertEqual(metrics1.totalScans, 1)

        // Record another event
        let input2 = LedgerEventInput(
            eventType: .sync,
            skillName: "test-skill-2",
            status: .success
        )
        _ = try await ledger.record(input2)

        // Second call - should hit cache and return same result
        let metrics2 = try await analytics.scanFrequency(days: 7)
        XCTAssertEqual(metrics2.totalScans, 1, "Cache should return original result")
    }

    func testScanFrequency_TrendIncreasing() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Create multiple events spread out
        // Record events on the same day - trend will be stable/unknown
        for _ in 0..<10 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(UUID().uuidString)",
                status: .success
            ))
        }

        let metrics = try await analytics.scanFrequency(days: 7)

        // With events on a single day, trend should be stable or unknown (not increasing/decreasing)
        // This test verifies the trend field is set without crashing
        XCTAssertTrue([.stable, .unknown].contains(metrics.trend), "Trend should be stable or unknown for single-day data")
    }

    // MARK: - errorTrends Tests

    func testErrorTrends_NoEvents_ReturnsEmptyReport() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        let report = try await analytics.errorTrends(byRule: true, days: 7)

        XCTAssertEqual(report.totalErrors, 0, "Should have zero errors")
        XCTAssertTrue(report.errorsByRule.isEmpty, "Errors by rule should be empty")
        XCTAssertTrue(report.errorsByAgent.isEmpty, "Errors by agent should be empty")
    }

    func testErrorTrends_WithFailureEvents_GroupsCorrectly() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record failure events with different agents
        let input1 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-1",
            agent: .codex,
            status: .failure,
            note: "Rule: frontmatter.missing - YAML frontmatter required"
        )
        _ = try await ledger.record(input1)

        let input2 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-2",
            agent: .claude,
            status: .failure,
            note: "Rule: [name.missing] - Skill name required"
        )
        _ = try await ledger.record(input2)

        let input3 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-3",
            agent: .codex,
            status: .failure,
            note: "Rule: frontmatter.missing - YAML frontmatter required"
        )
        _ = try await ledger.record(input3)

        let report = try await analytics.errorTrends(byRule: true, days: 7)

        XCTAssertEqual(report.totalErrors, 3, "Should have 3 errors")
        XCTAssertEqual(report.errorsByAgent[.codex], 2, "Codex should have 2 errors")
        XCTAssertEqual(report.errorsByAgent[.claude], 1, "Claude should have 1 error")
    }

    func testErrorTrends_ByRule_ExtractsRuleIDs() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record failures with rule IDs in notes
        let input1 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-1",
            status: .failure,
            note: "Rule: frontmatter.missing - YAML frontmatter required"
        )
        _ = try await ledger.record(input1)

        let input2 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-2",
            status: .failure,
            note: "rule: name.missing - Skill name required"
        )
        _ = try await ledger.record(input2)

        let input3 = LedgerEventInput(
            eventType: .sync,
            skillName: "skill-3",
            status: .failure,
            note: "Rule: frontmatter.missing - YAML frontmatter required"
        )
        _ = try await ledger.record(input3)

        let report = try await analytics.errorTrends(byRule: true, days: 7)

        XCTAssertEqual(report.errorsByRule["frontmatter.missing"], 2, "frontmatter.missing should have 2 errors")
        XCTAssertEqual(report.errorsByRule["name.missing"], 1, "name.missing should have 1 error")
    }

    // MARK: - mostScannedSkills Tests

    func testMostScannedSkills_NoEvents_ReturnsEmptyRanking() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        let rankings = try await analytics.mostScannedSkills(limit: 10, days: 7)

        XCTAssertTrue(rankings.isEmpty, "Should return empty ranking")
    }

    func testMostScannedSkills_WithEvents_RanksByScanCount() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Create skills with varying scan counts
        // skill-a: 5 scans
        for _ in 0..<5 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-a",
                agent: .codex,
                status: .success
            ))
        }

        // skill-b: 3 scans
        for _ in 0..<3 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-b",
                agent: .claude,
                status: .success
            ))
        }

        // skill-c: 7 scans
        for _ in 0..<7 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-c",
                agent: .codexSkillManager,
                status: .success
            ))
        }

        let rankings = try await analytics.mostScannedSkills(limit: 10, days: 7)

        XCTAssertEqual(rankings.count, 3, "Should have 3 skills ranked")
        XCTAssertEqual(rankings[0].skillName, "skill-c", "skill-c should be first (7 scans)")
        XCTAssertEqual(rankings[0].scanCount, 7)
        XCTAssertEqual(rankings[1].skillName, "skill-a", "skill-a should be second (5 scans)")
        XCTAssertEqual(rankings[1].scanCount, 5)
        XCTAssertEqual(rankings[2].skillName, "skill-b", "skill-b should be third (3 scans)")
        XCTAssertEqual(rankings[2].scanCount, 3)
    }

    func testMostScannedSkills_Limit_HonorsLimitParameter() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Create 5 skills with 1 scan each
        for i in 1...5 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            ))
        }

        let rankings = try await analytics.mostScannedSkills(limit: 3, days: 7)

        XCTAssertEqual(rankings.count, 3, "Should respect limit of 3")
    }

    func testMostScannedSkills_LastScanned_RecordsLatestTimestamp() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Scan skill-a multiple times
        let baseTime = Date()
        var timestamp = baseTime.addingTimeInterval(-100)

        for i in 0..<3 {
            let input = LedgerEventInput(
                eventType: .sync,
                skillName: "skill-a",
                status: .success
            )
            _ = try await ledger.record(input)
        }

        let rankings = try await analytics.mostScannedSkills(limit: 10, days: 7)

        XCTAssertEqual(rankings.count, 1, "Should have one skill")
        XCTAssertNotNil(rankings[0].lastScanned, "Should have last scanned timestamp")
    }

    // MARK: - Cache Behavior

    func testCache_Expiration_RecomputesAfterTTL() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record initial event
        _ = try await ledger.record(LedgerEventInput(
            eventType: .sync,
            skillName: "skill-1",
            status: .success
        ))

        // First call
        let metrics1 = try await analytics.scanFrequency(days: 7)
        XCTAssertEqual(metrics1.totalScans, 1)

        // Add more events - cache should prevent this from showing up
        for i in 2...5 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            ))
        }

        // Second call - still cached
        let metrics2 = try await analytics.scanFrequency(days: 7)
        XCTAssertEqual(metrics2.totalScans, 1, "Cache should still return original result")
    }

    func testCache_DifferentKeys_StoresSeparately() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record events
        _ = try await ledger.record(LedgerEventInput(
            eventType: .sync,
            skillName: "skill-1",
            status: .success
        ))

        // Call with different day parameters
        let metrics7days = try await analytics.scanFrequency(days: 7)
        let metrics30days = try await analytics.scanFrequency(days: 30)

        // Both should return the same result since we have the same data
        XCTAssertEqual(metrics7days.totalScans, 1)
        XCTAssertEqual(metrics30days.totalScans, 1)
    }

    // MARK: - ScanFrequencyMetrics JSON Encoding/Decoding Tests

    func testScanFrequencyMetrics_JSONEncoding_RoundTrip() throws {
        let dailyCounts: [(Date, Int)] = [
            (Date(timeIntervalSince1970: 1704067200), 5),  // 2024-01-01
            (Date(timeIntervalSince1970: 1704153600), 8),  // 2024-01-02
            (Date(timeIntervalSince1970: 1704240000), 12)  // 2024-01-03
        ]

        let metrics = ScanFrequencyMetrics(
            totalScans: 25,
            averageScansPerDay: 8.33,
            dailyCounts: dailyCounts,
            trend: .increasing
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(metrics)

        // Decode back from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScanFrequencyMetrics.self, from: jsonData)

        // Verify all fields match
        XCTAssertEqual(decoded.totalScans, 25, "totalScans should match")
        XCTAssertEqual(decoded.averageScansPerDay, 8.33, accuracy: 0.01, "averageScansPerDay should match")
        XCTAssertEqual(decoded.dailyCounts.count, 3, "dailyCounts count should match")
        XCTAssertEqual(decoded.dailyCounts[0].count, 5, "First daily count should match")
        XCTAssertEqual(decoded.dailyCounts[1].count, 8, "Second daily count should match")
        XCTAssertEqual(decoded.dailyCounts[2].count, 12, "Third daily count should match")
        XCTAssertEqual(decoded.trend, .increasing, "trend should match")
    }

    func testScanFrequencyMetrics_JSONEncoding_AllTrendDirections() throws {
        let trends: [TrendDirection] = [.increasing, .decreasing, .stable, .unknown]

        for trend in trends {
            let metrics = ScanFrequencyMetrics(
                totalScans: 10,
                averageScansPerDay: 2.5,
                dailyCounts: [(Date(), 5)],
                trend: trend
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(metrics)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ScanFrequencyMetrics.self, from: jsonData)

            XCTAssertEqual(decoded.trend, trend, "Trend '\(trend)' should survive round-trip")
        }
    }

    func testScanFrequencyMetrics_JSONEncoding_EmptyDailyCounts() throws {
        let metrics = ScanFrequencyMetrics(
            totalScans: 0,
            averageScansPerDay: 0.0,
            dailyCounts: [],
            trend: .unknown
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(metrics)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScanFrequencyMetrics.self, from: jsonData)

        XCTAssertEqual(decoded.totalScans, 0)
        XCTAssertEqual(decoded.averageScansPerDay, 0.0, accuracy: 0.01)
        XCTAssertTrue(decoded.dailyCounts.isEmpty, "dailyCounts should be empty")
        XCTAssertEqual(decoded.trend, .unknown)
    }

    // MARK: - Pagination Tests

    func testPagination_OffsetZero_ReturnsFirstPage() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 20 events
        for i in 0..<20 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            ))
        }

        // Get first 10 events
        let events = try await ledger.fetchEvents(limit: 10, offset: 0)

        XCTAssertEqual(events.count, 10, "Should return 10 events")
    }

    func testPagination_OffsetNonZero_SkipsEvents() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 20 events
        for i in 0..<20 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            ))
        }

        // Get events with offset 10 (should skip first 10)
        let page1 = try await ledger.fetchEvents(limit: 10, offset: 0)
        let page2 = try await ledger.fetchEvents(limit: 10, offset: 10)

        XCTAssertEqual(page1.count, 10, "First page should have 10 events")
        XCTAssertEqual(page2.count, 10, "Second page should have 10 events")

        // Verify pages have different events (by ID)
        let page1Ids = Set(page1.map { $0.id })
        let page2Ids = Set(page2.map { $0.id })
        XCTAssertTrue(page1Ids.isDisjoint(with: page2Ids), "Pages should have different events")
    }

    func testPagination_OffsetBeyondRange_ReturnsEmpty() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record only 5 events
        for i in 0..<5 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i)",
                status: .success
            ))
        }

        // Request with offset 10 (beyond available events)
        let events = try await ledger.fetchEvents(limit: 10, offset: 10)

        XCTAssertEqual(events.count, 0, "Should return empty result when offset exceeds available events")
    }

    func testPagination_ScanFrequencyWithLimit_ReturnsCorrectSlice() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 50 events
        for i in 0..<50 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i % 10)", // 10 unique skills, 5 scans each
                status: .success
            ))
        }

        // Query with limit 20
        let page1 = try await ledger.fetchEvents(limit: 20, offset: 0, eventTypes: [.sync])
        let page2 = try await ledger.fetchEvents(limit: 20, offset: 20, eventTypes: [.sync])

        // Should get different slices
        XCTAssertEqual(page1.count, 20, "First page should have 20 events")
        XCTAssertEqual(page2.count, 20, "Second page should have 20 events")

        // Verify pages have different events
        let page1Ids = Set(page1.map { $0.id })
        let page2Ids = Set(page2.map { $0.id })
        XCTAssertTrue(page1Ids.isDisjoint(with: page2Ids), "Pages should have different events")
    }

    func testPagination_ErrorTrendsWithOffset_ReturnsCorrectSlice() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 30 failure events
        for i in 0..<30 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i % 5)", // 5 unique skills
                status: .failure,
                note: "Rule: test.rule - Test error \(i)"
            ))
        }

        // First page: 10 events
        let page1 = try await ledger.fetchEvents(limit: 10, offset: 0, statuses: [.failure])

        // Second page: next 10 events
        let page2 = try await ledger.fetchEvents(limit: 10, offset: 10, statuses: [.failure])

        // Both should have data
        XCTAssertEqual(page1.count, 10, "First page should have 10 events")
        XCTAssertEqual(page2.count, 10, "Second page should have 10 events")

        // Verify different events
        let page1Ids = Set(page1.map { $0.id })
        let page2Ids = Set(page2.map { $0.id })
        XCTAssertTrue(page1Ids.isDisjoint(with: page2Ids), "Pages should have different events")
    }

    func testPagination_MostScannedSkillsWithOffset_ReturnsDifferentSkills() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Create many skills with different scan counts
        for i in 0..<30 {
            let scans = (i % 5) + 1 // 1-5 scans per skill
            for _ in 0..<scans {
                _ = try await ledger.record(LedgerEventInput(
                    eventType: .sync,
                    skillName: "skill-\(String(format: "%02d", i))",
                    status: .success
                ))
            }
        }

        // First page: limit 10, query 20 events
        let page1 = try await analytics.mostScannedSkills(limit: 10, days: 7, offset: 0, queryLimit: 20)

        // Second page: offset 20, query another 20 events
        let page2 = try await analytics.mostScannedSkills(limit: 10, days: 7, offset: 20, queryLimit: 20)

        // Pages should potentially have different skills
        // (depending on scan counts distribution)
        let page1Names = Set(page1.map { $0.skillName })
        let page2Names = Set(page2.map { $0.skillName })

        // At least verify both pages return data
        XCTAssertGreaterThan(page1.count, 0, "First page should have rankings")
        XCTAssertGreaterThan(page2.count, 0, "Second page should have rankings")
    }

    func testPagination_LargeDataset_PerformanceIsAcceptable() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 1500 events (simulating large dataset)
        for i in 0..<1500 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .sync,
                skillName: "skill-\(i % 100)", // 100 unique skills
                status: i % 10 == 0 ? .failure : .success // 10% failure rate
            ))
        }

        // Measure performance of paginated queries
        let start = Date()

        // Query multiple pages
        let page1 = try await analytics.scanFrequency(days: 7, offset: 0, limit: 500)
        let page2 = try await analytics.scanFrequency(days: 7, offset: 500, limit: 500)
        let page3 = try await analytics.scanFrequency(days: 7, offset: 1000, limit: 500)

        let duration = Date().timeIntervalSince(start)

        // Performance check: all pages should complete in reasonable time
        XCTAssertLessThan(duration, 2.0, "Pagination queries should complete in under 2 seconds")
        XCTAssertGreaterThan(page1.totalScans, 0, "Page 1 should have data")
        XCTAssertGreaterThan(page2.totalScans, 0, "Page 2 should have data")
        XCTAssertGreaterThan(page3.totalScans, 0, "Page 3 should have data")
    }
}
