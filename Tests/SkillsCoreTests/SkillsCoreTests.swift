import XCTest
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

    private func fixture(_ relative: String) -> URL {
        let file = URL(fileURLWithPath: relative).lastPathComponent
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: file).pathExtension
        guard let url = Bundle.module.url(forResource: name, withExtension: ext.isEmpty ? nil : ext) else {
            fatalError("Missing fixture \(relative)")
        }
        return url
    }
}
