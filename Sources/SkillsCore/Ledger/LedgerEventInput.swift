import Foundation

public struct LedgerEventInput: Sendable {
    public let timestamp: Date?
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

    public init(
        timestamp: Date? = nil,
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
        signerKeyId: String? = nil
    ) {
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
    }
}
