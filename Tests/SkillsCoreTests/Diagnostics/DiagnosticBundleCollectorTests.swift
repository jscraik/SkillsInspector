import XCTest
@testable import SkillsCore

/// Tests for DiagnosticBundleCollector covering bundle collection,
/// system info gathering, ledger querying, and statistics computation.
final class DiagnosticBundleCollectorTests: XCTestCase {

    // MARK: - Test Properties

    private var collector: DiagnosticBundleCollector!
    private var ledger: SkillLedger!
    private var tempDir: URL!

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

    // MARK: - Basic Collection Tests

    func testCollectWithEmptyFindings() async throws {
        // Given: Empty findings and minimal config
        let findings: [Finding] = []
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        // Then: Bundle should have valid structure with no findings
        XCTAssertNotNil(bundle.bundleID)
        XCTAssertNotNil(bundle.generatedAt)
        XCTAssertFalse(bundle.sToolsVersion.isEmpty)
        XCTAssertFalse(bundle.systemInfo.macOSVersion.isEmpty)
        XCTAssertEqual(bundle.recentFindings.count, 0)
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 0)
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 0)
    }

    func testCollectWithFindings() async throws {
        // Given: Sample findings with errors and warnings
        let testURL = URL(fileURLWithPath: "/test/skill/SKILL.md")
        let findings = [
            Finding(
                ruleID: "test.error",
                severity: .error,
                agent: .codex,
                fileURL: testURL,
                message: "Test error"
            ),
            Finding(
                ruleID: "test.warning",
                severity: .warning,
                agent: .claude,
                fileURL: testURL,
                message: "Test warning"
            )
        ]
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/test/skills"],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: [".git"]
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        // Then: Bundle should contain findings and correct statistics
        XCTAssertEqual(bundle.recentFindings.count, 2)
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 1) // 1 unique file
        XCTAssertEqual(bundle.skillStatistics.skillsWithErrors, 1)
        XCTAssertEqual(bundle.skillStatistics.skillsWithWarnings, 1)
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 2)

        // Verify scan config was captured
        XCTAssertEqual(bundle.scanConfig.codexRoots.count, 1)
        XCTAssertEqual(bundle.scanConfig.recursive, true)
        XCTAssertEqual(bundle.scanConfig.maxDepth, 5)
        XCTAssertTrue(bundle.scanConfig.excludes.contains(".git"))
    }

    func testCollectMultipleSkillsGroupedByAgent() async throws {
        // Given: Findings from multiple agents
        let codexURL = URL(fileURLWithPath: "/codex/skill1/SKILL.md")
        let claudeURL = URL(fileURLWithPath: "/claude/skill2/SKILL.md")
        let findings = [
            Finding(ruleID: "test.1", severity: .error, agent: .codex, fileURL: codexURL, message: "Error 1"),
            Finding(ruleID: "test.2", severity: .error, agent: .codex, fileURL: codexURL, message: "Error 2"),
            Finding(ruleID: "test.3", severity: .warning, agent: .claude, fileURL: claudeURL, message: "Warning 1"),
            Finding(ruleID: "test.4", severity: .warning, agent: .claude, fileURL: claudeURL, message: "Warning 2"),
            Finding(ruleID: "test.5", severity: .error, agent: .claude, fileURL: claudeURL, message: "Error 3")
        ]
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        // Then: Statistics should group by agent correctly
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 2) // 2 unique files
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 5)
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["codex"], 2)
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["claude"], 3)
        XCTAssertEqual(bundle.skillStatistics.skillsWithErrors, 2) // Both files have errors
        XCTAssertEqual(bundle.skillStatistics.skillsWithWarnings, 1) // Only claude file has warnings
    }

    // MARK: - System Info Tests

    func testSystemInfoCollected() async throws {
        // Given: Minimal configuration
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: [],
            config: config
        )

        // Then: System info should be populated
        XCTAssertFalse(bundle.systemInfo.macOSVersion.isEmpty, "macOS version should not be empty")
        XCTAssertFalse(bundle.systemInfo.architecture.isEmpty, "Architecture should not be empty")
        XCTAssertEqual(bundle.systemInfo.hostName, "<redacted>", "Hostname should be redacted")
        XCTAssertGreaterThanOrEqual(bundle.systemInfo.availableDiskSpace, 0, "Disk space should be non-negative")
        XCTAssertGreaterThan(bundle.systemInfo.totalMemory, 0, "Total memory should be positive")
    }

    // MARK: - Ledger Events Tests

    func testLedgerEventsQueried() async throws {
        // Given: Record some test events in the ledger
        _ = try await ledger.record(LedgerEventInput(
            eventType: .appLaunch,
            skillName: "test-skill-1",
            status: .success
        ))
        _ = try await ledger.record(LedgerEventInput(
            eventType: .appLaunch,
            skillName: "test-skill-2",
            status: .success
        ))

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: [],
            config: config
        )

        // Then: Bundle should contain the ledger events
        XCTAssertGreaterThanOrEqual(bundle.ledgerEvents.count, 2, "Should contain recorded events")

        // Verify events are sorted by timestamp descending
        for i in 0..<(bundle.ledgerEvents.count - 1) {
            XCTAssertGreaterThanOrEqual(
                bundle.ledgerEvents[i].timestamp,
                bundle.ledgerEvents[i + 1].timestamp,
                "Events should be sorted descending by timestamp"
            )
        }
    }

    // MARK: - Edge Cases

    func testEmptyConfig() async throws {
        // Given: All optional config fields are nil
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: [],
            config: config
        )

        // Then: Should still produce valid bundle
        XCTAssertNotNil(bundle)
        XCTAssertTrue(bundle.scanConfig.codexRoots.isEmpty)
        XCTAssertNil(bundle.scanConfig.claudeRoot)
        XCTAssertNil(bundle.scanConfig.codexSkillManagerRoot)
        XCTAssertNil(bundle.scanConfig.copilotRoot)
        XCTAssertFalse(bundle.scanConfig.recursive)
        XCTAssertNil(bundle.scanConfig.maxDepth)
        XCTAssertTrue(bundle.scanConfig.excludes.isEmpty)
    }

    func testMultipleFindingsSameFile() async throws {
        // Given: Multiple findings for the same file
        let testURL = URL(fileURLWithPath: "/test/skill/SKILL.md")
        let findings = [
            Finding(ruleID: "test.1", severity: .error, agent: .codex, fileURL: testURL, message: "Error 1"),
            Finding(ruleID: "test.2", severity: .error, agent: .codex, fileURL: testURL, message: "Error 2"),
            Finding(ruleID: "test.3", severity: .warning, agent: .codex, fileURL: testURL, message: "Warning 1")
        ]
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        // Then: Should count as 1 skill with 3 findings
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 1, "Should count unique files")
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 3, "Should count all findings")
        XCTAssertEqual(bundle.skillStatistics.skillsWithErrors, 1, "File has errors")
        XCTAssertEqual(bundle.skillStatistics.skillsWithWarnings, 1, "File has warnings")
    }

    func testVersionStringPopulated() async throws {
        // Given: Any config
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        // When: Collecting bundle
        let bundle = try await collector.collect(
            findings: [],
            config: config
        )

        // Then: Version should be a valid string (fallback to 0.0.0)
        XCTAssertFalse(bundle.sToolsVersion.isEmpty, "Version should not be empty")
    }
}
