import Foundation
import CryptoKit

/// Verification strictness for remote artifact handling.
public enum RemoteVerificationMode: String, Codable, Sendable {
    /// Allow artifacts with verification issues while still recording them.
    case permissive
    /// Require verification to succeed; treat issues as install blockers.
    case strict
}

public extension RemoteVerificationMode {
    var description: String {
        rawValue
    }

    init?(description: String) {
        self.init(rawValue: description.lowercased())
    }
}

/// Limits applied to downloaded and extracted archives to guard against zip bombs and oversized payloads.
public struct RemoteVerificationLimits: Sendable {
    /// Maximum archive size allowed for download (bytes).
    public let maxArchiveBytes: Int64
    /// Maximum total size allowed after extraction (bytes).
    public let maxExtractedBytes: Int64
    /// Maximum number of files allowed in the extracted archive.
    public let maxFileCount: Int
    /// Allowed MIME types for downloadable artifacts.
    public let allowedMIMETypes: Set<String>

    public init(
        maxArchiveBytes: Int64 = 50 * 1024 * 1024,
        maxExtractedBytes: Int64 = 50 * 1024 * 1024,
        maxFileCount: Int = 2_000,
        allowedMIMETypes: Set<String> = ["application/zip", "application/x-zip-compressed"]
    ) {
        self.maxArchiveBytes = maxArchiveBytes
        self.maxExtractedBytes = maxExtractedBytes
        self.maxFileCount = maxFileCount
        self.allowedMIMETypes = allowedMIMETypes
    }

    public static let `default` = RemoteVerificationLimits()
}

/// Manifest describing an artifact's integrity and provenance.
public struct RemoteArtifactManifest: Codable, Sendable {
    public let name: String
    public let version: String
    public let sha256: String
    public let size: Int64?
    public let signature: String?
    public let signerKeyId: String?
    public let trustedSigners: [String]?
    public let revokedKeys: [String]?
    public let builtWith: BuiltWith?
    public let targets: [AgentKind]?
    public let minAppVersion: String?

    public struct BuiltWith: Codable, Sendable {
        public let tool: String
        public let version: String
        public let hash: String?

        public init(tool: String, version: String, hash: String? = nil) {
            self.tool = tool
            self.version = version
            self.hash = hash
        }
    }

    public init(
        name: String,
        version: String,
        sha256: String,
        size: Int64? = nil,
        signature: String? = nil,
        signerKeyId: String? = nil,
        trustedSigners: [String]? = nil,
        revokedKeys: [String]? = nil,
        builtWith: BuiltWith? = nil,
        targets: [AgentKind]? = nil,
        minAppVersion: String? = nil
    ) {
        self.name = name
        self.version = version
        self.sha256 = sha256
        self.size = size
        self.signature = signature
        self.signerKeyId = signerKeyId
        self.trustedSigners = trustedSigners
        self.revokedKeys = revokedKeys
        self.builtWith = builtWith
        self.targets = targets
        self.minAppVersion = minAppVersion
    }
}

/// Outcome of a verification pass.
public struct RemoteVerificationOutcome: Codable, Sendable {
    public let mode: RemoteVerificationMode
    public let checksumValidated: Bool
    public let signatureValidated: Bool
    public let trustedSigner: Bool
    public let issues: [String]

    public init(
        mode: RemoteVerificationMode,
        checksumValidated: Bool,
        signatureValidated: Bool,
        trustedSigner: Bool,
        issues: [String] = []
    ) {
        self.mode = mode
        self.checksumValidated = checksumValidated
        self.signatureValidated = signatureValidated
        self.trustedSigner = trustedSigner
        self.issues = issues
    }
}

/// Local trust store for signer keys.
public struct RemoteTrustStore: Sendable {
    /// Trusted signer key metadata.
    public struct TrustedKey: Codable, Sendable {
        /// Identifier for the key, used in manifests.
        public let keyId: String
        /// Base64-encoded Ed25519 public key.
        public let publicKeyBase64: String
        /// Optional list of slugs that the key may sign.
        public let allowedSlugs: [String]?

        public init(keyId: String, publicKeyBase64: String, allowedSlugs: [String]? = nil) {
            self.keyId = keyId
            self.publicKeyBase64 = publicKeyBase64
            self.allowedSlugs = allowedSlugs
        }
    }

    private var keys: [String: TrustedKey]

    public init(keys: [TrustedKey] = []) {
        self.keys = Dictionary(uniqueKeysWithValues: keys.map { ($0.keyId, $0) })
    }

    /// Returns a trusted key scoped to an optional slug.
    public func trustedKey(for keyId: String, scopeSlug: String? = nil) -> TrustedKey? {
        guard let key = keys[keyId] else { return nil }
        if let allowed = key.allowedSlugs {
            guard let scopeSlug, allowed.contains(scopeSlug) else {
                return nil
            }
        }
        return key
    }

    /// Verify a signature against a hex digest using a trusted key.
    public func verifySignature(hexDigest: String, signatureBase64: String, keyId: String, scopeSlug: String? = nil) throws -> Bool {
        guard let key = trustedKey(for: keyId, scopeSlug: scopeSlug) else { return false }
        guard let sigData = Data(base64Encoded: signatureBase64) else { return false }
        guard let keyData = Data(base64Encoded: key.publicKeyBase64) else { return false }
        let message = Data(hexDigest.utf8)
        let pubKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        return pubKey.isValidSignature(sigData, for: message)
    }

    /// In-memory empty store for callers that do not persist trust yet.
    public static let ephemeral = RemoteTrustStore()

    // MARK: - Persistence

