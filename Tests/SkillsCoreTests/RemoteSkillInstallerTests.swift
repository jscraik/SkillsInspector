import XCTest
@testable import SkillsCore

final class RemoteSkillInstallerTests: XCTestCase {
    func testInstallCopiesSkillAndComputesChecksum() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        let skillDir = temp.appendingPathComponent("skill-one", isDirectory: true)
        let archiveURL = temp.appendingPathComponent("skill-one.zip")
        let targetRoot = temp.appendingPathComponent("target", isDirectory: true)

        try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try """
        ---
        name: demo
        description: Demo skill
        ---

        # Sample skill
        """.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // zip the skill directory
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = temp
        process.arguments = ["-rq", archiveURL.lastPathComponent, "skill-one"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let installer = RemoteSkillInstaller()
        let result = try await installer.install(
            archiveURL: archiveURL,
            target: .custom(targetRoot),
            overwrite: false
        )

        let expectedDir = targetRoot.appendingPathComponent("skill-one")
        XCTAssertTrue(fm.fileExists(atPath: expectedDir.path))
        XCTAssertEqual(result.skillDirectory, expectedDir)
        XCTAssertNotNil(result.archiveSHA256)
    }
}
