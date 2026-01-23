import XCTest
@testable import SkillsCore

/// Tests for SecurityIgnoredFindings actor
final class SecurityIgnoredFindingsTests: XCTestCase {
    private var ignoredFindings: SecurityIgnoredFindings!

    override func setUp() async throws {
        try await super.setUp()
        ignoredFindings = SecurityIgnoredFindings()
        // Clear any existing ignored findings before each test
        await ignoredFindings.clearAll()
    }

    override func tearDown() async throws {
        // Clean up after each test
        await ignoredFindings.clearAll()
        try await super.tearDown()
    }

    // MARK: - Test Methods

    /// Test that a finding can be marked as ignored
    func testIgnoreFinding() async throws {
        let ruleID = "security.hardcoded_secret"
        let fileURL = URL(fileURLWithPath: "/path/to/test.swift")

        // Initially not ignored
        var isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertFalse(isIgnored, "Finding should not be ignored initially")

        // Mark as ignored
        await ignoredFindings.ignore(ruleID: ruleID, fileURL: fileURL)

        // Now should be ignored
        isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertTrue(isIgnored, "Finding should be ignored after marking")
    }

    /// Test that a finding can be unignored (restored)
    func testUnignoreFinding() async throws {
        let ruleID = "security.hardcoded_secret"
        let fileURL = URL(fileURLWithPath: "/path/to/test.swift")

        // Mark as ignored
        await ignoredFindings.ignore(ruleID: ruleID, fileURL: fileURL)
        var isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertTrue(isIgnored)

        // Unmark as ignored
        await ignoredFindings.unignore(ruleID: ruleID, fileURL: fileURL)

        // Should no longer be ignored
        isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertFalse(isIgnored, "Finding should not be ignored after unmarking")
    }

    /// Test that different findings can be ignored independently
    func testMultipleFindings() async throws {
        let ruleID1 = "security.hardcoded_secret"
        let ruleID2 = "security.command_injection"
        let fileURL1 = URL(fileURLWithPath: "/path/to/test1.swift")
        let fileURL2 = URL(fileURLWithPath: "/path/to/test2.swift")

        // Ignore first finding
        await ignoredFindings.ignore(ruleID: ruleID1, fileURL: fileURL1)

        // First should be ignored
        var isIgnored1 = await ignoredFindings.isIgnored(ruleID: ruleID1, fileURL: fileURL1)
        XCTAssertTrue(isIgnored1)

        // Second should not be ignored
        var isIgnored2 = await ignoredFindings.isIgnored(ruleID: ruleID2, fileURL: fileURL2)
        XCTAssertFalse(isIgnored2)

        // Ignore second finding
        await ignoredFindings.ignore(ruleID: ruleID2, fileURL: fileURL2)

        // Both should now be ignored
        isIgnored1 = await ignoredFindings.isIgnored(ruleID: ruleID1, fileURL: fileURL1)
        isIgnored2 = await ignoredFindings.isIgnored(ruleID: ruleID2, fileURL: fileURL2)
        XCTAssertTrue(isIgnored1)
        XCTAssertTrue(isIgnored2)
    }

    /// Test that the same rule on different files creates different ignored entries
    func testSameRuleDifferentFiles() async throws {
        let ruleID = "security.hardcoded_secret"
        let fileURL1 = URL(fileURLWithPath: "/path/to/test1.swift")
        let fileURL2 = URL(fileURLWithPath: "/path/to/test2.swift")

        // Ignore finding in first file
        await ignoredFindings.ignore(ruleID: ruleID, fileURL: fileURL1)

        // First file should be ignored
        var isIgnored1 = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL1)
        XCTAssertTrue(isIgnored1)

