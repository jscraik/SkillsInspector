import Foundation

/// Actor orchestrating skill lifecycle workflow operations
public actor SkillLifecycleCoordinator {
    private let stateStore: WorkflowStateStore
    private let acipScanner: ACIPScanner
    private let searchEngine: SkillSearchEngine?

    public init(
        stateStore: WorkflowStateStore = WorkflowStateStore(),
        acipScanner: ACIPScanner = ACIPScanner(),
        searchEngine: SkillSearchEngine? = nil
    ) {
        self.stateStore = stateStore
        self.acipScanner = acipScanner
        self.searchEngine = searchEngine
    }

    /// Create a new skill workflow
    public func createSkill(
        name: String,
        description: String,
        agent: AgentKind,
        in rootURL: URL,
        createdBy: String = "system"
    ) async throws -> WorkflowState {
        let skillSlug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let skillPath = rootURL.appendingPathComponent(skillSlug)

        // Create skill directory structure
        let fm = FileManager.default
        if !fm.fileExists(atPath: skillPath.path) {
            try fm.createDirectory(at: skillPath, withIntermediateDirectories: true)
        }

        // Create initial SKILL.md
        let initialContent = """
---
name: \(name)
description: \(description)
version: 1.0.0
author: \(createdBy)
tags:
---

# \(name)

\(description)

## Getting Started

Instructions for using this skill.

"""

        let skillFile = skillPath.appendingPathComponent("SKILL.md")
        try initialContent.write(to: skillFile, atomically: true, encoding: .utf8)

        // Create workflow state
        let state = await stateStore.create(
            skillSlug: skillSlug,
            stage: .draft,
            createdBy: createdBy
        )

        return state
    }

    /// Validate a skill and advance workflow
    public func validateSkill(
        at path: URL,
        agent: AgentKind,
        rootURL: URL
    ) async throws -> WorkflowState {
        let skillSlug = path.lastPathComponent
        var state: WorkflowState
        if let existing = await stateStore.get(skillSlug: skillSlug) {
            state = existing
        } else {
            state = await stateStore.create(skillSlug: skillSlug)
        }

        // Parse skill spec
        let skillFile = path.appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
            throw WorkflowError.skillFileNotFound
        }

        let spec = SkillSpec.parse(content)

        // Clear previous validation results
        state.clearValidationResults()

        // Run spec validation
        let validationErrors = spec.validate(for: agent)
        for error in validationErrors {
            state.addValidationResult(error.toWorkflowError(file: skillFile.path))
        }

        // Run security scanning
        let scanResult = await acipScanner.scanSkill(at: path, source: .remote)

        for (filePath, result) in scanResult {
            switch result.action {
            case .block:
                state.addValidationResult(WorkflowValidationError(
                    code: "security_block",
                    message: "Content blocked: \(result.patterns.map { $0.name }.joined(separator: ", "))",
                    severity: .error,
                    file: filePath
                ))
            case .quarantine:
                state.addValidationResult(WorkflowValidationError(
                    code: "security_quarantine",
                    message: "Content quarantined: \(result.patterns.map { $0.name }.joined(separator: ", "))",
                    severity: .warning,
                    file: filePath
                ))
            default:
                break
            }
        }

        // Update workflow state
        if state.errorCount == 0 {
            state.transitionTo(Stage.reviewed, notes: "Validation passed")
        } else {
            state.transitionTo(Stage.validating, notes: "Validation found \(state.errorCount) error(s)")
        }

        await stateStore.update(state)
        return state
    }

    /// Approve a skill for publication
    public func approve(
        at path: URL,
        reviewer: String,
        notes: String = ""
    ) async throws -> WorkflowState {
        let skillSlug = path.lastPathComponent
        guard var state = await stateStore.get(skillSlug: skillSlug) else {
            throw WorkflowError.skillNotFound
        }

        guard state.stage.canApprove else {
            throw WorkflowError.invalidTransition
        }

        state.transitionTo(Stage.approved, by: reviewer, notes: notes)
        await stateStore.update(state)
        return state
    }

    /// Publish a skill
    public func publish(
        at path: URL,
        changelog: String,
        publisher: String = "system"
    ) async throws -> WorkflowState {
        let skillSlug = path.lastPathComponent
        guard var state = await stateStore.get(skillSlug: skillSlug) else {
            throw WorkflowError.workflowNotFound
        }

        guard state.stage == .approved else {
            throw WorkflowError.invalidTransition
        }

        // Update version in SKILL.md
        try updateVersionInSkill(at: path)

        state.transitionTo(Stage.published, by: publisher, notes: changelog)

        // Update search index if available
        if let engine = searchEngine {
            let skill = SkillSearchEngine.Skill(
                slug: skillSlug,
                name: nil, // Will be extracted from content
                description: nil,
                agent: .codex, // Default, could be detected
                rootPath: path.path,
                tags: nil,
                rank: nil,
                fileSize: nil
            )

            let content = try? String(contentsOf: path.appendingPathComponent("SKILL.md"), encoding: .utf8)
            if let content = content {
                try? await engine.indexSkill(skill, content: content)
            }
        }

        await stateStore.update(state)
        return state
    }

    /// Sync skill across multiple agent targets
    public func syncAcrossAgents(
        at path: URL,
        targets: [AgentKind],
        syncContent: Bool = true
    ) async throws -> [AgentKind: Result<WorkflowState, WorkflowError>] {
        let skillSlug = path.lastPathComponent
        let sourceContent = try? String(contentsOf: path.appendingPathComponent("SKILL.md"), encoding: .utf8)

        var results: [AgentKind: Result<WorkflowState, WorkflowError>] = [:]

        for target in targets {
            do {
                let targetRoot = targetRootURL(for: target)
                let targetPath = targetRoot.appendingPathComponent(skillSlug)

                // Create target directory if needed
                let fm = FileManager.default
                if !fm.fileExists(atPath: targetPath.path) {
                    try fm.createDirectory(at: targetPath, withIntermediateDirectories: true)
                }

                // Copy SKILL.md
                if let content = sourceContent, syncContent {
                    let targetFile = targetPath.appendingPathComponent("SKILL.md")
                    try content.write(to: targetFile, atomically: true, encoding: .utf8)
                }

                // Get or create workflow state for target
                // Note: In real implementation, this would need to track per-agent states
                let workflowState: WorkflowState
                if let existing = await stateStore.get(skillSlug: skillSlug) {
                    workflowState = existing
                } else {
                    workflowState = await stateStore.create(skillSlug: skillSlug)
                }
                results[target] = .success(workflowState)

            } catch {
                results[target] = .failure(.syncFailed(target, error))
            }
        }

        return results
    }

    /// Get workflow state for a skill
    public func getWorkflowState(skillSlug: String) async -> WorkflowState? {
        return await stateStore.get(skillSlug: skillSlug)
    }

    /// List all workflow states
    public func listWorkflows(stage: Stage? = nil) async -> [WorkflowState] {
        if let stage = stage {
            return await stateStore.list(stage: stage)
        } else {
            return await stateStore.list()
        }
    }

    // MARK: - Private Helpers

    private func targetRootURL(for agent: AgentKind) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser

        switch agent {
        case .codex:
            return home.appendingPathComponent(".codex/skills")
        case .claude:
            return home.appendingPathComponent(".claude/skills")
        case .copilot:
            return home.appendingPathComponent(".copilot/skills")
        default:
            return home.appendingPathComponent("Skills")
        }
    }

    private func updateVersionInSkill(at path: URL) throws {
        let skillFile = path.appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
            throw WorkflowError.skillFileNotFound
        }

        let spec = SkillSpec.parse(content)

        // Increment version
        let currentVersion = spec.metadata.version ?? "1.0.0"
        let newVersion = incrementVersion(currentVersion)

        // Update spec
        var updatedSpec = spec
        updatedSpec.metadata.version = newVersion

        // Write back
        let updatedContent = updatedSpec.toMarkdown()
        try updatedContent.write(to: skillFile, atomically: true, encoding: .utf8)
    }

    private func incrementVersion(_ version: String) -> String {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return version }

        let major = parts[0]
        let minor = parts[1]
        let patch = parts[2]

        return "\(major).\(minor).\(patch + 1)"
    }
}

