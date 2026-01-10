import Foundation
import AppKit
import SkillsCore

/// Helper for performing actions on findings (baseline, open, copy, etc.)
@MainActor
class FindingActions {
    /// Add a finding to the baseline file
    static func addToBaseline(_ finding: Finding, baselineURL: URL) throws {
        // Load existing baseline or create new one
        let baseline: BaselineManifest
        if FileManager.default.fileExists(atPath: baselineURL.path),
           let data = try? Data(contentsOf: baselineURL),
           let loaded = try? JSONDecoder().decode(BaselineManifest.self, from: data) {
            baseline = loaded
        } else {
            baseline = BaselineManifest(schemaVersion: 1, findings: [])
        }
        
        // Create new entry
        let entry = BaselineEntry(
            ruleID: finding.ruleID,
            file: finding.fileURL.path,
            agent: finding.agent.rawValue
        )
        
        // Check if already baselined
        if baseline.findings.contains(entry) {
            return // Already exists
        }
        
        // Append and save
        var newFindings = baseline.findings
        newFindings.append(entry)
        let newBaseline = BaselineManifest(
            schemaVersion: baseline.schemaVersion,
            findings: newFindings
        )
        
        // Ensure directory exists
        let dir = baselineURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // Write
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(newBaseline)
        try data.write(to: baselineURL, options: .atomic)
    }
    
    /// Open the file containing the finding in the user's default editor
    static func openInEditor(_ fileURL: URL, line: Int? = nil, editor: Editor? = nil) {
        EditorIntegration.openFile(fileURL, line: line, editor: editor)
    }
    
    /// Reveal the file in Finder
    static func showInFinder(_ fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
    
    /// Copy text to clipboard
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct BaselineManifest: Codable {
    let schemaVersion: Int
    var findings: [BaselineEntry]
}
