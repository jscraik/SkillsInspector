import Foundation

/// A structured representation of a SKILL.md file that enables deterministic
/// round-trip conversion between markdown and JSON formats.
public struct SkillSpec: Codable, Sendable, Equatable {
    /// Metadata extracted from the YAML frontmatter block
    public var metadata: Metadata

    /// Content sections parsed from the markdown body
    public var sections: [Section]

    /// Validation errors accumulated during parsing or validation
    public var errors: [ValidationError] = []

    public init(metadata: Metadata, sections: [Section], errors: [ValidationError] = []) {
        self.metadata = metadata
        self.sections = sections
        self.errors = errors
    }

    // MARK: - Metadata

    /// Frontmatter metadata from SKILL.md
    public struct Metadata: Codable, Sendable, Equatable {
        /// Unique identifier/slug for the skill (e.g., "prompt-booster")
        public var name: String?

        /// Human-readable description
        public var description: String?

        /// Semantic version (e.g., "1.2.0")
        public var version: String?

        /// Author/creator information
        public var author: String?

        /// List of tags/categories
        public var tags: [String]?

        /// Minimum agent version required
        public var minAgentVersion: String?

        /// Target agent platforms (codex, claude, copilot)
        public var targets: [String]?

        public init(
            name: String? = nil,
            description: String? = nil,
            version: String? = nil,
            author: String? = nil,
            tags: [String]? = nil,
            minAgentVersion: String? = nil,
            targets: [String]? = nil
        ) {
            self.name = name
            self.description = description
            self.version = version
            self.author = author
            self.tags = tags
            self.minAgentVersion = minAgentVersion
            self.targets = targets
        }

        /// Convert to YAML frontmatter block
        func toYAML() -> String {
            var lines: [String] = ["---"]
            if let name = name { lines.append("name: \(name)") }
            if let description = description { lines.append("description: \(description)") }
            if let version = version { lines.append("version: \(version)") }
            if let author = author { lines.append("author: \(author)") }
            if let tags = tags, !tags.isEmpty { lines.append("tags: \(tags.joined(separator: ", ")))") }
            if let minAgentVersion = minAgentVersion { lines.append("minAgentVersion: \(minAgentVersion)") }
            if let targets = targets, !targets.isEmpty { lines.append("targets: \(targets.joined(separator: ", ")))") }
            lines.append("---")
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Section

    /// A content section from the markdown body
    public struct Section: Codable, Sendable, Equatable {
        /// Section type (heading level determines hierarchy)
        public enum Level: Int, Codable, Sendable {
            case h1 = 1
            case h2 = 2
            case h3 = 3
            case h4 = 4
            case h5 = 5
            case h6 = 6
        }

        /// Heading level (1-6)
        public var level: Level

        /// Section heading text (without # symbols)
        public var heading: String

        /// Section content (paragraphs, lists, code blocks, etc.)
        public var content: String

        /// Child subsections
        public var subsections: [Section] = []

        public init(level: Level, heading: String, content: String, subsections: [Section] = []) {
            self.level = level
            self.heading = heading
            self.content = content
            self.subsections = subsections
        }

        /// Convert section to markdown format
        func toMarkdown(indent: Int = 0) -> String {
            let prefix = String(repeating: "#", count: level.rawValue) + " "
            let indentation = String(repeating: "  ", count: indent)
            var result = "\(indentation)\(prefix)\(heading)\n"

            if !content.isEmpty {
                result += "\(indentation)\(content)\n"
            }

            for subsection in subsections {
                result += subsection.toMarkdown(indent: indent + 1)
            }

            return result
        }
    }

    // MARK: - ValidationError

    /// A validation error with context
    public struct ValidationError: Codable, Sendable, Equatable, LocalizedError {
        /// Unique identifier for this error type
        public var code: String

        /// Human-readable error message
        public var message: String

        /// Severity level
        public var severity: Severity

        /// Line number where error occurred (1-indexed)
        public var line: Int?

        /// Column number where error occurred (1-indexed)
        public var column: Int?

        public enum Severity: String, Codable, Sendable {
            case error
            case warning
            case info
        }

        public init(code: String, message: String, severity: Severity, line: Int? = nil, column: Int? = nil) {
            self.code = code
            self.message = message
            self.severity = severity
            self.line = line
            self.column = column
        }

        public var errorDescription: String? {
            var result = "[\(severity.rawValue.uppercased())] \(code): \(message)"
            if let line = line {
                if let column = column {
                    result += " (line \(line):\(column))"
                } else {
                    result += " (line \(line))"
                }
            }
            return result
        }
    }

    // MARK: - Parsing

    /// Parse a SKILL.md file into a SkillSpec
    /// - Parameter text: The raw markdown content
    /// - Returns: A parsed SkillSpec with any validation errors
    public static func parse(_ text: String) -> SkillSpec {
        // Parse frontmatter
        let frontmatter = FrontmatterParser.parseTopBlock(text)

        let metadata = Metadata(
            name: frontmatter["name"],
            description: frontmatter["description"],
            version: frontmatter["version"],
            author: frontmatter["author"],
            tags: frontmatter["tags"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            minAgentVersion: frontmatter["minAgentVersion"],
            targets: frontmatter["targets"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        )

        // Parse markdown body into sections
        let sections = parseSections(text: text)

        return SkillSpec(metadata: metadata, sections: sections)
    }

    /// Parse markdown content into structured sections
    private static func parseSections(text: String) -> [Section] {
        guard let bodyStart = extractBodyStart(from: text) else {
            return []
        }

        let body = String(text.dropFirst(bodyStart))
        var sections: [Section] = []
        var currentSection: Section?
        var currentContent: [String] = []

        let lines = body.split(whereSeparator: \.isNewline)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for heading
            if trimmed.hasPrefix("#") {
                let headingMatch = trimmed.dropFirst().prefix(while: { $0 == "#" })
                let level = min(headingMatch.count + 1, 6)

                if let hashIndex = trimmed.firstIndex(of: " ") {
                    let heading = String(trimmed[trimmed.index(after: hashIndex)...])

                    // Save previous section
                    if var prev = currentSection {
                        prev.content = currentContent.joined(separator: "\n")
                        sections.append(prev)
                    }

                    currentSection = Section(level: Section.Level(rawValue: level) ?? .h1, heading: heading, content: "")
                    currentContent = []
                }
            } else if !trimmed.isEmpty {
                currentContent.append(String(line))
            }
        }

        // Don't forget the last section
        if var last = currentSection {
            last.content = currentContent.joined(separator: "\n")
            sections.append(last)
        }

        return sections
    }

    /// Find where the markdown body starts (after frontmatter)
    private static func extractBodyStart(from text: String) -> Int? {
        let lines = text.split(whereSeparator: \.isNewline)

        guard lines.first == "---" else { return 0 }

        var index = 1
        while index < lines.count {
            if lines[index] == "---" {
                return index + 1
            }
            index += 1
        }

        return 0
    }


    // MARK: - Serialization

    /// Convert SkillSpec back to SKILL.md format
    public func toMarkdown() -> String {
        var result = metadata.toYAML()
        result += "\n\n"

        for section in sections {
            result += section.toMarkdown()
            result += "\n"
        }

        return result
    }

    /// Convert SkillSpec to JSON
    public func toJSON(prettyPrint: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrint ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Create SkillSpec from JSON
    public static func fromJSON(_ data: Data) throws -> SkillSpec {
        let decoder = JSONDecoder()
        return try decoder.decode(SkillSpec.self, from: data)
    }

    // MARK: - Validation

    /// Validate the spec for a specific agent platform
    /// - Parameter agent: The target agent kind
    /// - Returns: Array of validation errors (empty if valid)
    public func validate(for agent: AgentKind) -> [ValidationError] {
        var errors: [ValidationError] = []

        // Validate metadata
        if metadata.name == nil || metadata.name!.isEmpty {
            errors.append(ValidationError(
                code: "metadata.name.missing",
                message: "Skill name is required in frontmatter",
                severity: .error,
                line: 1
            ))
        }

        if let name = metadata.name {
            switch agent {
            case .claude:
                // Claude requires kebab-case names
                if !name.isEmpty && name != name.lowercased() || name.contains("_") {
                    errors.append(ValidationError(
                        code: "metadata.name.pattern",
                        message: "Claude skill names must be kebab-case (lowercase with hyphens)",
                        severity: .error,
                        line: 1
                    ))
                }
            case .codex, .codexSkillManager, .copilot:
                // Other agents are more lenient
                break
            }
        }

        // Validate version format
        if let version = metadata.version {
            let versionPattern = /^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.]+))?$/
            do {
                if try versionPattern.wholeMatch(in: version) == nil {
                    errors.append(ValidationError(
                        code: "metadata.version.format",
                        message: "Version must follow semantic versioning (e.g., 1.2.0)",
                        severity: .warning,
                        line: 1
                    ))
                }
            } catch {
                errors.append(ValidationError(
                    code: "metadata.version.format",
                    message: "Version must follow semantic versioning (e.g., 1.2.0)",
                    severity: .warning,
                    line: 1
                ))
            }
        }

        // Validate sections
        if sections.isEmpty {
            errors.append(ValidationError(
                code: "sections.empty",
                message: "SKILL.md must contain at least one section",
                severity: .warning
            ))
        }

        return errors
    }