        // Second file should not be ignored
        var isIgnored2 = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL2)
        XCTAssertFalse(isIgnored2)
    }

    /// Test getting all ignored findings
    func testGetAllIgnored() async throws {
        let ruleID1 = "security.hardcoded_secret"
        let ruleID2 = "security.command_injection"
        let fileURL1 = URL(fileURLWithPath: "/path/to/test1.swift")
        let fileURL2 = URL(fileURLWithPath: "/path/to/test2.swift")

        // Ignore two findings
        await ignoredFindings.ignore(ruleID: ruleID1, fileURL: fileURL1, line: 42)
        await ignoredFindings.ignore(ruleID: ruleID2, fileURL: fileURL2)

        // Get all ignored findings
        let allIgnored = await ignoredFindings.getAllIgnored()

        // Should have exactly 2 ignored findings
        XCTAssertEqual(allIgnored.count, 2, "Should have exactly 2 ignored findings")

        // Verify the findings have correct data
        let finding1 = allIgnored.first { $0.ruleID == ruleID1 }
        XCTAssertNotNil(finding1, "Should find first ignored finding")
        XCTAssertEqual(finding1?.line, 42, "Should preserve line number")

        let finding2 = allIgnored.first { $0.ruleID == ruleID2 }
        XCTAssertNotNil(finding2, "Should find second ignored finding")
    }

    /// Test clearing all ignored findings
    func testClearAll() async throws {
        let ruleID = "security.hardcoded_secret"
        let fileURL = URL(fileURLWithPath: "/path/to/test.swift")

        // Ignore a finding
        await ignoredFindings.ignore(ruleID: ruleID, fileURL: fileURL)
        var isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertTrue(isIgnored)

        // Clear all
        await ignoredFindings.clearAll()

        // Should no longer be ignored
        isIgnored = await ignoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertFalse(isIgnored, "Finding should not be ignored after clearing all")
    }

    /// Test counting ignored findings
    func testCount() async throws {
        // Initially zero
        var count = await ignoredFindings.count()
        XCTAssertEqual(count, 0, "Should start with zero ignored findings")

        // Add three ignored findings
        await ignoredFindings.ignore(ruleID: "rule1", fileURL: URL(fileURLWithPath: "/test1.swift"))
        await ignoredFindings.ignore(ruleID: "rule2", fileURL: URL(fileURLWithPath: "/test2.swift"))
        await ignoredFindings.ignore(ruleID: "rule3", fileURL: URL(fileURLWithPath: "/test3.swift"))

        // Count should be 3
        count = await ignoredFindings.count()
        XCTAssertEqual(count, 3, "Should count 3 ignored findings")

        // Unignore one
        await ignoredFindings.unignore(ruleID: "rule2", fileURL: URL(fileURLWithPath: "/test2.swift"))

        // Count should be 2
        count = await ignoredFindings.count()
        XCTAssertEqual(count, 2, "Should count 2 ignored findings after unignoring one")
    }

    /// Test that ignored findings persist across actor instances
    func testPersistence() async throws {
        let ruleID = "security.hardcoded_secret"
        let fileURL = URL(fileURLWithPath: "/path/to/test.swift")

        // Use first instance to ignore
        await ignoredFindings.ignore(ruleID: ruleID, fileURL: fileURL)

        // Create new instance
        let newIgnoredFindings = SecurityIgnoredFindings()

        // Should still be ignored (UserDefaults persistence)
        let isIgnored = await newIgnoredFindings.isIgnored(ruleID: ruleID, fileURL: fileURL)
        XCTAssertTrue(isIgnored, "Finding should remain ignored across instances")
    }

    /// Test IgnoredFinding model
    func testIgnoredFindingModel() throws {
        let finding = IgnoredFinding(
            ruleID: "security.hardcoded_secret",
            fileURL: URL(fileURLWithPath: "/path/to/test.swift"),
            line: 42,
            ignoredAt: "2024-01-20T12:00:00Z"
        )

        // Test properties
        XCTAssertEqual(finding.ruleID, "security.hardcoded_secret")
        XCTAssertEqual(finding.line, 42)
        XCTAssertEqual(finding.ignoredAt, "2024-01-20T12:00:00Z")

        // Test that id is generated
        XCTAssertFalse(finding.id.isEmpty, "Should have a unique ID")
    }
}

