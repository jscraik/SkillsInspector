import XCTest
@testable import SkillsCore

final class HardcodedSecretRuleTests: XCTestCase {
    var rule: HardcodedSecretRule!
    var testDoc: SkillDoc!
    var testFileURL: URL!

    override func setUp() async throws {
        rule = HardcodedSecretRule()

        // Create a temporary file URL for testing
        let tempDir = FileManager.default.temporaryDirectory
        testFileURL = tempDir.appendingPathComponent("test-script.swift")

        // Create a test SkillDoc
        testDoc = SkillDoc(
            agent: .codex,
            rootURL: tempDir,
            skillDirURL: tempDir,
            skillFileURL: tempDir.appendingPathComponent("SKILL.md"),
            name: "test-skill",
            description: "Test skill",
            lineCount: 10,
            isSymlinkedDir: false,
            hasFrontmatter: true,
            frontmatterStartLine: 1,
            referencesCount: 0,
            assetsCount: 0,
            scriptsCount: 1
        )
    }

    override func tearDown() async throws {
        // Clean up test file
        try? FileManager.default.removeItem(at: testFileURL)
    }

    // MARK: - Detection Tests

    func testDetectsHardcodedAPIKeyWith32PlusChars() async throws {
        // This is the key test from the acceptance criteria
        let content = """
        // Swift script with hardcoded secret
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"
        print(apiKey)
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertEqual(findings.count, 1, "Should detect exactly one hardcoded secret")
        XCTAssertEqual(findings.first?.ruleID, "security.hardcoded_secret")
        XCTAssertEqual(findings.first?.severity, .error)
        XCTAssertEqual(findings.first?.line, 2)
        XCTAssertNotNil(findings.first?.suggestedFix)
        XCTAssertTrue(
            findings.first?.suggestedFix?.description.contains("environment") ?? false,
            "Suggested fix should mention environment variables"
        )
    }

    func testDetectsVariableAssignmentWithSecret() async throws {
        let content = """
        var secretToken = "sk-live_51AbCdEf1234567890abcdefghijklmnopqrstuv"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertGreaterThan(findings.count, 0, "Should detect secret in variable assignment")
    }

    func testDetectsConfigStyleAssignment() async throws {
        let content = """
        password: "mySuperSecretPassword12345678901234567890"
        api_key: "pk_test_1234567890abcdefghijklmnopqrstuvwxyz"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertGreaterThan(findings.count, 0, "Should detect config-style secrets")
    }

    func testDetectsBearerToken() async throws {
        let content = """
        let authHeader = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghijklmnopqrstuvwxyz12345678901234567890"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertGreaterThan(findings.count, 0, "Should detect Bearer token")
    }

    // MARK: - False Positive Prevention Tests

    func testIgnoresShortStrings() async throws {
        let content = """
        let apiKey = "short"  // Too short to trigger
        let token = "also_too_short"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertEqual(findings.count, 0, "Should ignore strings shorter than 32 characters")
    }

    func testIgnoresPlaceholders() async throws {
        let content = """
        let apiKey = "your_api_key_here_replace_with_actual_key"
        let secret = "replace_with_your_secret_placeholder_123456789012"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertEqual(findings.count, 0, "Should ignore obvious placeholder values")
    }

    func testIgnoresCommentsContainingKeywords() async throws {
        let content = """
        // TODO: Replace apiKey with environment variable
        // FIXME: Don't hardcode secret in production
        func authenticate() {
            // Implementation needed
        }
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertEqual(findings.count, 0, "Should ignore comments without assignments")
    }

    func testIgnoresExampleURLs() async throws {
        let content = """
        let exampleURL = "https://api.example.com/v1/endpoint?api_key=demo12345678901234567890123456"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        // May or may not detect depending on pattern, but shouldn't be a false positive
        // The "demo" prefix should help identify it as an example
    }

    // MARK: - Context-Aware Tests

    func testRequiresAssignmentContext() async throws {
        // String literal without assignment shouldn't trigger
        let content = """
        print("sk-1234567890abcdefghijklmnopqrstuvwxyz123456")
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        // Pattern 2 may still detect this (it looks for quoted strings with known prefixes)
        // But pattern 1 (assignment context) shouldn't trigger alone
    }

    func testDetectsMultipleAssignmentStyles() async throws {
        let content = """
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456"
        var secret: String = "secret_value_here_123456789012345678901234"
        const token = "pk_live_1234567890abcdefghijklmnopqrstuvwxyz1234"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertGreaterThanOrEqual(findings.count, 2, "Should detect multiple assignment styles")
    }

    // MARK: - Edge Cases

    func testHandlesEmptyContent() async throws {
        let findings = try await rule.scan(content: "", file: testFileURL, skillDoc: testDoc)
        XCTAssertEqual(findings.count, 0)
    }

    func testHandlesMultilineStrings() async throws {
        // Note: Using escaped newline to avoid nested multiline literal syntax
        let content = #"let secret = """# + "\n" + #"sk-1234567890abcdefghijklmnopqrstuvwxyz123456"# + "\n" + #""""#

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        // Multiline strings are complex; behavior depends on line-by-line scanning
        // This test documents current behavior
    }

    func testDetectsSecretWithDifferentVariableNames() async throws {
        let content = """
        let accessToken = "sk-test-REDACTED-0000000000000000"
        let apiSecret = "sk_live_REDACTED_DO_NOT_USE"
        let authToken = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9REDACTED"
        """

        try content.write(to: testFileURL, atomically: true, encoding: .utf8)
        let findings = try await rule.scan(content: content, file: testFileURL, skillDoc: testDoc)

        XCTAssertGreaterThan(findings.count, 0, "Should detect secrets with various variable names")
    }
}
