import Foundation
import Sparkle

/// Wrapper for Sparkle's standard updater controller
@MainActor
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController
    
    init() {
        // Create the controller - this will automatically look for SUFeedURL in Info.plist
        // or we can set it programmatically if we wanted.
        // For standard Sparkle usage, we usually just init standard controller.
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    /// Trigger the "Check for Updates" action
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
