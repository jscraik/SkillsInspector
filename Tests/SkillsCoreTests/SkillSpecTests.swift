import XCTest
@testable import SkillsCore

final class SkillSpecTests: XCTestCase {

    // MARK: - Round-Trip Conversion Tests

    func testParseAndToMarkdownRoundTrip() throws {
        let original = """
        ---
        name: example-skill
        description: An example skill for testing
        version: 1.0.0
        author: Test Author
        tags: testing, example
        ---

        # Introduction

        This is an example skill that demonstrates parsing.

        ## Usage

        Use this skill as a reference for creating your own.

        ### Example

        Here's a code example:

        ```swift
        let spec = SkillSpec.parse(markdown)
        ```
        """

        // Parse the markdown
        let spec = SkillSpec.parse(original)

        // Verify metadata was parsed correctly
        XCTAssertEqual(spec.metadata.name, "example-skill")
        XCTAssertEqual(spec.metadata.description, "An example skill for testing")
        XCTAssertEqual(spec.metadata.version, "1.0.0")
        XCTAssertEqual(spec.metadata.author, "Test Author")
        XCTAssertEqual(spec.metadata.tags, ["testing", "example"])

        // Verify sections were parsed
        XCTAssertFalse(spec.sections.isEmpty, "Should have parsed sections")

        // Convert back to markdown
        let regenerated = spec.toMarkdown()

        // Parse again to verify round-trip
        let roundTripSpec = SkillSpec.parse(regenerated)

        // Verify metadata survived round-trip
        XCTAssertEqual(roundTripSpec.metadata.name, "example-skill")
        XCTAssertEqual(roundTripSpec.metadata.description, "An example skill for testing")
        XCTAssertEqual(roundTripSpec.metadata.version, "1.0.0")
        XCTAssertEqual(roundTripSpec.metadata.author, "Test Author")
    }

    func testParseMinimalSkill() {
        let minimal = """
        ---
        name: minimal
        ---

        # Content

        Simple content here.
        """

        let spec = SkillSpec.parse(minimal)

        XCTAssertEqual(spec.metadata.name, "minimal")
        XCTAssertNil(spec.metadata.description)
        XCTAssertNil(spec.metadata.version)
        XCTAssertEqual(spec.sections.count, 1)
        XCTAssertEqual(spec.sections.first?.heading, "Content")
    }

    func testParseSkillWithoutFrontmatter() {
        let noFrontmatter = """
        # Just Content

        Content without frontmatter.
        """

        let spec = SkillSpec.parse(noFrontmatter)

        XCTAssertNil(spec.metadata.name)
        XCTAssertNil(spec.metadata.description)
        // Should still parse sections
        XCTAssertEqual(spec.sections.count, 1)
        XCTAssertEqual(spec.sections.first?.heading, "Just Content")
    }

    // MARK: - JSON Serialization Tests

    func testToJSONAndFromJSONRoundTrip() throws {
        let original = SkillSpec(
            metadata: .init(
                name: "json-test",
                description: "Testing JSON serialization",
                version: "2.0.0",
                author: "Test Author",
                tags: ["json", "test"]
            ),
            sections: [
                .init(level: .h1, heading: "Test Section", content: "Test content")
            ]
        )

        // Convert to JSON
        let jsonData = try original.toJSON(prettyPrint: true)

        // Convert back from JSON
        let restored = try SkillSpec.fromJSON(jsonData)

        // Verify round-trip
        XCTAssertEqual(restored.metadata.name, "json-test")
        XCTAssertEqual(restored.metadata.description, "Testing JSON serialization")
        XCTAssertEqual(restored.metadata.version, "2.0.0")
        XCTAssertEqual(restored.metadata.author, "Test Author")
        XCTAssertEqual(restored.metadata.tags, ["json", "test"])
        XCTAssertEqual(restored.sections.count, 1)
        XCTAssertEqual(restored.sections.first?.heading, "Test Section")
        XCTAssertEqual(restored.sections.first?.content, "Test content")
    }

    func testJSONSerializationHandlesAllFields() throws {
        let spec = SkillSpec(
            metadata: .init(
                name: "complete",
                description: "Complete spec",
                version: "1.2.3",
                author: "Author",
                tags: ["tag1", "tag2"],
                minAgentVersion: "1.5.0",
                targets: ["codex", "claude"]
            ),
            sections: [
                .init(level: .h1, heading: "Main", content: "Main content", subsections: [
                    .init(level: .h2, heading: "Sub", content: "Sub content")
                ])
            ],
            errors: [
                .init(code: "test.error", message: "Test error", severity: .error, line: 1)
            ]
        )

        let jsonData = try spec.toJSON()
        let restored = try SkillSpec.fromJSON(jsonData)

        XCTAssertEqual(restored.metadata.name, "complete")
        XCTAssertEqual(restored.metadata.minAgentVersion, "1.5.0")
        XCTAssertEqual(restored.metadata.targets, ["codex", "claude"])
        XCTAssertEqual(restored.sections.count, 1)
        XCTAssertEqual(restored.sections.first?.subsections.count, 1)
        XCTAssertEqual(restored.errors.count, 1)
        XCTAssertEqual(restored.errors.first?.code, "test.error")
    }

    // MARK: - Validation Tests

    func testValidateCodexValidSkill() {
        let spec = SkillSpec(
            metadata: .init(
                name: "codex-skill",
                description: "Valid Codex skill",
                version: "1.0.0"
            ),
            sections: [
                .init(level: .h1, heading: "Content", content: "Some content")
            ]
        )

        let errors = spec.validate(for: .codex)

        XCTAssertTrue(errors.isEmpty, "Valid Codex skill should have no errors")
    }

