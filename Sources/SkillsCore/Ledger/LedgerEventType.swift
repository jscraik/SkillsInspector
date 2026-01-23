import Foundation

public enum LedgerEventType: String, Codable, CaseIterable, Sendable {
    case install
    case update
    case remove
    case verify
    case sync
    case appLaunch
    case crash

    // Phase 1 enhancement event types
    case diagnosticBundle   // Feature 1: Diagnostic bundle generation
    case analyticsQuery     // Feature 2: Analytics queries
    case securityScan       // Feature 5: Security scanning
}
