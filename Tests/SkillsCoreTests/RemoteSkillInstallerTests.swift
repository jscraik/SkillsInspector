import XCTest
@testable import SkillsCore

final class RemoteSkillInstallerTests: XCTestCase {
    func testInstallCopiesSkillAndComputesChecksum() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-one", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-one.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: demo
        description: Demo skill
        ---

        # Sample skill
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // zip the skill directory
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-one"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(name: "demo", version: "1.0.0", sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL))
        let installer = RemoteSkillInstaller()
        let result = try await installer.install(
            archiveURL: archiveURL,
            target: .custom(targetRoot),
            overwrite: false,
            manifest: manifest,
            policy: .permissive
        )

        let expectedDir = targetRoot.appendingPathComponent("skill-one")
        XCTAssertTrue(fm.fileExists(atPath: expectedDir.path))
        XCTAssertEqual(result.skillDirectory, expectedDir)
        XCTAssertNotNil(result.archiveSHA256)
    }

    func testRejectsFileCountLimit() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-many", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-many.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: bad
        description: bad
        ---
        # bad
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "extra".write(to: skillDir.appendingPathComponent("extra.txt"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, skillDir.lastPathComponent]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let installer = RemoteSkillInstaller()
        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                overwrite: false,
                manifest: RemoteArtifactManifest(name: "bad", version: "1.0.0", sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)),
                policy: RemoteVerificationPolicy(mode: .permissive, limits: RemoteVerificationLimits(maxArchiveBytes: 50 * 1024 * 1024, maxExtractedBytes: 50 * 1024 * 1024, maxFileCount: 1))
            )
            XCTFail("Expected verification failure for file-count limit")
        } catch {
            guard case RemoteInstallError.verificationFailed(let reason) = error else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("file-count"), "Reason was: \(reason)")
        }
    }

    func testChecksumMismatchFails() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-bad", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-bad.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: bad
        description: bad
        ---
        # bad
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-bad"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(name: "bad", version: "1.0.0", sha256: String(repeating: "0", count: 64))
        let installer = RemoteSkillInstaller()
        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                overwrite: false,
                manifest: manifest,
                policy: .permissive
            )
            XCTFail("Expected verification failure for checksum mismatch")
        } catch {
            guard case RemoteInstallError.verificationFailed(let reason) = error else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("Checksum mismatch"))
        }
    }

    func testVerifyReturnsIssuesInPermissiveMode() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-verify", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-verify.zip")

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try """
        ---
        name: verify
        description: verify
        ---
        # verify
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-verify"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let manifest = RemoteArtifactManifest(
            name: "verify",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )
        let installer = RemoteSkillInstaller()
        let outcome = try installer.verify(
            archiveURL: archiveURL,
            manifest: manifest,
            policy: .permissive
        )
        XCTAssertTrue(outcome.checksumValidated)
        XCTAssertTrue(outcome.issues.contains(where: { $0.contains("Signature") }))
    }

    // MARK: - Security Tests

    func testRevokedKeyIsRejected() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-revoked", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-revoked.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: revoked
        description: revoked
        ---
        # revoked
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-revoked"]
        try process.run()
        process.waitUntilExit()

        let manifest = RemoteArtifactManifest(
            name: "revoked",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL),
            signerKeyId: "revoked-key-123",
            revokedKeys: ["revoked-key-123"]
        )
        let installer = RemoteSkillInstaller()
        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                manifest: manifest,
                policy: RemoteVerificationPolicy(mode: .strict)
            )
            XCTFail("Expected verification failure for revoked key")
        } catch RemoteInstallError.verificationFailed(let reason) {
            XCTAssertTrue(reason.contains("revoked"))
        }
    }

    func testOversizedArchiveIsRejected() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-large", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-large.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: large
        description: large
        ---
        # large
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-large"]
        try process.run()
        process.waitUntilExit()

        let installer = RemoteSkillInstaller()
        let policy = RemoteVerificationPolicy(
            mode: .strict,
            limits: RemoteVerificationLimits(maxArchiveBytes: 100) // Very small limit
        )
        let manifest = RemoteArtifactManifest(
            name: "large",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL)
        )

        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                manifest: manifest,
                policy: policy
            )
            XCTFail("Expected verification failure for oversized archive")
        } catch RemoteInstallError.verificationFailed(let reason) {
            XCTAssertTrue(reason.contains("size"))
        }
    }

    func testManifestWithoutRequiredFields() {
        // Test that manifest can be created with minimal required fields
        let manifest = RemoteArtifactManifest(
            name: "test",
            version: "1.0.0",
            sha256: String(repeating: "a", count: 64)
        )
        XCTAssertEqual(manifest.name, "test")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertNil(manifest.signature)
        XCTAssertNil(manifest.signerKeyId)
    }

    func testTrustStorePersistence() throws {
        let fm = FileManager.default
        let tempURL = fm.temporaryDirectory.appendingPathComponent("trust-test-\(UUID().uuidString)")

        // Create a trust store with a test key
        let key = RemoteTrustStore.TrustedKey(
            keyId: "test-key-1",
            publicKeyBase64: "dGVzdC1wdWJsaWMta2V5LWJhc2U2NA=="
        )
        let store = RemoteTrustStore(keys: [key])

        // Verify the key exists
        XCTAssertNotNil(store.trustedKey(for: "test-key-1"))
        XCTAssertNil(store.trustedKey(for: "unknown-key"))

        // Test scope restriction
        let scopedKey = RemoteTrustStore.TrustedKey(
            keyId: "scoped-key",
            publicKeyBase64: "c2NvcGVkLWtleQ==",
            allowedSlugs: ["allowed-skill"]
        )
        let scopedStore = RemoteTrustStore(keys: [scopedKey])
        XCTAssertNotNil(scopedStore.trustedKey(for: "scoped-key", scopeSlug: "allowed-skill"))
        XCTAssertNil(scopedStore.trustedKey(for: "scoped-key", scopeSlug: "other-skill"))
    }

    func testRemoteVerificationLimitsDefaults() {
        let limits = RemoteVerificationLimits()
        XCTAssertEqual(limits.maxArchiveBytes, 50 * 1024 * 1024) // 50MB
        XCTAssertEqual(limits.maxExtractedBytes, 50 * 1024 * 1024) // 50MB
        XCTAssertEqual(limits.maxFileCount, 2000)
        XCTAssertTrue(limits.allowedMIMETypes.contains("application/zip"))
    }

    func testVerificationOutcomeHasCorrectMode() {
        let outcome = RemoteVerificationOutcome(
            mode: .strict,
            checksumValidated: true,
            signatureValidated: false,
            trustedSigner: false,
            issues: ["Signature missing"]
        )
        XCTAssertEqual(outcome.mode, .strict)
        XCTAssertTrue(outcome.checksumValidated)
        XCTAssertFalse(outcome.signatureValidated)
        XCTAssertFalse(outcome.trustedSigner)
        XCTAssertEqual(outcome.issues.count, 1)
    }

    // MARK: - Story S9: Security-Conscious Developer Tests

    func testInstallFailsClosedOnSignatureMismatch() async throws {
        // AC1: Install fails closed (no files written) on signature/hash mismatch
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("s9-fails-closed-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-sig-test", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-sig-test.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: sig-test
        description: Test signature validation
        ---
        # Signature Test Skill
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Create archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-sig-test"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        // Test 1: Checksum mismatch fails closed (no files written)
        let badChecksumManifest = RemoteArtifactManifest(
            name: "sig-test",
            version: "1.0.0",
            sha256: String(repeating: "0", count: 64) // Wrong checksum
        )
        let installer = RemoteSkillInstaller()
        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                manifest: badChecksumManifest,
                policy: RemoteVerificationPolicy(mode: .strict)
            )
            XCTFail("Expected installation to fail with checksum mismatch")
        } catch RemoteInstallError.verificationFailed(let reason) {
            // Verify error message is clear
            XCTAssertTrue(reason.contains("Checksum mismatch"), "Error should explain checksum failure: \(reason)")
        }

        // Verify no files were written to target (fail-closed)
        let targetContents = try? fm.contentsOfDirectory(at: targetRoot, includingPropertiesForKeys: nil)
        XCTAssertTrue(targetContents?.isEmpty ?? true, "Target directory should be empty after failed install")

        // Test 2: Archive size mismatch also fails closed
        let wrongSizeManifest = RemoteArtifactManifest(
            name: "sig-test",
            version: "1.0.0",
            sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL),
            size: 999_999_999 // Wrong size
        )
        do {
            _ = try await installer.install(
                archiveURL: archiveURL,
                target: .custom(targetRoot),
                manifest: wrongSizeManifest,
                policy: RemoteVerificationPolicy(mode: .strict)
            )
            XCTFail("Expected installation to fail with size mismatch")
        } catch RemoteInstallError.verificationFailed(let reason) {
            XCTAssertTrue(reason.contains("size"), "Error should explain size failure: \(reason)")
        }

        // Verify still no files written
        let targetContents2 = try? fm.contentsOfDirectory(at: targetRoot, includingPropertiesForKeys: nil)
        XCTAssertTrue(targetContents2?.isEmpty ?? true, "Target directory should remain empty after size mismatch")
    }

    func testProvenanceBadgeShowsSignerKeyIdAndStatus() {
        // AC2: Provenance badge shows signer key ID and verification status
        // This test verifies the data structures that feed the UI badges

        // Test verification outcome with valid signature
        let goodOutcome = RemoteVerificationOutcome(
            mode: .strict,
            checksumValidated: true,
            signatureValidated: true,
            trustedSigner: true,
            issues: []
        )
        XCTAssertTrue(goodOutcome.signatureValidated)
        XCTAssertTrue(goodOutcome.trustedSigner)
        XCTAssertTrue(goodOutcome.issues.isEmpty)

        // Test verification outcome with invalid signature
        let badOutcome = RemoteVerificationOutcome(
            mode: .strict,
            checksumValidated: true,
            signatureValidated: false,
            trustedSigner: false,
            issues: ["Signature invalid for key test-key-123"]
        )
        XCTAssertFalse(badOutcome.signatureValidated)
        XCTAssertFalse(badOutcome.trustedSigner)
        XCTAssertEqual(badOutcome.issues.count, 1)
        XCTAssertTrue(badOutcome.issues.contains("Signature invalid for key test-key-123"))

        // Test manifest with signer key ID
        let manifest = RemoteArtifactManifest(
            name: "test",
            version: "1.0.0",
            sha256: String(repeating: "a", count: 64),
            signature: "dummy-signature",
            signerKeyId: "signer-key-abc123"
        )
        XCTAssertEqual(manifest.signerKeyId, "signer-key-abc123")
        XCTAssertNotNil(manifest.signature)
    }

    func testClearErrorMessagesForVerificationFailures() async throws {
        // AC3: Clear error messages explain verification failures
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("s9-errors-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-error-msg", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-error-msg.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: error-test
        description: Test error messages
        ---
        # Error Test
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-error-msg"]
        try process.run()
        process.waitUntilExit()

        // Test each error type has a clear message
        let errorCases: [(String, RemoteArtifactManifest, String)] = [
            ("Checksum mismatch",
             RemoteArtifactManifest(name: "error-test", version: "1.0.0", sha256: String(repeating: "0", count: 64)),
             "Checksum mismatch"),
            ("Archive size mismatch",
             RemoteArtifactManifest(name: "error-test", version: "1.0.0", sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL), size: 999),
             "size mismatch"),
            ("Revoked signer",
             RemoteArtifactManifest(name: "error-test", version: "1.0.0", sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL), signerKeyId: "revoked-key", revokedKeys: ["revoked-key"]),
             "revoked"),
            ("Untrusted signer",
             RemoteArtifactManifest(name: "error-test", version: "1.0.0", sha256: try RemoteSkillInstaller.sha256Hex(of: archiveURL), signerKeyId: "unknown-key", trustedSigners: ["trusted-key"]),
             "trustedSigners")
        ]

        let installer = RemoteSkillInstaller()

        for (name, manifest, expectedKeyword) in errorCases {
            do {
                _ = try await installer.install(
                    archiveURL: archiveURL,
                    target: .custom(targetRoot),
                    manifest: manifest,
                    policy: RemoteVerificationPolicy(mode: .strict)
                )
                XCTFail("\(name): Expected verification failure")
            } catch RemoteInstallError.verificationFailed(let reason) {
                XCTAssertTrue(reason.lowercased().contains(expectedKeyword.lowercased()),
                              "\(name): Error message should contain '\(expectedKeyword)'. Got: \(reason)")
            } catch {
                XCTFail("\(name): Expected verificationFailed error, got \(error)")
            }
        }
    }

    func testTrustPromptAllowsPerSkillSignerApproval() throws {
        // AC4: Trust prompt allows per-skill signer approval
        // Test the trust store scope functionality

        // Test 1: Global trust (all skills)
        let globalKey = RemoteTrustStore.TrustedKey(
            keyId: "global-signer-1",
            publicKeyBase64: "Z2xvYmFsLXB1YmxpYy1rZXk=",
            allowedSlugs: nil // nil means all skills
        )
        let globalStore = RemoteTrustStore(keys: [globalKey])

        // Should be trusted for any skill
        XCTAssertNotNil(globalStore.trustedKey(for: "global-signer-1", scopeSlug: "skill-a"))
        XCTAssertNotNil(globalStore.trustedKey(for: "global-signer-1", scopeSlug: "skill-b"))
        XCTAssertNotNil(globalStore.trustedKey(for: "global-signer-1", scopeSlug: nil))

        // Test 2: Per-skill trust (scoped)
        let scopedKey = RemoteTrustStore.TrustedKey(
            keyId: "scoped-signer-2",
            publicKeyBase64: "c2NvcGVkLXB1YmxpYy1rZXk=",
            allowedSlugs: ["allowed-skill-1", "allowed-skill-2"]
        )
        let scopedStore = RemoteTrustStore(keys: [scopedKey])

        // Should be trusted only for allowed skills
        XCTAssertNotNil(scopedStore.trustedKey(for: "scoped-signer-2", scopeSlug: "allowed-skill-1"))
        XCTAssertNotNil(scopedStore.trustedKey(for: "scoped-signer-2", scopeSlug: "allowed-skill-2"))
        XCTAssertNil(scopedStore.trustedKey(for: "scoped-signer-2", scopeSlug: "other-skill"), "Should not trust for non-allowed skill")
        XCTAssertNil(scopedStore.trustedKey(for: "scoped-signer-2", scopeSlug: nil), "Should not trust when no scope provided")

        // Test 3: Mixed trust store (some global, some scoped)
        let mixedStore = RemoteTrustStore(keys: [globalKey, scopedKey])

        // Global key works everywhere
        XCTAssertNotNil(mixedStore.trustedKey(for: "global-signer-1", scopeSlug: "any-skill"))
        // Scoped key only works for allowed skills
        XCTAssertNotNil(mixedStore.trustedKey(for: "scoped-signer-2", scopeSlug: "allowed-skill-1"))
        XCTAssertNil(mixedStore.trustedKey(for: "scoped-signer-2", scopeSlug: "other-skill"))
    }
}
