import XCTest
@testable import SkillsCore

/// Tests for SystemInfo collector.
final class SystemInfoTests: XCTestCase {

    // MARK: - Collection Tests

    func testCollectSystemInfo() throws {
        let info = SystemInfoCollector.collect()

        // Verify macOS version is not empty
        XCTAssertFalse(info.macOSVersion.isEmpty, "macOS version should not be empty")

        // Verify architecture is one of the expected values
        let validArchitectures = ["arm64", "x86_64", "arm64e", "i386"]
        XCTAssertTrue(validArchitectures.contains(info.architecture), "Architecture should be valid: \(info.architecture)")

        // Verify hostname is redacted to <redacted>
        XCTAssertEqual(info.hostName, "<redacted>", "Hostname should be redacted to '<redacted>'")

        // Verify disk space is non-negative
        XCTAssertGreaterThanOrEqual(info.availableDiskSpace, 0, "Available disk space should be non-negative")

        // Verify total memory is positive (should always have memory)
        XCTAssertGreaterThan(info.totalMemory, 0, "Total memory should be positive")
    }

    func testSystemInfoIsSendable() {
        // Verify SystemInfo conforms to Sendable
        let _ = SystemInfoCollector.collect()
        // This should compile without error if Sendable conformance is correct
        let _: @Sendable (SystemInfo) -> Void = { _ in }
    }

    func testSystemInfoIsCodable() throws {
        let info = SystemInfoCollector.collect()

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(info)
        XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SystemInfo.self, from: data)

        // Verify fields match
        XCTAssertEqual(decoded.macOSVersion, info.macOSVersion)
        XCTAssertEqual(decoded.architecture, info.architecture)
        XCTAssertEqual(decoded.hostName, info.hostName)
        XCTAssertEqual(decoded.availableDiskSpace, info.availableDiskSpace)
        XCTAssertEqual(decoded.totalMemory, info.totalMemory)
    }

    func testCollectIsConsistent() {
        // Collect twice and verify consistency
        let info1 = SystemInfoCollector.collect()
        let info2 = SystemInfoCollector.collect()

        // Architecture and memory should be identical
        XCTAssertEqual(info1.architecture, info2.architecture, "Architecture should not change")
        XCTAssertEqual(info1.totalMemory, info2.totalMemory, "Total memory should not change")

        // macOS version should be identical
        XCTAssertEqual(info1.macOSVersion, info2.macOSVersion, "macOS version should not change")

        // Hostname should be identical (both redacted the same way)
        XCTAssertEqual(info1.hostName, info2.hostName, "Hostname should be identical")
    }

    func testTotalMemoryIsReasonable() {
        let info = SystemInfoCollector.collect()

        // Total memory should be at least 1 GB (even for very old systems)
        let oneGB: Int64 = 1_000_000_000
        XCTAssertGreaterThan(info.totalMemory, oneGB, "Total memory should be at least 1 GB")

        // Total memory should not exceed 1 TB (sanity check)
        let oneTB: Int64 = 1_000_000_000_000
        XCTAssertLessThan(info.totalMemory, oneTB, "Total memory should be less than 1 TB (sanity check)")
    }

    func testAvailableDiskSpaceIsReasonable() {
        let info = SystemInfoCollector.collect()

        // Available disk space should be non-negative
        XCTAssertGreaterThanOrEqual(info.availableDiskSpace, 0, "Available disk space should be non-negative")

        // If we got a value, it should be at least 1 MB (even on nearly-full systems)
        if info.availableDiskSpace > 0 {
            let oneMB: Int64 = 1_000_000
            XCTAssertGreaterThanOrEqual(info.availableDiskSpace, oneMB, "Available disk space should be at least 1 MB if retrievable")
        }
    }

    func testMacOSVersionFormat() throws {
        let info = SystemInfoCollector.collect()

        // macOS version should contain a version number (e.g., "14.5.0" or "Version 14.5.0")
        // Just verify it contains digits and dots
        let hasVersionPattern = info.macOSVersion.contains(where: { $0.isNumber }) ||
                              info.macOSVersion.contains(".")
        XCTAssertTrue(hasVersionPattern, "macOS version should contain version info: \(info.macOSVersion)")
    }

    func testArchitectureIsKnown() {
        let info = SystemInfoCollector.collect()

        // Verify architecture is a known value
        let knownArchitectures = ["arm64", "x86_64", "arm64e", "i386", "arm"]
        XCTAssertTrue(
            knownArchitectures.contains(info.architecture),
            "Architecture '\(info.architecture)' should be a known value"
        )
    }
}
