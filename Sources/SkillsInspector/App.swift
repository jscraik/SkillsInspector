import SwiftUI
import AppKit
import SkillsCore

@main
struct sToolsApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("sTools") {
            ContentView()
                .frame(minWidth: 1024, minHeight: 700)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                // No new document in this app
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    if let url = URL(string: "sinspect://settings") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Scan") {
                Button("Run Scan") {
                    NotificationCenter.default.post(name: .runScan, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Cancel Scan") {
                    NotificationCenter.default.post(name: .cancelScan, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)
                
                Divider()
                
                Button("Toggle Watch Mode") {
                    NotificationCenter.default.post(name: .toggleWatch, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Clear Cache") {
                    NotificationCenter.default.post(name: .clearCache, object: nil)
                }
            }
            
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    if let url = URL(string: "sinspect://shortcuts") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
        
        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Window("Keyboard Shortcuts", id: "shortcuts") {
            KeyboardShortcutsView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .keyboardShortcut("?", modifiers: .command)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let runScan = Notification.Name("runScan")
    static let cancelScan = Notification.Name("cancelScan")
    static let toggleWatch = Notification.Name("toggleWatch")
    static let clearCache = Notification.Name("clearCache")
}

enum AppMode: Hashable {
    case validate
    case stats
    case sync
    case index
    case remote
    case changelog
}
