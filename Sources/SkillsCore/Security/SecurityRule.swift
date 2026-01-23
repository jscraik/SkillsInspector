import Foundation

/// Security validation rule for detecting security issues in skill scripts
public protocol SecurityRule: Sendable {
    /// Unique identifier for this rule
    var ruleID: String { get }

    /// Human-readable description of what this rule detects
    var description: String { get }

    /// Severity level for violations
    var severity: Severity { get }

    /// Patterns to match for security violations
    var patterns: [SecurityPattern] { get }

    /// Scan content for security violations
    /// - Parameters:
    ///   - content: File content to scan
    ///   - file: URL of the file being scanned
    ///   - skillDoc: Associated skill document
    /// - Returns: Array of security findings
    func scan(content: String, file: URL, skillDoc: SkillDoc) async throws -> [Finding]
}

/// Security pattern with regex and context
public struct SecurityPattern: Sendable {
    /// Type of security issue
    public let type: PatternType

    /// Compiled regex pattern
    public let regex: NSRegularExpression

    /// Error message to display when pattern matches
    public let message: String

    /// Suggested fix for the issue
    public let suggestedFix: String?

    public init(
        type: PatternType,
        regex: NSRegularExpression,
        message: String,
        suggestedFix: String? = nil
    ) {
        self.type = type
        self.regex = regex
        self.message = message
        self.suggestedFix = suggestedFix
    }

    /// Create pattern from regex string (throws if invalid)
    public init(
        type: PatternType,
        pattern: String,
        message: String,
        suggestedFix: String? = nil
    ) throws {
        self.type = type
        self.regex = try NSRegularExpression(pattern: pattern)
        self.message = message
        self.suggestedFix = suggestedFix
    }
}

/// Categories of security patterns
public enum PatternType: String, Sendable, Codable {
    case secret
    case commandInjection
    case insecureFileOp
    case hardcodedCredential
    case evalUsage
}
