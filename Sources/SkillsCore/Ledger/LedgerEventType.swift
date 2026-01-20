import Foundation

public enum LedgerEventType: String, Codable, CaseIterable, Sendable {
    case install
    case update
    case remove
    case verify
    case sync
    case appLaunch
    case crash
}
