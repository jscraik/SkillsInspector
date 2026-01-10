import Foundation
import CryptoKit

/// Cache entry for a validated skill file.
public struct CachedValidation: Codable, Hashable, Sendable {
    public let filePath: String
    public let modificationTime: TimeInterval
    public let contentHash: String
    public let findings: [CachedFinding]
    public let cachedAt: TimeInterval

    public init(filePath: String, modificationTime: TimeInterval, contentHash: String, findings: [CachedFinding], cachedAt: TimeInterval) {
        self.filePath = filePath
        self.modificationTime = modificationTime
        self.contentHash = contentHash
        self.findings = findings
        self.cachedAt = cachedAt
    }
}

/// Simplified finding for cache storage.
public struct CachedFinding: Codable, Hashable, Sendable {
    public let ruleID: RuleID
    public let severity: String
    public let agent: String
    public let message: String
    public let line: Int?
    public let column: Int?

    public init(from finding: Finding) {
        self.ruleID = finding.ruleID
        self.severity = finding.severity.rawValue
        self.agent = finding.agent.rawValue
        self.message = finding.message
        self.line = finding.line
        self.column = finding.column
    }

    public func toFinding(fileURL: URL) -> Finding {
        Finding(
            ruleID: ruleID,
            severity: Severity(rawValue: severity) ?? .error,
            agent: AgentKind(rawValue: agent) ?? .codex,
            fileURL: fileURL,
            message: message,
            line: line,
            column: column
        )
    }
}

/// Cache manifest structure.
struct CacheManifest: Codable, Sendable {
    let schemaVersion: Int
    let configHash: String?
    let entries: [String: CachedValidation]

    init(schemaVersion: Int = 1, configHash: String? = nil, entries: [String: CachedValidation] = [:]) {
        self.schemaVersion = schemaVersion
        self.configHash = configHash
        self.entries = entries
    }
}

/// Manages validation result caching for incremental scans.
public actor CacheManager {
    private var manifest: CacheManifest
    private let cacheURL: URL?
    private let configHash: String?

    public init(cacheURL: URL?, configHash: String? = nil) {
        self.cacheURL = cacheURL
        self.configHash = configHash
        self.manifest = Self.loadManifest(from: cacheURL, expectedConfigHash: configHash)
    }

    private static func loadManifest(from url: URL?, expectedConfigHash: String?) -> CacheManifest {
        guard let url, let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(CacheManifest.self, from: data) else {
            return CacheManifest(configHash: expectedConfigHash)
        }

        // Invalidate cache if config changed
        if let expectedConfigHash, loaded.configHash != expectedConfigHash {
            return CacheManifest(configHash: expectedConfigHash)
        }

        return loaded
    }

    /// Check if a file has a valid cache entry.
    public func getCached(for fileURL: URL) -> CachedValidation? {
        let path = fileURL.path
        guard let entry = manifest.entries[path] else { return nil }

        // Verify file hasn't changed
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modTime = attrs[.modificationDate] as? Date else {
            return nil
        }

        let currentModTime = modTime.timeIntervalSince1970
        if abs(currentModTime - entry.modificationTime) > 0.001 {
            return nil
        }

        // Optionally verify hash for extra safety
        if let currentHash = SkillHash.sha256Hex(ofFile: fileURL),
           currentHash != entry.contentHash {
            return nil
        }

        return entry
    }

    /// Store validation results for a file.
    public func setCached(for fileURL: URL, findings: [Finding]) {
        let path = fileURL.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modTime = attrs[.modificationDate] as? Date,
              let hash = SkillHash.sha256Hex(ofFile: fileURL) else {
            return
        }

        let entry = CachedValidation(
            filePath: path,
            modificationTime: modTime.timeIntervalSince1970,
            contentHash: hash,
            findings: findings.map(CachedFinding.init),
            cachedAt: Date().timeIntervalSince1970
        )

        var entries = manifest.entries
        entries[path] = entry
        manifest = CacheManifest(
            schemaVersion: manifest.schemaVersion,
            configHash: configHash,
            entries: entries
        )
    }

    /// Save cache to disk.
    public func save() {
        guard let cacheURL else { return }

        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Get cache statistics.
    public func getStats() -> (entries: Int, oldestCacheAge: TimeInterval?) {
        let now = Date().timeIntervalSince1970
        let oldest = manifest.entries.values.map { now - $0.cachedAt }.max()
        return (manifest.entries.count, oldest)
    }

    /// Clear all cache entries.
    public func clear() {
        manifest = CacheManifest(configHash: configHash)
    }
}
