import Foundation

// MARK: - SLO Definitions

/// Service Level Objectives for sTools platform reliability.
public struct SLO: Sendable, Codable {
    /// The target percentage for the SLO (e.g., 99.5 = 99.5%)
    public let target: Double

    /// The measurement window for this SLO
    public let window: MeasurementWindow

    /// Human-readable description
    public let description: String

    /// Error budget percentage (100 - target)
    public var errorBudgetPercent: Double {
        100.0 - target
    }

    public init(target: Double, window: MeasurementWindow, description: String) {
        self.target = target
        self.window = window
        self.description = description
    }

    /// Measurement windows for SLOs
    public enum MeasurementWindow: String, Sendable, Codable {
        case rolling24h = "24h"
        case rolling7d = "7d"
        case rolling30d = "30d"
        case quarter = "90d"

        public var calendarDays: Int {
            switch self {
            case .rolling24h: return 1
            case .rolling7d: return 7
            case .rolling30d: return 30
            case .quarter: return 90
            }
        }
    }

    // Pre-defined SLOs for sTools
    public static let crashFreeSessions = SLO(
        target: 99.5,
        window: .rolling30d,
        description: "Crash-free sessions (app launches without crashes)"
    )

    public static let verifiedInstallSuccess = SLO(
        target: 95.0,
        window: .rolling30d,
        description: "Verified install success (skills installed with signature verification)"
    )

    public static let syncSuccess = SLO(
        target: 98.0,
        window: .rolling7d,
        description: "Sync operations completed without errors"
    )
}

// MARK: - SLO Measurement

/// Measures SLO compliance from ledger data.
public actor SLOMeasurer {
    private let ledger: SkillLedger

    public init(ledger: SkillLedger = try! SkillLedger()) {
        self.ledger = ledger
    }

    /// Calculate crash-free session rate
    /// Returns percentage of sessions without crashes
    public func crashFreeSessions(slo: SLO = .crashFreeSessions) async throws -> SLOMeasurement {
        let since = Date().addingTimeInterval(-Double(slo.window.calendarDays) * 24 * 60 * 60)

        // Get all ledger events in the window
        let events = try await ledger.fetchEvents(limit: Int.max, since: since)

        // Count sessions (app launches) and crashes
        var totalSessions = 0
        var crashes = 0

        for event in events {
            switch event.eventType {
            case .appLaunch:
                totalSessions += 1
            case .crash:
                crashes += 1
            default:
                break
            }
        }

        let successCount = totalSessions - crashes
        let successRate = totalSessions > 0 ? Double(successCount) / Double(totalSessions) * 100 : 100.0

        return SLOMeasurement(
            slo: slo,
            successRate: successRate,
            successCount: successCount,
            totalCount: totalSessions,
            errorBudget: slo.errorBudgetPercent,
            errorBudgetRemaining: (slo.errorBudgetPercent - (100.0 - successRate)).clamp(min: 0, max: slo.errorBudgetPercent)
        )
    }

    /// Calculate verified install success rate
    /// Returns percentage of installs with successful verification
    public func verifiedInstallSuccess(slo: SLO = .verifiedInstallSuccess) async throws -> SLOMeasurement {
        let since = Date().addingTimeInterval(-Double(slo.window.calendarDays) * 24 * 60 * 60)

        let events = try await ledger.fetchEvents(
            limit: Int.max,
            since: since,
            eventTypes: [.install]
        )

        let totalInstalls = events.count
        let verifiedInstalls = events.filter { $0.verification != nil && $0.status == .success }.count
        let successRate = totalInstalls > 0 ? Double(verifiedInstalls) / Double(totalInstalls) * 100 : 100.0

        return SLOMeasurement(
            slo: slo,
            successRate: successRate,
            successCount: verifiedInstalls,
            totalCount: totalInstalls,
            errorBudget: slo.errorBudgetPercent,
            errorBudgetRemaining: (slo.errorBudgetPercent - (100.0 - successRate)).clamp(min: 0, max: slo.errorBudgetPercent)
        )
    }

    /// Calculate sync operation success rate
    public func syncSuccess(slo: SLO = .syncSuccess) async throws -> SLOMeasurement {
        let since = Date().addingTimeInterval(-Double(slo.window.calendarDays) * 24 * 60 * 60)

        let events = try await ledger.fetchEvents(
            limit: Int.max,
            since: since,
            eventTypes: [.sync]
        )

        let totalSyncs = events.count
        let successfulSyncs = events.filter { $0.status == .success }.count
        let successRate = totalSyncs > 0 ? Double(successfulSyncs) / Double(totalSyncs) * 100 : 100.0

        return SLOMeasurement(
            slo: slo,
            successRate: successRate,
            successCount: successfulSyncs,
            totalCount: totalSyncs,
            errorBudget: slo.errorBudgetPercent,
            errorBudgetRemaining: (slo.errorBudgetPercent - (100.0 - successRate)).clamp(min: 0, max: slo.errorBudgetPercent)
        )
    }

    /// Generate a comprehensive SLO report
    public func generateReport() async throws -> SLOReport {
        let crashFree = try await crashFreeSessions()
        let verifiedInstalls = try await verifiedInstallSuccess()
        let sync = try await syncSuccess()

        return SLOReport(
            generatedAt: Date(),
            crashFreeSessions: crashFree,
            verifiedInstallSuccess: verifiedInstalls,
            syncSuccess: sync
        )
    }
}

// MARK: - SLO Measurement Result

/// Result of measuring an SLO against actual data.
public struct SLOMeasurement: Sendable, Codable {
    /// The SLO being measured
    public let slo: SLO

    /// Actual success rate achieved
    public let successRate: Double

    /// Number of successful events
    public let successCount: Int

    /// Total number of events measured
    public let totalCount: Int

    /// Total error budget (percentage)
    public let errorBudget: Double

    /// Remaining error budget (percentage)
    public let errorBudgetRemaining: Double

    /// Whether the SLO is being met
    public var isCompliant: Bool {
        successRate >= slo.target
    }

    /// Error budget consumed (percentage)
    public var errorBudgetConsumed: Double {
        errorBudget - errorBudgetRemaining
    }

    /// Alert if error budget is below 10%
    public var shouldAlert: Bool {
        errorBudgetRemaining < (errorBudget * 0.1)
    }
}

// MARK: - SLO Report

/// Comprehensive SLO compliance report.
public struct SLOReport: Sendable, Codable {
    public let generatedAt: Date
    public let crashFreeSessions: SLOMeasurement
    public let verifiedInstallSuccess: SLOMeasurement
    public let syncSuccess: SLOMeasurement

    /// Overall compliance (all SLOs met)
    public var isCompliant: Bool {
        crashFreeSessions.isCompliant &&
        verifiedInstallSuccess.isCompliant &&
        syncSuccess.isCompliant
    }

    /// SLOs that need attention (not compliant or low error budget)
    public var needsAttention: [String: SLOMeasurement] {
        var result: [String: SLOMeasurement] = [:]
        if !crashFreeSessions.isCompliant || crashFreeSessions.shouldAlert {
            result["Crash-Free Sessions"] = crashFreeSessions
        }
        if !verifiedInstallSuccess.isCompliant || verifiedInstallSuccess.shouldAlert {
            result["Verified Installs"] = verifiedInstallSuccess
        }
        if !syncSuccess.isCompliant || syncSuccess.shouldAlert {
            result["Sync Success"] = syncSuccess
        }
        return result
    }
}

// MARK: - Helpers

private extension Double {
    func clamp(min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, self))
   }
}
