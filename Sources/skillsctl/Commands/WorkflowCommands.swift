import ArgumentParser
import Foundation
import SkillsCore

/// Workflow management commands for skill lifecycle
struct WorkflowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workflow",
        abstract: "Manage skill workflow lifecycle (create, validate, approve, publish).",
        subcommands: [
            Create.self,
            Validate.self,
            Review.self,
            Approve.self,
            Publish.self,
            Sync.self,
            Status.self,
            List.self,
            Dashboard.self
        ]
    )
}

// MARK: - Create

extension WorkflowCommand {
    /// Create a new skill from a template
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new skill from a template.",
            discussion: """
            Creates a new skill directory with a SKILL.md file generated from a template.
            The skill will be initialized in the 'draft' workflow stage.

            Templates: automation, analysis, development, security, testing
            """
        )

        @Argument var name: String

        @Option var description: String

        @Option var template: String?

        @Option var agent: String?

        @Option var author: String?

        @Option var output: String?

        @Flag var listTemplates: Bool = false

        func run() async throws {
            // List templates if requested
            if listTemplates {
                listAvailableTemplates()
                return
            }

            // Detect agent from path or option
            let agentKind = detectAgentKind(from: agent, path: output)

            // Get template
            let skillTemplate: SkillTemplate
            if let templateName = template {
                guard let found = SkillTemplate.find(named: templateName) else {
                    throw WorkflowValidationError(
                        code: "template_not_found",
                        message: "Template '\(templateName)' not found. Available: \(availableTemplateNames())",
                        severity: WorkflowValidationError.Severity.error
                    )
                }
                skillTemplate = found
            } else {
                // Use default template based on agent
                skillTemplate = agentKind == .claude ? SkillTemplate.analysisTemplate : SkillTemplate.automationTemplate
            }

            // Determine output directory
            let outputURL: URL
            if let outputPath = output {
                outputURL = URL(fileURLWithPath: outputPath)
            } else {
                outputURL = defaultRootURL(for: agentKind)
            }

            // Create skill
            let coordinator = SkillLifecycleCoordinator()
            let state = try await coordinator.createSkill(
                name: name,
                description: description,
                agent: agentKind,
                in: outputURL,
                createdBy: author ?? NSFullUserName()
            )

            // Output result
            print("✓ Created skill: \(state.skillSlug)")
            print("  Location: \(outputURL.appendingPathComponent(state.skillSlug).path)")
            print("  Stage: \(state.stage.displayName)")
            print("  Template: \(skillTemplate.name)")
        }

        private func detectAgentKind(from option: String?, path: String?) -> AgentKind {
            if let agentStr = option {
                return AgentKind(rawValue: agentStr) ?? .codex
            }

            if let pathStr = path {
                if pathStr.contains("claude") { return .claude }
                if pathStr.contains("copilot") { return .copilot }
            }

            return .codex
        }

        private func defaultRootURL(for agent: AgentKind) -> URL {
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

        private func listAvailableTemplates() {
            print("Available Templates:")
            print("")
            for template in SkillTemplate.builtInTemplates() {
                let icon = template.category.icon
                print("  \(template.name) (\(template.category.rawValue))")
                print("    \(template.description)")
                print("    Default agent: \(template.defaultAgent.rawValue)")
                print("    Tags: \(template.metadata.tags.joined(separator: ", "))")
                print("")
            }
        }

        private func availableTemplateNames() -> String {
            SkillTemplate.builtInTemplates()
                .map { $0.name.lowercased() }
                .joined(separator: ", ")
        }
    }
}

// MARK: - Validate

