import Foundation

/// Detects hardcoded secrets, API keys, tokens, and passwords in code
///
/// This rule uses context-aware patterns to reduce false positives by checking for:
/// - Assignment patterns (variable = value)
/// - Quoted strings (single or double quotes)
/// - Minimum length threshold (32+ characters)
public struct HardcodedSecretRule: SecurityRule {
    public let ruleID = "security.hardcoded_secret"
    public let description = "Detects hardcoded API keys, secrets, tokens, and passwords"
    public let severity: Severity = .error

    /// Patterns for detecting hardcoded secrets with context
    public let patterns: [SecurityPattern]

    public init() {
        var patterns: [SecurityPattern] = []

        // Pattern 1: Variable assignment with long string value
        // Matches: apiKey = "sk-1234567890..." (32+ chars after prefix)
        // Context: Assignment with quoted value
        if let pattern1 = try? SecurityPattern(
            type: .secret,
            pattern: #"(?i)(?:let|var|const|private|public|internal|fileprivate)\s+(?:api[_-]?key|secret|token|password|passphrase|auth[_-]?token|access[_-]?key|secret[_-]?key|api[_-]?secret)\s*[:=]\s*['"]\s*([a-zA-Z0-9_+-/]{32,})['"]"#,
            message: "Possible hardcoded secret detected (32+ character string assigned to sensitive variable name)",
            suggestedFix: "Use environment variables or secure credential storage"
        ) {
            patterns.append(pattern1)
        }

        // Pattern 2: Direct string literals with common secret prefixes
        // Matches: "sk-...", "Bearer eyJ...", "pk_test_..." (32+ chars)
        // Context: Quoted strings with known secret prefixes
        if let pattern2 = try? SecurityPattern(
            type: .secret,
            pattern: #"['\"]\s*(sk-[a-zA-Z0-9]{32,}|pk_[a-zA-Z0-9]{32,}|Bearer\s+[a-zA-Z0-9._-]{32,}|eyJ[a-zA-Z0-9+/=-]{32,})\s*['\"]"#,
            message: "Possible hardcoded secret with known prefix (sk-, pk_, Bearer, JWT)",
            suggestedFix: "Use environment variables or secure credential storage"
        ) {
            patterns.append(pattern2)
        }

        // Pattern 3: Password/secret in config-like format
        // Matches: password: "longstring...", secret: "longstring..." (32+ chars)
        // Context: Config/property assignment
        if let pattern3 = try? SecurityPattern(
            type: .hardcodedCredential,
            pattern: #"(?i)(password|secret|token|api[_-]?key|access[_-]?key)\s*[:=]\s*['"][^\s'"]{32,}['"]"#,
            message: "Possible hardcoded credential in config format",
            suggestedFix: "Use environment variables or secure credential storage"
        ) {
            patterns.append(pattern3)
        }

        self.patterns = patterns
    }

    public func scan(content: String, file: URL, skillDoc: SkillDoc) async throws -> [Finding] {
        var findings: [Finding] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var linesWithFindings: Set<Int> = Set()  // Deduplicate by line number

        for (lineIndex, line) in lines.enumerated() {
            let lineStr = String(line)
            let lineNum = lineIndex + 1

            // Check each pattern
            for pattern in patterns {
                let range = NSRange(location: 0, length: lineStr.utf16.count)
                let matches = pattern.regex.matches(in: lineStr, range: range)

                for match in matches {
                    // Extract matched string for validation
                    if let matchRange = Range(match.range, in: lineStr) {
                        let matchedText = String(lineStr[matchRange])

                        // Additional validation: check if this looks like a real secret
                        if isValidSecret(matchedText) && !linesWithFindings.contains(lineNum) {
                            linesWithFindings.insert(lineNum)
                            findings.append(Finding(
                                ruleID: ruleID,
                                severity: severity,
                                agent: skillDoc.agent,
                                fileURL: file,
                                message: pattern.message,
                                line: lineNum,
                                column: nil,
                                suggestedFix: SuggestedFix(
                                    ruleID: ruleID,
                                    description: pattern.suggestedFix ?? "Remove hardcoded secret",
                                    automated: false,
                                    changes: []
                                )
                            ))
                        }
                    }
                }
            }
        }

        return findings
    }

    /// Additional validation to reduce false positives
    /// - Parameters:
    ///   - text: The matched text to validate
    /// - Returns: True if this appears to be a real secret
    private func isValidSecret(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must be at least 32 characters
        guard trimmed.count >= 32 else { return false }

        // Should contain mix of alphanumeric (common in real secrets)
        let hasLetters = trimmed.contains { $0.isLetter }
        let hasNumbers = trimmed.contains { $0.isNumber }

        // At least one of letters or numbers
        guard hasLetters || hasNumbers else { return false }

        // Reject obvious placeholders
        let placeholders = [
            "your_api_key",
            "your_secret",
            "your_token",
            "your_password",
            "replace_with",
            "example",
            "placeholder",
            "xxx",
            "0000000000"
        ]

        let lowercased = trimmed.lowercased()
        for placeholder in placeholders {
            if lowercased.contains(placeholder) {
                return false
            }
        }

        return true
    }
}
