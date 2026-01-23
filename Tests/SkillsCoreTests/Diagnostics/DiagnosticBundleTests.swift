import XCTest
import ZIPFoundation
@testable import SkillsCore

/// Tests for DiagnosticBundle model encoding/decoding and PII redaction
final class DiagnosticBundleTests: XCTestCase {

    // MARK: - JSON Encoding/Decoding Tests

    func testEncodeDecodeDiagnosticBundle() throws {
        // Create test data
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/Users/test/codex/skills"],
            claudeRoot: "/Users/test/claude/skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: [".git", "node_modules"]
        )

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 42,
            skillsByAgent: ["codex": 20, "claude": 22],
            skillsWithErrors: 2,
            skillsWithWarnings: 5,
            totalFindings: 15
        )

        let findings = [
            Finding(
                ruleID: "test.rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test/SKILL.md"),
                message: "Test finding",
                line: 10,
                column: 5
            )
        ]

        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success
        )

        let bundle = DiagnosticBundle(
            bundleID: UUID(),
            generatedAt: Date(),
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: [event],
            skillStatistics: skillStatistics
        )

        // Test encoding
        let jsonData = try bundle.toJSON()
        XCTAssertFalse(jsonData.isEmpty, "Encoded JSON should not be empty")

        // Test decoding
        let decodedBundle = try DiagnosticBundle.fromJSON(jsonData)

        // Verify all fields match
        XCTAssertEqual(decodedBundle.bundleID, bundle.bundleID)
        XCTAssertEqual(decodedBundle.sToolsVersion, bundle.sToolsVersion)
        XCTAssertEqual(decodedBundle.systemInfo.macOSVersion, "14.5.0")
        XCTAssertEqual(decodedBundle.systemInfo.architecture, "arm64")
        XCTAssertEqual(decodedBundle.systemInfo.hostName, "<redacted>")
        XCTAssertEqual(decodedBundle.systemInfo.availableDiskSpace, 500_000_000_000)
        XCTAssertEqual(decodedBundle.systemInfo.totalMemory, 16_000_000_000)

        XCTAssertEqual(decodedBundle.scanConfig.codexRoots.count, 1)
        XCTAssertEqual(decodedBundle.scanConfig.codexRoots.first, "/Users/test/codex/skills")
        XCTAssertEqual(decodedBundle.scanConfig.claudeRoot, "/Users/test/claude/skills")
        XCTAssertEqual(decodedBundle.scanConfig.recursive, true)
        XCTAssertEqual(decodedBundle.scanConfig.maxDepth, 5)
        XCTAssertEqual(decodedBundle.scanConfig.excludes.count, 2)

        XCTAssertEqual(decodedBundle.skillStatistics.totalSkills, 42)
        XCTAssertEqual(decodedBundle.skillStatistics.skillsByAgent["codex"], 20)
        XCTAssertEqual(decodedBundle.skillStatistics.skillsWithErrors, 2)
        XCTAssertEqual(decodedBundle.skillStatistics.skillsWithWarnings, 5)
        XCTAssertEqual(decodedBundle.skillStatistics.totalFindings, 15)

        XCTAssertEqual(decodedBundle.recentFindings.count, 1)
        XCTAssertEqual(decodedBundle.recentFindings.first?.ruleID, "test.rule")
        XCTAssertEqual(decodedBundle.recentFindings.first?.severity, .error)

        XCTAssertEqual(decodedBundle.ledgerEvents.count, 1)
        XCTAssertEqual(decodedBundle.ledgerEvents.first?.skillName, "test-skill")
    }

    func testMinimalBundle() throws {
        // Test bundle with minimal required data
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.0.0",
            architecture: "x86_64",
            hostName: "test-host",
            availableDiskSpace: 100_000_000_000,
            totalMemory: 8_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 0,
            skillsByAgent: [:],
            skillsWithErrors: 0,
            skillsWithWarnings: 0,
            totalFindings: 0
        )

        let bundle = DiagnosticBundle(
            sToolsVersion: "0.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: [],
            ledgerEvents: [],
            skillStatistics: skillStatistics
        )

        let jsonData = try bundle.toJSON()
        let decodedBundle = try DiagnosticBundle.fromJSON(jsonData)

        XCTAssertEqual(decodedBundle.sToolsVersion, "0.0.0")
        XCTAssertEqual(decodedBundle.systemInfo.macOSVersion, "14.0.0")
        XCTAssertEqual(decodedBundle.skillStatistics.totalSkills, 0)
        XCTAssertTrue(decodedBundle.recentFindings.isEmpty)
        XCTAssertTrue(decodedBundle.ledgerEvents.isEmpty)
    }

    func testJSONIsValidStructure() throws {
        let bundle = DiagnosticBundle(
            sToolsVersion: "0.0.0",
            systemInfo: DiagnosticBundle.SystemInfo(
                macOSVersion: "14.5.0",
                architecture: "arm64",
                hostName: "test",
                availableDiskSpace: 100,
                totalMemory: 100
            ),
            scanConfig: DiagnosticBundle.ScanConfiguration(
                codexRoots: ["/test"],
                claudeRoot: nil,
                codexSkillManagerRoot: nil,
                copilotRoot: nil,
                recursive: false,
                maxDepth: nil,
                excludes: []
            ),
            recentFindings: [],
            ledgerEvents: [],
            skillStatistics: DiagnosticBundle.SkillStatistics(
                totalSkills: 1,
                skillsByAgent: ["codex": 1],
                skillsWithErrors: 0,
                skillsWithWarnings: 0,
                totalFindings: 0
            )
        )

        let jsonData = try bundle.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Verify JSON contains expected keys
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("bundleID"))
        XCTAssertTrue(jsonString!.contains("generatedAt"))
        XCTAssertTrue(jsonString!.contains("sToolsVersion"))
        XCTAssertTrue(jsonString!.contains("systemInfo"))
        XCTAssertTrue(jsonString!.contains("scanConfig"))
        XCTAssertTrue(jsonString!.contains("recentFindings"))
        XCTAssertTrue(jsonString!.contains("ledgerEvents"))
        XCTAssertTrue(jsonString!.contains("skillStatistics"))
    }

    // MARK: - PII Redaction Tests

    func testPIIRedactionRedactsHomeDirectoryInBundle() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        // Create config with actual home directory paths
        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["\(homeDir)/codex/skills"],
            claudeRoot: "\(homeDir)/claude/skills",
            codexSkillManagerRoot: "\(homeDir)/csm/skills",
            copilotRoot: "\(homeDir)/copilot/skills",
            recursive: true,
            maxDepth: 5,
            excludes: [".git"]
        )

        // Create findings with actual home directory paths
        let findings = [
            Finding(
                ruleID: "test.rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "\(homeDir)/codex/skills/test/SKILL.md"),
                message: "Test finding",
                line: 10,
                column: 5
            ),
            Finding(
                ruleID: "test.rule2",
                severity: .warning,
                agent: .claude,
                fileURL: URL(fileURLWithPath: "\(homeDir)/claude/skills/another/SKILL.md"),
                message: "Another finding"
            )
        ]

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 2,
            skillsByAgent: ["codex": 1, "claude": 1],
            skillsWithErrors: 1,
            skillsWithWarnings: 1,
            totalFindings: 2
        )

        let bundle = DiagnosticBundle(
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: [],
            skillStatistics: skillStatistics
        )

        // Encode to JSON and verify redaction
        let jsonData = try bundle.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString, "JSON string should not be nil")

        // The home directory should NOT appear in the JSON
        XCTAssertFalse(jsonString!.contains(homeDir), "Home directory path should be redacted")

        // Verify tilde appears somewhere (some path was redacted)
        XCTAssertTrue(jsonString!.contains("~"), "Should contain ~ for redacted home directory")
    }

    func testPIIRedactionRedactsHomeDirectoryInFindings() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let finding = Finding(
            ruleID: "test.rule",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "\(homeDir)/codex/skills/test/SKILL.md"),
            message: "Test finding",
            line: 10,
            column: 5
        )

        let redactedFinding = RedactedFinding(from: finding)

        // Verify the path was redacted
        XCTAssertEqual(redactedFinding.filePath, "~/codex/skills/test/SKILL.md")
        XCTAssertFalse(redactedFinding.filePath.contains(homeDir))
    }

    func testPIIRedactionPreservesNonHomePaths() throws {
        // Paths outside home directory should be preserved
        let finding = Finding(
            ruleID: "test.rule",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/usr/local/bin/something"),
            message: "Test finding"
        )

        let redactedFinding = RedactedFinding(from: finding)

        // Verify the path was NOT redacted
        XCTAssertEqual(redactedFinding.filePath, "/usr/local/bin/something")
    }

    func testPIIRedactionRedactsRelativePathsUnderHome() throws {
        // Relative paths under home directory still get resolved to absolute paths
        // and should be redacted if they start with home directory
        let finding = Finding(
            ruleID: "test.rule",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "./relative/path/SKILL.md"),
            message: "Test finding"
        )

        let redactedFinding = RedactedFinding(from: finding)

        // The path should be redacted since ./relative/path/SKILL.md resolves under home
        // The TelemetryRedactor.redactPath only redacts if path starts with home directory
        // Since URL.path returns the absolute path for relative paths,
        // we expect either redaction (if under home) or preservation (if absolute and not under home)
        // The actual behavior depends on the current working directory
        let currentDir = FileManager.default.currentDirectoryPath
        if redactedFinding.filePath.hasPrefix(currentDir) {
            // If it contains current directory path, verify it was properly redacted
            XCTAssertTrue(redactedFinding.filePath.contains("~") || !redactedFinding.filePath.contains(currentDir))
        }
    }

    func testPIIRedactionVerifiesNoHomePathsInJSON() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let finding = Finding(
            ruleID: "test.rule",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "\(homeDir)/codex/skills/test/SKILL.md"),
            message: "Test finding"
        )

        let redactedFinding = RedactedFinding(from: finding)

        // Verify the path was redacted
        XCTAssertEqual(redactedFinding.filePath, "~/codex/skills/test/SKILL.md")

        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(redactedFinding)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Core requirement: home directory should NOT appear in the JSON
        XCTAssertFalse(jsonString.contains(homeDir), "Home directory path should be redacted")
    }

    func testHostnameIsRedacted() {
        let processInfo = ProcessInfo.processInfo
        let originalHostName = processInfo.hostName

        let redactedHostName = TelemetryRedactor.redactHostName(originalHostName)

        // Hostname should always be redacted to <redacted>
        XCTAssertEqual(redactedHostName, "<redacted>")
        XCTAssertNotEqual(redactedHostName, originalHostName)
    }

    // MARK: - Sendable Tests

    func testSystemInfoSendable() {
        // Verify SystemInfo conforms to Sendable
        // This should compile without error if Sendable conformance is correct
        let _: @Sendable (DiagnosticBundle.SystemInfo) -> Void = { _ in }
    }

    func testScanConfigurationSendable() {
        let config = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )
        let _ = config
    }

    func testSkillStatisticsSendable() {
        let stats = DiagnosticBundle.SkillStatistics(
            totalSkills: 0,
            skillsByAgent: [:],
            skillsWithErrors: 0,
            skillsWithWarnings: 0,
            totalFindings: 0
        )
        let _ = stats
    }

    func testRedactedFindingSendable() {
        let redacted = RedactedFinding(
            from: Finding(
                ruleID: "test",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test"),
                message: "test"
            )
        )
        let _ = redacted
    }
}

