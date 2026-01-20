import XCTest
import CryptoKit
@testable import SkillsCore

final class SkillsCoreTests: XCTestCase {
    func testFrontmatterParsing() {
        let text = """
        ---
        name: sample
        description: something
        ---
        body
        """
        let parsed = FrontmatterParser.parseTopBlock(text)
        XCTAssertEqual(parsed["name"], "sample")
        XCTAssertEqual(parsed["description"], "something")
    }

    func testValidatorCodexValidHasNoErrors() throws {
        let file = fixture("codex-valid/codex-valid.md")
        let doc = try XCTUnwrap(SkillLoader.load(agent: .codex, rootURL: file.deletingLastPathComponent().deletingLastPathComponent(), skillFileURL: file))
        let findings = SkillValidator.validate(doc: doc)
        XCTAssertFalse(findings.contains { $0.severity == .error })
    }

    func testValidatorMissingFrontmatterErrors() throws {
        let file = fixture("missing-frontmatter/missing-frontmatter.md")
        let doc = try XCTUnwrap(SkillLoader.load(agent: .codex, rootURL: file.deletingLastPathComponent().deletingLastPathComponent(), skillFileURL: file))
        let findings = SkillValidator.validate(doc: doc)
        XCTAssertTrue(findings.contains { $0.ruleID == "frontmatter.missing" })
    }

    func testValidatorClaudeNamePattern() throws {
        let file = fixture("claude-invalid-name/claude-invalid-name.md")
        let doc = try XCTUnwrap(SkillLoader.load(agent: .claude, rootURL: file.deletingLastPathComponent().deletingLastPathComponent(), skillFileURL: file))
        let findings = SkillValidator.validate(doc: doc)
        XCTAssertTrue(findings.contains { $0.ruleID == "claude.name.pattern" })
    }

    func testSyncCheckerDetectsDifference() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let codexRoot = temp.appendingPathComponent(".codex/skills/example", isDirectory: true)
        let claudeRoot = temp.appendingPathComponent(".claude/skills/example", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        let codexFile = codexRoot.appendingPathComponent("SKILL.md")
        let claudeFile = claudeRoot.appendingPathComponent("SKILL.md")

        try """
        ---
        name: example
        description: one
        ---
        """.write(to: codexFile, atomically: true, encoding: .utf8)

        try """
        ---
        name: example
        description: two
        ---
        """.write(to: claudeFile, atomically: true, encoding: .utf8)

        let report = SyncChecker.byName(
            codexRoot: codexFile.deletingLastPathComponent().deletingLastPathComponent(),
            claudeRoot: claudeFile.deletingLastPathComponent().deletingLastPathComponent()
        )

        XCTAssertEqual(report.differentContent, ["example"])
    }

    func testRecursiveScanFindsNested() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = temp.appendingPathComponent("deep/inner", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let skill = nested.appendingPathComponent("SKILL.md")
        try """
        ---
        name: nested-skill
        description: nested example
        ---
        """.write(to: skill, atomically: true, encoding: .utf8)

        let scanRoot = ScanRoot(agent: .codex, rootURL: temp, recursive: true)
        let files = SkillsScanner.findSkillFiles(roots: [scanRoot], excludeDirNames: [".git"], excludeGlobs: [])
        XCTAssertEqual(files[scanRoot]?.count, 1)
        try? FileManager.default.removeItem(at: temp)
    }