    // MARK: - Diff

    /// Compute semantic differences between two specs
    /// - Parameter other: The other spec to compare against
    /// - Returns: Array of differences
    public func diff(_ other: SkillSpec) -> [SpecDiff] {
        var differences: [SpecDiff] = []

        // Compare metadata
        if metadata.name != other.metadata.name {
            differences.append(.metadataChanged(key: "name", old: metadata.name, new: other.metadata.name))
        }

        if metadata.description != other.metadata.description {
            differences.append(.metadataChanged(key: "description", old: metadata.description, new: other.metadata.description))
        }

        if metadata.version != other.metadata.version {
            differences.append(.metadataChanged(key: "version", old: metadata.version, new: other.metadata.version))
        }

        // Compare sections
        if sections.count != other.sections.count {
            differences.append(.sectionsChanged(
                count: sections.count,
                otherCount: other.sections.count
            ))
        }

        // Compare section content
        for (index, section) in sections.enumerated() {
            if index < other.sections.count {
                let otherSection = other.sections[index]
                if section.heading != otherSection.heading {
                    differences.append(.sectionChanged(
                        index: index,
                        field: "heading",
                        old: section.heading,
                        new: otherSection.heading
                    ))
                }

                if section.content != otherSection.content {
                    differences.append(.sectionChanged(
                        index: index,
                        field: "content",
                        old: section.content.prefix(50) + "...",
                        new: otherSection.content.prefix(50) + "..."
                    ))
                }
            }
        }

        return differences
    }

    /// Represents a semantic difference between two specs
    public enum SpecDiff: Equatable {
        case metadataChanged(key: String, old: String?, new: String?)
        case sectionsChanged(count: Int, otherCount: Int)
        case sectionChanged(index: Int, field: String, old: String, new: String)
        case sectionAdded(index: Int, heading: String)
        case sectionRemoved(index: Int, heading: String)
    }
}
