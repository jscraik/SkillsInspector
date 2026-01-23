import XCTest
@testable import SkillsCore

/// Performance tests for DiagnosticBundleCollector
/// Tests that generating bundles with 1000 findings completes in under 5 seconds
final class DiagnosticPerformanceTests: XCTestCase {

    // MARK: - Test Properties

    private var collector: DiagnosticBundleCollector!
    private var ledger: SkillLedger!
    private var tempDir: URL!

    // MARK: - Performance Targets

    /// Performance target: 5 seconds for 1000 findings
    private let performanceTarget: TimeInterval = 5.0

    /// Number of findings to test with (per acceptance criteria)
    private let findingCount = 1000

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Create temp directory for test ledger
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        ledger = try SkillLedger(url: ledgerURL)
        collector = DiagnosticBundleCollector(ledger: ledger)
    }

    override func tearDown() async throws {
        collector = nil
        ledger = nil
        // Clean up temp directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    // MARK: - Performance Tests

    /// Test generating bundle with 1000 findings completes in under 5 seconds
    /// This is the primary performance acceptance criterion
    func testGenerateBundleWith1000FindingsUnder5Seconds() async throws {
        // Given: 1000 findings across different agents and severities
        let findings = try createFindings(count: findingCount)
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/test/codex"],
            claudeRoot: "/test/claude",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 10,
            excludes: [".git", "node_modules", "build"]
        )

        // When: Generating diagnostic bundle
        let startTime = Date()
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Bundle should be valid and complete in <5s
        XCTAssertNotNil(bundle.bundleID)
        XCTAssertEqual(bundle.recentFindings.count, findingCount)
        XCTAssertEqual(bundle.skillStatistics.totalFindings, findingCount)

        // Assert performance target
        XCTAssertLessThan(
            elapsed,
            performanceTarget,
            "Generating bundle with \(findingCount) findings should complete in <\(performanceTarget)s, took \(String(format: "%.3f", elapsed))s"
        )

        // Print performance metrics for verification
        print("✅ Diagnostic Bundle Performance Test Results:")
        print("   - Findings processed: \(findingCount)")
        print("   - Unique skills: \(bundle.skillStatistics.totalSkills)")
        print("   - Generation time: \(String(format: "%.3f", elapsed))s")
        print("   - Time per finding: \(String(format: "%.4f", elapsed / Double(findingCount)))s")
        print("   - Target: <\(performanceTarget)s ✓")
    }

    /// Test generating bundle with 1000 findings and ledger events
    /// More realistic scenario with database queries
    func testGenerateBundleWithFindingsAndLedgerEvents() async throws {
        // Given: 1000 findings and recorded ledger events
        let findings = try createFindings(count: findingCount)

        // Record some ledger events to simulate realistic workload
        for i in 0..<100 {
            _ = try await ledger.record(LedgerEventInput(
                eventType: .install,
                skillName: "test-skill-\(i)",
                status: .success
            ))
        }

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Generating bundle with ledger events
        let startTime = Date()
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Should include ledger events and meet performance target
        XCTAssertGreaterThanOrEqual(bundle.ledgerEvents.count, 100)
        XCTAssertEqual(bundle.recentFindings.count, findingCount)

        XCTAssertLessThan(
            elapsed,
            performanceTarget,
            "Bundle with \(findingCount) findings + ledger events should complete in <\(performanceTarget)s, took \(String(format: "%.3f", elapsed))s"
        )

        print("✅ Bundle with Ledger Events Performance:")
        print("   - Findings: \(findingCount)")
        print("   - Ledger events: \(bundle.ledgerEvents.count)")
        print("   - Generation time: \(String(format: "%.3f", elapsed))s")
    }

    /// Test memory efficiency during bundle generation with 1000 findings
    func testMemoryEfficiencyWith1000Findings() async throws {
        // Get baseline memory
        let baselineMemory = getMemoryUsage()

        // Generate bundle with 1000 findings
        let findings = try createFindings(count: findingCount)
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        // Get memory after generation
        let peakMemory = getMemoryUsage()

        // Calculate memory growth
        let memoryGrowthMB = Double(peakMemory - baselineMemory) / 1024.0 / 1024.0

        // Assert reasonable memory growth (<50MB for 1000 findings)
        XCTAssertLessThan(
            memoryGrowthMB,
            50.0,
            "Memory growth should be <50MB for \(findingCount) findings, was \(String(format: "%.1f", memoryGrowthMB))MB"
        )

        // Verify bundle completeness
        XCTAssertEqual(bundle.recentFindings.count, findingCount)

        print("✅ Memory Efficiency with \(findingCount) Findings:")
        print("   - Memory growth: \(String(format: "%.1f", memoryGrowthMB))MB")
        print("   - Target: <50MB ✓")
    }

    /// Test statistics computation performance
    /// Statistics are computed for every bundle, so they must be fast
    func testStatisticsComputationPerformance() async throws {
        // Given: 1000 findings with diverse attributes
        let findings = try createFindings(count: findingCount)

        // When: Computing statistics (timing just this operation)
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        let startTime = Date()
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )
        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Statistics should be accurate and fast
        XCTAssertEqual(bundle.skillStatistics.totalFindings, findingCount)
        XCTAssertGreaterThan(bundle.skillStatistics.totalSkills, 0)

        // Statistics computation should be very fast (<1s for 1000 findings)
        XCTAssertLessThan(
            elapsed,
            1.0,
            "Statistics computation for \(findingCount) findings should complete in <1s, took \(String(format: "%.3f", elapsed))s"
        )

        print("✅ Statistics Computation Performance:")
        print("   - Findings: \(findingCount)")
        print("   - Unique skills: \(bundle.skillStatistics.totalSkills)")
        print("   - Computation time: \(String(format: "%.3f", elapsed))s")
        print("   - Skills by agent: \(bundle.skillStatistics.skillsByAgent)")
    }

    // MARK: - Helper Methods

    /// Create test findings with varying attributes
    /// - Parameter count: Number of findings to create
    /// - Returns: Array of Finding objects
    private func createFindings(count: Int) throws -> [Finding] {
        var findings: [Finding] = []

        let agents: [AgentKind] = [.codex, .claude, .copilot]
        let severities: [Severity] = [.error, .warning, .info]
        let ruleIDs = [
            "test.frontmatter.missing",
            "test.frontmatter.invalid",
            "test.references.broken",
            "test.name.empty",
            "test.agent.invalid"
        ]

        for i in 0..<count {
            // Distribute findings across 100 unique files
            let fileIndex = i % 100
            let fileURL = URL(fileURLWithPath: "/test/skills/skill-\(fileIndex)/SKILL.md")

            let finding = Finding(
                ruleID: ruleIDs[i % ruleIDs.count],
                severity: severities[i % severities.count],
                agent: agents[i % agents.count],
                fileURL: fileURL,
                message: "Test finding \(i) for performance testing",
                line: i % 100 + 1,
                column: i % 80
            )
            findings.append(finding)
        }

        return findings
    }

    /// Get current memory usage in bytes
    /// - Returns: Memory usage in bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - C Interop for Memory Usage

import Darwin

private struct mach_task_basic_info {
    var virtual_size: UInt64 = 0
    var resident_size: UInt64 = 0
    var resident_size_max: UInt64 = 0
    var user_time: time_value_t = time_value_t(seconds: 0, microseconds: 0)
    var system_time: time_value_t = time_value_t(seconds: 0, microseconds: 0)
    var policy: integer_t = 0
    var pages: integer_t = 0
    var max_pages: integer_t = 0
    var surrogate: integer_t = 0
}
