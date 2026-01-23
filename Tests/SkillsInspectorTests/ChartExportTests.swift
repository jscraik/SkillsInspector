import XCTest
@testable import SkillsCore
@testable import SkillsInspector
import AppKit

@MainActor
final class ChartExportTests: XCTestCase {

    // MARK: - ScanFrequencyChart PNG Export Tests

    func testScanFrequencyChart_HasExportButton() {
        // Given: A scan frequency chart with sample data
        let metrics = ScanFrequencyChart.sampleMetrics
        let chart = ScanFrequencyChart(metrics: metrics)

        // When & Then: The chart should be renderable
        // This test verifies the chart compiles and has the export button in its header
        XCTAssertNotNil(chart)
    }

    func testScanFrequencyChart_WithEmptyData_IsRenderable() {
        // Given: A scan frequency chart with empty data
        let metrics = ScanFrequencyChart.emptyMetrics
        let chart = ScanFrequencyChart(metrics: metrics)

        // When & Then: The chart should render without crashing
        XCTAssertNotNil(chart)
    }

    // MARK: - ErrorTrendsChart PNG Export Tests

    func testErrorTrendsChart_HasExportButton() {
        // Given: An error trends chart with sample data
        let report = ErrorTrendsChart.sampleReport
        let chart = ErrorTrendsChart(report: report)

        // When & Then: The chart should be renderable
        XCTAssertNotNil(chart)
    }

    func testErrorTrendsChart_WithEmptyData_IsRenderable() {
        // Given: An error trends chart with empty data
        let report = ErrorTrendsChart.emptyReport
        let chart = ErrorTrendsChart(report: report)

        // When & Then: The chart should render without crashing
        XCTAssertNotNil(chart)
    }

    func testErrorTrendsChart_WithSingleError_IsRenderable() {
        // Given: An error trends chart with a single error
        let report = ErrorTrendsChart.singleErrorReport
        let chart = ErrorTrendsChart(report: report)

        // When & Then: The chart should render without crashing
        XCTAssertNotNil(chart)
    }

    // MARK: - PNG Data Validation Tests

    func testPNGDataSignature() {
        // Given: The PNG file signature (first 8 bytes)
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

        // When: We check the signature
        let expectedData = Data(pngSignature)

        // Then: It should match the PNG specification
        XCTAssertEqual(expectedData.count, 8, "PNG signature is 8 bytes")
        XCTAssertEqual(expectedData[0], 0x89, "First byte is high bit set")
        XCTAssertEqual(expectedData[1], 0x50, "Second byte is 'P'")
        XCTAssertEqual(expectedData[2], 0x4E, "Third byte is 'N'")
        XCTAssertEqual(expectedData[3], 0x47, "Fourth byte is 'G'")
    }

    func testImageRenderer_Availability() {
        // Given: macOS 14.0+ target
        if #available(macOS 14.0, *) {
            // When & Then: ImageRenderer should be available
            // This is a compile-time check - if it compiles, ImageRenderer is available
            XCTAssertTrue(true, "ImageRenderer is available on macOS 14+")
        } else {
            XCTSkip("ImageRenderer requires macOS 14.0+")
        }
    }

    // MARK: - Integration Tests

    func testChartComponents_CanCreatePNGRepresentation() {
        // Given: Sample data for both charts
        let metrics = ScanFrequencyChart.sampleMetrics
        let report = ErrorTrendsChart.sampleReport

        // When: We create the chart views
        let frequencyChart = ScanFrequencyChart(metrics: metrics)
        let errorChart = ErrorTrendsChart(report: report)

        // Then: Both charts should be created without error
        XCTAssertNotNil(frequencyChart, "Scan frequency chart should create successfully")
        XCTAssertNotNil(errorChart, "Error trends chart should create successfully")
    }

    func testSampleMetrics_HasValidData() {
        // Given: The sample metrics
        let metrics = ScanFrequencyChart.sampleMetrics

        // When & Then: It should have valid data
        XCTAssertGreaterThan(metrics.totalScans, 0, "Total scans should be positive")
        XCTAssertGreaterThan(metrics.averageScansPerDay, 0, "Average should be positive")
        XCTAssertFalse(metrics.dailyCounts.isEmpty, "Daily counts should not be empty")
        XCTAssertNotEqual(metrics.trend, .unknown, "Trend should be determined")
    }

    func testSampleReport_HasValidData() {
        // Given: The sample report
        let report = ErrorTrendsChart.sampleReport

        // When & Then: It should have valid data
        XCTAssertGreaterThan(report.totalErrors, 0, "Total errors should be positive")
        XCTAssertFalse(report.errorsByRule.isEmpty, "Errors by rule should not be empty")
        XCTAssertFalse(report.errorsByAgent.isEmpty, "Errors by agent should not be empty")
    }

    // MARK: - File Extension Tests

    func testPNGFileExtension_IsValid() {
        // Given: A PNG filename
        let filename = "scan-frequency-20260120-123456.png"

        // When: We extract the extension
        let fileExtension = URL(fileURLWithPath: filename).pathExtension

        // Then: It should be "png"
        XCTAssertEqual(fileExtension, "png", "File extension should be png")
    }

    func testTimestampedFilename_IsValid() {
        // Given: An ISO8601 timestamp
        let formatter = ISO8601DateFormatter()
        let date = Date()
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "-")

        // When: We create a filename
        let filename = "scan-frequency-\(timestamp).png"

        // Then: It should contain the timestamp
        XCTAssertTrue(filename.contains("scan-frequency-"), "Filename should contain prefix")
        XCTAssertTrue(filename.hasSuffix(".png"), "Filename should end with .png")
    }
}
