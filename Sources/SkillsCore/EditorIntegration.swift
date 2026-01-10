import Foundation
#if os(macOS)
import AppKit
#endif

public enum Editor: String, CaseIterable, Sendable {
    case vscode = "VS Code"
    case cursor = "Cursor"
    case codexCLI = "Codex CLI"
    case claudeCode = "Claude Code"
    case kiro = "Kiro IDE"
    case xcode = "Xcode"
    case finder = "Finder"
    
    public var bundleIdentifier: String? {
        switch self {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .codexCLI: return nil // CLI tool
        case .claudeCode: return "com.anthropic.claude-code"
        case .kiro: return "com.kiro.ide"
        case .xcode: return "com.apple.dt.Xcode"
        case .finder: return "com.apple.finder"
        }
    }
    
    public var icon: String {
        switch self {
        case .vscode: return "curlybraces"
        case .cursor: return "curlybraces.square"
        case .codexCLI: return "terminal"
        case .claudeCode: return "brain.head.profile"
        case .kiro: return "sparkles"
        case .xcode: return "hammer"
        case .finder: return "folder"
        }
    }
    
    public func isInstalled() -> Bool {
        #if os(macOS)
        if let bundleId = bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        } else if self == .codexCLI {
            // Check if codex CLI exists
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["codex"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        }
        return false
        #else
        return false
        #endif
    }
    
    public func openFile(_ url: URL, line: Int? = nil, column: Int? = nil) {
        #if os(macOS)
        switch self {
        case .vscode, .cursor:
            openVSCodeLike(url, line: line, column: column)
        case .codexCLI:
            openCodexCLI(url, line: line)
        case .claudeCode:
            openClaudeCode(url, line: line)
        case .kiro:
            openKiro(url, line: line)
        case .xcode:
            openXcode(url)
        case .finder:
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
        #endif
    }
    
    #if os(macOS)
    private func openVSCodeLike(_ url: URL, line: Int?, column: Int?) {
        var urlString = "vscode://file\(url.path)"
        if let line {
            urlString += ":\(line)"
            if let column {
                urlString += ":\(column)"
            }
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openCodexCLI(_ url: URL, line: Int?) {
        // Use codex CLI to open file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var args = ["codex", "open", url.path]
        if let line {
            args.append("--line")
            args.append("\(line)")
        }
        process.arguments = args
        
        try? process.run()
    }
    
    private func openClaudeCode(_ url: URL, line: Int?) {
        // Use claude:// URL scheme or CLI if available
        var urlString = "claude://file\(url.path)"
        if let line {
            urlString += ":\(line)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openKiro(_ url: URL, line: Int?) {
        // Use kiro:// URL scheme
        var urlString = "kiro://file\(url.path)"
        if let line {
            urlString += ":\(line)"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openXcode(_ url: URL) {
        // Xcode doesn't support line numbers in URL scheme
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/Applications/Xcode.app"), configuration: NSWorkspace.OpenConfiguration())
    }
    #endif
}

public enum EditorIntegration {
    public static var defaultEditor: Editor {
        get {
            if let raw = UserDefaults.standard.string(forKey: "defaultEditor"),
               let editor = Editor(rawValue: raw) {
                return editor
            }
            // Auto-detect installed editor
            return Editor.allCases.first { $0.isInstalled() } ?? .finder
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "defaultEditor")
        }
    }
    
    public static func openFile(_ url: URL, line: Int? = nil, column: Int? = nil, editor: Editor? = nil) {
        let targetEditor = editor ?? defaultEditor
        targetEditor.openFile(url, line: line, column: column)
    }
    
    public static var installedEditors: [Editor] {
        Editor.allCases.filter { $0.isInstalled() }
    }
}
