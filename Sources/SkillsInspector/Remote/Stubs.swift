import Foundation
import SkillsCore

// Temporary stubs for missing types referenced by RemoteView
// TODO: Implement proper trust prompt UI

enum TrustPrompt {
    case none
}

struct BulkOperationProgress {
    let current: Int
    let total: Int
    let operation: BulkOperation

    enum BulkOperation {
        var displayName: String {
            switch self {
            case .verifying: return "Verifying"
            case .updating: return "Updating"
            }
        }

        case verifying
        case updating
    }
}
