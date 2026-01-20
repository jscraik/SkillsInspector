import Foundation
import ArgumentParser
import SkillsCore

/// Spec commands for exporting, importing, and diffing skill specifications
struct Spec: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export and import skill specifications as JSON.",
        subcommands: [Export.self, Import.self, Diff.self]
    )
}

// MARK: - Export

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export a skill as a JSON spec.",
        discussion: """
        Exports a SKILL.md file as a structured JSON specification.

        Example:
            skillsctl spec export my-skill --output spec.json
        """
    )

    @Argument(help: "Path to the skill directory (containing SKILL.md)")
    var skillPath: String

    @Option(name: .long, help: "Output JSON file path (defaults to stdout)")
    var output: String?

    @Option(name: .long, help: "Output format: json|pretty (default: pretty)")
    var format: String = "pretty"

    @Flag(name: .long, help: "Include validation errors in output")
    var includeValidation: Bool = false

    func run() async throws {
        let skillURL = URL(fileURLWithPath: skillPath)

        // Find SKILL.md
        let skillFileURL: URL
        if skillURL.hasDirectoryPath {
            skillFileURL = skillURL.appendingPathComponent("SKILL.md")
        } else {
            skillFileURL = skillURL
        }

        // Read SKILL.md
        guard let text = try? String(contentsOf: skillFileURL, encoding: .utf8) else {
            fputs("Error: Cannot read SKILL.md at \(skillFileURL.path)\n", stderr)
            throw ExitCode(1)
        }

        // Parse into SkillSpec
        let spec = SkillSpec.parse(text)

        // Optionally validate
        if includeValidation {
            // Detect agent from path or default to codex
            let agent = detectAgent(from: skillURL)
            let errors = spec.validate(for: agent)
            if !errors.isEmpty {
                fputs("Validation errors:\n", stderr)
                for error in errors {
                    if let desc = error.errorDescription {
                        fputs("  - \(desc)\n", stderr)
                    }
                }
            }
        }

        // Convert to JSON
        let prettyPrint = format.lowercased() == "pretty"
        let jsonData = try spec.toJSON(prettyPrint: prettyPrint)

        // Output
        if let outputPath = output {
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            print("Exported spec to \(outputPath)")
        } else {
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }

    private func detectAgent(from path: URL) -> AgentKind {
        let pathString = path.path.lowercased()
        if pathString.contains("claude") {
            return .claude
        } else if pathString.contains("copilot") {
            return .copilot
        } else {
            return .codex
        }
    }
}

// MARK: - Import

struct Import: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Import a JSON spec and convert to SKILL.md.",
        discussion: """
        Imports a JSON specification and converts it back to SKILL.md format.

        Example:
            skillsctl spec import spec.json --validate
        """
    )

    @Argument(help: "Path to the JSON spec file")
    var inputFile: String

    @Option(name: .long, help: "Output directory for SKILL.md (defaults to skill name in current directory)")
    var output: String?

    @Flag(name: .long, help: "Validate the imported spec")
    var validate: Bool = false

    @Option(name: .long, help: "Agent to validate for: codex|claude|copilot (default: codex)")
    var agent: String = "codex"

    func run() async throws {
        let inputURL = URL(fileURLWithPath: inputFile)

        // Read JSON
        guard let jsonData = try? Data(contentsOf: inputURL) else {
            fputs("Error: Cannot read JSON file at \(inputURL.path)\n", stderr)
            throw ExitCode(1)
        }

        // Parse into SkillSpec
        let spec: SkillSpec
        do {
            spec = try SkillSpec.fromJSON(jsonData)
        } catch {
            fputs("Error: Failed to parse JSON: \(error.localizedDescription)\n", stderr)
            throw ExitCode(1)
        }

        // Optionally validate
        if validate {
            let agentKind = parseAgent(agent)
            let errors = spec.validate(for: agentKind)
            if !errors.isEmpty {
                fputs("Validation errors:\n", stderr)
                for error in errors {
                    if let desc = error.errorDescription {
                        fputs("  - \(desc)\n", stderr)
                    }
                }
                // Check for blocking errors
                let hasErrors = errors.contains { $0.severity == .error }
                if hasErrors {
                    throw ExitCode(1)
                }
            } else {
                print("✓ Validation passed")
            }
        }

        // Convert to markdown
        let markdown = spec.toMarkdown()

        // Determine output location
        let outputURL: URL
        if let outputPath = output {
            outputURL = URL(fileURLWithPath: outputPath).appendingPathComponent("SKILL.md")
        } else if let skillName = spec.metadata.name {
            outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(skillName)
                .appendingPathComponent("SKILL.md")
        } else {
            outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("SKILL.md")
        }

        // Create directory if needed
        if outputURL.hasDirectoryPath {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }

        // Write SKILL.md
        let parentDir = outputURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        print("Imported SKILL.md to \(outputURL.path)")
    }

    private func parseAgent(_ string: String) -> AgentKind {
        switch string.lowercased() {
        case "claude": return .claude
        case "copilot": return .copilot
        case "codex", "codexskillmanager": return .codex
        default: return .codex
        }
    }
}