// MARK: - Types

public enum WorkflowError: LocalizedError {
    case skillNotFound
    case workflowNotFound
    case invalidTransition
    case skillFileNotFound
    case syncFailed(AgentKind, Error)

    public var errorDescription: String? {
        switch self {
        case .skillNotFound:
            return "Skill not found"
        case .workflowNotFound:
            return "Workflow state not found"
        case .invalidTransition:
            return "Invalid workflow transition"
        case .skillFileNotFound:
            return "SKILL.md file not found"
        case .syncFailed(let agent, let error):
            return "Failed to sync to \(agent.rawValue): \(error.localizedDescription)"
        }
    }

    public var isError: Bool {
        switch self {
        case .skillNotFound, .workflowNotFound, .invalidTransition, .skillFileNotFound, .syncFailed:
            return true
        }
    }
}

// MARK: - Stage Extensions

extension Stage {
    public var canApprove: Bool {
        switch self {
        case .reviewed, .approved:
            return true
        case .draft, .validating, .published, .archived:
            return false
        }
    }
}

// MARK: - ValidationError Conversion

extension SkillSpec.ValidationError {
    /// Convert SkillSpec.ValidationError to WorkflowValidationError
    func toWorkflowError(file: String = "") -> WorkflowValidationError {
        let workflowSeverity: WorkflowValidationError.Severity
        switch severity {
        case .error:
            workflowSeverity = .error
        case .warning:
            workflowSeverity = .warning
        case .info:
            workflowSeverity = .info
        }

        return WorkflowValidationError(
            code: code,
            message: message,
            severity: workflowSeverity,
            file: file,
            line: line
        )
    }
}
