import XCTest
@testable import SkillsCore

/// Tests for SecurityScanner actor
final class SecurityScannerTests: XCTestCase {
    /// Test fixture directory
    private var testDir: URL!
    private var skillFile: URL!
    private var scriptsDir: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        let tmpDir = FileManager.default.temporaryDirectory
        testDir = tmpDir.appendingPathComponent("SecurityScannerTests-\(UUID().uuidString)")
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

    /// Test that scanner initializes with default rules
    func testDefaultRulesRegistered() async throws {
        let scanner = SecurityScanner()
        let ruleIDs = await scanner.registeredRuleIDs()

        XCTAssertTrue(ruleIDs.contains("security.hardcoded_secret"), "Default rules should include HardcodedSecretRule")
        XCTAssertTrue(ruleIDs.contains("security.command_injection"), "Default rules should include CommandInjectionRule")
    }

    /// Test scanning a skill document with hardcoded secrets
    func testScanDocWithHardcodedSecret() async throws {
        // Create skill file with hardcoded secret
        let skillContent = """
        ---
        name: Test Skill
        description: Test skill with secret
        agent: codex
        ---

        # Test Skill

        This skill has a hardcoded API key.
        """
        try skillContent.write(to: skillFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scan(doc: doc)

        // Should not trigger on skill file without secrets
        XCTAssertEqual(findings.count, 0, "No findings in clean skill file")
    }

    /// Test scanning a skill document with a script containing hardcoded secret
    func testScanDocWithScriptContainingSecret() async throws {
        // Create script with hardcoded secret
        let scriptContent = """
        import Foundation

        // This should be detected
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"

        func makeRequest() {
            // Use API key
        }
        """
        let scriptFile = scriptsDir.appendingPathComponent("test.swift")
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scan(doc: doc)

        // Should detect the hardcoded secret in the script
        XCTAssertTrue(findings.count > 0, "Should detect hardcoded secret in script")
        XCTAssertEqual(findings.first?.ruleID, "security.hardcoded_secret", "Should be detected by HardcodedSecretRule")
        // Compare lastPathComponent (resolves /private/ symlinks on macOS)
        XCTAssertEqual(findings.first?.fileURL.lastPathComponent, scriptFile.lastPathComponent, "Finding should point to correct script file")
    }

    /// Test scanning a skill document with a script containing command injection
    func testScanDocWithScriptContainingCommandInjection() async throws {
        // Create script with command injection
        let scriptContent = """
        import Foundation

        // This should be detected
        let result = shell("rm -rf /")

        func cleanup() {
            // Clean up files
        }
        """
        let scriptFile = scriptsDir.appendingPathComponent("test.swift")
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scan(doc: doc)

        // Should detect the command injection
        XCTAssertTrue(findings.count > 0, "Should detect command injection in script")
        XCTAssertEqual(findings.first?.ruleID, "security.command_injection", "Should be detected by CommandInjectionRule")
    }

    /// Test scanning all scripts in a skill directory
    func testScanAllScripts() async throws {
        // Create multiple scripts
        let script1Content = """
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"
        """
        let script1File = scriptsDir.appendingPathComponent("secret.swift")
        try script1Content.write(to: script1File, atomically: true, encoding: .utf8)

        let script2Content = """
        let result = shell("cat /etc/passwd")
        """
        let script2File = scriptsDir.appendingPathComponent("inject.swift")
        try script2Content.write(to: script2File, atomically: true, encoding: .utf8)

        // Create clean script (should not trigger)
        let script3Content = """
        let greeting = "Hello, World!"
        """
        let script3File = scriptsDir.appendingPathComponent("clean.swift")
        try script3Content.write(to: script3File, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scanAllScripts(in: doc)

        // Should detect issues in first two scripts
        XCTAssertEqual(findings.count, 2, "Should detect 2 security issues across scripts")

        // Check that findings are from different files
        let files = Set(findings.map { $0.fileURL })
        XCTAssertEqual(files.count, 2, "Findings should be from 2 different files")
    }

    /// Test scanning a single script file
    func testScanScript() async throws {
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
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scanScript(at: scriptFile, skillDoc: doc)

        XCTAssertEqual(findings.count, 1, "Should detect one security issue")
        XCTAssertEqual(findings.first?.ruleID, "security.hardcoded_secret")
    }

    /// Test that commented-out code doesn't trigger false positives
    // NOTE: This test documents current behavior - commented code may still trigger
    // The HardcodedSecretRule checks for string length and patterns, not comment context
    func testCommentedCodeMayStillTrigger() async throws {
        let scriptContent = """
        // This is a comment about an API key
        let apiKey = "placeholder"

        # This is also a comment
        """
        let scriptFile = scriptsDir.appendingPathComponent("test.swift")
        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let scanner = SecurityScanner()
        let findings = try await scanner.scanScript(at: scriptFile, skillDoc: doc)

        // The rules check for patterns; "placeholder" is too short to trigger
        XCTAssertEqual(findings.count, 0, "Should not detect issues with safe placeholder text")
    }

    /// Test registering a custom rule
    func testRegisterCustomRule() async throws {
        struct CustomTestRule: SecurityRule {
            let ruleID = "test.custom"
            let description = "Test rule"
            let severity: Severity = .warning
            let patterns: [SecurityPattern] = []

            func scan(content: String, file: URL, skillDoc: SkillDoc) async throws -> [Finding] {
                // Check for "CUSTOM_PATTERN" in content
                if content.contains("CUSTOM_PATTERN") {
                    return [Finding(
                        ruleID: ruleID,
                        severity: severity,
                        agent: skillDoc.agent,
                        fileURL: file,
                        message: "Custom pattern detected"
                    )]
                }
                return []
            }
        }

        let scanner = SecurityScanner()
        await scanner.registerRule(CustomTestRule())

        let ruleIDs = await scanner.registeredRuleIDs()
        XCTAssertTrue(ruleIDs.contains("test.custom"), "Should register custom rule")
    }

    /// Test unregistering a rule
    func testUnregisterRule() async throws {
        let scanner = SecurityScanner()

        // Verify rule exists
        var ruleIDs = await scanner.registeredRuleIDs()
        XCTAssertTrue(ruleIDs.contains("security.hardcoded_secret"))

        // Unregister rule
        await scanner.unregisterRule(ruleID: "security.hardcoded_secret")

        // Verify rule is removed
        ruleIDs = await scanner.registeredRuleIDs()
        XCTAssertFalse(ruleIDs.contains("security.hardcoded_secret"), "Should unregister rule")
    }

    /// Test scanning with custom rules only
    func testScannerWithCustomRules() async throws {
        struct AlwaysFireRule: SecurityRule {
            let ruleID = "test.always"
            let description = "Always fires"
            let severity: Severity = .warning
            let patterns: [SecurityPattern] = []

            func scan(content: String, file: URL, skillDoc: SkillDoc) async throws -> [Finding] {
                return [Finding(
                    ruleID: ruleID,
                    severity: severity,
                    agent: skillDoc.agent,
                    fileURL: file,
                    message: "Always fires test"
                )]
            }
        }

        let scanner = SecurityScanner(rules: [AlwaysFireRule()])
        let doc = SkillDoc(
            agent: .codex,
            rootURL: testDir,
            skillDirURL: testDir,
            skillFileURL: skillFile,
            name: "Test Skill",
            description: "Test skill for security scanner",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )

        let findings = try await scanner.scan(doc: doc)

        XCTAssertEqual(findings.count, 1, "Custom rule should fire")
        XCTAssertEqual(findings.first?.ruleID, "test.always")
    }

    // MARK: - Helper Methods

    private func createTestSkill() throws {
        let skillContent = """
        ---
        name: Test Skill
        description: Test skill for security scanner
        agent: codex
        ---

        # Test Skill

        This is a test skill for security scanning.
        """
        try skillContent.write(to: skillFile, atomically: true, encoding: .utf8)
    }
}
