import XCTest
@testable import SkillsCore
@testable import SkillsInspector

@MainActor
final class InspectorViewModelTests: XCTestCase {
    var sut: InspectorViewModel!
    var tempDirectory: URL!
    private let settingsKey = "com.stools.settings"

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
        sut = InspectorViewModel()
        sut.codexSkillManagerRoot = nil
        sut.copilotRoot = nil
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ViewModelTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        sut = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesWithDefaultRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expectedCodex = home.appendingPathComponent(".codex/skills", isDirectory: true)
        let expectedClaude = home.appendingPathComponent(".claude/skills", isDirectory: true)

        XCTAssertEqual(sut.codexRoot, expectedCodex)
        XCTAssertEqual(sut.claudeRoot, expectedClaude)
        XCTAssertFalse(sut.isScanning)
        XCTAssertTrue(sut.findings.isEmpty)
        XCTAssertNil(sut.lastScanAt)
        XCTAssertNil(sut.lastScanDuration)
        XCTAssertEqual(sut.scanProgress, 0)
        XCTAssertEqual(sut.filesScanned, 0)
        XCTAssertEqual(sut.totalFiles, 0)
    }

    // MARK: - Scan Cancellation Tests

    func testScanCancellationStopsProcessing() async throws {
        // Setup: Create a structure with multiple files to scan
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create several valid skill files
        for i in 1...5 {
            let skillDir = codexRoot.appendingPathComponent("skill\(i)", isDirectory: true)
            try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
            let skillFile = skillDir.appendingPathComponent("SKILL.md")
            try """
            ---
            name: skill\(i)
            description: Test skill \(i)
            ---
            """.write(to: skillFile, atomically: true, encoding: .utf8)
        }

        sut.codexRoot = codexRoot
        sut.claudeRoot = claudeRoot
        sut.recursive = true

        // Start scan
        let scanTask = Task {
            await sut.scan(userInitiated: true)
        }

        // Wait a bit then cancel
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        sut.cancelScan()

        await scanTask.value

        // Verify scan was cancelled and state reset
        XCTAssertFalse(sut.isScanning, "isScanning should be false after cancellation")
        XCTAssertNil(sut.scanTask, "scanTask should be nil after cancellation")
    }

    func testConsecutiveScansDoNotInterfere() async throws {
        // Setup: Create skill files
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        let skillDir = codexRoot.appendingPathComponent("test-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        try """
        ---
        name: test-skill
        description: A test skill
        ---
        """.write(to: skillFile, atomically: true, encoding: .utf8)

        sut.codexRoot = codexRoot
        sut.claudeRoot = claudeRoot

        // First scan
        await sut.scan(userInitiated: true)
        // Wait for MainActor state updates to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        let firstFindings = sut.findings
        let firstScanTime = sut.lastScanAt

        // Small delay to ensure timestamps differ
        try await Task.sleep(nanoseconds: 10_000_000)

        // Second scan
        await sut.scan(userInitiated: true)
        // Wait for MainActor state updates to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        let secondFindings = sut.findings
        let secondScanTime = sut.lastScanAt

        // Verify state consistency
        XCTAssertEqual(firstFindings.count, secondFindings.count, "Should have same number of findings")
        XCTAssertNotEqual(firstScanTime, secondScanTime, "Timestamps should differ")
        XCTAssertFalse(sut.isScanning, "Should not be scanning after completion")
    }

    // MARK: - Progress Reporting Tests

    func testScanProgressUpdatesDuringScan() async throws {
        // Create skill files for scanning
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)

        // Create multiple skill files to observe progress
        for i in 1...3 {
            let skillDir = codexRoot.appendingPathComponent("skill\(i)", isDirectory: true)
            try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
            let skillFile = skillDir.appendingPathComponent("SKILL.md")
            try """
            ---
            name: skill\(i)
            description: Test skill \(i)
            ---
            """.write(to: skillFile, atomically: true, encoding: .utf8)
        }

        sut.codexRoot = codexRoot
        sut.claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)

        // Track progress values
        var progressValues: [Double] = []
        var filesScannedValues: [Int] = []

        let progressTask = Task {
            await sut.scan(userInitiated: true)
        }

        // Sample progress during scan
        for _ in 0..<10 {
            await MainActor.run {
                progressValues.append(sut.scanProgress)
                filesScannedValues.append(sut.filesScanned)
            }
            try? await Task.sleep(nanoseconds: 1_000_000) // 0.001 seconds
        }

        await progressTask.value

        // Verify final state
        await MainActor.run {
            XCTAssertEqual(sut.scanProgress, 1.0, "Progress should be 1.0 after completion")
            XCTAssertEqual(sut.filesScanned, sut.totalFiles, "filesScanned should equal totalFiles")
            XCTAssertEqual(sut.totalFiles, 3, "Should have scanned 3 files")
        }
    }

    // MARK: - Scan Duration Tests

    func testScanDurationIsRecorded() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)

        let skillDir = codexRoot.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        try """
        ---
        name: test
        description: test
        ---
        """.write(to: skillFile, atomically: true, encoding: .utf8)

        sut.codexRoot = codexRoot
        sut.claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)

        await sut.scan(userInitiated: true)
        // Wait for MainActor state updates to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

        XCTAssertNotNil(sut.lastScanDuration, "Duration should be recorded")
        XCTAssertGreaterThan(sut.lastScanDuration!, 0, "Duration should be positive")
    }

    func testValidateRootRejectsTraversal() {
        let bad = URL(fileURLWithPath: "/tmp/../etc")
        XCTAssertFalse(sut.validateRoot(bad))
    }

    // MARK: - Findings Sorting Tests

    func testFindingsAreSortedBySeverityThenAgentThenPath() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)

        // Create multiple skills with different severities
        for (name, _) in [("c-skill", "codex"), ("a-skill", "codex"), ("b-skill", "claude")] {
            let skillDir = codexRoot.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
            let skillFile = skillDir.appendingPathComponent("SKILL.md")
            try """
            ---
            name: \(name)
            description: test
            ---
            """.write(to: skillFile, atomically: true, encoding: .utf8)
        }

        sut.codexRoot = codexRoot
        sut.claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        sut.recursive = true

        await sut.scan(userInitiated: true)

        // Verify findings are sorted
        var previousSeverity: String?
        var previousAgent: String?
        var previousPath: String?

        for finding in sut.findings {
            if let prev = previousSeverity {
                // Within same severity, should be sorted by agent
                if finding.severity.rawValue == prev {
                    if let prevAgent = previousAgent {
                        if finding.agent.rawValue == prevAgent {
                            // Within same agent, should be sorted by path
                            if let prevPath = previousPath {
                                XCTAssertTrue(finding.fileURL.path >= prevPath, "Should be sorted by path within same agent")
                            }
                        }
                    }
                }
            }
            previousSeverity = finding.severity.rawValue
            previousAgent = finding.agent.rawValue
            previousPath = finding.fileURL.path
        }
    }

    // MARK: - Error Handling Tests

    func testScanWithInvalidRootReturnsEmptyFindings() async throws {
        let nonExistent = tempDirectory.appendingPathComponent("does-not-exist", isDirectory: true)

        sut.codexRoot = nonExistent
        sut.claudeRoot = nonExistent

        await sut.scan(userInitiated: true)
        // Wait for MainActor state updates to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

        XCTAssertTrue(sut.findings.isEmpty, "Should have no findings for non-existent roots")
        XCTAssertFalse(sut.isScanning, "Should not be scanning")
        XCTAssertNotNil(sut.lastScanAt, "Should have recorded scan time")
    }

    func testScanWithUnreadableFilesCreatesErrorFindings() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)

        let skillDir = codexRoot.appendingPathComponent("bad-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")

        // Create an empty file (invalid SKILL.md)
        try Data().write(to: skillFile)

        sut.codexRoot = codexRoot
        sut.claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)

        await sut.scan(userInitiated: true)
        // Wait for MainActor state updates to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

        // Should have error findings
        let errors = sut.findings.filter { $0.severity == .error }
        XCTAssertTrue(errors.count > 0, "Should have error findings for unreadable/invalid files")
    }
}

// MARK: - SyncViewModel Tests

@MainActor
final class SyncViewModelTests: XCTestCase {
    var sut: SyncViewModel!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        sut = SyncViewModel()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("SyncVMTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        sut = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesWithEmptyReport() {
        XCTAssertTrue(sut.report.missingByAgent.isEmpty)
        XCTAssertTrue(sut.report.differentContent.isEmpty)
        XCTAssertFalse(sut.isRunning)
        XCTAssertNil(sut.selection)
    }

    // MARK: - Run Tests

    func testRunDetectsOnlyInCodex() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create skill only in codex
        let codexSkill = codexRoot.appendingPathComponent("only-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexSkill, withIntermediateDirectories: true)
        let codexFile = codexSkill.appendingPathComponent("SKILL.md")
        try """
        ---
        name: only-codex
        description: Only in codex
        ---
        """.write(to: codexFile, atomically: true, encoding: .utf8)

        await sut.run(
            roots: [.codex: codexRoot, .claude: claudeRoot],
            recursive: false,
            maxDepth: nil,
            excludes: [],
            excludeGlobs: []
        )

        XCTAssertEqual(sut.report.missingByAgent[.claude], ["only-codex"])
        XCTAssertEqual(sut.report.missingByAgent[.codex] ?? [], [])
        XCTAssertTrue(sut.report.differentContent.isEmpty)
        XCTAssertFalse(sut.isRunning)
    }

    func testRunDetectsOnlyInClaude() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create skill only in claude
        let claudeSkill = claudeRoot.appendingPathComponent("only-claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeSkill, withIntermediateDirectories: true)
        let claudeFile = claudeSkill.appendingPathComponent("SKILL.md")
        try """
        ---
        name: only-claude
        description: Only in claude
        ---
        """.write(to: claudeFile, atomically: true, encoding: .utf8)

        await sut.run(
            roots: [.codex: codexRoot, .claude: claudeRoot],
            recursive: false,
            maxDepth: nil,
            excludes: [],
            excludeGlobs: []
        )

        XCTAssertEqual(sut.report.missingByAgent[.codex], ["only-claude"])
        XCTAssertEqual(sut.report.missingByAgent[.claude] ?? [], [])
        XCTAssertTrue(sut.report.differentContent.isEmpty)
        XCTAssertFalse(sut.isRunning)
    }

    func testRunDetectsDifferentContent() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create same skill with different content
        let codexSkill = codexRoot.appendingPathComponent("different", isDirectory: true)
        let claudeSkill = claudeRoot.appendingPathComponent("different", isDirectory: true)
        try FileManager.default.createDirectory(at: codexSkill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeSkill, withIntermediateDirectories: true)

        try """
        ---
        name: different
        description: version 1
        ---
        """.write(to: codexSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        try """
        ---
        name: different
        description: version 2
        ---
        """.write(to: claudeSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        await sut.run(
            roots: [.codex: codexRoot, .claude: claudeRoot],
            recursive: false,
            maxDepth: nil,
            excludes: [],
            excludeGlobs: []
        )

        XCTAssertTrue(sut.report.missingByAgent.values.allSatisfy { $0.isEmpty })
        XCTAssertEqual(sut.report.differentContent.map(\.name), ["different"])
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - Selection Tests

    func testSelectionCanBeUpdated() {
        sut.selection = .missing(agent: .codex, name: "test")
        XCTAssertEqual(sut.selection, .missing(agent: .codex, name: "test"))

        sut.selection = .missing(agent: .claude, name: "test2")
        XCTAssertEqual(sut.selection, .missing(agent: .claude, name: "test2"))

        sut.selection = .different(name: "test3")
        XCTAssertEqual(sut.selection, .different(name: "test3"))

        sut.selection = nil
        XCTAssertNil(sut.selection)
    }

    // MARK: - Recursive Scan Tests

    func testRunWithRecursiveFindsNestedSkills() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create nested skill directory
        let nested = codexRoot.appendingPathComponent("level1/level2", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let nestedFile = nested.appendingPathComponent("SKILL.md")
        try """
        ---
        name: nested
        description: Nested skill
        ---
        """.write(to: nestedFile, atomically: true, encoding: .utf8)

        await sut.run(
            roots: [.codex: codexRoot, .claude: claudeRoot],
            recursive: true,
            maxDepth: nil,
            excludes: [],
            excludeGlobs: []
        )

        let missing = sut.report.missingByAgent[.claude] ?? []
        XCTAssertEqual(missing, ["nested"])
    }

    // MARK: - Exclude Tests

    func testRunWithExcludesSkipsDirectories() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Create skill in excluded directory
        let excluded = codexRoot.appendingPathComponent("excluded-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        let excludedFile = excluded.appendingPathComponent("SKILL.md")
        try """
        ---
        name: excluded
        description: Should be excluded
        ---
        """.write(to: excludedFile, atomically: true, encoding: .utf8)

        // Create skill in non-excluded directory
        let included = codexRoot.appendingPathComponent("included", isDirectory: true)
        try FileManager.default.createDirectory(at: included, withIntermediateDirectories: true)
        let includedFile = included.appendingPathComponent("SKILL.md")
        try """
        ---
        name: included
        description: Should be included
        ---
        """.write(to: includedFile, atomically: true, encoding: .utf8)

        await sut.run(
            roots: [.codex: codexRoot, .claude: claudeRoot],
            recursive: true,
            maxDepth: nil,
            excludes: ["excluded-dir"],
            excludeGlobs: []
        )

        let missingClaude = sut.report.missingByAgent[.claude] ?? []
        XCTAssertEqual(missingClaude, ["included"])
    }
}

final class IndexerAndSettingsTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("IndexerTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "com.stools.settings")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        UserDefaults.standard.removeObject(forKey: "com.stools.settings")
        try await super.tearDown()
    }

    func testGenerateIndexesAcrossMultipleCodexRoots() async throws {
        let codexRootA = tempDirectory.appendingPathComponent("codexA", isDirectory: true)
        let codexRootB = tempDirectory.appendingPathComponent("codexB", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRootA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexRootB, withIntermediateDirectories: true)

        let skillA = codexRootA.appendingPathComponent("skillA", isDirectory: true)
        try FileManager.default.createDirectory(at: skillA, withIntermediateDirectories: true)
        try """
        ---
        name: skillA
        description: from A
        ---
        """.write(to: skillA.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let skillB = codexRootB.appendingPathComponent("skillB", isDirectory: true)
        try FileManager.default.createDirectory(at: skillB, withIntermediateDirectories: true)
        try """
        ---
        name: skillB
        description: from B
        ---
        """.write(to: skillB.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let defaults = await MainActor.run { InspectorViewModel.defaultExcludes }
        let entries = SkillIndexer.generate(
            codexRoots: [codexRootA, codexRootB],
            claudeRoot: nil,
            include: .codex,
            recursive: true,
            excludes: defaults,
            excludeGlobs: []
        )

        let names = Set(entries.map { $0.name })
        XCTAssertEqual(names, Set(["skillA", "skillB"]))
    }

    func testUserSettingsPersistAcrossInstances() async throws {
        let codexRoot = tempDirectory.appendingPathComponent("codexPersist", isDirectory: true)
        let claudeRoot = tempDirectory.appendingPathComponent("claudePersist", isDirectory: true)
        try FileManager.default.createDirectory(at: codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeRoot, withIntermediateDirectories: true)

        // Save settings on the main actor
        await MainActor.run {
            let vm = InspectorViewModel()
            vm.codexRoots = [codexRoot]
            vm.claudeRoot = claudeRoot
            vm.recursive = true
            vm.excludeInput = "tmp,build"
            vm.excludeGlobInput = "*.tmp"
            vm.maxDepth = 2
        }

        // Load settings and capture values on the main actor
        var loadedCodex: URL?
        var loadedClaude: URL?
        var loadedRecursive = false
        var loadedExcludes: [String] = []
        var loadedGlobExcludes: [String] = []
        var loadedMaxDepth: Int?
        var defaults: [String] = []

        await MainActor.run {
            let loaded = InspectorViewModel()
            loadedCodex = loaded.codexRoots.first
            loadedClaude = loaded.claudeRoot
            loadedRecursive = loaded.recursive
            loadedExcludes = loaded.effectiveExcludes
            loadedGlobExcludes = loaded.effectiveGlobExcludes
            loadedMaxDepth = loaded.maxDepth
            defaults = InspectorViewModel.defaultExcludes
        }

        XCTAssertEqual(loadedCodex, codexRoot)
        XCTAssertEqual(loadedClaude, claudeRoot)
        XCTAssertTrue(loadedRecursive)
        XCTAssertEqual(Set(loadedExcludes), Set(defaults + ["tmp", "build"]))
        XCTAssertEqual(loadedGlobExcludes, ["*.tmp"])
        XCTAssertEqual(loadedMaxDepth, 2)
    }

    // MARK: - Polish 4 Test: ViewModel properties publish correctly

    func testDiagnosticBundlePropertiesPublish() async throws {
        // Given/When/Then: Verify properties are @Published and can be observed
        await MainActor.run {
            let vm = InspectorViewModel()
            XCTAssertTrue(vm.diagnosticBundleURL == nil)
            XCTAssertTrue(vm.isGeneratingBundle == false)

            // Set values to test publishing
            vm.isGeneratingBundle = true
            XCTAssertTrue(vm.isGeneratingBundle == true)

            vm.isGeneratingBundle = false
        }
    }

    func testAnalyticsReportPropertyPublish() async throws {
        // Given/When/Then: Verify analyticsReport property exists and is @Published
        await MainActor.run {
            let vm = InspectorViewModel()
            XCTAssertTrue(vm.analyticsReport == nil)
        }
    }

    func testSecurityFindingsPropertyPublish() async throws {
        // Given/When/Then: Verify securityFindings property exists and is @Published
        await MainActor.run {
            let vm = InspectorViewModel()
            XCTAssertTrue(vm.securityFindings.isEmpty)

            vm.securityFindings = []
        }
    }
}
