import Foundation

/// Aggregates ledger events into time-series metrics
public struct MetricsAggregator: Sendable {

    /// Groups events by day (date only, ignoring time)
    /// - Parameter events: Array of ledger events to group
    /// - Returns: Array of tuples (date, count) sorted by date ascending
    public static func groupEventsByDay(_ events: [LedgerEvent]) -> [(Date, Int)] {
        let calendar = Calendar.current

        // Group events by day
        var grouped: [Date: Int] = [:]

        for event in events {
            // Normalize timestamp to start of day
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: event.timestamp)
            if let day = calendar.date(from: dayComponents) {
                grouped[day, default: 0] += 1
            }
        }

        // Sort by date ascending and convert to array
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