// MARK: - Diff

struct Diff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show semantic differences between two specs.",
        discussion: """
        Compares two skill specifications and shows semantic differences.

        Example:
            skillsctl spec diff spec1.json spec2.json
        """
    )

    @Argument(help: "First spec file (original)")
    var file1: String

    @Argument(help: "Second spec file (modified)")
    var file2: String

    @Option(name: .long, help: "Output format: text|json (default: text)")
    var format: String = "text"

    @Option(name: .long, help: "Agent context for validation: codex|claude|copilot")
    var agent: String = "codex"

    func run() async throws {
        let url1 = URL(fileURLWithPath: file1)
        let url2 = URL(fileURLWithPath: file2)

        // Read both specs
        guard let data1 = try? Data(contentsOf: url1) else {
            fputs("Error: Cannot read \(file1)\n", stderr)
            throw ExitCode(1)
        }

        guard let data2 = try? Data(contentsOf: url2) else {
            fputs("Error: Cannot read \(file2)\n", stderr)
            throw ExitCode(1)
        }

        // Parse specs
        let spec1: SkillSpec
        let spec2: SkillSpec

        do {
            spec1 = try SkillSpec.fromJSON(data1)
            spec2 = try SkillSpec.fromJSON(data2)
        } catch {
            fputs("Error: Failed to parse JSON: \(error.localizedDescription)\n", stderr)
            throw ExitCode(1)
        }

        // Compute differences
        let differences = spec1.diff(spec2)

        // Output results
        if differences.isEmpty {
            print("✓ No differences found")
            return
        }

        switch format.lowercased() {
        case "json":
            try outputAsJSON(differences, spec1: spec1, spec2: spec2)
        case "text":
            outputAsText(differences)
        default:
            fputs("Error: Unknown format '\(format)'. Use 'text' or 'json'.\n", stderr)
            throw ExitCode(1)
        }
    }

    private func outputAsText(_ differences: [SkillSpec.SpecDiff]) {
        print("Differences found: \(differences.count)\n")

        for diff in differences {
            switch diff {
            case .metadataChanged(let key, let old, let new):
                print("  [metadata] \(key):")
                print("    - \(old ?? "(nil)")")
                print("    + \(new ?? "(nil)")")

            case .sectionsChanged(let count, let otherCount):
                print("  [sections] count: \(count) → \(otherCount)")

            case .sectionChanged(let index, let field, let old, let new):
                print("  [section #\(index)] \(field):")
                print("    - \(old)")
                print("    + \(new)")

            case .sectionAdded(let index, let heading):
                print("  [section #\(index)] added: \(heading)")

            case .sectionRemoved(let index, let heading):
                print("  [section #\(index)] removed: \(heading)")
            }
            print()
        }
    }

    private func outputAsJSON(_ differences: [SkillSpec.SpecDiff], spec1: SkillSpec, spec2: SkillSpec) throws {
        struct DiffOutput: Codable {
            let count: Int
            let differences: [DiffItem]
            let spec1: SkillSpec
            let spec2: SkillSpec

            struct DiffItem: Codable {
                let type: String
                let details: String
            }
        }

        var items: [DiffOutput.DiffItem] = []
        for diff in differences {
            let details: String
            switch diff {
            case .metadataChanged(let key, let old, let new):
                details = "\(key): '\(old ?? "nil")' → '\(new ?? "nil")'"
            case .sectionsChanged(let count, let otherCount):
                details = "count: \(count) → \(otherCount)"
            case .sectionChanged(let index, let field, let old, let new):
                details = "[#\(index)] \(field): '\(old.prefix(50))' → '\(new.prefix(50))'"
            case .sectionAdded(let index, let heading):
                details = "[#\(index)] added: \(heading)"
            case .sectionRemoved(let index, let heading):
                details = "[#\(index)] removed: \(heading)"
            }

            let type: String
            switch diff {
            case .metadataChanged: type = "metadata"
            case .sectionsChanged: type = "sections"
            case .sectionChanged: type = "section"
            case .sectionAdded: type = "added"
            case .sectionRemoved: type = "removed"
            }

            items.append(DiffOutput.DiffItem(type: type, details: details))
        }

        let output = DiffOutput(count: differences.count, differences: items, spec1: spec1, spec2: spec2)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)

        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    }
}
