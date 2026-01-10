import Foundation

/// Suggested fix for a validation finding
public struct SuggestedFix: Codable, Hashable, Sendable {
    public let ruleID: String
    public let description: String
    public let automated: Bool
    public let changes: [FileChange]
    
    public init(ruleID: String, description: String, automated: Bool, changes: [FileChange]) {
        self.ruleID = ruleID
        self.description = description
        self.automated = automated
        self.changes = changes
    }
}

/// A change to apply to a file
public struct FileChange: Codable, Hashable, Sendable {
    public let fileURL: URL
    public let startLine: Int
    public let endLine: Int
    public let originalText: String
    public let replacementText: String
    
    public init(fileURL: URL, startLine: Int, endLine: Int, originalText: String, replacementText: String) {
        self.fileURL = fileURL
        self.startLine = startLine
        self.endLine = endLine
        self.originalText = originalText
        self.replacementText = replacementText
    }
}

/// Result of applying a fix
public enum FixResult: Sendable {
    case success
    case failed(String)
    case notApplicable
}

/// Engine for generating and applying fixes to validation findings
public final class FixEngine: Sendable {
    
    /// Generate suggested fix for a finding
    public static func suggestFix(for finding: Finding, content: String) -> SuggestedFix? {
        switch finding.ruleID {
        case "frontmatter-structure":
            return fixFrontmatter(finding: finding, content: content)
        case "skill-name-format":
            return fixSkillName(finding: finding, content: content)
        case "description-length":
            return fixDescriptionLength(finding: finding, content: content)
        case "required-sections":
            return fixRequiredSections(finding: finding, content: content)
        default:
            return nil
        }
    }
    
    /// Apply a fix to the filesystem with atomic backup
    public static func applyFix(_ fix: SuggestedFix) -> FixResult {
        var backups: [(URL, String)] = []
        
        do {
            // Create backups for all files
            for change in fix.changes {
                let originalContent = try String(contentsOf: change.fileURL, encoding: .utf8)
                backups.append((change.fileURL, originalContent))
            }
            
            // Apply all changes
            for change in fix.changes {
                try applyChange(change)
            }
            
            return .success
            
        } catch {
            // Rollback on error
            for (url, content) in backups {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
            return .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Fix Generators
    
    private static func fixFrontmatter(finding: Finding, content: String) -> SuggestedFix? {
        let lines = content.components(separatedBy: .newlines)
        
        // Check if frontmatter is missing or malformed
        if !(lines.first?.starts(with: "---") ?? false) {
            let newFrontmatter = """
            ---
            name: skill-name
            description: Brief description of what this skill does
            ---
            
            """
            
            return SuggestedFix(
                ruleID: finding.ruleID,
                description: "Add valid frontmatter at the start of the file",
                automated: true,
                changes: [
                    FileChange(
                        fileURL: finding.fileURL,
                        startLine: 1,
                        endLine: 1,
                        originalText: lines.first ?? "",
                        replacementText: newFrontmatter + (lines.first ?? "")
                    )
                ]
            )
        }
        
        return nil
    }
    
    private static func fixSkillName(finding: Finding, content: String) -> SuggestedFix? {
        let lines = content.components(separatedBy: .newlines)
        
        // Find the name: line in frontmatter
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("name:") {
                let currentName = line
                    .dropFirst(5)
                    .trimmingCharacters(in: .whitespaces)
                
                // Convert to lowercase-hyphenated format
                let fixedName = currentName
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: "_", with: "-")
                
                if fixedName != currentName {
                    return SuggestedFix(
                        ruleID: finding.ruleID,
                        description: "Convert skill name to lowercase-hyphenated format",
                        automated: true,
                        changes: [
                            FileChange(
                                fileURL: finding.fileURL,
                                startLine: index + 1,
                                endLine: index + 1,
                                originalText: line,
                                replacementText: "name: \(fixedName)"
                            )
                        ]
                    )
                }
            }
        }
        
        return nil
    }
    
    private static func fixDescriptionLength(finding: Finding, content: String) -> SuggestedFix {
        // This is a manual fix - provide guidance
        SuggestedFix(
            ruleID: finding.ruleID,
            description: "Shorten description to under 150 characters while preserving key information",
            automated: false,
            changes: []
        )
    }
    
    private static func fixRequiredSections(finding: Finding, content: String) -> SuggestedFix? {
        // Detect which section is missing and suggest adding it
        let lines = content.components(separatedBy: .newlines)
        let message = finding.message.lowercased()
        
        var sectionToAdd = ""
        var sectionTitle = ""
        
        if message.contains("usage") {
            sectionTitle = "## Usage"
            sectionToAdd = """
            
            ## Usage
            
            [Describe how to use this skill]
            
            """
        } else if message.contains("examples") {
            sectionTitle = "## Examples"
            sectionToAdd = """
            
            ## Examples
            
            [Provide usage examples]
            
            """
        }
        
        guard !sectionToAdd.isEmpty else { return nil }
        
        // Find end of file to append section
        let endLine = lines.count
        
        return SuggestedFix(
            ruleID: finding.ruleID,
            description: "Add missing '\(sectionTitle)' section",
            automated: true,
            changes: [
                FileChange(
                    fileURL: finding.fileURL,
                    startLine: endLine,
                    endLine: endLine,
                    originalText: lines.last ?? "",
                    replacementText: (lines.last ?? "") + sectionToAdd
                )
            ]
        )
    }
    
    // MARK: - Private Helpers
    
    private static func applyChange(_ change: FileChange) throws {
        let content = try String(contentsOf: change.fileURL, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        
        // Validate that the original text matches (safety check)
        let startIdx = change.startLine - 1
        let endIdx = change.endLine - 1
        
        guard startIdx >= 0 && endIdx < lines.count else {
            throw NSError(domain: "FixEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Line range out of bounds"])
        }
        
        let originalSection = lines[startIdx...endIdx].joined(separator: "\n")
        
        guard originalSection == change.originalText else {
            throw NSError(domain: "FixEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Original text mismatch - file may have changed"])
        }
        
        // Apply the replacement
        lines.replaceSubrange(startIdx...endIdx, with: [change.replacementText])
        
        let newContent = lines.joined(separator: "\n")
        try newContent.write(to: change.fileURL, atomically: true, encoding: .utf8)
    }
}
