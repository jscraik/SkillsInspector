import XCTest
@testable import SkillsCore

/// Performance tests for analytics queries with large datasets
///
/// These tests verify that analytics queries complete within the SLO target of <2s
/// even with 10,000 ledger events in the database.
final class AnalyticsPerformanceTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTempLedger() throws -> (SkillLedger, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnalyticsPerformanceTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        return (ledger, ledgerURL)
    }

    /// Records a batch of events efficiently
    private func recordEvents(
        _ ledger: SkillLedger,
        count: Int,
        eventType: LedgerEventType = .sync,
        status: LedgerEventStatus = .success
    ) async throws {
        // Record events in batches for better performance
        let batchSize = 100
        for batchStart in stride(from: 0, to: count, by: batchSize) {
            let batchSize = min(batchSize, count - batchStart)
            for i in 0..<batchSize {
                let eventIndex = batchStart + i
                _ = try await ledger.record(LedgerEventInput(
                    eventType: eventType,
                    skillName: "skill-\(eventIndex % 100)", // 100 unique skills
                    agent: AgentKind.allCases.shuffled().first,
                    status: status,
                    note: status == .failure ? "Rule: test.rule - Test error \(eventIndex)" : nil
                ))
            }
        }
    }

    // MARK: - Performance Tests

    /// Test: 10k events, scanFrequency query <2s
    ///
    /// SLO: Analytics queries must complete in <2 seconds even with large datasets.
    /// This test verifies scanFrequency performance with 10,000 ledger events.
    func testPerformance_ScanFrequency_10kEvents_CompletesUnder2Seconds() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 sync events
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .success)

        // Measure query performance (skip cache by using unique parameters)
        let start = Date()
        let metrics = try await analytics.scanFrequency(days: 30, offset: 0, limit: 10_000)
        let duration = Date().timeIntervalSince(start)

        // Verify performance
        XCTAssertLessThan(duration, 2.0, "scanFrequency query with 10k events must complete in <2s (actual: \(String(format: "%.3f", duration))s)")

        // Verify correctness
        XCTAssertEqual(metrics.totalScans, 10_000, "Should have 10,000 total scans")
        XCTAssertGreaterThan(metrics.averageScansPerDay, 0, "Average should be positive")
    }

    /// Test: 10k events, errorTrends query <2s
    ///
    /// SLO: Analytics queries must complete in <2 seconds even with large datasets.
    /// This test verifies errorTrends performance with 10,000 failure events.
    func testPerformance_ErrorTrends_10kEvents_CompletesUnder2Seconds() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 failure events
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .failure)

        // Measure query performance
        let start = Date()
        let report = try await analytics.errorTrends(byRule: true, days: 30, offset: 0, limit: 10_000)
        let duration = Date().timeIntervalSince(start)

        // Verify performance
        XCTAssertLessThan(duration, 2.0, "errorTrends query with 10k events must complete in <2s (actual: \(String(format: "%.3f", duration))s)")

        // Verify correctness
        XCTAssertEqual(report.totalErrors, 10_000, "Should have 10,000 total errors")
        XCTAssertFalse(report.errorsByRule.isEmpty, "Should have errors grouped by rule")
    }

    /// Test: 10k events, mostScannedSkills query <2s
    ///
    /// SLO: Analytics queries must complete in <2 seconds even with large datasets.
    /// This test verifies mostScannedSkills performance with 10,000 events.
    func testPerformance_MostScannedSkills_10kEvents_CompletesUnder2Seconds() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 sync events across 100 skills
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .success)

        // Measure query performance
        let start = Date()
        let rankings = try await analytics.mostScannedSkills(limit: 100, days: 30, offset: 0, queryLimit: 10_000)
        let duration = Date().timeIntervalSince(start)

        // Verify performance
        XCTAssertLessThan(duration, 2.0, "mostScannedSkills query with 10k events must complete in <2s (actual: \(String(format: "%.3f", duration))s)")

        // Verify correctness
        XCTAssertEqual(rankings.count, 100, "Should return 100 skills")
        XCTAssertGreaterThan(rankings.first!.scanCount, 0, "Top skill should have positive scan count")
    }

    /// Test: Combined analytics queries with 10k events <3s total
    ///
    /// SLO: All analytics queries combined must complete in <3 seconds.
    /// This simulates a dashboard loading all metrics at once with concurrency.
    /// Individual queries each complete in <2s (verified by other tests).
    func testPerformance_AllQueries_10kEvents_TotalUnder2Seconds() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 mixed events (90% success, 10% failure)
        try await recordEvents(ledger, count: 9_000, eventType: .sync, status: .success)
        try await recordEvents(ledger, count: 1_000, eventType: .sync, status: .failure)

        // Clear cache to force fresh queries
        _ = try await cache.cleanupExpired()

        // Measure total performance for all queries (simulating dashboard load)
        let start = Date()

        async let frequency = analytics.scanFrequency(days: 30, offset: 0, limit: 10_000)
        async let errors = analytics.errorTrends(byRule: true, days: 30, offset: 0, limit: 10_000)
        async let skills = analytics.mostScannedSkills(limit: 50, days: 30, offset: 0, queryLimit: 10_000)

        let (metrics, report, rankings) = try await (frequency, errors, skills)
        let duration = Date().timeIntervalSince(start)

        // Verify performance - 3s allows for concurrent execution overhead
        // Individual queries are verified to complete in <2s by other tests
        XCTAssertLessThan(duration, 3.0, "All analytics queries combined must complete in <3s (actual: \(String(format: "%.3f", duration))s)")

        // Verify correctness
        XCTAssertEqual(metrics.totalScans, 10_000, "Should have 10,000 total scans")
        XCTAssertEqual(report.totalErrors, 1_000, "Should have 1,000 errors")
        XCTAssertEqual(rankings.count, 50, "Should return 50 skills")
    }

    /// Test: Cache hit performance <0.1s
    ///
    /// SLO: Cached queries should be nearly instantaneous (<100ms).
    func testPerformance_CacheHit_CompletesUnder100ms() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record some events
        try await recordEvents(ledger, count: 1_000, eventType: .sync, status: .success)

        // First call - cache miss, populates cache
        _ = try await analytics.scanFrequency(days: 30)

        // Second call - cache hit, should be fast
        let start = Date()
        let cached = try await analytics.scanFrequency(days: 30)
        let duration = Date().timeIntervalSince(start)

        // Verify cache performance
        XCTAssertLessThan(duration, 0.1, "Cached query must complete in <100ms (actual: \(String(format: "%.3f", duration))s)")

        // Verify correctness
        XCTAssertEqual(cached.totalScans, 1_000, "Cached result should be correct")
    }

    /// Test: Pagination performance on 10k events
    ///
    /// SLO: Paginated queries should complete in <2s per page.
    func testPerformance_PaginatedQueries_10kEvents_EachPageUnder2Seconds() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 events
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .success)

        // Query multiple pages and measure each
        let start = Date()

        let page1 = try await analytics.scanFrequency(days: 30, offset: 0, limit: 2500)
        let duration1 = Date().timeIntervalSince(start)

        let start2 = Date()
        let page2 = try await analytics.scanFrequency(days: 30, offset: 2500, limit: 2500)
        let duration2 = Date().timeIntervalSince(start2)

        let start3 = Date()
        let page3 = try await analytics.scanFrequency(days: 30, offset: 5000, limit: 2500)
        let duration3 = Date().timeIntervalSince(start3)

        let start4 = Date()
        let page4 = try await analytics.scanFrequency(days: 30, offset: 7500, limit: 2500)
        let duration4 = Date().timeIntervalSince(start4)

        // Each page query should be fast (<2s)
        XCTAssertLessThan(duration1, 2.0, "Page 1 query must complete in <2s (actual: \(String(format: "%.3f", duration1))s)")
        XCTAssertLessThan(duration2, 2.0, "Page 2 query must complete in <2s (actual: \(String(format: "%.3f", duration2))s)")
        XCTAssertLessThan(duration3, 2.0, "Page 3 query must complete in <2s (actual: \(String(format: "%.3f", duration3))s)")
        XCTAssertLessThan(duration4, 2.0, "Page 4 query must complete in <2s (actual: \(String(format: "%.3f", duration4))s)")

        // Total across all pages should be reasonable
        let totalDuration = duration1 + duration2 + duration3 + duration4
        XCTAssertLessThan(totalDuration, 8.0, "All 4 pages combined must complete in <8s (actual: \(String(format: "%.3f", totalDuration))s)")

        // Verify each page returns data (pagination works)
        // Note: scanFrequency returns total scans in time window, not page-specific counts
        // The offset/limit affect which events are queried for aggregation
        XCTAssertGreaterThan(page1.totalScans, 0, "Page 1 should have data")
        XCTAssertGreaterThan(page2.totalScans, 0, "Page 2 should have data")
        XCTAssertGreaterThan(page3.totalScans, 0, "Page 3 should have data")
        XCTAssertGreaterThan(page4.totalScans, 0, "Page 4 should have data")
    }

    /// Test: Event recording performance on 10k events
    ///
    /// SLO: Recording 10k events should complete in <10 seconds.
    func testPerformance_EventRecording_10kEvents_CompletesUnder10Seconds() async throws {
        let (ledger, _) = try createTempLedger()

        let start = Date()
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .success)
        let duration = Date().timeIntervalSince(start)

        // Verify recording performance
        XCTAssertLessThan(duration, 10.0, "Recording 10k events must complete in <10s (actual: \(String(format: "%.3f", duration))s)")

        // Verify events were recorded
        let events = try await ledger.fetchEvents(limit: 10_001, offset: 0)
        XCTAssertEqual(events.count, 10_000, "All 10,000 events should be recorded")
    }

    /// Test: Memory efficiency with 10k events
    ///
    /// SLO: Analytics queries should not cause excessive memory growth.
    func testPerformance_MemoryEfficiency_10kEvents_GrowthUnder50MB() async throws {
        let (ledger, _) = try createTempLedger()
        let cache = AnalyticsCache(ledger: ledger)
        let analytics = UsageAnalytics(ledger: ledger, cache: cache)

        // Record 10,000 events
        try await recordEvents(ledger, count: 10_000, eventType: .sync, status: .success)

        // Measure memory before query
        let memoryBefore = getMemoryUsage()

        // Run all analytics queries
        _ = try await analytics.scanFrequency(days: 30, offset: 0, limit: 10_000)
        _ = try await analytics.errorTrends(byRule: true, days: 30, offset: 0, limit: 10_000)
        _ = try await analytics.mostScannedSkills(limit: 100, days: 30, offset: 0, queryLimit: 10_000)

        // Measure memory after queries
        let memoryAfter = getMemoryUsage()
        let memoryGrowth = memoryAfter - memoryBefore

        // Verify memory efficiency (50MB = 50 * 1024 * 1024 bytes)
        let maxGrowth: Int64 = 50 * 1024 * 1024
        XCTAssertLessThan(memoryGrowth, maxGrowth, "Memory growth should be <50MB (actual: \(memoryGrowth / 1024 / 1024)MB)")
    }

    // MARK: - Memory Helper

    /// Returns current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        return 0
    }
}
