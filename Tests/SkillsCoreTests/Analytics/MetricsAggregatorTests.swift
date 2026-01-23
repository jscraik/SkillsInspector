import XCTest
@testable import SkillsCore

final class MetricsAggregatorTests: XCTestCase {

    // MARK: - groupEventsByDay Tests

    func testGroupEventsByDay_EmptyArray_ReturnsEmpty() {
        let result = MetricsAggregator.groupEventsByDay([])

        XCTAssertTrue(result.isEmpty, "Empty input should return empty array")
    }

    func testGroupEventsByDay_SingleEvent_ReturnsOneDay() {
        let event = LedgerEvent(
            id: 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000), // 2023-11-15
            eventType: .verify,
            skillName: "test",
            skillSlug: nil,
            version: nil,
            agent: nil,
            status: .success,
            note: nil,
            source: nil,
            verification: nil,
            manifestSHA256: nil,
            targetPath: nil,
            targets: nil,
            perTargetResults: nil,
            signerKeyId: nil
        )

        let result = MetricsAggregator.groupEventsByDay([event])

        XCTAssertEqual(result.count, 1, "Single event should return one day")
        XCTAssertEqual(result[0].1, 1, "Count should be 1")
    }

    func testGroupEventsByDay_SameDayGroupsTogether() {
        // Use noon timestamp to ensure adding hours doesn't cross day boundary
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = 12 // Set to noon
        components.minute = 0
        components.second = 0
        let noonDate = calendar.date(from: components)!

        // Note: LedgerEvent now has a simpler initializer that doesn't require all optional params
        // The test creates 3 events on the same day (just at different times)
        // They should all group into a single day entry with count 3
        var events: [LedgerEvent] = []
        for i in 1...3 {
            let event = LedgerEvent(
                id: Int64(i),
                timestamp: noonDate.addingTimeInterval(Double((i - 1) * 3600)),
                eventType: .verify,
                skillName: "test",
                status: .success
            )
            events.append(event)
        }

        let result = MetricsAggregator.groupEventsByDay(events)

        XCTAssertEqual(result.count, 1, "All events on same day should group together")
        XCTAssertEqual(result[0].1, 3, "Count should be 3")
    }

    func testGroupEventsByDay_DifferentDaysSeparates() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-15
        let day2 = day1.addingTimeInterval(86400) // +1 day

        let events = [
            LedgerEvent(id: 1, timestamp: day1, eventType: .verify, skillName: "test", status: .success),
            LedgerEvent(id: 2, timestamp: day2, eventType: .verify, skillName: "test", status: .success),
        ]

        let result = MetricsAggregator.groupEventsByDay(events)

        XCTAssertEqual(result.count, 2, "Events on different days should separate")
        XCTAssertEqual(result[0].1, 1, "First day count should be 1")
        XCTAssertEqual(result[1].1, 1, "Second day count should be 1")
    }

    func testGroupEventsByDay_ReturnsSortedByDate() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-15
        let day2 = day1.addingTimeInterval(86400) // +1 day
        let day3 = day2.addingTimeInterval(86400) // +1 day

        // Create events in reverse order (day3, day1, day2)
        let events = [
            LedgerEvent(id: 1, timestamp: day3, eventType: .verify, skillName: "test", status: .success),
            LedgerEvent(id: 2, timestamp: day1, eventType: .verify, skillName: "test", status: .success),
            LedgerEvent(id: 3, timestamp: day2, eventType: .verify, skillName: "test", status: .success),
        ]

        let result = MetricsAggregator.groupEventsByDay(events)

        XCTAssertEqual(result.count, 3, "Should have 3 days")

        // Verify sorted order (dates should be normalized to start of day)
        for i in 0..<(result.count - 1) {
            XCTAssertLessThan(result[i].0, result[i + 1].0, "Result should be sorted by date ascending")
        }
    }

    func testGroupEventsByDay_MultipleEventsPerDay() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-15
        let day2 = day1.addingTimeInterval(86400) // +1 day
        let day3 = day2.addingTimeInterval(86400) // +1 day

        // Create varying counts: 3 on day1, 1 on day2, 5 on day3
        var events: [LedgerEvent] = []
        for i in 1...3 {
            events.append(LedgerEvent(
                id: Int64(i),
                timestamp: day1,
                eventType: .verify,
                skillName: "test",
                status: .success
            ))
        }
        events.append(LedgerEvent(
            id: 4,
            timestamp: day2,
            eventType: .verify,
            skillName: "test",
            status: .success
        ))
        for i in 5...9 {
            events.append(LedgerEvent(
                id: Int64(i),
                timestamp: day3,
                eventType: .verify,
                skillName: "test",
                status: .success
            ))
        }

        let result = MetricsAggregator.groupEventsByDay(events)

        XCTAssertEqual(result.count, 3, "Should have 3 days")
        XCTAssertEqual(result[0].1, 3, "Day 1 should have 3 events")
        XCTAssertEqual(result[1].1, 1, "Day 2 should have 1 event")
        XCTAssertEqual(result[2].1, 5, "Day 3 should have 5 events")
    }

    func testGroupEventsByDay_MidnightBoundary() {
        // Create events exactly at midnight boundary
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2023
        components.month = 11
        components.day = 15
        components.hour = 23
        components.minute = 59
        components.second = 59

        let beforeMidnight = calendar.date(from: components)!
        let afterMidnight = beforeMidnight.addingTimeInterval(2) // crosses midnight

        let events = [
            LedgerEvent(id: 1, timestamp: beforeMidnight, eventType: .verify, skillName: "test", status: .success),
            LedgerEvent(id: 2, timestamp: afterMidnight, eventType: .verify, skillName: "test", status: .success),
        ]

        let result = MetricsAggregator.groupEventsByDay(events)

        XCTAssertEqual(result.count, 2, "Events across midnight should be in different days")
    }
}