    func testPathValidatorRejectsTraversal() {
        let result = PathValidator.validatedDirectory(from: "/tmp/../etc")
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .traversal)
        default:
            XCTFail("Expected traversal failure")
        }
    }

    func testPathValidatorRejectsNotDirectory() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "hi".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let result = PathValidator.validatedDirectory(from: tempFile.path)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .notDirectory)
        default:
            XCTFail("Expected notDirectory failure")
        }
    }

    func testPathValidatorEmpty() {
        let result = PathValidator.validatedDirectory(from: "   ")
        if case .failure(let error) = result {
            XCTAssertEqual(error, .empty)
        } else {
            XCTFail("Expected empty failure")
        }
    }

    func testCodexSkillManagerRootScans() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("csm-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("example", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        try """
        ---
        name: csm-example
        description: example
        ---
        """.write(to: skillFile, atomically: true, encoding: .utf8)

        let root = ScanRoot(agent: .codexSkillManager, rootURL: temp, recursive: false)
        let files = SkillsScanner.findSkillFiles(roots: [root], excludeDirNames: [".git"], excludeGlobs: [])
        XCTAssertEqual(files[root]?.count, 1)
        try? FileManager.default.removeItem(at: temp)
    }

    private func fixture(_ relative: String) -> URL {
        let file = URL(fileURLWithPath: relative).lastPathComponent
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: file).pathExtension
        guard let url = Bundle.module.url(forResource: name, withExtension: ext.isEmpty ? nil : ext) else {
            fatalError("Missing fixture \(relative)")
        }
        return url
    }

    // MARK: - Pinned Publishing Tests

    func testPinnedToolHasCorrectVersion() {
        XCTAssertEqual(PinnedTool.version, "0.1.0")
    }

    func testPinnedToolHasCorrectIntegrityHash() {
        XCTAssertEqual(PinnedTool.integritySHA512, "LZ0mRf61F5SjgprrMwgyLRqMOKxC5sQZYF1tZGgZCawiaVfb79A8cp0Fl32/JNRqiRI7TB0/EuPJPMJ4evmK0g==")
    }

    func testPinnedToolHasCorrectName() {
        XCTAssertEqual(PinnedTool.toolName, "clawdhub")
    }

    func testPinnedToolCreatesValidToolConfig() {
        let toolPath = URL(fileURLWithPath: "/usr/bin/false")
        let config = PinnedTool.toolConfig(toolPath: toolPath)

        XCTAssertEqual(config.toolPath, toolPath)
        XCTAssertEqual(config.toolName, "clawdhub")
        XCTAssertNil(config.expectedSHA256)
        XCTAssertEqual(config.expectedSHA512, PinnedTool.integritySHA512)
        XCTAssertEqual(config.arguments, ["publish", "--artifact", "{artifact}", "--attestation", "{attestation}"])
    }

    func testDeterministicZipProducesSameHash() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("deterministic-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("test-skill", isDirectory: true)
        let output1 = temp.appendingPathComponent("output1.zip")
        let output2 = temp.appendingPathComponent("output2.zip")

        defer { try? fm.removeItem(at: temp) }

        // Create test skill directory with consistent content
        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try """
        ---
        name: test-skill
        version: 1.0.0
        description: Test skill for deterministic zip
        ---

        # Test Skill

        This is a test skill.
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Create two zips using zip command directly
        let process1 = Process()
        process1.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process1.currentDirectoryURL = temp
        process1.arguments = ["-X", "-q", "-r", output1.lastPathComponent, skillDir.lastPathComponent]
        try process1.run()
        process1.waitUntilExit()
        XCTAssertEqual(process1.terminationStatus, 0)

        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process2.currentDirectoryURL = temp
        process2.arguments = ["-X", "-q", "-r", output2.lastPathComponent, skillDir.lastPathComponent]
        try process2.run()
        process2.waitUntilExit()
        XCTAssertEqual(process2.terminationStatus, 0)

        // Verify they have the same hash
        let publisher = SkillPublisher()
        let hash1 = try publisher.sha256Hex(of: output1)
        let hash2 = try publisher.sha256Hex(of: output2)

        XCTAssertEqual(hash1, hash2, "Deterministic zips should produce identical hashes")
    }

    func testToolValidationRejectsMismatchedHash() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        // Create a fake tool
        try "fake tool content".write(to: temp, atomically: true, encoding: .utf8)

        let config = SkillPublisher.ToolConfig(
            toolPath: temp,
            toolName: "test-tool",
            expectedSHA256: String(repeating: "0", count: 64), // Wrong hash
            expectedSHA512: nil,
            arguments: []
        )

        let publisher = SkillPublisher()

        do {
            try publisher.validateToolForTesting(config)
            XCTFail("Expected toolHashMismatch")
        } catch SkillPublisher.PublishError.toolHashMismatch {
            // Expected
        } catch {
            XCTFail("Expected PublishError.toolHashMismatch, got \(error)")
        }
    }

    func testToolValidationAcceptsCorrectHash() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("tool-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        // Create a fake tool
        try "fake tool content".write(to: temp, atomically: true, encoding: .utf8)

        // Calculate correct hash
        let publisher = SkillPublisher()
        let correctHash = try publisher.sha256Hex(of: temp)

        let config = SkillPublisher.ToolConfig(
            toolPath: temp,
            toolName: "test-tool",
            expectedSHA256: correctHash,
            expectedSHA512: nil,
            arguments: []
        )

        // Should not throw
        try publisher.validateToolForTesting(config)
    }

    func testToolValidationFailsForNonexistentFile() {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString)")

        let config = SkillPublisher.ToolConfig(
            toolPath: temp,
            toolName: "test-tool",
            expectedSHA256: nil,
            expectedSHA512: nil,
            arguments: []
        )

        let publisher = SkillPublisher()

        do {
            try publisher.validateToolForTesting(config)
            XCTFail("Expected invalidTool error")
        } catch SkillPublisher.PublishError.invalidTool {
            // Expected
        } catch {
            XCTFail("Expected PublishError.invalidTool, got \(error)")
        }
    }

    func testAttestationContainsToolHash() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("attestation-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("test-skill", isDirectory: true)
        let artifact = temp.appendingPathComponent("artifact.zip")

        defer { try? fm.removeItem(at: temp) }

        // Create test skill
        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try """
        ---
        name: test-skill
        version: 1.0.0
        ---
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Create artifact
        try "artifact content".write(to: artifact, atomically: true, encoding: .utf8)

        // Create signing key
        let privateKey = Curve25519.Signing.PrivateKey()
        let signingKey = SkillPublisher.SigningKey(privateKey: privateKey)

        // Create tool config
        let toolPath = URL(fileURLWithPath: "/usr/bin/true") // Use an existing executable
        let toolConfig = SkillPublisher.ToolConfig(
            toolPath: toolPath,
            toolName: "test-tool",
            expectedSHA256: nil,
            expectedSHA512: nil,
            arguments: []
        )

        // Create attestation
        let publisher = SkillPublisher()
        let result = try publisher.signAttestationForTesting(
            skillDirectory: skillDir,
            artifactURL: artifact,
            tool: toolConfig,
            signingKey: signingKey
        )

        // Verify attestation contains tool hash
        XCTAssertNotNil(result.toolHash)
        XCTAssertFalse(result.toolHash.isEmpty)

        // Verify other fields
        XCTAssertEqual(result.skillName, "test-skill")
        XCTAssertEqual(result.version, "1.0.0")
        XCTAssertEqual(result.toolName, "test-tool")
        XCTAssertEqual(result.signatureAlgorithm, "ed25519")
        XCTAssertFalse(result.signature.isEmpty)
    }

    func testDryRunDoesNotInvokeTool() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("dryrun-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("test-skill", isDirectory: true)
        let output = temp.appendingPathComponent("output.zip")
        let attestation = temp.appendingPathComponent("attestation.json")

        defer { try? fm.removeItem(at: temp) }

        // Create test skill
        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try """
        ---
        name: test-skill
        version: 1.0.0
        ---
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Create signing key
        let privateKey = Curve25519.Signing.PrivateKey()
        let signingKey = SkillPublisher.SigningKey(privateKey: privateKey)

        // Create tool config with a tool that would fail if invoked
        let toolPath = URL(fileURLWithPath: "/usr/bin/false")
        let toolConfig = SkillPublisher.ToolConfig(
            toolPath: toolPath,
            toolName: "false",
            expectedSHA256: nil,
            expectedSHA512: nil,
            arguments: [] // No arguments - tool should not be invoked
        )

        // Build with dry-run - should not invoke the tool
        let publisher = SkillPublisher()
        let result = try publisher.buildOnly(
            skillDirectory: skillDir,
            outputURL: output,
            attestationURL: attestation,
            tool: toolConfig,
            signingKey: signingKey
        )

        // Verify outputs were created
        XCTAssertTrue(fm.fileExists(atPath: output.path), "Artifact should be created")
        XCTAssertTrue(fm.fileExists(atPath: attestation.path), "Attestation should be created")
        XCTAssertEqual(result.artifactURL, output)
        XCTAssertEqual(result.attestationURL, attestation)
        XCTAssertFalse(result.artifactSHA256.isEmpty)
    }

    // MARK: - Telemetry Tests

    func testTelemetryEventVerifiedInstall() {
        let event = TelemetryEvent.verifiedInstall(
            skillSlug: "test-skill",
            version: "1.0.0",
            installerId: "abc123"
        )

        XCTAssertEqual(event.name, "verified_install")
        XCTAssertEqual(event.attributes["skill_slug"], "test-skill")
        XCTAssertEqual(event.attributes["version"], "1.0.0")
        XCTAssertEqual(event.attributes["installer_id"], "abc123")
    }

    func testTelemetryEventBlockedDownload() {
        let event = TelemetryEvent.blockedDownload(
            skillSlug: "blocked-skill",
            reason: "size_exceeded",
            installerId: "abc123"
        )

        XCTAssertEqual(event.name, "blocked_download")
        XCTAssertEqual(event.attributes["skill_slug"], "blocked-skill")
        XCTAssertEqual(event.attributes["reason"], "size_exceeded")
        XCTAssertEqual(event.attributes["installer_id"], "abc123")
    }

    func testTelemetryEventPublishRun() {
        let event = TelemetryEvent.publishRun(
            skillSlug: "my-skill",
            version: "2.0.0",
            success: true,
            publisherId: "xyz789"
        )

        XCTAssertEqual(event.name, "publish_run")
        XCTAssertEqual(event.attributes["skill_slug"], "my-skill")
        XCTAssertEqual(event.attributes["version"], "2.0.0")
        XCTAssertEqual(event.attributes["success"], "true")
        XCTAssertEqual(event.attributes["publisher_id"], "xyz789")
    }

    func testTelemetryStoreFilePersistence() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("telemetry-\(UUID().uuidString).jsonl")
        defer { try? fm.removeItem(at: temp) }

        let store = TelemetryStore.file(url: temp, retentionDays: 30)

        // Record some events
        store.record(.verifiedInstall(skillSlug: "skill1", version: "1.0.0", installerId: "test"))
        store.record(.blockedDownload(skillSlug: "skill2", reason: "size", installerId: "test"))
        store.record(.publishRun(skillSlug: "skill1", version: "1.0.0", success: true, publisherId: "test"))

        // Verify events are persisted
        XCTAssertTrue(fm.fileExists(atPath: temp.path))

        let events = store.getEvents()
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].name, "verified_install")
        XCTAssertEqual(events[1].name, "blocked_download")
        XCTAssertEqual(events[2].name, "publish_run")
    }

    func testTelemetryStoreClearsOldData() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("telemetry-\(UUID().uuidString).jsonl")
        defer { try? fm.removeItem(at: temp) }

        // Create store with 1 day retention
        let store = TelemetryStore.file(url: temp, retentionDays: 1)

        // Create an old event (2 days ago)
        let oldEvent = TelemetryEvent(
            name: "test_event",
            timestamp: Date().addingTimeInterval(-2 * 24 * 60 * 60), // 2 days ago
            attributes: ["test": "old"]
        )

        // Write the old event directly to file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(oldEvent)
        if let line = String(data: data, encoding: .utf8) {
            try (line + "\n").write(to: temp, atomically: true, encoding: .utf8)
        }

        // Create a new event
        store.record(.verifiedInstall(skillSlug: "new-skill", version: "1.0.0", installerId: "test"))

        // Get events should only return the new one
        let events = store.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, "verified_install")
        XCTAssertEqual(events[0].attributes["skill_slug"], "new-skill")
    }

    func testTelemetryStoreClear() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("telemetry-\(UUID().uuidString).jsonl")
        defer { try? fm.removeItem(at: temp) }

        let store = TelemetryStore.file(url: temp, retentionDays: 30)

        // Record some events
        store.record(.verifiedInstall(skillSlug: "skill1", version: "1.0.0", installerId: "test"))
        store.record(.blockedDownload(skillSlug: "skill2", reason: "size", installerId: "test"))

        XCTAssertTrue(fm.fileExists(atPath: temp.path))

        // Clear the store
        store.clear()

        // File should be deleted
        XCTAssertFalse(fm.fileExists(atPath: temp.path))
    }

    func testTelemetryCountsFromEvents() {
        let events: [TelemetryEvent] = [
            .verifiedInstall(skillSlug: "s1", version: "1.0.0", installerId: "test"),
            .verifiedInstall(skillSlug: "s2", version: "1.0.0", installerId: "test"),
            .blockedDownload(skillSlug: "s3", reason: "size", installerId: "test"),
            .publishRun(skillSlug: "s1", version: "2.0.0", success: true, publisherId: "test"),
            .publishRun(skillSlug: "s1", version: "2.0.0", success: false, publisherId: "test")
        ]

        let counts = TelemetryCounts.from(events: events)

        XCTAssertEqual(counts.verifiedInstalls, 2)
        XCTAssertEqual(counts.blockedDownloads, 1)
        XCTAssertEqual(counts.publishRuns, 2)
    }

    func testInstallerIdIsPersistent() {
        // Clear any existing installer ID
        UserDefaults.standard.removeObject(forKey: "stools_installer_id")

        let id1 = InstallerId.getOrCreate()
        let id2 = InstallerId.getOrCreate()

        XCTAssertEqual(id1, id2, "Installer ID should be the same across calls")
        XCTAssertEqual(id1.count, 8, "Installer ID should be 8 characters")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "stools_installer_id")
    }

    func testPathRedactorRedactsHomeDirectory() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let message = "Error loading \(homePath)/.codex/skills/myskill/SKILL.md"

        let redacted = PathRedactor.redact(message)

        XCTAssertTrue(redacted.contains("~"), "Should redact home directory with ~")
        XCTAssertFalse(redacted.contains(homePath), "Should not contain original home path")
    }

    func testPathRedactorRedactsUsernames() {
        let message = "Install failed for /Users/john Doe/.codex/skills/myskill"
        let message2 = "Install failed for /Users/admin/.codex/skills/other"

        let redacted1 = PathRedactor.redact(message)
        let redacted2 = PathRedactor.redact(message2)

        XCTAssertTrue(redacted1.contains("[REDACTED]"), "Should redact username")
        XCTAssertTrue(redacted2.contains("[REDACTED]"), "Should redact username")
        XCTAssertFalse(redacted1.contains("john Doe"), "Should not contain original username")
        XCTAssertFalse(redacted2.contains("admin"), "Should not contain original username")
    }

    func testPathRedactorRedactsUUIDs() {
        let message = "Processing file with ID 550e8400-e29b-41d4-a716-446655440000"

        let redacted = PathRedactor.redact(message)

        XCTAssertTrue(redacted.contains("[UUID-REDACTED]"), "Should redact UUID")
        XCTAssertFalse(redacted.contains("550e8400"), "Should not contain original UUID")
    }

    func testTelemetryEventCodable() throws {
        let event = TelemetryEvent.verifiedInstall(
            skillSlug: "test-skill",
            version: "1.0.0",
            installerId: "abc123"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TelemetryEvent.self, from: data)

        XCTAssertEqual(decoded.name, event.name)
        XCTAssertEqual(decoded.attributes, event.attributes)
        XCTAssertEqual(decoded.attributes["skill_slug"], "test-skill")
        XCTAssertEqual(decoded.attributes["version"], "1.0.0")
        XCTAssertEqual(decoded.attributes["installer_id"], "abc123")
    }
}

