import XCTest
@testable import SkillsCore

final class MultiTargetSkillInstallerTests: XCTestCase {
    func testRollbackOnFailure() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("multi-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-one", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-one.zip")
        let goodRoot = temp.appendingPathComponent("good-root", isDirectory: true)
        let badRootFile = temp.appendingPathComponent("bad-root-file")

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: goodRoot, withIntermediateDirectories: true)
        try "not a dir".write(to: badRootFile, atomically: true, encoding: .utf8)
        try """
        ---
        name: demo
        description: Demo skill
        ---
        # Sample
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-one",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let installer = MultiTargetSkillInstaller()
        let outcome = try await installer.install(
            archiveURL: archiveURL,
            targets: [
                .codex(goodRoot),
                .copilot(badRootFile)
            ],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        // Rollback: no successful installs should remain
        XCTAssertTrue(outcome.didRollback)
        XCTAssertTrue(outcome.successes.isEmpty)
        XCTAssertEqual(outcome.failures.count, 2)
        let installedPath = goodRoot.appendingPathComponent("skill-one")
        XCTAssertFalse(fm.fileExists(atPath: installedPath.path))
    }

    // MARK: - Post-Install Validation Tests

    func testDefaultPostInstallValidatorPasses() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("validator-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("test-skill", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try """
        ---
        name: test
        description: Test skill
        ---
        # Test
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let result = RemoteSkillInstallResult(
            verification: .permissive,
            skillDirectory: skillDir,
            filesCopied: 1,
            totalBytes: 100,
            archiveSHA256: nil,
            contentSHA256: nil,
            backupURL: nil
        )

        let validator = DefaultPostInstallValidator()
        let error = validator.validate(result: result, target: .codex(temp))

