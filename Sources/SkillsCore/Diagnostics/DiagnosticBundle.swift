import Foundation

/// Diagnostic bundle containing system info, scan results, and events for debugging.
/// Encodes to JSON for export and troubleshooting.
public struct DiagnosticBundle: Sendable, Codable {
    /// Unique identifier for this bundle
    public let bundleID: UUID

    /// Timestamp when bundle was generated
    public let generatedAt: Date

    /// sTools version string
    public let sToolsVersion: String

    /// System information at time of bundle generation
    public let systemInfo: SystemInfo

    /// Scan configuration snapshot
    public let scanConfig: ScanConfiguration

    /// Recent validation findings (paths redacted)
    public let recentFindings: [RedactedFinding]

    /// Recent ledger events
    public let ledgerEvents: [LedgerEvent]

    /// Aggregated skill statistics
    public let skillStatistics: SkillStatistics

    public init(
        bundleID: UUID = UUID(),
        generatedAt: Date = Date(),
        sToolsVersion: String,
        systemInfo: SystemInfo,
        scanConfig: ScanConfiguration,
        recentFindings: [Finding],
        ledgerEvents: [LedgerEvent],
        skillStatistics: SkillStatistics
    ) {
        self.bundleID = bundleID
        self.generatedAt = generatedAt
        self.sToolsVersion = sToolsVersion
        self.systemInfo = systemInfo
        self.scanConfig = scanConfig
        self.recentFindings = recentFindings.map(RedactedFinding.init(from:))
        self.ledgerEvents = ledgerEvents
        self.skillStatistics = skillStatistics
    }
}

// MARK: - Redacted Finding

/// A Finding with PII-redacted file paths for diagnostic bundles.
public struct RedactedFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID = UUID()
    public let ruleID: RuleID
    public let severity: Severity
    public let agent: AgentKind
    public let filePath: String  // Redacted path
    public let message: String
    public let line: Int?
    public let column: Int?
    public let suggestedFix: SuggestedFix?

    public init(from finding: Finding) {
        self.id = finding.id
        self.ruleID = finding.ruleID
        self.severity = finding.severity
        self.agent = finding.agent
        self.filePath = TelemetryRedactor.redactPath(finding.fileURL.path)
        self.message = finding.message
        self.line = finding.line
        self.column = finding.column
        self.suggestedFix = finding.suggestedFix
    }
}

// MARK: - Nested Types

extension DiagnosticBundle {
    /// System information at time of diagnostic collection
    public struct SystemInfo: Sendable, Codable {
        /// macOS version (e.g., "14.5.0")
        public let macOSVersion: String

        /// System architecture (e.g., "arm64", "x86_64")
        public let architecture: String

        /// Host name (redacted for privacy)
        public let hostName: String

        /// Available disk space in bytes
        public let availableDiskSpace: Int64

        /// Total memory in bytes
        public let totalMemory: Int64

        public init(
            macOSVersion: String,
            architecture: String,
            hostName: String,
            availableDiskSpace: Int64,
            totalMemory: Int64
        ) {
            self.macOSVersion = macOSVersion
            self.architecture = architecture
            self.hostName = hostName
            self.availableDiskSpace = availableDiskSpace
            self.totalMemory = totalMemory
        }
    }

    /// Snapshot of scan configuration
    public struct ScanConfiguration: Sendable, Codable {
        /// Codex skill root paths
        public let codexRoots: [String]

        /// Claude skill root path
        public let claudeRoot: String?

        /// CodexSkillManager root path
        public let codexSkillManagerRoot: String?

        /// Copilot root path
        public let copilotRoot: String?

        /// Whether scan was recursive
        public let recursive: Bool

        /// Max scan depth (if set)
        public let maxDepth: Int?

        /// Exclude patterns
        public let excludes: [String]

        public init(
            codexRoots: [String],
            claudeRoot: String?,
            codexSkillManagerRoot: String?,
            copilotRoot: String?,
            recursive: Bool,
            maxDepth: Int?,
            excludes: [String]
        ) {
            self.codexRoots = codexRoots
            self.claudeRoot = claudeRoot
            self.codexSkillManagerRoot = codexSkillManagerRoot
            self.copilotRoot = copilotRoot
            self.recursive = recursive
            self.maxDepth = maxDepth
            self.excludes = excludes
        }

        // MARK: - Custom Coding for PII Redaction

        enum CodingKeys: String, CodingKey {
            case codexRoots
            case claudeRoot
            case codexSkillManagerRoot
            case copilotRoot
            case recursive
            case maxDepth
            case excludes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.codexRoots = try container.decode([String].self, forKey: .codexRoots)
            self.claudeRoot = try container.decodeIfPresent(String.self, forKey: .claudeRoot)
            self.codexSkillManagerRoot = try container.decodeIfPresent(String.self, forKey: .codexSkillManagerRoot)
            self.copilotRoot = try container.decodeIfPresent(String.self, forKey: .copilotRoot)
            self.recursive = try container.decode(Bool.self, forKey: .recursive)
            self.maxDepth = try container.decodeIfPresent(Int.self, forKey: .maxDepth)
            self.excludes = try container.decode([String].self, forKey: .excludes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(redactPaths(codexRoots), forKey: .codexRoots)
            try container.encodeIfPresent(claudeRoot.map(TelemetryRedactor.redactPath), forKey: .claudeRoot)
            try container.encodeIfPresent(codexSkillManagerRoot.map(TelemetryRedactor.redactPath), forKey: .codexSkillManagerRoot)
            try container.encodeIfPresent(copilotRoot.map(TelemetryRedactor.redactPath), forKey: .copilotRoot)
            try container.encode(recursive, forKey: .recursive)
            try container.encodeIfPresent(maxDepth, forKey: .maxDepth)
            try container.encode(excludes, forKey: .excludes)
        }

        private func redactPaths(_ paths: [String]) -> [String] {
            paths.map(TelemetryRedactor.redactPath)
        }
    }

    /// Aggregated statistics about scanned skills
    public struct SkillStatistics: Sendable, Codable {
        /// Total skills scanned
        public let totalSkills: Int

        /// Skills by agent type
        public let skillsByAgent: [String: Int]

        /// Skills with errors
        public let skillsWithErrors: Int

        /// Skills with warnings
        public let skillsWithWarnings: Int

        /// Total findings count
        public let totalFindings: Int

        public init(
            totalSkills: Int,
            skillsByAgent: [String: Int],
            skillsWithErrors: Int,
            skillsWithWarnings: Int,
            totalFindings: Int
        ) {
            self.totalSkills = totalSkills
            self.skillsByAgent = skillsByAgent
            self.skillsWithErrors = skillsWithErrors
            self.skillsWithWarnings = skillsWithWarnings
            self.totalFindings = totalFindings
        }
    }
}

// MARK: - JSON Encoding Helper

extension DiagnosticBundle {
    /// Encode bundle to JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decode bundle from JSON data
    public static func fromJSON(_ data: Data) throws -> DiagnosticBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiagnosticBundle.self, from: data)
    }
}