/// Tests for SecurityScanner false positive filtering
final class SecurityScannerFalsePositiveTests: XCTestCase {
    private var testDir: URL!
    private var skillFile: URL!
    private var scriptsDir: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        let tmpDir = FileManager.default.temporaryDirectory
        testDir = tmpDir.appendingPathComponent("SecurityScannerFPTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // Create skill file
        skillFile = testDir.appendingPathComponent("SKILL.md")
        try createTestSkill()

        // Create scripts directory
        scriptsDir = testDir.appendingPathComponent("scripts")
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDir)
        try await super.tearDown()
    }

    // MARK: - Test Methods

    /// Test that ignored findings don't appear in scan results
    func testIgnoredFindingFilteredOut() async throws {
        // Create script with hardcoded secret
        let scriptContent = """
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"
        """
        let scriptFile = scriptsDir.appendingPathComponent("test.swift")
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()

        // First scan should find the issue
        let findings1 = try await scanner.scan(doc: doc)
        XCTAssertEqual(findings1.count, 1, "Should detect security issue")

        let finding = findings1.first!
        XCTAssertEqual(finding.ruleID, "security.hardcoded_secret")

        // Mark as ignored
        await scanner.ignoreFinding(finding)

        // Wait a moment for the async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Second scan should NOT find the issue (filtered out)
        let findings2 = try await scanner.scan(doc: doc)
        XCTAssertEqual(findings2.count, 0, "Ignored finding should be filtered out")
    }

    /// Test that unignoring a finding restores it in scan results
    func testUnignoreFindingRestoresIt() async throws {
        // Create script with hardcoded secret
        let scriptContent = """
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"
        """
        let scriptFile = scriptsDir.appendingPathComponent("test.swift")
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()

        // Scan and ignore the finding
        let findings1 = try await scanner.scan(doc: doc)
        let finding = findings1.first!
        await scanner.ignoreFinding(finding)

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Scan again - should be filtered
        let findings2 = try await scanner.scan(doc: doc)
        XCTAssertEqual(findings2.count, 0, "Should be filtered after ignoring")

        // Unignore the finding
        await scanner.unignoreFinding(finding)

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Scan again - should be restored
        let findings3 = try await scanner.scan(doc: doc)
        XCTAssertEqual(findings3.count, 1, "Should be restored after unignoring")
    }

    /// Test that isIgnored correctly checks ignored status
    func testIsIgnored() async throws {
        let scanner = SecurityScanner()

        let finding = Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/path.swift"),
            message: "Test",
            line: 42
        )

        // Initially not ignored
        var isIgnored = await scanner.isIgnored(finding)
        XCTAssertFalse(isIgnored, "Should not be ignored initially")

        // Ignore it
        await scanner.ignoreFinding(finding)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Now should be ignored
        isIgnored = await scanner.isIgnored(finding)
        XCTAssertTrue(isIgnored, "Should be ignored after marking")
    }

    /// Test that different findings are tracked independently
    func testMultipleFindingsTrackedIndependently() async throws {
        let scanner = SecurityScanner()

        let finding1 = Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/file1.swift"),
            message: "Test 1"
        )

        let finding2 = Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/file2.swift"),
            message: "Test 2"
        )

        // Ignore first finding
        await scanner.ignoreFinding(finding1)
        try await Task.sleep(nanoseconds: 100_000_000)

        // First should be ignored
        var isIgnored1 = await scanner.isIgnored(finding1)
        XCTAssertTrue(isIgnored1)

        // Second should NOT be ignored
        var isIgnored2 = await scanner.isIgnored(finding2)
        XCTAssertFalse(isIgnored2)
    }

    /// Test clearing all ignored findings
    func testClearAllIgnored() async throws {
        let scanner = SecurityScanner()

        let finding1 = Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/file1.swift"),
            message: "Test 1"
        )

        let finding2 = Finding(
            ruleID: "security.command_injection",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/file2.swift"),
            message: "Test 2"
        )

        // Ignore both findings
        await scanner.ignoreFinding(finding1)
        await scanner.ignoreFinding(finding2)
        try await Task.sleep(nanoseconds: 100_000_000)

        var count = await scanner.ignoredCount()
        XCTAssertEqual(count, 2, "Should have 2 ignored findings")

        // Clear all
        await scanner.clearAllIgnored()
        try await Task.sleep(nanoseconds: 100_000_000)

        // None should be ignored now
        var isIgnored1 = await scanner.isIgnored(finding1)
        var isIgnored2 = await scanner.isIgnored(finding2)
        XCTAssertFalse(isIgnored1)
        XCTAssertFalse(isIgnored2)

        count = await scanner.ignoredCount()
        XCTAssertEqual(count, 0, "Should have 0 ignored findings")
    }

    /// Test getting all ignored findings
    func testGetAllIgnored() async throws {
        let scanner = SecurityScanner()

        let finding1 = Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/test/file1.swift"),
            message: "Test 1",
            line: 10
        )

        let finding2 = Finding(
            ruleID: "security.command_injection",
            severity: .warning,
            agent: .claude,
            fileURL: URL(fileURLWithPath: "/test/file2.swift"),
            message: "Test 2",
            line: 20
        )

        // Ignore both findings
        await scanner.ignoreFinding(finding1)
        await scanner.ignoreFinding(finding2)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Get all ignored
        let allIgnored = await scanner.getAllIgnored()

        XCTAssertEqual(allIgnored.count, 2, "Should have 2 ignored findings")

        // Verify they contain correct info
        let ignored1 = allIgnored.first { $0.ruleID == "security.hardcoded_secret" }
        XCTAssertNotNil(ignored1)
        XCTAssertEqual(ignored1?.line, 10)

        let ignored2 = allIgnored.first { $0.ruleID == "security.command_injection" }
        XCTAssertNotNil(ignored2)
        XCTAssertEqual(ignored2?.line, 20)
    }

    // MARK: - Helper Methods

    private func createTestSkill() throws {
        let skillContent = """
        ---
        name: Test Skill
        description: Test skill for false positive tests
        agent: codex
        ---

        # Test Skill

        This is a test skill.
        """
        try skillContent.write(to: skillFile, atomically: true, encoding: .utf8)
    }
}