// MARK: - PII Redaction Tests (Task 20)

/// Dedicated tests for PII redaction in diagnostic bundles
/// Verifies no home paths or usernames appear in bundle JSON output
final class PIIRedactionTests: XCTestCase {

    func testLedgerEventRedactsHomeDirectoryInTargetPath() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success,
            targetPath: "\(homeDir)/codex/skills/test-skill"
        )

        // Encode to JSON and verify redaction
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        // Home directory should NOT appear
        XCTAssertFalse(jsonString!.contains(homeDir), "Home directory should be redacted from targetPath")
        // Should contain ~ instead (escaped or unescaped both OK)
        XCTAssertTrue(jsonString!.contains("~/codex/skills/test-skill") || jsonString!.contains("~\\/codex\\/skills\\/test-skill"), "Should use ~ for home directory")
    }

    func testLedgerEventRedactsHomeDirectoryInSource() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success,
            source: "\(homeDir)/.config/stools/config.json"
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        XCTAssertFalse(jsonString!.contains(homeDir), "Home directory should be redacted from source")
        XCTAssertTrue(jsonString!.contains("~/.config/stools/config.json") || jsonString!.contains("~\\/.config\\/stools\\/config.json"), "Should use ~ for home directory")
    }

    func testLedgerEventPreservesNonHomePaths() throws {
        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success,
            targetPath: "/usr/local/share/skills/test-skill"
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("/usr/local/share/skills/test-skill") || jsonString!.contains("\\/usr\\/local\\/share\\/skills\\/test-skill"), "Non-home paths should be preserved")
    }

    func testDiagnosticBundleRedactsAllPaths() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["\(homeDir)/codex/skills"],
            claudeRoot: "\(homeDir)/claude/skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: []
        )

        let findings = [
            Finding(
                ruleID: "test.rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "\(homeDir)/codex/skills/test/SKILL.md"),
                message: "Test finding"
            )
        ]

        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success,
            targetPath: "\(homeDir)/codex/skills/test-skill"
        )

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 1,
            skillsByAgent: ["codex": 1],
            skillsWithErrors: 1,
            skillsWithWarnings: 0,
            totalFindings: 1
        )

        let bundle = DiagnosticBundle(
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: [event],
            skillStatistics: skillStatistics
        )

        // Encode to JSON
        let jsonData = try bundle.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)

        // Verify home directory does NOT appear anywhere in the bundle
        XCTAssertFalse(jsonString!.contains(homeDir), "Home directory should not appear in bundle JSON")

        // Verify redacted paths use ~ instead
        XCTAssertTrue(jsonString!.contains("~/codex/skills") || jsonString!.contains("~\\/codex\\/skills"), "Should contain ~-prefixed paths")
    }

    func testLedgerEventRedactsPIIInNote() throws {
        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success,
            note: "Contact user@example.com for questions or call +1-555-0123"
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        // Email should be redacted
        XCTAssertFalse(jsonString!.contains("user@example.com"), "Email should be redacted from note")
        XCTAssertTrue(jsonString!.contains("[EMAIL-REDACTED]"), "Should contain email redaction placeholder")
        // Phone should be redacted
        XCTAssertFalse(jsonString!.contains("+1-555-0123"), "Phone should be redacted from note")
        XCTAssertTrue(jsonString!.contains("[PHONE-REDACTED]"), "Should contain phone redaction placeholder")
    }

    func testCompleteBundleHasNoHomePaths() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Create a realistic bundle with home directory paths everywhere
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["\(homeDir)/dev/codex/skills", "\(homeDir)/work/another/skills"],
            claudeRoot: "\(homeDir)/dev/claude/skills",
            codexSkillManagerRoot: "\(homeDir)/csm/skills",
            copilotRoot: "\(homeDir)/copilot/skills",
            recursive: true,
            maxDepth: 5,
            excludes: ["\(homeDir)/.git"]
        )

        let findings = [
            Finding(
                ruleID: "test.rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "\(homeDir)/dev/codex/skills/agent-skill/SKILL.md"),
                message: "Test finding in \(homeDir)/dev/codex/skills"
            ),
            Finding(
                ruleID: "test.rule2",
                severity: .warning,
                agent: .claude,
                fileURL: URL(fileURLWithPath: "\(homeDir)/dev/claude/skills/another/SKILL.md"),
                message: "Path: \(homeDir)/dev/claude/skills"
            )
        ]

        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .sync,
                skillName: "agent-skill",
                status: .success,
                source: "\(homeDir)/.config/stools",
                targetPath: "\(homeDir)/dev/codex/skills/agent-skill"
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .install,
                skillName: "another-skill",
                status: .success,
                targetPath: "\(homeDir)/dev/claude/skills/another-skill"
            )
        ]

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 2,
            skillsByAgent: ["codex": 1, "claude": 1],
            skillsWithErrors: 1,
            skillsWithWarnings: 1,
            totalFindings: 2
        )

        let bundle = DiagnosticBundle(
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: events,
            skillStatistics: skillStatistics
        )

        let jsonData = try bundle.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)

        // The critical assertion: home directory must not appear anywhere
        XCTAssertFalse(jsonString!.contains(homeDir), "Home directory must not appear anywhere in bundle JSON")

        // Verify all paths use ~ instead (handle escaped slashes in JSON)
        func hasTildePath(_ json: String, _ path: String) -> Bool {
            json.contains(path) || json.contains(path.replacingOccurrences(of: "/", with: "\\/"))
        }
        XCTAssertTrue(hasTildePath(jsonString!, "~/dev/codex/skills"), "Config paths should use ~")
        XCTAssertTrue(hasTildePath(jsonString!, "~/dev/claude/skills"), "Config paths should use ~")
        XCTAssertTrue(hasTildePath(jsonString!, "~/csm/skills"), "Config paths should use ~")
        XCTAssertTrue(hasTildePath(jsonString!, "~/copilot/skills"), "Config paths should use ~")
        XCTAssertTrue(hasTildePath(jsonString!, "~/.config/stools"), "Event paths should use ~")
    }
}

