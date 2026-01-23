import XCTest
@testable import SkillsCore

/// Tests for CSV export functionality
final class CSVExportTests: XCTestCase {

    // MARK: - Scan Frequency CSV Export

    func testExportFrequencyMetrics_CreatesValidCSV() throws {
        // Given: Sample scan frequency metrics
        let calendar = Calendar.current
        let now = Date()
        let dailyCounts: [(Date, Int)] = [
            (calendar.date(byAdding: .day, value: -3, to: now)!, 10),
            (calendar.date(byAdding: .day, value: -2, to: now)!, 15),
            (calendar.date(byAdding: .day, value: -1, to: now)!, 8),
        ]

        let metrics = ScanFrequencyMetrics(
            totalScans: 33,
            averageScansPerDay: 11.0,
            dailyCounts: dailyCounts,
            trend: .increasing
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportScanFrequency(metrics)

        // Then: CSV has valid format
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 4, "Should have header + 3 data rows")
        XCTAssertEqual(lines[0], "date,scan_count", "First line should be header")

        // Each data line should have format: date,scan_count
        for i in 1..<lines.count {
            let parts = lines[i].components(separatedBy: ",")
            XCTAssertEqual(parts.count, 2, "Each data line should have 2 columns")
            XCTAssertNotNil(Int(parts[1]), "Second column should be an integer")
        }
    }

    func testExportFrequencyMetrics_EmptyData() throws {
        // Given: Empty metrics
        let metrics = ScanFrequencyMetrics(
            totalScans: 0,
            averageScansPerDay: 0.0,
            dailyCounts: [],
            trend: .unknown
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportScanFrequency(metrics)

        // Then: CSV has only header
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "Should have only header")
        XCTAssertEqual(lines[0], "date,scan_count")
    }

