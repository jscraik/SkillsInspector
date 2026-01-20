import XCTest
import SkillsCore

final class SkillLedgerTests: XCTestCase {
    func testLedgerRecordsAndFetchesEvents() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        let input = LedgerEventInput(
            eventType: .install,
            skillName: "Prompt Booster",
            skillSlug: "prompt-booster",
            version: "1.2.0",
            agent: .codex,
            status: .success,
            note: "Installed via test",
            source: "unit-test",
            verification: .strict,
            manifestSHA256: "abc123",
            targetPath: "/tmp/skills/prompt-booster"
        )

        let saved = try await ledger.record(input)
        let fetched = try await ledger.fetchEvents(limit: 10)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, saved.id)
        XCTAssertEqual(fetched.first?.skillName, "Prompt Booster")
        XCTAssertEqual(fetched.first?.eventType, .install)
    }

    func testChangelogGeneratorFormatsEvents() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .update,
                skillName: "Lint Wizard",
                skillSlug: "lint-wizard",
                version: "2.0.0",
                agent: .claude,
                status: .success,
                note: "Updated for release",
                source: nil,
                verification: .strict,
                manifestSHA256: nil,
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            )
        ]
        let markdown = generator.generateAppStoreMarkdown(events: events)
        XCTAssertTrue(markdown.contains("## Changelog"))
        XCTAssertTrue(markdown.contains("Updated Lint Wizard v2.0.0"))
    }

    // MARK: - Story S4: Ledger + Changelog Tests

    func testFetchLastSuccessfulInstallReturnsMostRecent() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Record multiple installs for the same skill
        try await ledger.record(LedgerEventInput(
            eventType: .install,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success
        ))

        try await ledger.record(LedgerEventInput(
            eventType: .update,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "2.0.0",
            agent: .codex,
            status: .success
        ))

        try await ledger.record(LedgerEventInput(
            eventType: .update,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "3.0.0",
            agent: .codex,
            status: .success
        ))

        // Fetch last successful install
        let lastInstall = try await ledger.fetchLastSuccessfulInstall(skillSlug: "test-skill")

        XCTAssertNotNil(lastInstall)
        XCTAssertEqual(lastInstall?.version, "3.0.0")
        XCTAssertEqual(lastInstall?.eventType, .update)
    }

    func testFetchLastSuccessfulInstallIgnoresFailures() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Record a successful install
        try await ledger.record(LedgerEventInput(
            eventType: .install,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success
        ))

        // Record a failed update
        try await ledger.record(LedgerEventInput(
            eventType: .update,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "2.0.0",
            agent: .codex,
            status: .failure,
            note: "Signature verification failed"
        ))

        // Fetch last successful install should return v1.0.0, not v2.0.0
        let lastInstall = try await ledger.fetchLastSuccessfulInstall(skillSlug: "test-skill")

        XCTAssertNotNil(lastInstall)
        XCTAssertEqual(lastInstall?.version, "1.0.0")
        XCTAssertEqual(lastInstall?.status, .success)
    }

    func testFetchLastSuccessfulInstallWithAgentFilter() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Record installs for different agents
        try await ledger.record(LedgerEventInput(
            eventType: .install,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success
        ))

        try await ledger.record(LedgerEventInput(
            eventType: .install,
            skillName: "Test Skill",
            skillSlug: "test-skill",
            version: "2.0.0",
            agent: .claude,
            status: .success
        ))

        // Fetch by agent
        let codexInstall = try await ledger.fetchLastSuccessfulInstall(skillSlug: "test-skill", agent: .codex)
        let claudeInstall = try await ledger.fetchLastSuccessfulInstall(skillSlug: "test-skill", agent: .claude)

        XCTAssertEqual(codexInstall?.version, "1.0.0")
        XCTAssertEqual(claudeInstall?.version, "2.0.0")
    }

    func testChangelogGeneratorPerSkillFilter() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Skill A",
                skillSlug: "skill-a",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: nil,
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .install,
                skillName: "Skill B",
                skillSlug: "skill-b",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: nil,
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            )
        ]

        let skillAChangelog = generator.generatePerSkillMarkdown(
            events: events,
            skillSlug: "skill-a",
            skillName: "Skill A"
        )

        XCTAssertTrue(skillAChangelog.contains("Skill A"))
        XCTAssertFalse(skillAChangelog.contains("Skill B"))
    }

    func testChangelogGeneratorFilteredByEventType() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: nil,
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .remove,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: nil,
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            )
        ]

        let installOnlyChangelog = generator.generateFilteredMarkdown(
            events: events,
            eventTypes: [.install]
        )

        XCTAssertTrue(installOnlyChangelog.contains("Installed"))
        XCTAssertFalse(installOnlyChangelog.contains("Removed"))
    }

    func testLedgerIsAppendOnly() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Record several events
        for i in 1...5 {
            try await ledger.record(LedgerEventInput(
                eventType: .install,
                skillName: "Skill \(i)",
                skillSlug: "skill-\(i)",
                version: "1.0.0",
                agent: .codex,
                status: .success
            ))
        }

        let allEvents = try await ledger.fetchEvents(limit: 100)
        XCTAssertEqual(allEvents.count, 5)

        // Verify events are in descending order (newest first)
        for i in 0..<allEvents.count - 1 {
            XCTAssertTrue(allEvents[i].timestamp >= allEvents[i + 1].timestamp)
        }
    }

    func testLedgerRecordsAllOperationTypes() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Test all event types
        let eventTypes: [LedgerEventType] = [.install, .update, .remove, .verify, .sync]

        for eventType in eventTypes {
            try await ledger.record(LedgerEventInput(
                eventType: eventType,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success
            ))
        }

        let allEvents = try await ledger.fetchEvents(limit: 100)
        XCTAssertEqual(allEvents.count, 5)

        let recordedTypes = Set(allEvents.map { $0.eventType })
        XCTAssertEqual(recordedTypes, Set(eventTypes))
    }

    // MARK: - Story S12: Auditor - Signed Changelog Tests

    func testAuditorChangelogIncludesFailures() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: "abc123def456",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-001"
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .update,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "2.0.0",
                agent: .codex,
                status: .failure,
                note: "Signature verification failed",
                source: nil,
                verification: .permissive,
                manifestSHA256: "badhash123",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-001"
            )
        ]

        let auditorMarkdown = generator.generateAuditorMarkdown(events: events)

        // Should include both success and failure events
        XCTAssertTrue(auditorMarkdown.contains("✓"), "Should include success indicator")
        XCTAssertTrue(auditorMarkdown.contains("✗"), "Should include failure indicator")
        XCTAssertTrue(auditorMarkdown.contains("[FAILED]"), "Should mark failed events")
        XCTAssertTrue(auditorMarkdown.contains("Signature verification failed"), "Should include failure notes")
    }

    func testAuditorChangelogIncludesSignerProvenance() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Signed Skill",
                skillSlug: "signed-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: "abc123def456789",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "ed25519:abc123"
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .install,
                skillName: "Unsigned Skill",
                skillSlug: "unsigned-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .permissive,
                manifestSHA256: "xyz789",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            )
        ]

        let auditorMarkdown = generator.generateAuditorMarkdown(events: events)

        // Should include signer key ID
        XCTAssertTrue(auditorMarkdown.contains("signer: `ed25519:abc123`"), "Should include signer key")
        XCTAssertTrue(auditorMarkdown.contains("signer: *(unsigned)*"), "Should mark unsigned items")

        // Should include SHA256 hash
        XCTAssertTrue(auditorMarkdown.contains("SHA256: `abc123def456789`"), "Should include SHA256 hash")
    }

    func testAuditorChangelogPerSkillFilter() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Skill A",
                skillSlug: "skill-a",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: "hash-a",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-a"
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .install,
                skillName: "Skill B",
                skillSlug: "skill-b",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .permissive,
                manifestSHA256: "hash-b",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-b"
            )
        ]

        let skillAChangelog = generator.generatePerSkillAuditorMarkdown(
            events: events,
            skillSlug: "skill-a",
            skillName: "Skill A"
        )

        XCTAssertTrue(skillAChangelog.contains("Skill A"))
        XCTAssertTrue(skillAChangelog.contains("signer: `signer-a`"))
        XCTAssertFalse(skillAChangelog.contains("Skill B"))
        XCTAssertFalse(skillAChangelog.contains("signer-b"))
    }

    func testAuditorChangelogFilteredByEventType() {
        let generator = SkillChangelogGenerator()
        let events = [
            LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .strict,
                manifestSHA256: "hash-1",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-1"
            ),
            LedgerEvent(
                id: 2,
                timestamp: Date(),
                eventType: .remove,
                skillName: "Test Skill",
                skillSlug: "test-skill",
                version: "1.0.0",
                agent: .codex,
                status: .success,
                note: nil,
                source: nil,
                verification: .permissive,
                manifestSHA256: "hash-1",
                targetPath: nil,
                targets: nil,
                perTargetResults: nil,
                signerKeyId: "signer-1"
            )
        ]

        let installOnlyChangelog = generator.generateFilteredAuditorMarkdown(
            events: events,
            eventTypes: [.install]
        )

        XCTAssertTrue(installOnlyChangelog.contains("**Installed**"))
        XCTAssertFalse(installOnlyChangelog.contains("**Removed**"))
    }

    func testAuditorChangelogFilteredByDateRange() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        let yesterday = Date().addingTimeInterval(-86400)
        let today = Date()

        try await ledger.record(LedgerEventInput(
            timestamp: yesterday,
            eventType: .install,
            skillName: "Old Skill",
            skillSlug: "old-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success,
            manifestSHA256: "old-hash",
            signerKeyId: "signer-old"
        ))

        try await ledger.record(LedgerEventInput(
            timestamp: today,
            eventType: .install,
            skillName: "New Skill",
            skillSlug: "new-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success,
            manifestSHA256: "new-hash",
            signerKeyId: "signer-new"
        ))

        let generator = SkillChangelogGenerator()
        let allEvents = try await ledger.fetchEvents(limit: 100)

        let todayChangelog = generator.generateFilteredAuditorMarkdown(
            events: allEvents,
            dateRange: today...today.addingTimeInterval(86400)
        )

        // Should only include events from today (or very recent)
        let allChangelog = generator.generateAuditorMarkdown(events: allEvents)
        XCTAssertLessThan(todayChangelog.count, allChangelog.count)
    }

    func testAuditorChangelogIsTamperEvident() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        // Record events with cryptographic provenance
        try await ledger.record(LedgerEventInput(
            eventType: .install,
            skillName: "Secure Skill",
            skillSlug: "secure-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success,
            source: nil,
            verification: .strict,
            manifestSHA256: "a1b2c3d4e5f6",
            signerKeyId: "ed25519:key001"
        ))

        let allEvents = try await ledger.fetchEvents(limit: 100)
        let generator = SkillChangelogGenerator()
        let auditTrail = generator.generateAuditorMarkdown(events: allEvents)

        // Verify tamper-evident language is present
        XCTAssertTrue(auditTrail.contains("tamper-evident"), "Should mention tamper-evidence")
        XCTAssertTrue(auditTrail.contains("cryptographically verifiable"), "Should mention cryptographic verification")
        XCTAssertTrue(auditTrail.contains("**Installed**"), "Should format action type")
        XCTAssertTrue(auditTrail.contains("signer: `ed25519:key001`"), "Should include signer key")
        XCTAssertTrue(auditTrail.contains("SHA256: `a1b2c3d4e5f6`"), "Should include hash")
    }

    func testLedgerRecordsCryptographicFields() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ledgerURL = tempDir.appendingPathComponent("ledger.sqlite3")
        let ledger = try SkillLedger(url: ledgerURL)

        let input = LedgerEventInput(
            eventType: .install,
            skillName: "Crypto Skill",
            skillSlug: "crypto-skill",
            version: "1.0.0",
            agent: .codex,
            status: .success,
            verification: .strict,
            manifestSHA256: "deadbeefcafe1234",
            signerKeyId: "ed25519:master-key"
        )

        let recorded = try await ledger.record(input)

        // Verify cryptographic fields are persisted
        XCTAssertEqual(recorded.manifestSHA256, "deadbeefcafe1234")
        XCTAssertEqual(recorded.signerKeyId, "ed25519:master-key")

        // Verify fields are retrievable
        let fetched = try await ledger.fetchEvents(limit: 1)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.manifestSHA256, "deadbeefcafe1234")
        XCTAssertEqual(fetched.first?.signerKeyId, "ed25519:master-key")
    }
}