    private static var trustStoreURL: URL {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupportURL.appendingPathComponent("SkillsInspector", isDirectory: true)

        // Ensure directory exists
        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        return supportDir.appendingPathComponent("trust.json")
    }

    /// Load trust store from disk, returning ephemeral store if file doesn't exist or is invalid.
    public static func load() -> RemoteTrustStore {
        let url = trustStoreURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .ephemeral
        }

        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TrustStoreFile.self, from: data) else {
            return .ephemeral
        }

        return RemoteTrustStore(keys: decoded.keys)
    }

    /// Save trust store to disk. Returns true on success, false on failure.
    public func save() -> Bool {
        let url = Self.trustStoreURL
        let file = TrustStoreFile(keys: Array(keys.values))
        guard let data = try? JSONEncoder().encode(file),
              (try? data.write(to: url)) != nil else {
            return false
        }
        return true
    }

    /// Internal file representation for JSON serialization.
    private struct TrustStoreFile: Codable {
        let keys: [TrustedKey]
    }
}

// MARK: - Security Integration

/// Result of security scanning on downloaded skill content
public enum SecurityCheckResult: Sendable {
    /// No security issues were detected.
    case clean
    /// Findings were detected but content is allowed with warnings.
    case warning(reasons: [String])
    /// Content was quarantined and requires manual review.
    case quarantined(quarantineID: String, reasons: [String], safeExcerpt: String)
    /// Content was blocked and must not be installed.
    case blocked(reason: String)

    public var isClean: Bool {
        if case .clean = self { return true }
        return false
    }

    public var isAllowed: Bool {
        switch self {
        case .clean, .warning: return true
        default: return false
        }
    }
}

/// Persistent store for quarantined skills that require review
public actor QuarantineStore {
    private var quarantinedItems: [String: QuarantineItem] = [:]
    private let storageURL: URL

    private static func defaultStorageURL() -> URL {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupportURL.appendingPathComponent("SkillsInspector", isDirectory: true)

        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        return supportDir.appendingPathComponent("quarantine.json")
    }

    /// A quarantined skill record awaiting review.
    public struct QuarantineItem: Codable, Sendable, Identifiable, Hashable {
        public let id: String
        public let skillName: String
        public let skillSlug: String
        public let quarantinedAt: Date
        public let reasons: [String]
        public let safeExcerpt: String
        public let sourceURL: URL
        public let status: Status

        /// Review status for a quarantined item.
        public enum Status: String, Codable, Sendable, Hashable {
            case pending
            case approved
            case rejected
        }

        public init(
            id: String,
            skillName: String,
            skillSlug: String,
            quarantinedAt: Date,
            reasons: [String],
            safeExcerpt: String,
            sourceURL: URL,
            status: Status = .pending
        ) {
            self.id = id
            self.skillName = skillName
            self.skillSlug = skillSlug
            self.quarantinedAt = quarantinedAt
            self.reasons = reasons
            self.safeExcerpt = safeExcerpt
            self.sourceURL = sourceURL
            self.status = status
        }
    }

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        // Load deferred to first access
    }

    private func ensureLoaded() {
        if quarantinedItems.isEmpty {
            load()
        }
    }

    /// Add an item to quarantine
    public func quarantine(
        skillName: String,
        skillSlug: String,
        reasons: [String],
        safeExcerpt: String,
        sourceURL: URL
    ) -> String {
        ensureLoaded()
        let id = UUID().uuidString
        let item = QuarantineItem(
            id: id,
            skillName: skillName,
            skillSlug: skillSlug,
            quarantinedAt: Date(),
            reasons: reasons,
            safeExcerpt: safeExcerpt,
            sourceURL: sourceURL
        )
        quarantinedItems[id] = item
        save()
        return id
    }

    /// Approve a quarantined item
    public func approve(id: String) -> Bool {
        ensureLoaded()
        guard let item = quarantinedItems[id] else { return false }
        quarantinedItems[id] = QuarantineItem(
            id: item.id,
            skillName: item.skillName,
            skillSlug: item.skillSlug,
            quarantinedAt: item.quarantinedAt,
            reasons: item.reasons,
            safeExcerpt: item.safeExcerpt,
            sourceURL: item.sourceURL,
            status: .approved
        )
        save()
        return true
    }

    /// Reject a quarantined item
    public func reject(id: String) -> Bool {
        ensureLoaded()
        guard let item = quarantinedItems[id] else { return false }
        quarantinedItems[id] = QuarantineItem(
            id: item.id,
            skillName: item.skillName,
            skillSlug: item.skillSlug,
            quarantinedAt: item.quarantinedAt,
            reasons: item.reasons,
            safeExcerpt: item.safeExcerpt,
            sourceURL: item.sourceURL,
            status: .rejected
        )
        save()
        return true
    }

    /// List all quarantined items
    public func list() -> [QuarantineItem] {
        ensureLoaded()
        return Array(quarantinedItems.values)
            .sorted { $0.quarantinedAt > $1.quarantinedAt }
    }

    /// Get a specific quarantined item
    public func get(id: String) -> QuarantineItem? {
        ensureLoaded()
        return quarantinedItems[id]
    }

    /// Remove an item from quarantine
    public func remove(id: String) -> Bool {
        ensureLoaded()
        guard quarantinedItems.removeValue(forKey: id) != nil else { return false }
        save()
        return true
    }

    /// Clear all items from quarantine
    public func clear() {
        quarantinedItems.removeAll()
        save()
    }

    private func save() {
        let data = try? JSONEncoder().encode(quarantinedItems)
        try? data?.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: QuarantineItem].self, from: data) else {
            return
        }
        quarantinedItems = decoded
    }
}