extension WorkflowCommand {
    /// Validate a skill and advance workflow
    struct Validate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate a skill and advance its workflow stage.",
            discussion: """
            Runs spec validation and ACIP security scanning on a skill.
            Advances the workflow stage based on validation results:
            - No errors: advances to 'reviewed'
            - With errors: stays in 'validating' with error details
            """
        )

        @Argument var path: String

        @Option var agent: String?

        @Option var root: String?

        func run() async throws {
            let skillURL = URL(fileURLWithPath: path)
            let agentKind = AgentKind(rawValue: agent ?? "") ?? detectAgent(from: skillURL)

            let rootURL: URL
            if let rootPath = root {
                rootURL = URL(fileURLWithPath: rootPath)
            } else {
                rootURL = skillURL.deletingLastPathComponent()
            }

            let coordinator = SkillLifecycleCoordinator()
            let state = try await coordinator.validateSkill(
                at: skillURL,
                agent: agentKind,
                rootURL: rootURL
            )

            // Output results
            print("Validation Results for: \(state.skillSlug)")
            print("  Stage: \(state.stage.displayName)")
            print("  Errors: \(state.errorCount)")
            print("  Warnings: \(state.warningCount)")

            if !state.validationResults.isEmpty {
                print("")
                print("Validation Issues:")
                for result in state.validationResults {
                    let icon = result.severity == WorkflowValidationError.Severity.error ? "✗" : "⚠"
                    print("  \(icon) [\(result.severity.rawValue.uppercased())] \(result.code)")
                    print("    \(result.message)")
                    if !result.file.isEmpty {
                        print("    File: \(result.file)\(result.line.map { ":\($0)" } ?? "")")
                    }
                }
            }

            if state.stage == .reviewed {
                print("")
                print("✓ Skill validated successfully and ready for review")
            }
        }

        private func detectAgent(from url: URL) -> AgentKind {
            let path = url.path.lowercased()
            if path.contains("claude") { return .claude }
            if path.contains("copilot") { return .copilot }
            return .codex
        }
    }
}

// MARK: - Review

extension WorkflowCommand {
    /// Submit a skill for review
    struct Review: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Submit a skill for review.",
            discussion: """
            Submits a skill for review with optional notes.
            The skill should be in the 'validating' stage before review.
            """
        )

        @Argument var path: String

        @Option var notes: String = ""

        func run() async throws {
            let skillSlug = URL(fileURLWithPath: path).lastPathComponent
            let store = WorkflowStateStore()

            guard var state = await store.get(skillSlug: skillSlug) else {
                throw WorkflowValidationError(
                    code: "workflow_not_found",
                    message: "No workflow state found for skill: \(skillSlug)",
                    severity: WorkflowValidationError.Severity.error
                )
            }

            guard state.stage == .validating || state.stage == .reviewed else {
                throw WorkflowValidationError(
                    code: "invalid_stage",
                    message: "Skill must be in 'validating' stage to submit for review, currently: \(state.stage.displayName)",
                    severity: WorkflowValidationError.Severity.error
                )
            }

            state.transitionTo(.reviewed, notes: notes.isEmpty ? "Submitted for review" : notes)
            await store.update(state)

            print("✓ Submitted \(skillSlug) for review")
            print("  Stage: \(state.stage.displayName)")
            if !notes.isEmpty {
                print("  Notes: \(notes)")
            }
        }
    }
}

// MARK: - Approve

extension WorkflowCommand {
    /// Approve a skill for publication
    struct Approve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Approve a skill for publication.",
            discussion: """
            Approves a skill and advances it to the 'approved' stage.
            Requires the skill to be in the 'reviewed' stage.
            """
        )

        @Argument var path: String

        @Option var reviewer: String?

        @Option var notes: String = ""

        func run() async throws {
            let skillURL = URL(fileURLWithPath: path)
            let coordinator = SkillLifecycleCoordinator()

            let reviewerName = reviewer ?? NSFullUserName()
            let state = try await coordinator.approve(
                at: skillURL,
                reviewer: reviewerName,
                notes: notes.isEmpty ? "Approved for publication" : notes
            )

            print("✓ Approved \(state.skillSlug)")
            print("  Reviewer: \(reviewerName)")
            print("  Stage: \(state.stage.displayName)")
            if !notes.isEmpty {
                print("  Notes: \(notes)")
            }
        }
    }
}

// MARK: - Publish