    func testValidateClaudeRequiresKebabCaseName() {
        let spec = SkillSpec(
            metadata: .init(
                name: "Invalid_Name",
                description: "Invalid Claude skill name",
                version: "1.0.0"
            ),
            sections: [
                .init(level: .h1, heading: "Content", content: "Some content")
            ]
        )

        let errors = spec.validate(for: .claude)

        XCTAssertTrue(errors.contains { $0.code == "metadata.name.pattern" },
                     "Claude skill with underscores should fail name pattern validation")
    }

    func testValidateClaudeAcceptsKebabCaseName() {
        let spec = SkillSpec(
            metadata: .init(
                name: "valid-claude-skill",
                description: "Valid Claude skill",
                version: "1.0.0"
            ),
            sections: [
                .init(level: .h1, heading: "Content", content: "Some content")
            ]
        )

        let errors = spec.validate(for: .claude)

        XCTAssertFalse(errors.contains { $0.code == "metadata.name.pattern" },
                      "Claude skill with kebab-case name should pass name pattern validation")
    }

    func testValidateMissingName() {
        let spec = SkillSpec(
            metadata: .init(
                name: nil,
                description: "Skill without name"
            ),
            sections: []
        )

        let errors = spec.validate(for: .codex)

        XCTAssertTrue(errors.contains { $0.code == "metadata.name.missing" },
                     "Skill without name should fail validation")
    }

    func testValidateInvalidVersionFormat() {
        let spec = SkillSpec(
            metadata: .init(
                name: "test-skill",
                version: "not-a-version"
            ),
            sections: []
        )

        let errors = spec.validate(for: .codex)

        XCTAssertTrue(errors.contains { $0.code == "metadata.version.format" },
                     "Invalid version format should generate warning")
    }

    func testValidateAcceptsSemanticVersion() {
        let validVersions = ["1.0.0", "2.3.4", "10.20.30", "1.0.0-beta", "2.0.0-rc.1"]

        for version in validVersions {
            let spec = SkillSpec(
                metadata: .init(name: "test", version: version),
                sections: []
            )

            let errors = spec.validate(for: .codex)

            XCTAssertFalse(errors.contains { $0.code == "metadata.version.format" },
                          "Version \(version) should be valid")
        }
    }

    // MARK: - Diff Tests

    func testDiffDetectsMetadataChanges() {
        let spec1 = SkillSpec(
            metadata: .init(
                name: "skill-one",
                description: "Original description",
                version: "1.0.0"
            ),
            sections: []
        )

        let spec2 = SkillSpec(
            metadata: .init(
                name: "skill-two",
                description: "Updated description",
                version: "2.0.0"
            ),
            sections: []
        )

        let differences = spec1.diff(spec2)

        XCTAssertGreaterThanOrEqual(differences.count, 3)
        XCTAssertTrue(differences.contains {
            if case .metadataChanged(let key, _, _) = $0, key == "name" { return true }
            return false
        })
        XCTAssertTrue(differences.contains {
            if case .metadataChanged(let key, _, _) = $0, key == "description" { return true }
            return false
        })
        XCTAssertTrue(differences.contains {
            if case .metadataChanged(let key, _, _) = $0, key == "version" { return true }
            return false
        })
    }

    func testDiffDetectsSectionChanges() {
        let spec1 = SkillSpec(
            metadata: .init(name: "test"),
            sections: [
                .init(level: .h1, heading: "Original Heading", content: "Original content")
            ]
        )

        let spec2 = SkillSpec(
            metadata: .init(name: "test"),
            sections: [
                .init(level: .h1, heading: "Updated Heading", content: "Updated content")
            ]
        )

        let differences = spec1.diff(spec2)

        // Should detect heading and content changes
        XCTAssertTrue(differences.contains {
            if case .sectionChanged(_, let field, _, _) = $0, field == "heading" { return true }
            return false
        })
    }

    func testDiffDetectsSectionCountChanges() {
        let spec1 = SkillSpec(
            metadata: .init(name: "test"),
            sections: [
                .init(level: .h1, heading: "Section 1", content: "")
            ]
        )

        let spec2 = SkillSpec(
            metadata: .init(name: "test"),
            sections: [
                .init(level: .h1, heading: "Section 1", content: ""),
                .init(level: .h1, heading: "Section 2", content: "")
            ]
        )

        let differences = spec1.diff(spec2)

        XCTAssertTrue(differences.contains {
            if case .sectionsChanged(_, _) = $0 { return true }
            return false
        })
    }

    func testDiffWithIdenticalSpecs() {
        let spec = SkillSpec(
            metadata: .init(name: "test", version: "1.0.0"),
            sections: [
                .init(level: .h1, heading: "Section", content: "Content")
            ]
        )

        let differences = spec.diff(spec)

        XCTAssertTrue(differences.isEmpty, "Identical specs should have no differences")
    }

    // MARK: - ValidationError Tests

    func testValidationErrorDescription() {
        let error = SkillSpec.ValidationError(
            code: "test.error",
            message: "Test error message",
            severity: .error,
            line: 10,
            column: 5
        )

        let description = error.errorDescription ?? ""

        XCTAssertTrue(description.contains("[ERROR]"))
        XCTAssertTrue(description.contains("test.error"))
        XCTAssertTrue(description.contains("Test error message"))
        XCTAssertTrue(description.contains("line 10:5"))
    }
}
