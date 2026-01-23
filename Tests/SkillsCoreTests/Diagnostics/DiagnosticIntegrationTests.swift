import XCTest
import ZIPFoundation
@testable import SkillsCore

/// Integration tests for end-to-end diagnostic bundle workflow:
/// 1. Simulates full scan with findings
/// 2. Generates diagnostic bundle
/// 3. Exports to ZIP archive
/// 4. Verifies ZIP contents are valid and complete
final class DiagnosticIntegrationTests: XCTestCase {

    // MARK: - Test Properties

    private var collector: DiagnosticBundleCollector!
    private var exporter: DiagnosticBundleExporter!
    private var ledger: SkillLedger!
    private var tempDir: URL!
    private var outputURL: URL!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create temp directory for test files
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Setup ledger with in-memory database
        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        ledger = try SkillLedger(url: ledgerURL)

        // Initialize collector and exporter
        collector = DiagnosticBundleCollector(ledger: ledger)
        exporter = DiagnosticBundleExporter()

        // Setup output ZIP path
        outputURL = tempDir.appendingPathComponent("diagnostics-test.zip")
    }

    override func tearDown() async throws {
        collector = nil
        exporter = nil
        ledger = nil

        // Clean up temp directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }

        try await super.tearDown()
    }

    // MARK: - Integration Tests

    /// Full integration test: scan -> collect -> export -> verify ZIP
    func testFullWorkflow_ScanCollectExportVerify() async throws {
        // Given: Simulated findings from a full scan with multiple issues
        let findings = generateRealisticFindings()

        // Record some ledger events (simulating scan history)
        _ = try await ledger.record(LedgerEventInput(
            eventType: .appLaunch,
            skillName: "test-skill-1",
            agent: .codex,
            status: .success
        ))
        _ = try await ledger.record(LedgerEventInput(
            eventType: .sync,
            skillName: "test-skill-2",
            agent: .claude,
            status: .success
        ))

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/Users/test/skills/codex"],
            claudeRoot: "/Users/test/skills/claude",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: [".git", "node_modules"]
        )

        // When: Collect diagnostic bundle
        let bundle = try await collector.collect(
            findings: findings,
            config: config,
            includeLogs: false,
            logHours: 24
        )

        // Then: Bundle should have complete data
        XCTAssertNotNil(bundle.bundleID)
        XCTAssertNotNil(bundle.generatedAt)
        XCTAssertFalse(bundle.sToolsVersion.isEmpty)
        XCTAssertEqual(bundle.recentFindings.count, 5)
        XCTAssertGreaterThanOrEqual(bundle.ledgerEvents.count, 2)
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 4)  // 4 unique skill files
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 5)

        // When: Export bundle to ZIP
        let exportedURL = try exporter.export(bundle: bundle, to: outputURL)

        // Then: ZIP file should exist at specified location
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: exportedURL.path),
            "ZIP file should exist at output path"
        )
        XCTAssertEqual(exportedURL.pathExtension, "zip")

        // Verify ZIP contents
        try verifyZIPContents(at: exportedURL, expectedBundle: bundle)
    }

    /// Integration test with empty findings (successful scan with no issues)
    func testFullWorkflow_EmptyFindings() async throws {
        // Given: No findings (clean scan)
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

        // When: Collect and export
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        let exportedURL = try exporter.export(bundle: bundle, to: outputURL)

        // Then: Should produce valid ZIP even with no findings
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        XCTAssertEqual(bundle.recentFindings.count, 0)
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 0)

        // Verify ZIP structure is complete
        try verifyZIPContents(at: exportedURL, expectedBundle: bundle)
    }

    /// Integration test with large dataset (stress test)
    func testFullWorkflow_LargeDataset() async throws {
        // Given: Many findings simulating large scan
        let findings = generateLargeFindings(count: 100)

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/large/repo"],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 10,
            excludes: []
        )

        // When: Collect and export
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        let exportedURL = try exporter.export(bundle: bundle, to: outputURL)

        // Then: Should handle large dataset
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        XCTAssertEqual(bundle.recentFindings.count, 100)
        XCTAssertEqual(bundle.skillStatistics.totalFindings, 100)

        // Verify ZIP is valid
        try verifyZIPContents(at: exportedURL, expectedBundle: bundle)
    }

    /// Integration test verifying PII redaction throughout
    func testFullWorkflow_PIIRedaction() async throws {
        // Given: Findings with sensitive paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let findings = [
            Finding(
                ruleID: "test.1",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "\(homeDir)/project/skill1/SKILL.md"),
                message: "Error in home directory"
            ),
            Finding(
                ruleID: "test.2",
                severity: .warning,
                agent: .claude,
                fileURL: URL(fileURLWithPath: "\(homeDir)/another/skill/SKILL.md"),
                message: "Warning in home directory"
            )
        ]

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["\(homeDir)/skills"],
            claudeRoot: "\(homeDir)/claude-skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: nil,
            excludes: []
        )

        // When: Collect and export
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        let exportedURL = try exporter.export(bundle: bundle, to: outputURL)

        // Then: Paths in findings should be redacted in the bundle
        for finding in bundle.recentFindings {
            // Home directory should be replaced with ~
            XCTAssertFalse(
                finding.filePath.contains(homeDir),
                "Home directory path should be redacted, got: \(finding.filePath)"
            )
            // Should contain ~ instead of home dir
            XCTAssertTrue(
                finding.filePath.contains("~/"),
                "Should use ~ for redacted home directory, got: \(finding.filePath)"
            )
        }

        // Note: Config paths are NOT redacted in memory, only when encoded to JSON
        // This is by design - redaction happens at export time

        // Verify ZIP contains redacted config paths in JSON
        let archive = try Archive(url: exportedURL, accessMode: .read)
        if let manifestEntry = archive.first(where: { $0.path == "manifest.json" }) {
            let manifestData = try extractData(from: manifestEntry, in: archive)
            let jsonString = String(data: manifestData, encoding: .utf8)!

            // Config paths should be redacted in JSON
            XCTAssertFalse(
                jsonString.contains(homeDir),
                "Home directory should not appear in exported JSON"
            )
            // In JSON, ~ may be followed by escaped slash \/
            XCTAssertTrue(
                jsonString.contains("~") && (jsonString.contains("~/") || jsonString.contains("~\\/")),
                "Config should use ~ in exported JSON"
            )
        }

        // Verify ZIP contains redacted data
        try verifyZIPContents(at: exportedURL, expectedBundle: bundle)
    }

    /// Integration test with multiple agents
    func testFullWorkflow_MultipleAgents() async throws {
        // Given: Findings from all supported agents
        let findings = [
            Finding(ruleID: "codex.error", severity: .error, agent: .codex,
                   fileURL: URL(fileURLWithPath: "/codex/skill/SKILL.md"), message: "Codex error"),
            Finding(ruleID: "claude.warning", severity: .warning, agent: .claude,
                   fileURL: URL(fileURLWithPath: "/claude/skill/SKILL.md"), message: "Claude warning"),
            Finding(ruleID: "csm.error", severity: .error, agent: .codexSkillManager,
                   fileURL: URL(fileURLWithPath: "/csm/skill/SKILL.md"), message: "CSM error"),
            Finding(ruleID: "copilot.warning", severity: .warning, agent: .copilot,
                   fileURL: URL(fileURLWithPath: "/copilot/skill/SKILL.md"), message: "Copilot warning")
        ]

        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/codex"],
            claudeRoot: "/claude",
            codexSkillManagerRoot: "/csm",
            copilotRoot: "/copilot",
            recursive: true,
            maxDepth: 3,
            excludes: []
        )

        // When: Collect and export
        let bundle = try await collector.collect(
            findings: findings,
            config: config
        )

        let exportedURL = try exporter.export(bundle: bundle, to: outputURL)

        // Then: All agents should be represented in statistics
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["codex"], 1)
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["claude"], 1)
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["codexSkillManager"], 1)
        XCTAssertEqual(bundle.skillStatistics.skillsByAgent["copilot"], 1)
        XCTAssertEqual(bundle.skillStatistics.totalSkills, 4)

        // Verify ZIP structure
        try verifyZIPContents(at: exportedURL, expectedBundle: bundle)
    }

    // MARK: - Verification Helpers

    /// Verifies that the ZIP archive contains all expected files with valid JSON
    private func verifyZIPContents(at url: URL, expectedBundle: DiagnosticBundle) throws {
        // Open the ZIP archive using the throwing initializer
        let archive = try Archive(url: url, accessMode: .read)

        // Expected files in the ZIP
        let expectedFiles = Set(["manifest.json", "findings.json", "events.json", "system.json"])
        let actualFiles = Set(archive.compactMap { $0.path })

        // Verify all expected files are present
        let missingFiles = expectedFiles.subtracting(actualFiles)
        let extraFiles = actualFiles.subtracting(expectedFiles)

        XCTAssertTrue(
            missingFiles.isEmpty,
            "ZIP is missing expected files: \(missingFiles)"
        )
        XCTAssertTrue(
            extraFiles.isEmpty,
            "ZIP has unexpected extra files: \(extraFiles)"
        )

        // Verify manifest.json contains valid DiagnosticBundle
        if let manifestEntry = archive.first(where: { $0.path == "manifest.json" }) {
            let manifestData = try extractData(from: manifestEntry, in: archive)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedBundle = try decoder.decode(DiagnosticBundle.self, from: manifestData)

            // Verify critical fields match
            XCTAssertEqual(decodedBundle.bundleID, expectedBundle.bundleID)
            XCTAssertEqual(decodedBundle.sToolsVersion, expectedBundle.sToolsVersion)
            XCTAssertEqual(decodedBundle.recentFindings.count, expectedBundle.recentFindings.count)
        } else {
            XCTFail("manifest.json not found in archive")
        }

        // Verify findings.json is valid JSON
        if let findingsEntry = archive.first(where: { $0.path == "findings.json" }) {
            let findingsData = try extractData(from: findingsEntry, in: archive)
            let decoder = JSONDecoder()
            let findings = try decoder.decode([RedactedFinding].self, from: findingsData)
            XCTAssertEqual(findings.count, expectedBundle.recentFindings.count)
        } else {
            XCTFail("findings.json not found in archive")
        }

        // Verify events.json is valid JSON
        if let eventsEntry = archive.first(where: { $0.path == "events.json" }) {
            let eventsData = try extractData(from: eventsEntry, in: archive)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let events = try decoder.decode([LedgerEvent].self, from: eventsData)
            XCTAssertEqual(events.count, expectedBundle.ledgerEvents.count)
        } else {
            XCTFail("events.json not found in archive")
        }

        // Verify system.json is valid JSON
        if let systemEntry = archive.first(where: { $0.path == "system.json" }) {
            let systemData = try extractData(from: systemEntry, in: archive)
            let decoder = JSONDecoder()
            let systemInfo = try decoder.decode(DiagnosticBundle.SystemInfo.self, from: systemData)
            XCTAssertEqual(systemInfo.macOSVersion, expectedBundle.systemInfo.macOSVersion)
            XCTAssertEqual(systemInfo.architecture, expectedBundle.systemInfo.architecture)
        } else {
            XCTFail("system.json not found in archive")
        }
    }

    /// Extracts data from a ZIP archive entry
    private func extractData(from entry: Entry, in archive: Archive) throws -> Data {
        // Extract to temporary file and read back
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try archive.extract(entry, to: tempURL)
        return try Data(contentsOf: tempURL)
    }

    // MARK: - Test Data Generators

    /// Generates realistic test findings
    private func generateRealisticFindings() -> [Finding] {
        return [
            Finding(
                ruleID: "frontmatter.missing",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test/skills/codex-skill/SKILL.md"),
                message: "Missing YAML frontmatter",
                line: 1,
                column: 1
            ),
            Finding(
                ruleID: "name.too_short",
                severity: .warning,
                agent: .claude,
                fileURL: URL(fileURLWithPath: "/test/skills/claude-skill/SKILL.md"),
                message: "Skill name is too short (min 3 chars)",
                line: 3,
                column: 7
            ),
            Finding(
                ruleID: "description.missing",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test/skills/another-skill/SKILL.md"),
                message: "Description field is required",
                line: 5,
                column: 1
            ),
            Finding(
                ruleID: "references.invalid_format",
                severity: .warning,
                agent: .claude,
                fileURL: URL(fileURLWithPath: "/test/skills/codex-skill/SKILL.md"),
                message: "Invalid @agent reference format",
                line: 12,
                column: 15
            ),
            Finding(
                ruleID: "asset.not_found",
                severity: .error,
                agent: .codexSkillManager,
                fileURL: URL(fileURLWithPath: "/test/skills/csm-skill/SKILL.md"),
                message: "Referenced asset not found: assets/example.png",
                line: 8,
                column: 10
            )
        ]
    }

    /// Generates a large number of findings for stress testing
    private func generateLargeFindings(count: Int) -> [Finding] {
        var findings: [Finding] = []
        findings.reserveCapacity(count)

        let agents = Array(AgentKind.allCases)
        let agentCount = agents.count

        for i in 0..<count {
            let agent = agents[i % agentCount]
            let severity: Severity = (i % 3 == 0) ? .error : .warning
            let ruleID = "test.rule.\(i % 10)"
            let fileURL = URL(fileURLWithPath: "/test/skill-\(i)/SKILL.md")
            let message = "Test finding \(i)"
            let line = i % 100 + 1
            let column = (i % 80) + 1

            let finding = Finding(
                ruleID: ruleID,
                severity: severity,
                agent: agent,
                fileURL: fileURL,
                message: message,
                line: line,
                column: column
            )
            findings.append(finding)
        }

        return findings
    }
}
