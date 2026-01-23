import XCTest
@testable import SkillsCore

final class FixEngineTests: XCTestCase {
    func testApplyFixUpdatesFile() throws {
        let tempDir = try makeTempDir()
        let fileURL = tempDir.appendingPathComponent("skill.md")
        try "name: Bad_Name\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let change = FileChange(
            fileURL: fileURL,
            startLine: 1,
            endLine: 1,
            originalText: "name: Bad_Name",
            replacementText: "name: bad-name"
        )
        let fix = SuggestedFix(
            ruleID: "skill-name-format",
            description: "Convert skill name to lowercase-hyphenated format",
            automated: true,
            changes: [change]
        )

        let result = FixEngine.applyFix(fix)
        switch result {
        case .success:
            let updated = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertTrue(updated.contains("name: bad-name"))
        default:
            XCTFail("Expected success, got \(result)")
        }
    }

    func testApplyFixRollsBackOnMismatch() throws {
        let tempDir = try makeTempDir()
        let fileURL = tempDir.appendingPathComponent("skill.md")
        let original = "name: Bad_Name\n"
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        let change = FileChange(
            fileURL: fileURL,
            startLine: 1,
            endLine: 1,
            originalText: "name: Mismatch",
            replacementText: "name: bad-name"
        )
        let fix = SuggestedFix(
            ruleID: "skill-name-format",
            description: "Convert skill name to lowercase-hyphenated format",
            automated: true,
            changes: [change]
        )

        let result = FixEngine.applyFix(fix)
        switch result {
        case .failed:
            let updated = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertEqual(updated, original)
        default:
            XCTFail("Expected failure, got \(result)")
        }
    }
}

private extension FixEngineTests {
    func makeTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
