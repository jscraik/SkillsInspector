import Foundation

/// Template for creating new skills with consistent structure
public struct SkillTemplate: Codable, Sendable {
    /// Template name
    public let name: String

    /// Template description
    public let description: String

    /// Template category (e.g., "automation", "analysis", "development")
    public let category: TemplateCategory

    /// Default agent for this template
    public let defaultAgent: AgentKind

    /// Template metadata
    public let metadata: TemplateMetadata

    /// Template sections (markdown content)
    public let sections: [TemplateSection]

    /// Template category
    public enum TemplateCategory: String, Codable, Sendable, CaseIterable {
        case automation = "Automation"
        case analysis = "Analysis"
        case development = "Development"
        case security = "Security"
        case testing = "Testing"
        case documentation = "Documentation"
        case utility = "Utility"

        public var icon: String {
            switch self {
            case .automation: return "gearshape.2"
            case .analysis: return "chart.bar.doc.horizontal"
            case .development: return "hammer"
            case .security: return "shield"
            case .testing: return "checkmark.circle"
            case .documentation: return "doc.text"
            case .utility: return "wrench.and.screwdriver"
            }
        }
    }

    /// Template metadata
    public struct TemplateMetadata: Codable, Sendable {
        /// Minimum agent version required
        public let minAgentVersion: String?

        /// Required dependencies
        public let dependencies: [String]

        /// Suggested tags
        public let tags: [String]

        /// Example usage
        public let exampleUsage: String?

        public init(
            minAgentVersion: String? = nil,
            dependencies: [String] = [],
            tags: [String] = [],
            exampleUsage: String? = nil
        ) {
            self.minAgentVersion = minAgentVersion
            self.dependencies = dependencies
            self.tags = tags
            self.exampleUsage = exampleUsage
        }
    }

    /// Template section
    public struct TemplateSection: Codable, Sendable {
        /// Section heading (without # symbols)
        public let heading: String

        /// Section content
        public let content: String

        /// Heading level (1-6)
        public let level: Int

        public init(heading: String, content: String, level: Int = 2) {
            self.heading = heading
            self.content = content
            self.level = level
        }
    }

    public init(
        name: String,
        description: String,
        category: TemplateCategory,
        defaultAgent: AgentKind,
        metadata: TemplateMetadata,
        sections: [TemplateSection]
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.defaultAgent = defaultAgent
        self.metadata = metadata
        self.sections = sections
    }

    /// Generate skill markdown from template
    public func render(
        skillName: String,
        skillDescription: String,
        author: String,
        customTags: [String]? = nil
    ) -> String {
        let tags = customTags ?? metadata.tags

        var result = """
---
name: \(skillName)
description: \(skillDescription)
version: 1.0.0
author: \(author)
tags: \(tags.sorted().joined(separator: ", "))
"""

        if let minVersion = metadata.minAgentVersion {
            result += "\nminAgentVersion: \(minVersion)"
        }

        if !metadata.dependencies.isEmpty {
            result += "\ndependencies:\n"
            for dep in metadata.dependencies {
                result += "  - \(dep)\n"
            }
        }

        result += """
---

# \(skillName)

\(skillDescription)

"""

        // Add template sections
        for section in sections {
            let prefix = String(repeating: "#", count: section.level)
            result += "\n\(prefix) \(section.heading)\n\n"
            result += "\(section.content)\n\n"
        }

        return result
    }

    /// Get built-in templates
    public static func builtInTemplates() -> [SkillTemplate] {
        return [
            automationTemplate,
            analysisTemplate,
            developmentTemplate,
            securityTemplate,
            testingTemplate
        ]
    }

    /// Find template by name
    public static func find(named name: String) -> SkillTemplate? {
        return builtInTemplates().first { $0.name.lowercased() == name.lowercased() }
    }
}

// MARK: - Built-in Templates

