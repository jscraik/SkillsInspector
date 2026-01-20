import XCTest
@testable import SkillsCore

/// Unit tests for workflow state management and lifecycle coordination
final class WorkflowTests: XCTestCase {
    private func makeWorkflowStore() throws -> (store: WorkflowStateStore, root: URL) {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("workflow-store-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let storeURL = tempRoot.appendingPathComponent("workflow-states.json")
        return (WorkflowStateStore(storageURL: storeURL), tempRoot)
    }

    // MARK: - Stage Tests

    func testStageDisplayName() {
        XCTAssertEqual(Stage.draft.displayName, "Draft")
        XCTAssertEqual(Stage.validating.displayName, "Validating")
        XCTAssertEqual(Stage.reviewed.displayName, "Reviewed")
        XCTAssertEqual(Stage.approved.displayName, "Approved")
        XCTAssertEqual(Stage.published.displayName, "Published")
        XCTAssertEqual(Stage.archived.displayName, "Archived")
    }

    func testStageTransitions() {
        XCTAssertEqual(Stage.draft.nextStage, .validating)
        XCTAssertEqual(Stage.validating.nextStage, .reviewed)
        XCTAssertEqual(Stage.reviewed.nextStage, .approved)
        XCTAssertEqual(Stage.approved.nextStage, .published)
        XCTAssertEqual(Stage.published.nextStage, .archived)
        XCTAssertNil(Stage.archived.nextStage)

        XCTAssertNil(Stage.draft.previousStage)
        XCTAssertEqual(Stage.validating.previousStage, .draft)
        XCTAssertEqual(Stage.reviewed.previousStage, .validating)
        XCTAssertEqual(Stage.approved.previousStage, .reviewed)
        XCTAssertEqual(Stage.published.previousStage, .approved)
        XCTAssertEqual(Stage.archived.previousStage, .published)
    }

    func testStageEditability() {
        XCTAssertTrue(Stage.draft.isEditable)
        XCTAssertTrue(Stage.validating.isEditable)
        XCTAssertFalse(Stage.reviewed.isEditable)
        XCTAssertFalse(Stage.approved.isEditable)
        XCTAssertFalse(Stage.published.isEditable)
        XCTAssertFalse(Stage.archived.isEditable)
    }

    func testStageCanApprove() {
        XCTAssertTrue(Stage.reviewed.canApprove)
        XCTAssertTrue(Stage.approved.canApprove)
        XCTAssertFalse(Stage.draft.canApprove)
        XCTAssertFalse(Stage.validating.canApprove)
        XCTAssertFalse(Stage.published.canApprove)
        XCTAssertFalse(Stage.archived.canApprove)
    }

    // MARK: - WorkflowState Tests

    func testWorkflowStateInitialization() {
        let state = WorkflowState(
            skillSlug: "test-skill",
            stage: .draft
        )

        XCTAssertEqual(state.skillSlug, "test-skill")
        XCTAssertEqual(state.stage, .draft)
        XCTAssertTrue(state.validationResults.isEmpty)
        XCTAssertEqual(state.reviewNotes, "")
        XCTAssertNil(state.reviewer)
        XCTAssertEqual(state.versionHistory.count, 1)
        XCTAssertEqual(state.versionHistory[0].stage, .draft)
        XCTAssertTrue(state.isValid)
        XCTAssertEqual(state.errorCount, 0)
        XCTAssertEqual(state.warningCount, 0)
    }

    func testWorkflowStateValidationResults() {
        var state = WorkflowState(
            skillSlug: "test-skill",
            stage: .validating
        )

        let error1 = WorkflowValidationError(
            code: "TEST001",
            message: "Test error",
            severity: .error,
            file: "test.md",
            line: 10
        )

        let error2 = WorkflowValidationError(
            code: "TEST002",
            message: "Test warning",
            severity: .warning,
            file: "test.md",
            line: 20
        )

        state.addValidationResult(error1)
        state.addValidationResult(error2)

        XCTAssertEqual(state.validationResults.count, 2)
        XCTAssertEqual(state.errorCount, 1)
        XCTAssertEqual(state.warningCount, 1)
        XCTAssertFalse(state.isValid)
    }

    func testWorkflowStateClearValidation() {
        var state = WorkflowState(
            skillSlug: "test-skill",
            stage: .validating
        )

        state.addValidationResult(WorkflowValidationError(
            code: "TEST001",
            message: "Test error",
            severity: .error
        ))

        XCTAssertEqual(state.validationResults.count, 1)

        state.clearValidationResults()

        XCTAssertTrue(state.validationResults.isEmpty)
        XCTAssertTrue(state.isValid)
    }

    func testWorkflowStateTransition() {
        var state = WorkflowState(
            skillSlug: "test-skill",
            stage: .draft
        )

        XCTAssertEqual(state.versionHistory.count, 1)
        XCTAssertEqual(state.versionHistory[0].stage, .draft)

        state.transitionTo(.validating, by: "tester", notes: "Ready for validation")

        XCTAssertEqual(state.stage, .validating)
        XCTAssertEqual(state.reviewer, "tester")
        XCTAssertEqual(state.reviewNotes, "Ready for validation")
        XCTAssertEqual(state.versionHistory.count, 2)
        XCTAssertEqual(state.versionHistory[1].stage, .validating)
        XCTAssertEqual(state.versionHistory[1].changedBy, "tester")
        XCTAssertEqual(state.versionHistory[1].changelog, "Ready for validation")
    }

    func testWorkflowStateValidationByStage() {
        var state = WorkflowState(
            skillSlug: "test-skill",
            stage: .draft
        )

        // Draft is always valid
        XCTAssertTrue(state.isValid)

        // Add error and move to validating
        state.stage = .validating
        state.addValidationResult(WorkflowValidationError(
            code: "TEST001",
            message: "Error",
            severity: .error
        ))
        XCTAssertFalse(state.isValid)

        // Clear errors
        state.clearValidationResults()
        XCTAssertTrue(state.isValid)
    }

    // MARK: - WorkflowValidationError Tests

    func testValidationErrorSeverity() {
        let error = WorkflowValidationError(
            code: "TEST001",
            message: "Test",
            severity: .error
        )
        XCTAssertTrue(error.severity.isError)
        XCTAssertFalse(error.severity.isWarning)

        let warning = WorkflowValidationError(
            code: "TEST002",
            message: "Test",
            severity: .warning
        )
        XCTAssertFalse(warning.severity.isError)
        XCTAssertTrue(warning.severity.isWarning)

        let info = WorkflowValidationError(
            code: "TEST003",
            message: "Test",
            severity: .info
        )
        XCTAssertFalse(info.severity.isError)
        XCTAssertFalse(info.severity.isWarning)
    }

    func testValidationErrorWithLocation() {
        let error = WorkflowValidationError(
            code: "SYNTAX001",
            message: "Invalid syntax",
            severity: .error,
            file: "skill.md",
            line: 42
        )

        XCTAssertEqual(error.file, "skill.md")
        XCTAssertEqual(error.line, 42)
    }

    // MARK: - WorkflowStateStore Tests

    func testWorkflowStateStoreCreateAndGet() async throws {
        let storeContext = try makeWorkflowStore()
        let store = storeContext.store
        defer { try? FileManager.default.removeItem(at: storeContext.root) }

        let created = await store.create(
            skillSlug: "test-skill",
            stage: .draft,
            createdBy: "tester"
        )

        XCTAssertEqual(created.skillSlug, "test-skill")
        XCTAssertEqual(created.stage, .draft)
        XCTAssertEqual(created.versionHistory.count, 1)

        let retrieved = await store.get(skillSlug: "test-skill")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.skillSlug, "test-skill")
    }

