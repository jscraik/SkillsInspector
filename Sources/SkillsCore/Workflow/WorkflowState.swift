import Foundation

/// Workflow stage enum for skill lifecycle management
public enum Stage: String, Codable, Sendable, CaseIterable {
    case draft
    case validating
    case reviewed
    case approved
    case published
    case archived

    /// Display name for the stage
    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .validating: return "Validating"
        case .reviewed: return "Reviewed"
        case .approved: return "Approved"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }

    /// Icon for the stage
    public var icon: String {
        switch self {
        case .draft: return "pencil"
        case .validating: return "checkmark.circle"
        case .reviewed: return "eye"
        case .approved: return "checkmark.shield.fill"
        case .published: return "globe"
        case .archived: return "archivebox"
        }
    }

    /// Next stage in the workflow
    public var nextStage: Stage? {
        switch self {
        case .draft: return .validating
        case .validating: return .reviewed
        case .reviewed: return .approved
        case .approved: return .published
        case .published: return .archived
        case .archived: return nil
        }
    }

    /// Previous stage in the workflow
    public var previousStage: Stage? {
        switch self {
        case .draft: return nil
        case .validating: return .draft
        case .reviewed: return .validating
        case .approved: return .reviewed
        case .published: return .approved
        case .archived: return .published
        }
    }

    /// Whether this stage allows skill editing
    public var isEditable: Bool {
        switch self {
        case .draft, .validating:
            return true
        case .reviewed, .approved, .published, .archived:
            return false
        }
    }
}

/// Workflow state for tracking skill lifecycle
public struct WorkflowState: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let skillSlug: String
    public var stage: Stage
    public var validationResults: [WorkflowValidationError]
    public var reviewNotes: String
    public var reviewer: String?
    public var versionHistory: [VersionEntry]
    public var createdAt: Date
    public var updatedAt: Date
    
    // Implement Hashable manually
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(skillSlug)
        hasher.combine(stage)
    }
    
    public static func == (lhs: WorkflowState, rhs: WorkflowState) -> Bool {
        lhs.id == rhs.id && lhs.skillSlug == rhs.skillSlug && lhs.stage == rhs.stage
    }

    public init(
        id: String = UUID().uuidString,
        skillSlug: String,
        stage: Stage = .draft,
        validationResults: [WorkflowValidationError] = [],
        reviewNotes: String = "",
        reviewer: String? = nil,
        versionHistory: [VersionEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skillSlug = skillSlug
        self.stage = stage
        self.validationResults = validationResults
        self.reviewNotes = reviewNotes
        self.reviewer = reviewer
        if versionHistory.isEmpty {
            self.versionHistory = [
                VersionEntry(
                    version: "1",
                    stage: stage,
                    changedBy: "system",
                    changelog: "Initial state"
                )
            ]
        } else {
            self.versionHistory = versionHistory
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Version history entry
    public struct VersionEntry: Codable, Sendable, Identifiable {
        public let id: String
        public let version: String
        public let stage: Stage
        public let changedBy: String
        public let changedAt: Date
        public let changelog: String

        public init(
            id: String = UUID().uuidString,
            version: String,
            stage: Stage,
            changedBy: String,
            changedAt: Date = Date(),
            changelog: String = ""
        ) {
            self.id = id
            self.version = version
            self.stage = stage
            self.changedBy = changedBy
            self.changedAt = changedAt
            self.changelog = changelog
        }
    }

    /// Add a validation result
    public mutating func addValidationResult(_ result: WorkflowValidationError) {
        validationResults.append(result)
        updatedAt = Date()
    }

    /// Clear validation results
    public mutating func clearValidationResults() {
        validationResults = []
        updatedAt = Date()
    }

    /// Transition to a new stage
    public mutating func transitionTo(_ newStage: Stage, by reviewer: String? = nil, notes: String = "") {
        let entry = VersionEntry(
            version: "\(versionHistory.count + 1)",
            stage: newStage,
            changedBy: reviewer ?? "system",
            changelog: notes
        )
        versionHistory.append(entry)
        stage = newStage
        if let reviewer = reviewer {
            self.reviewer = reviewer
        }
        reviewNotes = notes
        updatedAt = Date()
    }

    /// Check if workflow is in a valid state
    public var isValid: Bool {
        switch stage {
        case .validating, .reviewed, .approved, .published:
            return validationResults.allSatisfy { !$0.severity.isError }
        case .draft, .archived:
            return true
        }
    }

    /// Get error count
    public var errorCount: Int {
        validationResults.filter { $0.severity.isError }.count
    }

    /// Get warning count
    public var warningCount: Int {
        validationResults.filter { $0.severity.isWarning }.count
    }
}

/// Workflow validation error
public struct WorkflowValidationError: Codable, Sendable, Identifiable, LocalizedError {
    public let id: String
    public let code: String
    public let message: String
    public let severity: Severity
    public let file: String
    public let line: Int?

    public enum Severity: String, Codable, Sendable {
        case error
        case warning
        case info

        public var isError: Bool {
            self == .error
        }

        public var isWarning: Bool {
            self == .warning
        }
    }

    public init(
        id: String = UUID().uuidString,
        code: String,
        message: String,
        severity: Severity = .error,
        file: String = "",
        line: Int? = nil
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.severity = severity
        self.file = file
        self.line = line
    }

    public var errorDescription: String? {
        var result = "[\(severity.rawValue.uppercased())] \(code): \(message)"
        if !file.isEmpty {
            result += " (file: \(file)"
            if let line = line {
                result += ":\(line)"
            }
            result += ")"
        }
        return result
    }
}