extension SkillTemplate {
    /// Basic automation template
    public static var automationTemplate: SkillTemplate {
        SkillTemplate(
            name: "Automation",
            description: "Template for automation skills that perform tasks",
            category: .automation,
            defaultAgent: .codex,
            metadata: TemplateMetadata(
                minAgentVersion: "1.0.0",
                tags: ["automation", "productivity", "workflow"],
                exampleUsage: "Run the skill with: /skill-name [options]"
            ),
            sections: [
                TemplateSection(
                    heading: "Overview",
                    content: """
This skill automates common tasks to improve productivity.
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Usage",
                    content: """
```bash
# Basic usage
command [options]

# With specific options
command --option1 value1 --option2 value2
```
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Requirements",
                    content: """
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Configuration",
                    content: """
Edit the configuration section below:

```yaml
# Configuration
option1: value1
option2: value2
```
""",
                    level: 2
                )
            ]
        )
    }

    /// Analysis template
    public static var analysisTemplate: SkillTemplate {
        SkillTemplate(
            name: "Analysis",
            description: "Template for analysis and inspection skills",
            category: .analysis,
            defaultAgent: .claude,
            metadata: TemplateMetadata(
                minAgentVersion: "1.0.0",
                tags: ["analysis", "inspection", "reporting"],
                exampleUsage: "Use this skill to analyze and report on code or data"
            ),
            sections: [
                TemplateSection(
                    heading: "Purpose",
                    content: """
This skill provides deep analysis and generates detailed reports.
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Analysis Targets",
                    content: """
- Code repositories
- Data files
- Configuration files
- Documentation
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Output Format",
                    content: """
Results are provided in the following format:

1. **Summary**: High-level overview
2. **Details**: Comprehensive findings
3. **Recommendations**: Actionable suggestions
4. **Metrics**: Quantitative measurements
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Usage Examples",
                    content: """
```bash
# Analyze a directory
analyze --path ./src

# Analyze with specific rules
analyze --path ./src --rules security,performance

# Generate report
analyze --path ./src --output report.md
```
""",
                    level: 2
                )
            ]
        )
    }

    /// Development template
    public static var developmentTemplate: SkillTemplate {
        SkillTemplate(
            name: "Development",
            description: "Template for development and coding assistance",
            category: .development,
            defaultAgent: .codex,
            metadata: TemplateMetadata(
                minAgentVersion: "1.0.0",
                tags: ["development", "coding", "programming"],
                exampleUsage: "Use this skill for code generation and refactoring"
            ),
            sections: [
                TemplateSection(
                    heading: "Capabilities",
                    content: """
This skill assists with software development tasks:

- **Code Generation**: Create new code from specifications
- **Refactoring**: Improve existing code structure
- **Debugging**: Identify and fix issues
- **Documentation**: Generate code documentation
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Supported Languages",
                    content: """
- Swift
- TypeScript/JavaScript
- Python
- Rust
- Go
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Best Practices",
                    content: """
When using this skill:

1. Provide clear requirements
2. Include context about the codebase
3. Specify coding standards
4. Review generated code before committing
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Examples",
                    content: """
```swift
// Example code generation
generate function: authenticateUser

// Example refactoring
refactor: improve error handling in AuthService
```
""",
                    level: 2
                )
            ]
        )
    }

    /// Security template
    public static var securityTemplate: SkillTemplate {
        SkillTemplate(
            name: "Security",
            description: "Template for security scanning and auditing",
            category: .security,
            defaultAgent: .claude,
            metadata: TemplateMetadata(
                minAgentVersion: "1.0.0",
                tags: ["security", "audit", "vulnerability"],
                exampleUsage: "Use this skill to identify security issues"
            ),
            sections: [
                TemplateSection(
                    heading: "Security Scope",
                    content: """
This skill performs comprehensive security analysis:

- **Vulnerability Detection**: Identify known CVEs
- **Code Scanning**: Find security anti-patterns
- **Dependency Analysis**: Check for vulnerable dependencies
- **Configuration Review**: Validate security settings
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Scan Types",
                    content: """
1. **SAST**: Static Application Security Testing
2. **DAST**: Dynamic Application Security Testing
3. **SCA**: Software Composition Analysis
4. **Configuration**: Security configuration audit
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Severity Levels",
                    content: """
- **Critical**: Immediate action required
- **High**: Should be fixed soon
- **Medium**: Plan to fix
- **Low**: Nice to have
- **Info**: Informational
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Reporting",
                    content: """
Security reports include:

- Executive summary
- Detailed findings with CVSS scores
- Remediation recommendations
- Compliance status
""",
                    level: 2
                )
            ]
        )
    }

    /// Testing template
    public static var testingTemplate: SkillTemplate {
        SkillTemplate(
            name: "Testing",
            description: "Template for test generation and execution",
            category: .testing,
            defaultAgent: .codex,
            metadata: TemplateMetadata(
                minAgentVersion: "1.0.0",
                tags: ["testing", "quality", "tdd"],
                exampleUsage: "Use this skill for test generation and coverage"
            ),
            sections: [
                TemplateSection(
                    heading: "Testing Approach",
                    content: """
This skill follows Test-Driven Development (TDD) principles:

1. **Red**: Write failing test
2. **Green**: Make test pass
3. **Refactor**: Improve code
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Test Types",
                    content: """
- **Unit Tests**: Test individual components
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test complete workflows
- **Performance Tests**: Measure performance characteristics
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Coverage Goals",
                    content: """
- Statement Coverage: >80%
- Branch Coverage: >70%
- Critical Path: 100%
""",
                    level: 2
                ),
                TemplateSection(
                    heading: "Usage",
                    content: """
```bash
# Generate tests for a function
test --function authenticateUser

# Generate test suite
test --suite AuthService

# Run tests with coverage
test --run --coverage
```
""",
                    level: 2
                )
            ]
        )
    }
}
