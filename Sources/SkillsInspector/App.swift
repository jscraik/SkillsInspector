import SwiftUI
import AppKit

@main
struct SkillsInspectorApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Skills Inspector") {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}

enum AppMode: Hashable {
    case validate
    case sync
    case index
}