    func testWorkflowStateStoreUpdate() async throws {
        let storeContext = try makeWorkflowStore()
        let store = storeContext.store
        defer { try? FileManager.default.removeItem(at: storeContext.root) }

        var state = await store.create(
            skillSlug: "test-skill",
            stage: .draft,
            createdBy: "tester"
        )

        state.transitionTo(.validating, by: "tester", notes: "Updated")
        await store.update(state)

        let retrieved = await store.get(skillSlug: "test-skill")
        XCTAssertEqual(retrieved?.stage, .validating)
        XCTAssertEqual(retrieved?.reviewNotes, "Updated")
    }

    func testWorkflowStateStoreList() async throws {
        let storeContext = try makeWorkflowStore()
        let store = storeContext.store
        defer { try? FileManager.default.removeItem(at: storeContext.root) }

        _ = await store.create(skillSlug: "skill1", stage: .draft)
        _ = await store.create(skillSlug: "skill2", stage: .reviewed)
        _ = await store.create(skillSlug: "skill3", stage: .approved)

        let all = await store.list()
        XCTAssertEqual(all.count, 3)

        let draft = await store.list(stage: .draft)
        XCTAssertEqual(draft.count, 1)
        XCTAssertEqual(draft[0].skillSlug, "skill1")

        let reviewed = await store.list(stage: .reviewed)
        XCTAssertEqual(reviewed.count, 1)
        XCTAssertEqual(reviewed[0].skillSlug, "skill2")
    }

