import XCTest
@testable import SkillsCore

/// Performance tests for SecurityScanner
/// Tests that scanning 100 skill files completes in under 30 seconds
final class SecurityPerformanceTests: XCTestCase {
    /// Test fixture directory
    private var testDir: URL!

    /// Performance target: 30 seconds for 100 skills
    private let performanceTarget: TimeInterval = 30.0

    /// Number of skill files to test with
    private let skillFileCount = 100

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        let tmpDir = FileManager.default.temporaryDirectory
        testDir = tmpDir.appendingPathComponent("SecurityPerformanceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDir)
        try await super.tearDown()
    }

    // MARK: - Performance Tests

    /// Test scanning 100 skill files completes in under 30 seconds
    /// This is the primary performance acceptance criterion
    func testScan100SkillsUnder30Seconds() async throws {
        // Create 100 test skill directories with scripts
        let skillDocs = try await createTestSkills(count: skillFileCount)

        let scanner = SecurityScanner()

        // Measure scan time
        let startTime = Date()

        var totalFindings = 0
        for doc in skillDocs {
            let findings = try await scanner.scan(doc: doc)
            totalFindings += findings.count
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Assert performance target
        XCTAssertLessThan(
            elapsed,
            performanceTarget,
            "Scanning \(skillFileCount) skill files should complete in <\(performanceTarget)s, took \(String(format: "%.2f", elapsed))s"
        )

        // Print performance metrics for verification
        print("✅ Performance Test Results:")
        print("   - Skills scanned: \(skillFileCount)")
        print("   - Total findings: \(totalFindings)")
        print("   - Scan time: \(String(format: "%.3f", elapsed))s")
        print("   - Time per skill: \(String(format: "%.3f", elapsed / Double(skillFileCount)))s")
        print("   - Target: <\(performanceTarget)s ✓")
    }

    /// Test scanning 100 skill files with multiple scripts each
    /// Simulates a more realistic workload
    func testScan100SkillsWithMultipleScripts() async throws {
        // Create 100 skills with 3 scripts each
        let skillDocs = try await createTestSkills(
            count: skillFileCount,
            scriptsPerSkill: 3,
            includeIssues: true
        )

        let scanner = SecurityScanner()

        // Measure scan time
        let startTime = Date()

        var totalFindings = 0
        for doc in skillDocs {
            let findings = try await scanner.scan(doc: doc)
            totalFindings += findings.count
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Assert performance target (with slightly more lenient target for multiple scripts)
        XCTAssertLessThan(
            elapsed,
            performanceTarget,
            "Scanning \(skillFileCount) skills with \(skillFileCount * 3) scripts should complete in <\(performanceTarget)s, took \(String(format: "%.2f", elapsed))s"
        )

        // Verify findings were detected
        XCTAssertGreaterThan(
            totalFindings,
            0,
            "Should detect at least some security issues in test files"
        )

        // Print performance metrics
        print("✅ Multi-Script Performance Test Results:")
        print("   - Skills scanned: \(skillFileCount)")
        print("   - Total scripts: \(skillFileCount * 3)")
        print("   - Findings detected: \(totalFindings)")
        print("   - Scan time: \(String(format: "%.3f", elapsed))s")
    }

    /// Test concurrent scanning performance
    /// Scans multiple skills concurrently using TaskGroup
    func testConcurrentScanPerformance() async throws {
        let skillDocs = try await createTestSkills(count: skillFileCount)
        let scanner = SecurityScanner()

        let startTime = Date()

        // Scan concurrently using TaskGroup
        var totalFindings = 0
        try await withThrowingTaskGroup(of: [Finding].self) { group in
            for doc in skillDocs {
                group.addTask {
                    try await scanner.scan(doc: doc)
                }
            }

            while let findings = try await group.next() {
                totalFindings += findings.count
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Concurrent scanning should be faster, but still under 30s
        XCTAssertLessThan(
            elapsed,
            performanceTarget,
            "Concurrent scan of \(skillFileCount) skills should complete in <\(performanceTarget)s, took \(String(format: "%.2f", elapsed))s"
        )

        print("✅ Concurrent Scan Performance:")
        print("   - Skills scanned: \(skillFileCount)")
        print("   - Scan time: \(String(format: "%.3f", elapsed))s")
        print("   - Throughput: \(String(format: "%.1f", Double(skillFileCount) / elapsed)) skills/sec")
    }

    /// Test memory efficiency during bulk scanning
    /// Measures memory before, during, and after scanning
    func testMemoryEfficiencyDuringBulkScan() async throws {
        // Use smaller set for memory testing
        let testCount = 50
        let skillDocs = try await createTestSkills(count: testCount)

        let scanner = SecurityScanner()

        // Get baseline memory
        let baselineMemory = getMemoryUsage()

        // Scan all skills
        var totalFindings = 0
        for doc in skillDocs {
            let findings = try await scanner.scan(doc: doc)
            totalFindings += findings.count
        }

        // Get memory after scan
        let peakMemory = getMemoryUsage()

        // Calculate memory growth
        let memoryGrowthMB = Double(peakMemory - baselineMemory) / 1024.0 / 1024.0

        // Assert reasonable memory growth (<100MB for 50 skills)
        XCTAssertLessThan(
            memoryGrowthMB,
            100.0,
            "Memory growth should be <100MB, was \(String(format: "%.1f", memoryGrowthMB))MB"
        )

        print("✅ Memory Efficiency:")
        print("   - Skills scanned: \(testCount)")
        print("   - Memory growth: \(String(format: "%.1f", memoryGrowthMB))MB")
    }

    // MARK: - Helper Methods

    /// Create test skill files
    /// - Parameters:
    ///   - count: Number of skills to create
    ///   - scriptsPerSkill: Number of scripts per skill (default: 1)
    ///   - includeIssues: Whether to include security issues (default: false)
    /// - Returns: Array of SkillDoc objects
    private func createTestSkills(
        count: Int,
        scriptsPerSkill: Int = 1,
        includeIssues: Bool = false
    ) async throws -> [SkillDoc] {
        var skillDocs: [SkillDoc] = []

        for i in 0..<count {
            // Create skill directory
            let skillDir = testDir.appendingPathComponent("skill-\(i)")
            try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

            // Create skill file
            let skillFile = skillDir.appendingPathComponent("SKILL.md")
            let skillContent = """
            ---
            name: Test Skill \(i)
            description: Test skill for performance testing
            agent: codex
            ---

            # Test Skill \(i)

            This is a test skill for security scanning performance.
            """
            try skillContent.write(to: skillFile, atomically: true, encoding: .utf8)

            // Create scripts directory and files
            let scriptsDir = skillDir.appendingPathComponent("scripts")
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

            for j in 0..<scriptsPerSkill {
                let scriptFile = scriptsDir.appendingPathComponent("script\(j).swift")

                let scriptContent: String
                if includeIssues && j % 3 == 0 {
                    // Every third script has a hardcoded secret
                    scriptContent = """
                    import Foundation

                    // This should be detected
                    let apiKey = "sk-\(String(repeating: "0", count: 32))"

                    func process() {
                        // Processing
                    }
                    """
                } else if includeIssues && j % 3 == 1 {
                    // Every third script has command injection
                    scriptContent = """
                    import Foundation

                    // This should be detected
                    let result = shell("rm -rf /tmp/test")

                    func cleanup() {
                        // Clean up
                    }
                    """
                } else {
                    // Clean script
                    scriptContent = """
                    import Foundation

                    func process() {
                        // Clean processing
                    }

                    func cleanup() {
                        // Clean up
                    }
                    """
                }

                try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)
            }

            // Create SkillDoc
            let doc = SkillDoc(
                agent: .codex,
                rootURL: testDir,
                skillDirURL: skillDir,
                skillFileURL: skillFile,
                name: "Test Skill \(i)",
                description: "Test skill for performance testing",
                lineCount: 15,
                isSymlinkedDir: false,
                hasFrontmatter: true,
                frontmatterStartLine: 1,
                referencesCount: 0,
                assetsCount: 0,
                scriptsCount: scriptsPerSkill
            )

            skillDocs.append(doc)
        }

        return skillDocs
    }

    /// Get current memory usage in bytes
    /// - Returns: Memory usage in bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - C Interop for Memory Usage

import Darwin

private struct mach_task_basic_info {
    var virtual_size: UInt64 = 0
    var resident_size: UInt64 = 0
    var resident_size_max: UInt64 = 0
    var user_time: time_value_t = time_value_t(seconds: 0, microseconds: 0)
    var system_time: time_value_t = time_value_t(seconds: 0, microseconds: 0)
    var policy: integer_t = 0
    var pages: integer_t = 0
    var max_pages: integer_t = 0
    var surrogate: integer_t = 0
}