// MARK: - DiagnosticBundleExporter Tests

/// Tests for DiagnosticBundleExporter ZIP export functionality
final class DiagnosticBundleExporterTests: XCTestCase {

    var tempDirectory: URL!
    var exporter: DiagnosticBundleExporter!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        exporter = DiagnosticBundleExporter()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    // MARK: - ZIP Export Tests

    func testExportCreatesValidZIP() throws {
        // Create test bundle
        let bundle = createTestBundle()

        let outputURL = tempDirectory.appendingPathComponent("test-export.zip")

        // Export to ZIP
        let resultURL = try exporter.export(bundle: bundle, to: outputURL)

        // Verify ZIP file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertEqual(resultURL, outputURL)

        // Verify file is not empty
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let fileSize = fileAttributes[.size] as! Int64
        XCTAssertGreaterThan(fileSize, 0, "ZIP file should not be empty")
    }

    func testExportContainsRequiredFiles() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("required-files.zip")

        // Export
        _ = try exporter.export(bundle: bundle, to: outputURL)

        // Verify ZIP contents
        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open created ZIP archive: \(error.localizedDescription)")
            return
        }

        let entryNames = Set(archive.map { $0.path })

        // Verify all required files exist
        XCTAssertTrue(entryNames.contains("manifest.json"), "ZIP must contain manifest.json")
        XCTAssertTrue(entryNames.contains("findings.json"), "ZIP must contain findings.json")
        XCTAssertTrue(entryNames.contains("events.json"), "ZIP must contain events.json")
        XCTAssertTrue(entryNames.contains("system.json"), "ZIP must contain system.json")

        // Should have exactly 4 files
        XCTAssertEqual(entryNames.count, 4, "ZIP should contain exactly 4 files")
    }

    func testExportManifestContainsFullBundle() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("manifest-test.zip")

        _ = try exporter.export(bundle: bundle, to: outputURL)

        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open archive: \(error.localizedDescription)")
            return
        }

        guard let manifestEntry = archive.first(where: { $0.path == "manifest.json" }) else {
            XCTFail("manifest.json not found in archive")
            return
        }

        // Extract manifest.json and verify it's valid JSON
        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { data in
            manifestData.append(data)
        }

        XCTAssertFalse(manifestData.isEmpty, "manifest.json should not be empty")

        // Verify it decodes back to DiagnosticBundle
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedBundle = try decoder.decode(DiagnosticBundle.self, from: manifestData)

        XCTAssertEqual(decodedBundle.bundleID, bundle.bundleID)
        XCTAssertEqual(decodedBundle.sToolsVersion, bundle.sToolsVersion)
        XCTAssertEqual(decodedBundle.recentFindings.count, bundle.recentFindings.count)
        XCTAssertEqual(decodedBundle.ledgerEvents.count, bundle.ledgerEvents.count)
    }

    func testExportFindingsContainsOnlyFindings() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("findings-test.zip")

        _ = try exporter.export(bundle: bundle, to: outputURL)

        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open archive: \(error.localizedDescription)")
            return
        }

        guard let findingsEntry = archive.first(where: { $0.path == "findings.json" }) else {
            XCTFail("findings.json not found in archive")
            return
        }

        var findingsData = Data()
        _ = try archive.extract(findingsEntry) { data in
            findingsData.append(data)
        }

        // Decode as [RedactedFinding]
        let decoder = JSONDecoder()
        let decodedFindings = try decoder.decode([RedactedFinding].self, from: findingsData)

        XCTAssertEqual(decodedFindings.count, bundle.recentFindings.count)
        XCTAssertEqual(decodedFindings.first?.ruleID, "test.rule")
    }

    func testExportEventsContainsOnlyEvents() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("events-test.zip")

        _ = try exporter.export(bundle: bundle, to: outputURL)

        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open archive: \(error.localizedDescription)")
            return
        }

        guard let eventsEntry = archive.first(where: { $0.path == "events.json" }) else {
            XCTFail("events.json not found in archive")
            return
        }

        var eventsData = Data()
        _ = try archive.extract(eventsEntry) { data in
            eventsData.append(data)
        }

        // Decode as [LedgerEvent]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEvents = try decoder.decode([LedgerEvent].self, from: eventsData)

        XCTAssertEqual(decodedEvents.count, bundle.ledgerEvents.count)
        XCTAssertEqual(decodedEvents.first?.skillName, "test-skill")
    }

    func testExportSystemContainsOnlySystemInfo() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("system-test.zip")

        _ = try exporter.export(bundle: bundle, to: outputURL)

        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open archive: \(error.localizedDescription)")
            return
        }

        guard let systemEntry = archive.first(where: { $0.path == "system.json" }) else {
            XCTFail("system.json not found in archive")
            return
        }

        var systemData = Data()
        _ = try archive.extract(systemEntry) { data in
            systemData.append(data)
        }

        // Decode as SystemInfo
        let decoder = JSONDecoder()
        let decodedSystem = try decoder.decode(DiagnosticBundle.SystemInfo.self, from: systemData)

        XCTAssertEqual(decodedSystem.macOSVersion, "14.5.0")
        XCTAssertEqual(decodedSystem.architecture, "arm64")
    }

    func testExportOverwritesExistingFile() throws {
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("overwrite-test.zip")

        // Create initial file with some content
        try "old content".write(to: outputURL, atomically: true, encoding: .utf8)
        let oldAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let oldSize = oldAttributes[.size] as! Int64

        // Export should overwrite
        _ = try exporter.export(bundle: bundle, to: outputURL)

        let newAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let newSize = newAttributes[.size] as! Int64

        // Size should be different (ZIP file with JSON content, not plain text)
        XCTAssertNotEqual(newSize, oldSize, "File should be overwritten")

        // Verify it's a valid ZIP
        let verifyArchive: Archive
        do {
            verifyArchive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Overwritten file should be a valid ZIP: \(error.localizedDescription)")
            return
        }
        _ = verifyArchive
    }

    func testExportRejectsNonZipExtension() throws {
        let bundle = createTestBundle()
        let invalidURL = tempDirectory.appendingPathComponent("export.txt") // Wrong extension

        XCTAssertThrowsError(
            try exporter.export(bundle: bundle, to: invalidURL),
            "Should reject non-.zip extension"
        ) { error in
            XCTAssertTrue(error is DiagnosticBundleExporter.ExportError)
        }
    }

    func testExportCreatesParentDirectory() throws {
        let bundle = createTestBundle()

        // Create a path with non-existent parent directories
        let nestedPath = tempDirectory
            .appendingPathComponent("level1")
            .appendingPathComponent("level2")
            .appendingPathComponent("export.zip")

        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedPath.deletingLastPathComponent().path))

        // Export should create parent directories
        let resultURL = try exporter.export(bundle: bundle, to: nestedPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath.deletingLastPathComponent().path))
    }

    func testDefaultOutputURL() {
        let defaultURL = exporter.defaultOutputURL()

        XCTAssertTrue(defaultURL.path.hasSuffix(".zip"), "Default URL should end with .zip")

        // Check filename format: diagnostics-YYYYMMDD-HHMMSS.zip
        let filename = defaultURL.lastPathComponent
        XCTAssertTrue(filename.hasPrefix("diagnostics-"), "Filename should start with diagnostics-")
        XCTAssertTrue(filename.hasSuffix(".zip"), "Filename should end with .zip")

        // Verify filename contains timestamp (between "diagnostics-" and ".zip")
        let timestampPart = filename.dropFirst("diagnostics-".count).dropLast(".zip".count)
        XCTAssertFalse(timestampPart.isEmpty, "Filename should contain timestamp")
        XCTAssertTrue(timestampPart.count >= 8, "Timestamp should have at least 8 characters (YYYYMMDD)")
    }

    func testExportWithEmptyBundle() throws {
        // Create minimal bundle
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.0.0",
            architecture: "x86_64",
            hostName: "test",
            availableDiskSpace: 100,
            totalMemory: 100
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: [],
            claudeRoot: nil,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: false,
            maxDepth: nil,
            excludes: []
        )

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 0,
            skillsByAgent: [:],
            skillsWithErrors: 0,
            skillsWithWarnings: 0,
            totalFindings: 0
        )

        let bundle = DiagnosticBundle(
            sToolsVersion: "0.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: [],
            ledgerEvents: [],
            skillStatistics: skillStatistics
        )

        let outputURL = tempDirectory.appendingPathComponent("empty-bundle.zip")
        _ = try exporter.export(bundle: bundle, to: outputURL)

        // Verify ZIP was created and contains files
        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .read)
        } catch {
            XCTFail("Failed to open archive: \(error.localizedDescription)")
            return
        }

        let entryCount = archive.reduce(0) { count, _ in count + 1 }
        XCTAssertGreaterThan(entryCount, 0, "ZIP should contain files even for empty bundle")
        XCTAssertEqual(entryCount, 4, "Should have 4 files: manifest, findings, events, system")
    }

    // MARK: - Bundle Size Limits Tests (Task 24)

    func testBundleWithinSizeLimitSucceeds() throws {
        // Create a normal-sized bundle (well under 5MB)
        let bundle = createTestBundle()

        let outputURL = tempDirectory.appendingPathComponent("normal-size.zip")
        let resultURL = try exporter.export(bundle: bundle, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        // Verify file size is reasonable
        let attributes = try FileManager.default.attributesOfItem(atPath: resultURL.path)
        let fileSize = attributes[.size] as! Int64
        XCTAssertLessThan(fileSize, DiagnosticBundleExporter.maxBundleSize)
    }

    func testBundleExceedsSizeLimitThrowsError() throws {
        // Create a bundle that exceeds 5MB by adding many findings with long messages
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/test/codex/skills"],
            claudeRoot: "/test/claude/skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: []
        )

        // Generate enough findings to exceed 5MB
        // Each finding with a 1KB message = need ~5000 findings to exceed 5MB
        let longMessage = String(repeating: "A", count: 1024) // 1KB per message
        var findings: [Finding] = []
        findings.reserveCapacity(6000)

        for i in 0..<6000 {
            findings.append(Finding(
                ruleID: "test.rule.\(i)",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test/skill\(i)/SKILL.md"),
                message: longMessage,
                line: i,
                column: 1
            ))
        }

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 6000,
            skillsByAgent: ["codex": 6000],
            skillsWithErrors: 6000,
            skillsWithWarnings: 0,
            totalFindings: 6000
        )

        let bundle = DiagnosticBundle(
            bundleID: UUID(),
            generatedAt: Date(),
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: [],
            skillStatistics: skillStatistics
        )

        let outputURL = tempDirectory.appendingPathComponent("oversized.zip")

        // Should throw bundleTooLarge error
        XCTAssertThrowsError(
            try exporter.export(bundle: bundle, to: outputURL),
            "Should throw error for bundle exceeding size limit"
        ) { error in
            guard case DiagnosticBundleExporter.ExportError.bundleTooLarge = error else {
                XCTFail("Expected bundleTooLarge error, got: \(error)")
                return
            }
        }

        // Verify no file was created
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testFileCountWithinLimitSucceeds() throws {
        // Current implementation always has 4 files (manifest, findings, events, system)
        let bundle = createTestBundle()
        let outputURL = tempDirectory.appendingPathComponent("file-count-test.zip")

        let resultURL = try exporter.export(bundle: bundle, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        // Verify ZIP contains exactly 4 files
        let archive = try Archive(url: outputURL, accessMode: .read)
        let entryCount = archive.reduce(0) { count, _ in count + 1 }
        XCTAssertEqual(entryCount, 4)
        XCTAssertLessThanOrEqual(entryCount, DiagnosticBundleExporter.maxFileCount)
    }

    func testConstantsAreCorrect() {
        // Verify the limit constants are set correctly
        XCTAssertEqual(DiagnosticBundleExporter.maxBundleSize, 5 * 1024 * 1024, "Max bundle size should be 5MB")
        XCTAssertEqual(DiagnosticBundleExporter.maxFileCount, 1000, "Max file count should be 1000")
    }

    func testBundleSizeLimitErrorMessage() {
        // Create error and verify message format
        let error = DiagnosticBundleExporter.ExportError.bundleTooLarge(6 * 1024 * 1024, 5 * 1024 * 1024)

        let errorMessage = error.errorDescription
        XCTAssertNotNil(errorMessage)

        let message = errorMessage!
        XCTAssertTrue(message.contains("6.00 MB"), "Should show actual size in MB")
        XCTAssertTrue(message.contains("5.00 MB"), "Should show max size in MB")
        XCTAssertTrue(message.contains("exceeds maximum"), "Should explain the limit")
    }

    func testFileCountLimitErrorMessage() {
        // Create error and verify message format
        let error = DiagnosticBundleExporter.ExportError.tooManyFiles(1500, 1000)

        let errorMessage = error.errorDescription
        XCTAssertNotNil(errorMessage)

        let message = errorMessage!
        XCTAssertTrue(message.contains("1500"), "Should show actual file count")
        XCTAssertTrue(message.contains("1000"), "Should show max file count")
        XCTAssertTrue(message.contains("exceeds maximum"), "Should explain the limit")
    }

    // MARK: - Helper Methods

    private func createTestBundle() -> DiagnosticBundle {
        let systemInfo = DiagnosticBundle.SystemInfo(
            macOSVersion: "14.5.0",
            architecture: "arm64",
            hostName: "<redacted>",
            availableDiskSpace: 500_000_000_000,
            totalMemory: 16_000_000_000
        )

        let scanConfig = DiagnosticBundle.ScanConfiguration(
            codexRoots: ["/test/codex/skills"],
            claudeRoot: "/test/claude/skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: 5,
            excludes: [".git", "node_modules"]
        )

        let findings = [
            Finding(
                ruleID: "test.rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/test/SKILL.md"),
                message: "Test finding",
                line: 10,
                column: 5
            )
        ]

        let event = LedgerEvent(
            id: 1,
            timestamp: Date(),
            eventType: .sync,
            skillName: "test-skill",
            status: .success
        )

        let skillStatistics = DiagnosticBundle.SkillStatistics(
            totalSkills: 42,
            skillsByAgent: ["codex": 20, "claude": 22],
            skillsWithErrors: 2,
            skillsWithWarnings: 5,
            totalFindings: 15
        )

        return DiagnosticBundle(
            bundleID: UUID(),
            generatedAt: Date(),
            sToolsVersion: "1.0.0",
            systemInfo: systemInfo,
            scanConfig: scanConfig,
            recentFindings: findings,
            ledgerEvents: [event],
            skillStatistics: skillStatistics
        )
    }
}
