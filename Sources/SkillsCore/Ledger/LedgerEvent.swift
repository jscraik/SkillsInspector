import Foundation

public struct LedgerEvent: Identifiable, Sendable, Codable {
    // MARK: - PII Redaction for Diagnostic Bundles

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case eventType
        case skillName
        case skillSlug
        case version
        case agent
        case status
        case note
        case source
        case verification
        case manifestSHA256
        case targetPath
        case targets
        case perTargetResults
        case signerKeyId
        case timeoutCount
        case retryCount
        case timeoutDuration
    }

    // Custom encoding to redact PII from file paths
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(skillName, forKey: .skillName)
        try container.encodeIfPresent(skillSlug, forKey: .skillSlug)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(agent, forKey: .agent)
        try container.encode(status, forKey: .status)

        // Redact PII from note field
        if let note = note {
            let redactedNote = TelemetryRedactor.scrubPII(note)
            try container.encode(redactedNote, forKey: .note)
        } else {
            try container.encodeIfPresent(note as String?, forKey: .note)
        }

        // Redact home directory from source (may contain file paths)
        if let source = source {
            try container.encode(TelemetryRedactor.redactPath(source), forKey: .source)
        } else {
            try container.encodeIfPresent(source as String?, forKey: .source)
        }

        try container.encodeIfPresent(verification, forKey: .verification)
        try container.encodeIfPresent(manifestSHA256, forKey: .manifestSHA256)

        // Redact home directory from targetPath (file path)
        if let targetPath = targetPath {
            try container.encode(TelemetryRedactor.redactPath(targetPath), forKey: .targetPath)
        } else {
            try container.encodeIfPresent(targetPath as String?, forKey: .targetPath)
        }

        try container.encodeIfPresent(targets, forKey: .targets)
        try container.encodeIfPresent(perTargetResults, forKey: .perTargetResults)
        try container.encodeIfPresent(signerKeyId, forKey: .signerKeyId)
        try container.encodeIfPresent(timeoutCount, forKey: .timeoutCount)
        try container.encodeIfPresent(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(timeoutDuration, forKey: .timeoutDuration)
    }
    public let id: Int64
    public let timestamp: Date
    public let eventType: LedgerEventType
    public let skillName: String
    public let skillSlug: String?
    public let version: String?
    public let agent: AgentKind?
    public let status: LedgerEventStatus
    public let note: String?
    public let source: String?
    public let verification: RemoteVerificationMode?
    public let manifestSHA256: String?
    public let targetPath: String?
    public let targets: [AgentKind]?
    public let perTargetResults: [AgentKind: String]?
    public let signerKeyId: String?

    // Network resilience metrics (P3)
    public let timeoutCount: Int?
    public let retryCount: Int?
    public let timeoutDuration: TimeInterval?  // in seconds

    public init(
        id: Int64,
        timestamp: Date,
        eventType: LedgerEventType,
        skillName: String,
        skillSlug: String?,
        version: String?,
        agent: AgentKind?,
        status: LedgerEventStatus,
        note: String?,
        source: String?,
        verification: RemoteVerificationMode?,
        manifestSHA256: String?,
        targetPath: String?,
        targets: [AgentKind]?,
        perTargetResults: [AgentKind: String]?,
        signerKeyId: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.skillName = skillName
        self.skillSlug = skillSlug
        self.version = version
        self.agent = agent
        self.status = status
        self.note = note
        self.source = source
        self.verification = verification
        self.manifestSHA256 = manifestSHA256
        self.targetPath = targetPath
        self.targets = targets
        self.perTargetResults = perTargetResults
        self.signerKeyId = signerKeyId
        self.timeoutCount = nil
        self.retryCount = nil
        self.timeoutDuration = nil
    }

    public init(
        id: Int64,
        timestamp: Date,
        eventType: LedgerEventType,
        skillName: String,
        skillSlug: String? = nil,
        version: String? = nil,
        agent: AgentKind? = nil,
        status: LedgerEventStatus,
        note: String? = nil,
        source: String? = nil,
        verification: RemoteVerificationMode? = nil,
        manifestSHA256: String? = nil,
        targetPath: String? = nil,
        targets: [AgentKind]? = nil,
        perTargetResults: [AgentKind: String]? = nil,
        signerKeyId: String? = nil,
        timeoutCount: Int? = nil,
        retryCount: Int? = nil,
        timeoutDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.skillName = skillName
        self.skillSlug = skillSlug
        self.version = version
        self.agent = agent
        self.status = status
        self.note = note
        self.source = source
        self.verification = verification
        self.manifestSHA256 = manifestSHA256
        self.targetPath = targetPath
        self.targets = targets
        self.perTargetResults = perTargetResults
        self.signerKeyId = signerKeyId
        self.timeoutCount = timeoutCount
        self.retryCount = retryCount
        self.timeoutDuration = timeoutDuration
    }
}
