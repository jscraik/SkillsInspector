import Foundation

/// Enhanced error context for validation findings.
public struct ErrorContext: Sendable, Codable, Hashable {
    /// Expected value (what was correct)
    public let expected: String?

    /// Actual value (what was found)
    public let actual: String?

    /// Related files that may be relevant to this error
    public let relatedFiles: [RelatedFile]

    /// Suggested fixes for this error
    public let suggestedFixes: [SuggestedFix]

    /// Next steps the user can take
    public let nextSteps: [String]

    /// Link to documentation
    public let documentationLink: String?

    public init(
        expected: String? = nil,
        actual: String? = nil,
        relatedFiles: [RelatedFile] = [],
        suggestedFixes: [SuggestedFix] = [],
        nextSteps: [String] = [],
        documentationLink: String? = nil
    ) {
        self.expected = expected
        self.actual = actual
        self.relatedFiles = relatedFiles
        self.suggestedFixes = suggestedFixes
        self.nextSteps = nextSteps
        self.documentationLink = documentationLink
    }
}

/// A related file reference for error context.
public struct RelatedFile: Sendable, Codable, Hashable {
    /// Path to the related file
    public let path: String

    /// Reason why this file is related
    public let reason: String

    /// Relevant line number (if applicable)
    public let line: Int?

    public init(path: String, reason: String, line: Int? = nil) {
        self.path = path
        self.reason = reason
        self.line = line
    }
}