extension WorkflowCommand {
    /// Publish a skill
    struct Publish: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Publish a skill to the target environment.",
            discussion: """
            Publishes a skill by:
            1. Incrementing the version in SKILL.md
            2. Advancing to 'published' stage
            3. Updating the search index

            Requires the skill to be in the 'approved' stage.
            """
        )

        @Argument var path: String

        @Option var changelog: String = "Published"

        @Option var publisher: String?

        func run() async throws {
            let skillURL = URL(fileURLWithPath: path)
            let coordinator = SkillLifecycleCoordinator()

            let publisherName = publisher ?? "system"
            let state = try await coordinator.publish(
                at: skillURL,
                changelog: changelog,
                publisher: publisherName
            )

            print("✓ Published \(state.skillSlug)")
            print("  Stage: \(state.stage.displayName)")
            print("  Changelog: \(changelog)")

            // Show version info
            let skillFile = skillURL.appendingPathComponent("SKILL.md")
            if let content = try? String(contentsOf: skillFile, encoding: .utf8),
               let version = content.split(separator: "\n")
                .first(where: { $0.contains("version:") }) {
                print("  \(version)")
            }
        }
    }
}

// MARK: - Sync

extension WorkflowCommand {
    /// Sync a skill across multiple agent targets
    struct Sync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sync a skill across multiple agent targets.",
            discussion: """
            Synchronizes a skill's SKILL.md file across multiple agent skill directories.
            Useful for maintaining the same skill across Codex, Claude, and Copilot.
            """
        )

        @Argument var path: String

        @Option var targets: String

        @Flag var skipContent: Bool = false

        func run() async throws {
            let skillURL = URL(fileURLWithPath: path)
            let coordinator = SkillLifecycleCoordinator()

            let targetAgents = targets.split(separator: ",").compactMap { AgentKind(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }

            guard !targetAgents.isEmpty else {
                throw WorkflowValidationError(
                    code: "invalid_targets",
                    message: "No valid targets specified. Available: codex, claude, copilot",
                    severity: WorkflowValidationError.Severity.error
                )
            }

            let results = try await coordinator.syncAcrossAgents(
                at: skillURL,
                targets: targetAgents,
                syncContent: !skipContent
            )

            print("Sync Results:")
            for (agent, result) in results {
                switch result {
                case .success(let state):
                    print("  ✓ \(agent.rawValue.capitalized): \(state.skillSlug)")
                case .failure(let error):
                    print("  ✗ \(agent.rawValue.capitalized): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Status

extension WorkflowCommand {
    /// Show workflow status for a skill
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show the current workflow status of a skill.",
            discussion: """
            Displays detailed workflow information including:
            - Current stage
            - Validation results
            - Review notes and reviewer
            - Version history
            """
        )

        @Argument var skillSlug: String

        @Option var format: String = "text"

        func run() async throws {
            let store = WorkflowStateStore()
            guard let state = await store.get(skillSlug: skillSlug) else {
                throw WorkflowValidationError(
                    code: "workflow_not_found",
                    message: "No workflow state found for skill: \(skillSlug)",
                    severity: WorkflowValidationError.Severity.error
                )
            }

            if format == "json" {
                outputJSON(state)
            } else {
                outputText(state)
            }
        }

        private func outputText(_ state: WorkflowState) {
            print("Workflow Status: \(state.skillSlug)")
            print("")
            print("  Stage: \(state.stage.icon) \(state.stage.displayName)")
            print("  Created: \(formatDate(state.createdAt))")
            print("  Updated: \(formatDate(state.updatedAt))")
            print("  Valid: \(state.isValid ? "✓" : "✗")")

            if let reviewer = state.reviewer {
                print("  Reviewer: \(reviewer)")
            }

            if !state.reviewNotes.isEmpty {
                print("  Notes: \(state.reviewNotes)")
            }

            if !state.validationResults.isEmpty {
                print("")
                print("  Validation:")
                for result in state.validationResults {
                    let icon = result.severity == .error ? "✗" : "⚠"
                    print("    \(icon) \(result.message)")
                }
            }

            if !state.versionHistory.isEmpty {
                print("")
                print("  History:")
                for entry in state.versionHistory.reversed().prefix(5) {
                    print("    \(entry.version) [\(entry.stage.displayName)] by \(entry.changedBy)")
                    if !entry.changelog.isEmpty {
                        print("      \(entry.changelog)")
                    }
                }
            }
        }

        private func outputJSON(_ state: WorkflowState) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            guard let data = try? encoder.encode(state),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }

            print(json)
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - List

extension WorkflowCommand {
    /// List skills by workflow stage
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List skills by workflow stage.",
            discussion: """
            Lists all skills, optionally filtered by stage.
            Shows workflow state information for each skill.
            """
        )

        @Option var stage: String?

        @Option var agent: String?

        @Option var format: String = "text"

        func run() async throws {
            let store = WorkflowStateStore()

            var workflows: [WorkflowState]

            if let stageName = stage {
                guard let stageEnum = Stage.allCases.first(where: { $0.rawValue.lowercased() == stageName.lowercased() }) else {
                    throw WorkflowValidationError(
                        code: "invalid_stage",
                        message: "Invalid stage: \(stageName). Available: \(Stage.allCases.map { $0.rawValue }.joined(separator: ", "))",
                        severity: WorkflowValidationError.Severity.error
                    )
                }
                workflows = await store.list(stage: stageEnum)
            } else if let agentName = agent {
                let agentKind = AgentKind(rawValue: agentName)
                guard let agentKind = agentKind else {
                    throw WorkflowValidationError(
                        code: "invalid_agent",
                        message: "Invalid agent: \(agentName). Available: codex, claude, copilot",
                        severity: WorkflowValidationError.Severity.error
                    )
                }
                workflows = await store.list(agent: agentKind)
            } else {
                workflows = await store.list()
            }

            if format == "json" {
                outputJSON(workflows)
            } else {
                outputText(workflows)
            }
        }

        private func outputText(_ workflows: [WorkflowState]) {
            if workflows.isEmpty {
                print("No workflows found")
                return
            }

            print("Workflows (\(workflows.count)):")
            print("")

            for state in workflows {
                print("\(state.stage.icon) \(state.skillSlug)")
                print("  Stage: \(state.stage.displayName)")
                print("  Updated: \(formatDate(state.updatedAt))")

                if !state.validationResults.isEmpty {
                    print("  Issues: \(state.errorCount) error(s), \(state.warningCount) warning(s)")
                }

                print("")
            }
        }

        private func outputJSON(_ workflows: [WorkflowState]) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            guard let data = try? encoder.encode(workflows),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }

            print(json)
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - Dashboard

extension WorkflowCommand {
    /// Show workflow dashboard overview
    struct Dashboard: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show a dashboard overview of all workflows.",
            discussion: """
            Displays a summary of all workflow states including:
            - Total skills in workflow
            - Skills by stage
            - Recent activity
            """
        )

        func run() async throws {
            let store = WorkflowStateStore()
            let allWorkflows = await store.list()

            print("Workflow Dashboard")
            print("")

            // Summary
            print("Summary:")
            print("  Total Skills: \(allWorkflows.count)")

            let byStage = Dictionary(grouping: allWorkflows, by: { $0.stage })
            for stage in Stage.allCases {
                let count = byStage[stage]?.count ?? 0
                print("  \(stage.icon) \(stage.displayName): \(count)")
            }

            // Recent activity
            print("")
            print("Recent Activity (last 5):")
            for state in allWorkflows.prefix(5) {
                print("  \(state.skillSlug) → \(state.stage.displayName)")
                print("    Updated: \(relativeTime(state.updatedAt))")
            }

            // Issues
            let withErrors = allWorkflows.filter { !$0.isValid }
            if !withErrors.isEmpty {
                print("")
                print("Skills Needing Attention:")
                for state in withErrors {
                    print("  ✗ \(state.skillSlug)")
                    print("    Errors: \(state.errorCount), Warnings: \(state.warningCount)")
                }
            }
        }

        private func relativeTime(_ date: Date) -> String {
            let seconds = Int(Date().timeIntervalSince(date))

            if seconds < 60 { return "just now" }
            if seconds < 3600 { return "\(seconds / 60)m ago" }
            if seconds < 86400 { return "\(seconds / 3600)h ago" }
            return "\(seconds / 86400)d ago"
        }
    }
}
