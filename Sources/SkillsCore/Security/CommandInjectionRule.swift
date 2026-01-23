import Foundation

/// Detects command injection vulnerabilities in code
///
/// This rule detects dangerous command execution patterns that could lead to
/// command injection attacks, including:
/// - Direct shell command execution with user input
/// - System calls with concatenated strings
/// - Process execution with unsanitized arguments
public struct CommandInjectionRule: SecurityRule {
    public let ruleID = "security.command_injection"
    public let description = "Detects command injection vulnerabilities through shell(), system(), exec(), popen(), and Process"
    public let severity: Severity = .error

    /// Patterns for detecting command injection vulnerabilities
    public let patterns: [SecurityPattern]

    public init() {
        var patterns: [SecurityPattern] = []

        // Pattern 1: shell() calls - simplified pattern
        if let pattern1 = try? SecurityPattern(
            type: .commandInjection,
            pattern: #"shell\s*\("#,
            message: "Direct shell execution with potentially unsafe arguments - shell() can execute arbitrary commands",
            suggestedFix: "Use Process class with proper argument escaping"
        ) {
            patterns.append(pattern1)
        }

        // Pattern 2: system() calls - simplified pattern
        if let pattern2 = try? SecurityPattern(
            type: .commandInjection,
            pattern: #"system\s*\("#,
            message: "Direct system() call with potentially unsafe command string",
            suggestedFix: "Use Process class with proper argument escaping"
        ) {
            patterns.append(pattern2)
        }

        // Pattern 3: exec() calls - simplified pattern
        if let pattern3 = try? SecurityPattern(
            type: .commandInjection,
            pattern: #"exec\s*\("#,
            message: "Direct exec() call - may execute commands without proper sanitization",
            suggestedFix: "Use Process class with proper argument escaping"
        ) {
            patterns.append(pattern3)
        }

        // Pattern 4: popen() calls - simplified pattern
        if let pattern4 = try? SecurityPattern(
            type: .commandInjection,
            pattern: #"popen\s*\("#,
            message: "popen() executes commands through shell - vulnerable to injection",
            suggestedFix: "Use Process class with proper argument escaping"
        ) {
            patterns.append(pattern4)
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

                        // Additional validation: check if this looks like a real command injection risk
                        if isCommandInjectionRisk(matchedText, line: lineStr) && !linesWithFindings.contains(lineNum) {
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
                                    description: pattern.suggestedFix ?? "Use Process class with proper argument escaping",
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
    ///   - line: The full line content for context
    /// - Returns: True if this appears to be a real command injection risk
    private func isCommandInjectionRisk(_ text: String, line: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must contain shell-related patterns
        guard trimmed.contains("shell") ||
              trimmed.contains("system") ||
              trimmed.contains("exec") ||
              trimmed.contains("popen") else {
            return false
        }

        // Reject comments
        let lineContent = line.trimmingCharacters(in: .whitespaces)
        if lineContent.hasPrefix("//") || lineContent.hasPrefix("#") {
            return false
        }

        // Check for actual function call syntax
        let hasCallSyntax = trimmed.contains("(")
        guard hasCallSyntax else { return false }

        // If it has shell/system/exec/popen AND opening paren, it's likely a call
        return true
    }
}
