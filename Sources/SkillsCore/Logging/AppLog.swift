import Foundation
import OSLog

// MARK: - Unified Logging

/// Centralized logging configuration for sTools.
/// Provides consistent structured logging across the codebase.
///
/// Usage:
/// ```swift
/// AppLog.ledger.info("Recorded new event", "skillId: \(skillId)")
/// AppLog.network.error("Request failed", error: error)
/// ```
public enum AppLog {
    /// Subsystem identifier for all sTools logs
    public static let subsystem = "com.stools.skills"

    /// Log categories for different components
    public enum Category: String {
        case general = "General"
        case ledger = "Ledger"
        case telemetry = "Telemetry"
        case remote = "Remote"
        case network = "Network"
        case validation = "Validation"
        case publishing = "Publishing"
        case sync = "Sync"
        case ui = "UI"
        case diagnostics = "Diagnostics"
        case analytics = "Analytics"
        case dependencies = "Dependencies"
        case security = "Security"
    }

    /// Create a logger for a specific category
    public static func make(category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    // Pre-configured loggers for common categories
    public static let general = make(category: .general)
    public static let ledger = make(category: .ledger)
    public static let telemetry = make(category: .telemetry)
    public static let remote = make(category: .remote)
    public static let network = make(category: .network)
    public static let validation = make(category: .validation)
    public static let publishing = make(category: .publishing)
    public static let sync = make(category: .sync)
    public static let ui = make(category: .ui)
    public static let diagnostics = make(category: .diagnostics)
    public static let analytics = make(category: .analytics)
    public static let dependencies = make(category: .dependencies)
    public static let security = make(category: .security)
}

// MARK: - Legacy Print Bridge

/// For gradual migration: intercept print() calls and redirect to logger
/// Usage: Replace `print(...)` with `Log.print(...)` to enable structured logging
public enum Log {
    public static func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        let message = items.map { "\($0)" }.joined(separator: separator)
        AppLog.general.info("\(message)")
    }

    public static func debug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: separator)
        AppLog.general.debug("\(message)")
        #endif
    }
}