    func testWorkflowStateStoreDelete() async throws {
        let storeContext = try makeWorkflowStore()
        let store = storeContext.store
        defer { try? FileManager.default.removeItem(at: storeContext.root) }

        _ = await store.create(skillSlug: "test-skill", stage: .draft)
        let beforeDelete = await store.get(skillSlug: "test-skill")
        XCTAssertNotNil(beforeDelete)

        await store.delete(skillSlug: "test-skill")
        let afterDelete = await store.get(skillSlug: "test-skill")
        XCTAssertNil(afterDelete)
    }

    // MARK: - SkillLifecycleCoordinator Tests

    func testCoordinatorCreateSkill() async throws {
        let storeContext = try makeWorkflowStore()
        let coordinator = SkillLifecycleCoordinator(stateStore: storeContext.store)
        let tempDir = FileManager.default.temporaryDirectory
        let testRoot = tempDir.appendingPathComponent("test-skills-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRoot)
            try? FileManager.default.removeItem(at: storeContext.root)
        }

        let state = try await coordinator.createSkill(
            name: "Test Skill",
            description: "A test skill",
            agent: .codex,
            in: testRoot,
            createdBy: "tester"
        )

        XCTAssertEqual(state.skillSlug, "test-skill")
        XCTAssertEqual(state.stage, .draft)
        XCTAssertEqual(state.versionHistory.count, 1)

        let skillPath = testRoot.appendingPathComponent("test-skill")
        let skillFile = skillPath.appendingPathComponent("SKILL.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillFile.path))

        let content = try String(contentsOf: skillFile, encoding: .utf8)
        XCTAssertTrue(content.contains("Test Skill"))
        XCTAssertTrue(content.contains("A test skill"))
    }

    func testCoordinatorValidateSkill() async throws {
        let storeContext = try makeWorkflowStore()
        let coordinator = SkillLifecycleCoordinator(stateStore: storeContext.store)
        let tempDir = FileManager.default.temporaryDirectory
        let testRoot = tempDir.appendingPathComponent("test-skills-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRoot)
            try? FileManager.default.removeItem(at: storeContext.root)
        }

        // Create a test skill
        let skillPath = testRoot.appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(at: skillPath, withIntermediateDirectories: true)

        let skillContent = """
---
name: Test Skill
description: A test skill
version: 1.0.0
author: tester
tags: [test]
---

# Test Skill

A test skill for validation.

## Getting Started

Instructions here.
"""

        let skillFile = skillPath.appendingPathComponent("SKILL.md")
        try skillContent.write(to: skillFile, atomically: true, encoding: .utf8)

        let state = try await coordinator.validateSkill(
            at: skillPath,
            agent: .codex,
            rootURL: testRoot
        )

        // Should transition to reviewed with no validation errors
        XCTAssertEqual(state.stage, .reviewed)
        XCTAssertTrue(state.errorCount == 0 || state.stage == .validating)
    }

    func testCoordinatorApproveSkill() async throws {
        let storeContext = try makeWorkflowStore()
        let coordinator = SkillLifecycleCoordinator(stateStore: storeContext.store)
        let tempDir = FileManager.default.temporaryDirectory
        let testRoot = tempDir.appendingPathComponent("test-skills-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRoot)
            try? FileManager.default.removeItem(at: storeContext.root)
        }

        // Create a skill in reviewed state
        let skillPath = testRoot.appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(at: skillPath, withIntermediateDirectories: true)

        let skillContent = """
---
name: Test Skill
description: A test skill
version: 1.0.0
---

# Test Skill
"""
        try skillContent.write(to: skillPath.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // First validate to get to reviewed
        _ = try await coordinator.validateSkill(at: skillPath, agent: .codex, rootURL: testRoot)

        // Then approve
        let state = try await coordinator.approve(
            at: skillPath,
            reviewer: "senior-dev",
            notes: "Looks good to me"
        )

        XCTAssertEqual(state.stage, .approved)
        XCTAssertEqual(state.reviewer, "senior-dev")
        XCTAssertEqual(state.reviewNotes, "Looks good to me")
    }

    func testCoordinatorPublishSkill() async throws {
        let storeContext = try makeWorkflowStore()
        let coordinator = SkillLifecycleCoordinator(stateStore: storeContext.store)
        let tempDir = FileManager.default.temporaryDirectory
        let testRoot = tempDir.appendingPathComponent("test-skills-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRoot)
            try? FileManager.default.removeItem(at: storeContext.root)
        }

        // Create a skill in approved state
        let skillPath = testRoot.appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(at: skillPath, withIntermediateDirectories: true)

        let skillContent = """
---
name: Test Skill
description: A test skill
version: 1.0.0
---

# Test Skill
"""
        try skillContent.write(to: skillPath.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Setup workflow state as approved
        var state = await storeContext.store.create(skillSlug: "test-skill", stage: .reviewed, createdBy: "tester")
        state.transitionTo(.approved, by: "senior-dev", notes: "Approved")
        await storeContext.store.update(state)

        // Publish
        let publishedState = try await coordinator.publish(
            at: skillPath,
            changelog: "Initial release",
            publisher: "system"
        )

        XCTAssertEqual(publishedState.stage, .published)

        // Check version was incremented
        let updatedContent = try String(contentsOf: skillPath.appendingPathComponent("SKILL.md"), encoding: .utf8)
        XCTAssertTrue(updatedContent.contains("version: 1.0.1"))
    }

    func testCoordinatorInvalidTransition() async throws {
        let storeContext = try makeWorkflowStore()
        let coordinator = SkillLifecycleCoordinator(stateStore: storeContext.store)
        let tempDir = FileManager.default.temporaryDirectory
        let testRoot = tempDir.appendingPathComponent("test-skills-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: testRoot)
            try? FileManager.default.removeItem(at: storeContext.root)
        }

        // Create a skill in draft state
        let skillPath = testRoot.appendingPathComponent("test-skill")
        try FileManager.default.createDirectory(at: skillPath, withIntermediateDirectories: true)
        _ = await storeContext.store.create(skillSlug: "test-skill", stage: .draft, createdBy: "tester")

        do {
            _ = try await coordinator.approve(
                at: skillPath,
                reviewer: "tester",
                notes: "Should fail"
            )
            XCTFail("Should have thrown WorkflowError.invalidTransition")
        } catch WorkflowError.invalidTransition {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - VersionEntry Tests

    func testVersionEntryInitialization() {
        let entry = WorkflowState.VersionEntry(
            version: "1.0.0",
            stage: .published,
            changedBy: "publisher",
            changelog: "First release"
        )

        XCTAssertEqual(entry.version, "1.0.0")
        XCTAssertEqual(entry.stage, .published)
        XCTAssertEqual(entry.changedBy, "publisher")
        XCTAssertEqual(entry.changelog, "First release")
    }

    func testVersionEntryAutoID() {
        let entry1 = WorkflowState.VersionEntry(
            version: "1.0.0",
            stage: .draft,
            changedBy: "author"
        )

        let entry2 = WorkflowState.VersionEntry(
            version: "1.0.0",
            stage: .draft,
            changedBy: "author"
        )

        // Each entry should have a unique ID
        XCTAssertNotEqual(entry1.id, entry2.id)
    }
}