        XCTAssertNil(error, "Default validator should pass for valid skill")
    }

    func testDefaultPostInstallValidatorFailsMissingSKILL() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("validator-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("test-skill", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        // Don't create SKILL.md

        let result = RemoteSkillInstallResult(
            verification: .permissive,
            skillDirectory: skillDir,
            filesCopied: 0,
            totalBytes: 0,
            archiveSHA256: nil,
            contentSHA256: nil,
            backupURL: nil
        )

        let validator = DefaultPostInstallValidator()
        let error = validator.validate(result: result, target: .codex(temp))

        XCTAssertNotNil(error, "Default validator should fail for missing SKILL.md")
        XCTAssertTrue(error?.contains("SKILL.md not found") ?? false)
    }

    func testCustomPostInstallValidator() async throws {
        struct CustomValidator: PostInstallValidator {
            let shouldFail: Bool

            func validate(result: RemoteSkillInstallResult, target: SkillInstallTarget) -> String? {
                if shouldFail {
                    return "Custom validation failed"
                }
                return nil
            }
        }

        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("custom-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-custom", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-custom.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: custom
        description: Custom validation test
        ---
        # Custom
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-custom",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )

        // Test with passing validator
        let passingValidator = CustomValidator(shouldFail: false)
        let installerWithPass = MultiTargetSkillInstaller(validator: passingValidator)
        let outcomePass = try await installerWithPass.install(
            archiveURL: archiveURL,
            targets: [.codex(targetRoot)],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        XCTAssertFalse(outcomePass.didRollback)
        XCTAssertTrue(outcomePass.successes[AgentKind.codex] != nil)

        // Clean up for next test
        try? fm.removeItem(at: targetRoot.appendingPathComponent("skill-custom"))

        // Test with failing validator
        let failingValidator = CustomValidator(shouldFail: true)
        let installerWithFail = MultiTargetSkillInstaller(validator: failingValidator)
        let outcomeFail = try await installerWithFail.install(
            archiveURL: archiveURL,
            targets: [.codex(targetRoot)],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        XCTAssertTrue(outcomeFail.didRollback)
        XCTAssertTrue(outcomeFail.successes.isEmpty)
        XCTAssertEqual(outcomeFail.failures[.codex], "Validation failed: Custom validation failed")
    }

    func testMultiTargetWithValidationFailure() async throws {
        struct TargetSpecificValidator: PostInstallValidator {
            func validate(result: RemoteSkillInstallResult, target: SkillInstallTarget) -> String? {
                // Fail only for Claude targets
                if case .claude = target {
                    return "Claude validation failed"
                }
                return nil
            }
        }

        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("multi-val-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-multi", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-multi.zip")
        let codexRoot = temp.appendingPathComponent("codex-root", isDirectory: true)
        let claudeRoot = temp.appendingPathComponent("claude-root", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: claudeRoot, withIntermediateDirectories: true)
        try """
        ---
        name: multi
        description: Multi-target validation test
        ---
        # Multi
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-multi",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let validator = TargetSpecificValidator()
        let installer = MultiTargetSkillInstaller(validator: validator)

        let outcome = try await installer.install(
            archiveURL: archiveURL,
            targets: [.codex(codexRoot), .claude(claudeRoot)],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        // Rollback: no installs should remain after validation failure
        XCTAssertTrue(outcome.didRollback)
        XCTAssertTrue(outcome.successes.isEmpty)
        XCTAssertTrue(outcome.failures[AgentKind.claude]?.contains("Claude validation failed") ?? false)
        XCTAssertFalse(fm.fileExists(atPath: codexRoot.appendingPathComponent("skill-multi").path))
        XCTAssertFalse(fm.fileExists(atPath: claudeRoot.appendingPathComponent("skill-multi").path))
    }

    func testAllThreeTargetsInstall() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("all-three-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-all", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-all.zip")
        let codexRoot = temp.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = temp.appendingPathComponent("claude", isDirectory: true)
        let copilotRoot = temp.appendingPathComponent("copilot", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: claudeRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: copilotRoot, withIntermediateDirectories: true)
        try """
        ---
        name: all-three
        description: Test all three targets
        ---
        # All Three
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-all",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let installer = MultiTargetSkillInstaller()

        let outcome = try await installer.install(
            archiveURL: archiveURL,
            targets: [
                .codex(codexRoot),
                .claude(claudeRoot),
                .copilot(copilotRoot)
            ],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        XCTAssertFalse(outcome.didRollback)
        XCTAssertEqual(outcome.successes.count, 3)
        XCTAssertTrue(outcome.successes[AgentKind.codex] != nil)
        XCTAssertTrue(outcome.successes[AgentKind.claude] != nil)
        XCTAssertTrue(outcome.successes[AgentKind.copilot] != nil)
        XCTAssertTrue(outcome.failures.isEmpty)

        // Verify all three installations exist
        XCTAssertTrue(fm.fileExists(atPath: codexRoot.appendingPathComponent("skill-all/SKILL.md").path))
        XCTAssertTrue(fm.fileExists(atPath: claudeRoot.appendingPathComponent("skill-all/SKILL.md").path))
        XCTAssertTrue(fm.fileExists(atPath: copilotRoot.appendingPathComponent("skill-all/SKILL.md").path))
    }

    // MARK: - Success Rate Tests

    func testSuccessRateCalculation() async throws {
        // With 3 targets, 2 successes = 67% (below 90% threshold)
        // With 3 targets, 3 successes = 100% (meets 90% threshold)
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("success-rate-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-rate", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-rate.zip")
        let codexRoot = temp.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = temp.appendingPathComponent("claude", isDirectory: true)
        let copilotBadRoot = temp.appendingPathComponent("copilot-bad")

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: claudeRoot, withIntermediateDirectories: true)
        try "not a dir".write(to: copilotBadRoot, atomically: true, encoding: .utf8)
        try """
        ---
        name: rate-test
        description: Success rate test
        ---
        # Rate Test
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-rate",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let installer = MultiTargetSkillInstaller()

        let outcome = try await installer.install(
            archiveURL: archiveURL,
            targets: [
                .codex(codexRoot),
                .claude(claudeRoot),
                .copilot(copilotBadRoot)
            ],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        // Rollback forces 0% success rate on any failure
        let totalAttempts = outcome.successes.count + outcome.failures.count
        let successRate = totalAttempts == 0 ? 0 : Double(outcome.successes.count) / Double(totalAttempts) * 100

        XCTAssertEqual(successRate, 0, accuracy: 0.1)
        XCTAssertTrue(outcome.didRollback)
        XCTAssertTrue(outcome.successes.isEmpty)
        XCTAssertEqual(outcome.failures.count, 3)
    }

    func testHighSuccessRate() async throws {
        // All targets should succeed = 100% (meets 90% threshold)
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("high-rate-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-high", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-high.zip")
        let codexRoot = temp.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = temp.appendingPathComponent("claude", isDirectory: true)
        let copilotRoot = temp.appendingPathComponent("copilot", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: claudeRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: copilotRoot, withIntermediateDirectories: true)
        try """
        ---
        name: high-rate
        description: High success rate test
        ---
        # High Rate
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "skill-high",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let installer = MultiTargetSkillInstaller()

        let outcome = try await installer.install(
            archiveURL: archiveURL,
            targets: [
                .codex(codexRoot),
                .claude(claudeRoot),
                .copilot(copilotRoot)
            ],
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        // Calculate success rate
        let totalAttempts = outcome.successes.count + outcome.failures.count
        let successRate = Double(outcome.successes.count) / Double(totalAttempts) * 100

        // 3 out of 3 = 100%, which meets the 90% threshold
        XCTAssertEqual(successRate, 100.0)
        XCTAssertGreaterThanOrEqual(successRate, 90.0, "Success rate should meet 90% threshold")
    }
}