// MARK: - Testing Extensions for Publisher

extension SkillPublisher {
    /// Testing helper to validate tool
    func validateToolForTesting(_ tool: ToolConfig) throws {
        guard FileManager.default.isReadableFile(atPath: tool.toolPath.path) else {
            throw PublishError.invalidTool
        }
        let toolSHA256 = try sha256Hex(of: tool.toolPath)
        if let expected = tool.expectedSHA256, expected.lowercased() != toolSHA256.lowercased() {
            throw PublishError.toolHashMismatch
        }
        if let expected512 = tool.expectedSHA512, try expected512.lowercased() != sha512Hex(of: tool.toolPath).lowercased() {
            throw PublishError.toolHashMismatch
        }
    }

    /// Testing helper to sign attestation
    func signAttestationForTesting(
        skillDirectory: URL,
        artifactURL: URL,
        tool: ToolConfig,
        signingKey: SigningKey
    ) throws -> PublishAttestation {
        let skillName = skillDirectory.lastPathComponent
        let version = readSkillVersionForTesting(skillDirectory)
        let artifactSHA256 = try sha256Hex(of: artifactURL)
        let payload = PublishAttestationPayload(
            schemaVersion: 1,
            skillName: skillName,
            version: version,
            artifactSHA256: artifactSHA256,
            toolName: tool.toolName,
            toolHash: try sha256Hex(of: tool.toolPath),
            builtAt: ISO8601DateFormatter().string(from: Date())
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let signature = try signingKey.privateKey.signature(for: data).base64EncodedString()
        return PublishAttestation(
            schemaVersion: 1,
            skillName: payload.skillName,
            version: payload.version,
            artifactSHA256: payload.artifactSHA256,
            toolName: payload.toolName,
            toolHash: payload.toolHash,
            builtAt: payload.builtAt,
            signatureAlgorithm: "ed25519",
            signature: signature
        )
    }

    /// Testing helper to read skill version
    func readSkillVersionForTesting(_ skillDirectory: URL) -> String? {
        let skillFile = skillDirectory.appendingPathComponent("SKILL.md")
        guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let frontmatter = FrontmatterParser.parseTopBlock(text)
        return frontmatter["version"]
    }
}

// MARK: - FeatureFlags Tests

final class FeatureFlagsTests: XCTestCase {
    // MARK: - Config-based Feature Flags

