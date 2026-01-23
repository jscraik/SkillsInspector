import XCTest
@testable import SkillsCore

final class LedgerEventTypeTests: XCTestCase {

    // MARK: - New Event Types Exist (Task 45)

    func testDiagnosticBundleEventTypeExists() {
        // Verify diagnosticBundle case exists and encodes correctly
        let eventType = LedgerEventType.diagnosticBundle
        XCTAssertEqual(eventType.rawValue, "diagnosticBundle")
    }

    func testAnalyticsQueryEventTypeExists() {
        // Verify analyticsQuery case exists and encodes correctly
        let eventType = LedgerEventType.analyticsQuery
        XCTAssertEqual(eventType.rawValue, "analyticsQuery")
    }

    func testSecurityScanEventTypeExists() {
        // Verify securityScan case exists and encodes correctly
        let eventType = LedgerEventType.securityScan
        XCTAssertEqual(eventType.rawValue, "securityScan")
    }

    // MARK: - Codable Conformance

    func testDiagnosticBundleCodable() throws {
        let eventType = LedgerEventType.diagnosticBundle
        let encoded = try JSONEncoder().encode(eventType)
        let decoded = try JSONDecoder().decode(LedgerEventType.self, from: encoded)
        XCTAssertEqual(decoded, .diagnosticBundle)
    }

    func testAnalyticsQueryCodable() throws {
        let eventType = LedgerEventType.analyticsQuery
        let encoded = try JSONEncoder().encode(eventType)
        let decoded = try JSONDecoder().decode(LedgerEventType.self, from: encoded)
        XCTAssertEqual(decoded, .analyticsQuery)
    }

    func testSecurityScanCodable() throws {
        let eventType = LedgerEventType.securityScan
        let encoded = try JSONEncoder().encode(eventType)
        let decoded = try JSONDecoder().decode(LedgerEventType.self, from: encoded)
        XCTAssertEqual(decoded, .securityScan)
    }

    // MARK: - CaseIterable Includes New Types

    func testAllCasesIncludesNewEventTypes() {
        let allCases = LedgerEventType.allCases

        XCTAssertTrue(allCases.contains(.diagnosticBundle),
                     "allCases should include diagnosticBundle")
        XCTAssertTrue(allCases.contains(.analyticsQuery),
                     "allCases should include analyticsQuery")
        XCTAssertTrue(allCases.contains(.securityScan),
                     "allCases should include securityScan")
    }

    func testExpectedCaseCount() {
        // Original: 7 cases (install, update, remove, verify, sync, appLaunch, crash)
        // New: 3 cases (diagnosticBundle, analyticsQuery, securityScan)
        // Total: 10 cases
        XCTAssertEqual(LedgerEventType.allCases.count, 10,
                      "LedgerEventType should have 10 total cases")
    }
}
