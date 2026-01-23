import Foundation

/// Collects diagnostic bundles containing system info, scan results, and ledger events.
/// Queries SkillLedger for recent events and aggregates findings for debugging support.
public actor DiagnosticBundleCollector {

    // MARK: - Properties

    private let ledger: SkillLedger

    // MARK: - Initialization

    /// Initialize with a custom ledger instance
    /// - Parameter ledger: The SkillLedger to query for events
    public init(ledger: SkillLedger) {
        self.ledger = ledger
    }

    /// Initialize with default ledger
    public init() throws {
        self.ledger = try SkillLedger()
    }

    // MARK: - Collection

    /// Collect a diagnostic bundle with system info, findings, config, and recent events.
    ///
    /// - Parameters:
    ///   - findings: Validation findings to include in the bundle
    ///   - config: Scan configuration snapshot (roots, excludes, depth)
    ///   - includeLogs: Whether to include log entries (default: false)
    ///   - logHours: Number of hours of log history to include (default: 24)
    /// - Returns: A complete DiagnosticBundle for export
    /// - Throws: Ledger access errors
    public func collect(
        findings: [Finding],
        config: DiagnosticBundle.ScanConfiguration,
        includeLogs: Bool = false,
        logHours: Int = 24
    ) async throws -> DiagnosticBundle {

        // Collect system information
        let systemInfo = SystemInfoCollector.collect()

        // Query recent ledger events (last 7 days by default)
        let sinceDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let ledgerEvents = try await ledger.fetchEvents(
            limit: 1000,
            since: sinceDate
        )

        // Compute skill statistics from findings
        let statistics = computeStatistics(from: findings)

        // Build the bundle
        let bundle = DiagnosticBundle(
            bundleID: UUID(),
            generatedAt: Date(),
            sToolsVersion: BundleVersion.current,
            systemInfo: systemInfo,
            scanConfig: config,
            recentFindings: findings,
            ledgerEvents: ledgerEvents,
            skillStatistics: statistics
        )

        return bundle
    }

    // MARK: - Private Helpers

    /// Compute aggregated statistics from findings.
    private func computeStatistics(from findings: [Finding]) -> DiagnosticBundle.SkillStatistics {
        // Group skills by agent
        var skillsByAgent: [String: Int] = [:]
        for finding in findings {
            let agent = finding.agent.rawValue
            skillsByAgent[agent, default: 0] += 1
        }

        // Count unique skills by file URL
        let uniqueSkills = Set(findings.map { $0.fileURL.path }).count

        // Count skills with errors vs warnings
        let filesWithErrors = Set(findings.filter { $0.severity == .error }.map { $0.fileURL.path }).count
        let filesWithWarnings = Set(findings.filter { $0.severity == .warning }.map { $0.fileURL.path }).count

        return DiagnosticBundle.SkillStatistics(
            totalSkills: uniqueSkills,
            skillsByAgent: skillsByAgent,
            skillsWithErrors: filesWithErrors,
            skillsWithWarnings: filesWithWarnings,
            totalFindings: findings.count
        )
    }
}

// MARK: - Bundle Version Helper

/// Helper to get current sTools version string
private enum BundleVersion {
    /// Current sTools version string from Bundle
    static var current: String {
        #if canImport(AppKit)
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        if let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return version
        }
        #endif
        return "0.0.0"
    }
}