    func testFeatureFlagsFromConfigWithAllFlags() throws {
        let config = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: SkillsConfig.FeatureFlagsConfig(
                skillVerification: false,
                pinnedPublishing: false,
                crossIDEAdapters: false,
                telemetryOptIn: true,
                bulkActions: false
            )
        )

        let flags = FeatureFlags.fromConfig(config)

        XCTAssertEqual(flags.skillVerification, false)
        XCTAssertEqual(flags.pinnedPublishing, false)
        XCTAssertEqual(flags.crossIDEAdapters, false)
        XCTAssertEqual(flags.telemetryOptIn, true)
        XCTAssertEqual(flags.bulkActions, false)
    }

    func testFeatureFlagsFromConfigWithPartialFlags() throws {
        let config = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: SkillsConfig.FeatureFlagsConfig(
                skillVerification: false,
                pinnedPublishing: nil,
                crossIDEAdapters: nil,
                telemetryOptIn: nil,
                bulkActions: nil
            )
        )

        let flags = FeatureFlags.fromConfig(config)

        XCTAssertEqual(flags.skillVerification, false)
        XCTAssertEqual(flags.pinnedPublishing, true) // default
        XCTAssertEqual(flags.crossIDEAdapters, true) // default
        XCTAssertEqual(flags.telemetryOptIn, false) // default
        XCTAssertEqual(flags.bulkActions, true) // default
    }

    func testFeatureFlagsFromConfigWithNoFlags() throws {
        let config = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: nil
        )

        let flags = FeatureFlags.fromConfig(config)

        XCTAssertEqual(flags.skillVerification, true) // default
        XCTAssertEqual(flags.pinnedPublishing, true) // default
        XCTAssertEqual(flags.crossIDEAdapters, true) // default
        XCTAssertEqual(flags.telemetryOptIn, false) // default
        XCTAssertEqual(flags.bulkActions, true) // default
    }

    func testFeatureFlagsEnvironmentOverridesConfig() throws {
        let config = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: SkillsConfig.FeatureFlagsConfig(
                skillVerification: false,
                pinnedPublishing: false,
                crossIDEAdapters: false,
                telemetryOptIn: false,
                bulkActions: false
            )
        )

        let env = [
            "STOOLS_FEATURE_VERIFICATION": "true",
            "STOOLS_FEATURE_PUBLISHING": "true",
            "STOOLS_FEATURE_ADAPTERS": "true",
            "STOOLS_FEATURE_BULK_ACTIONS": "true"
        ]

        let flags = FeatureFlags.fromConfig(config, env: env)

        XCTAssertEqual(flags.skillVerification, true) // env override
        XCTAssertEqual(flags.pinnedPublishing, true) // env override
        XCTAssertEqual(flags.crossIDEAdapters, true) // env override
        XCTAssertEqual(flags.telemetryOptIn, false) // config value
        XCTAssertEqual(flags.bulkActions, true) // env override
    }

    func testFeatureFlagsEmptyConfig() throws {
        let config = SkillsConfig()

        let flags = FeatureFlags.fromConfig(config)

        XCTAssertEqual(flags.skillVerification, true) // default
        XCTAssertEqual(flags.pinnedPublishing, true) // default
        XCTAssertEqual(flags.crossIDEAdapters, true) // default
        XCTAssertEqual(flags.telemetryOptIn, false) // default
        XCTAssertEqual(flags.bulkActions, true) // default
    }

    // MARK: - Config JSON Encoding/Decoding

    func testFeatureFlagsConfigCodableRoundTrip() throws {
        let original = SkillsConfig.FeatureFlagsConfig(
            skillVerification: true,
            pinnedPublishing: false,
            crossIDEAdapters: true,
            telemetryOptIn: false,
            bulkActions: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SkillsConfig.FeatureFlagsConfig.self, from: data)

        XCTAssertEqual(decoded.skillVerification, original.skillVerification)
        XCTAssertEqual(decoded.pinnedPublishing, original.pinnedPublishing)
        XCTAssertEqual(decoded.crossIDEAdapters, original.crossIDEAdapters)
        XCTAssertEqual(decoded.telemetryOptIn, original.telemetryOptIn)
        XCTAssertEqual(decoded.bulkActions, original.bulkActions)
    }

    func testSkillsConfigWithFeatureFlagsCodable() throws {
        let original = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: SkillsConfig.FeatureFlagsConfig(
                skillVerification: true,
                pinnedPublishing: true,
                crossIDEAdapters: false,
                telemetryOptIn: true,
                bulkActions: false
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SkillsConfig.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertNotNil(decoded.features)
        XCTAssertEqual(decoded.features?.skillVerification, true)
        XCTAssertEqual(decoded.features?.pinnedPublishing, true)
        XCTAssertEqual(decoded.features?.crossIDEAdapters, false)
        XCTAssertEqual(decoded.features?.telemetryOptIn, true)
        XCTAssertEqual(decoded.features?.bulkActions, false)
    }

    func testFeatureFlagsFromConfigWithPartialNilValues() throws {
        // Test that nil values in config use defaults correctly
        let config = SkillsConfig(
            schemaVersion: 1,
            scan: nil,
            excludes: nil,
            excludeGlobs: nil,
            policy: nil,
            sync: nil,
            features: SkillsConfig.FeatureFlagsConfig(
                skillVerification: nil,
                pinnedPublishing: nil,
                crossIDEAdapters: nil,
                telemetryOptIn: nil,
                bulkActions: nil
            )
        )

        let flags = FeatureFlags.fromConfig(config)

        // All should use defaults when nil
        XCTAssertEqual(flags.skillVerification, true)
        XCTAssertEqual(flags.pinnedPublishing, true)
        XCTAssertEqual(flags.crossIDEAdapters, true)
        XCTAssertEqual(flags.telemetryOptIn, false)
        XCTAssertEqual(flags.bulkActions, true)
    }
}