    func testExportFrequencyMetrics_DateFormat() throws {
        // Given: Metrics with known date
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let metrics = ScanFrequencyMetrics(
            totalScans: 5,
            averageScansPerDay: 5.0,
            dailyCounts: [(date, 5)],
            trend: .unknown
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportScanFrequency(metrics)

        // Then: Date is in ISO 8601 format (YYYY-MM-DD)
        XCTAssertTrue(csv.contains("2026-01-15"), "CSV should contain ISO formatted date")
    }

    // MARK: - Error Trends CSV Export

    func testExportErrorTrends_CreatesValidCSV() throws {
        // Given: Sample error trends report
        let report = ErrorTrendsReport(
            totalErrors: 25,
            errorsByRule: [
                "missing-description": 10,
                "invalid-format": 8,
                "required-field": 7
            ],
            errorsByAgent: [:]
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportErrorTrends(report)

        // Then: CSV has valid format
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 4, "Should have header + 3 data rows")
        XCTAssertEqual(lines[0], "rule,error_count", "First line should be header")

        // Each data line should have format: rule,error_count
        for i in 1..<lines.count {
            let parts = lines[i].components(separatedBy: ",")
            XCTAssertEqual(parts.count, 2, "Each data line should have 2 columns")
            XCTAssertNotNil(Int(parts[1]), "Second column should be an integer")
        }
    }

    func testExportErrorTrends_SortedByCount() throws {
        // Given: Report with unsorted errors
        let report = ErrorTrendsReport(
            totalErrors: 20,
            errorsByRule: [
                "rule-a": 3,
                "rule-b": 10,
                "rule-c": 5,
                "rule-d": 2
            ],
            errorsByAgent: [:]
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportErrorTrends(report)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Then: Errors are sorted by count (descending)
        // Expected order: rule-b (10), rule-c (5), rule-a (3), rule-d (2)
        XCTAssertTrue(lines[1].contains("rule-b,10"))
        XCTAssertTrue(lines[2].contains("rule-c,5"))
        XCTAssertTrue(lines[3].contains("rule-a,3"))
        XCTAssertTrue(lines[4].contains("rule-d,2"))
    }

    func testExportErrorTrends_EscapesSpecialCharacters() throws {
        // Given: Report with rule names containing special characters
        let report = ErrorTrendsReport(
            totalErrors: 15,
            errorsByRule: [
                "rule,with,commas": 5,
                "rule\"with\"quotes": 3,
                "normal-rule": 7
            ],
            errorsByAgent: [:]
        )

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportErrorTrends(report)

        // Then: Special characters are properly escaped
        // Commas and quotes should be escaped with quotes
        XCTAssertTrue(csv.contains("\"rule,with,commas\""))
        XCTAssertTrue(csv.contains("\"rule\"\"with\"\"quotes\""))
    }

    // MARK: - Top Skills CSV Export

    func testExportTopSkills_CreatesValidCSV() throws {
        // Given: Sample top skills rankings
        let calendar = Calendar.current
        let now = Date()
        let rankings: [SkillUsageRanking] = [
            SkillUsageRanking(
                skillName: "code-review",
                agent: .claude,
                scanCount: 47,
                lastScanned: calendar.date(byAdding: .hour, value: -2, to: now)!
            ),
            SkillUsageRanking(
                skillName: "refactor",
                agent: .codex,
                scanCount: 35,
                lastScanned: calendar.date(byAdding: .hour, value: -5, to: now)!
            )
        ]

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportTopSkills(rankings)

        // Then: CSV has valid format
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 3, "Should have header + 2 data rows")
        XCTAssertEqual(lines[0], "skill_name,agent,scan_count,last_scanned", "First line should be header")

        // Each data line should have 4 columns
        for i in 1..<lines.count {
            let parts = lines[i].components(separatedBy: ",")
            XCTAssertEqual(parts.count, 4, "Each data line should have 4 columns")
        }
    }

    func testExportTopSkills_AgentDisplayNames() throws {
        // Given: Rankings with different agents
        let rankings: [SkillUsageRanking] = [
            SkillUsageRanking(skillName: "skill1", agent: .claude, scanCount: 1, lastScanned: Date()),
            SkillUsageRanking(skillName: "skill2", agent: .codex, scanCount: 1, lastScanned: Date()),
            SkillUsageRanking(skillName: "skill3", agent: .codexSkillManager, scanCount: 1, lastScanned: Date()),
            SkillUsageRanking(skillName: "skill4", agent: .copilot, scanCount: 1, lastScanned: Date()),
            SkillUsageRanking(skillName: "skill5", agent: nil, scanCount: 1, lastScanned: Date())
        ]

        // When: Generating CSV
        let csv = AnalyticsCSVExporter.exportTopSkills(rankings)

        // Then: Agent display names are correct
        XCTAssertTrue(csv.contains("Claude"))
        XCTAssertTrue(csv.contains("Codex"))
        XCTAssertTrue(csv.contains("CodexSkillManager"))
        XCTAssertTrue(csv.contains("Copilot"))
        XCTAssertTrue(csv.contains("unknown"))
    }

    // MARK: - Combined Export

    func testExportAllData_CreatesValidCombinedCSV() throws {
        // Given: Sample analytics data
        let calendar = Calendar.current
        let now = Date()
        let dailyCounts: [(Date, Int)] = [
            (calendar.date(byAdding: .day, value: -1, to: now)!, 5)
        ]

        let metrics = ScanFrequencyMetrics(
            totalScans: 5,
            averageScansPerDay: 5.0,
            dailyCounts: dailyCounts,
            trend: .stable
        )

        let report = ErrorTrendsReport(
            totalErrors: 3,
            errorsByRule: ["test-rule": 3],
            errorsByAgent: [:]
        )

        let rankings: [SkillUsageRanking] = [
            SkillUsageRanking(
                skillName: "test-skill",
                agent: .claude,
                scanCount: 10,
                lastScanned: now
            )
        ]

        // When: Generating combined CSV
        let csv = AnalyticsCSVExporter.exportAll(
            frequencyMetrics: metrics,
            errorReport: report,
            skillRankings: rankings
        )

        // Then: CSV contains all three sections
        XCTAssertTrue(csv.contains("# Scan Frequency"), "Should have frequency section")
        XCTAssertTrue(csv.contains("# Error Trends"), "Should have errors section")
        XCTAssertTrue(csv.contains("# Top Skills"), "Should have top skills section")
        XCTAssertTrue(csv.contains("date,scan_count"), "Should have frequency header")
        XCTAssertTrue(csv.contains("rule,error_count"), "Should have errors header")
        XCTAssertTrue(csv.contains("skill_name,agent,scan_count,last_scanned"), "Should have skills header")
    }
}
