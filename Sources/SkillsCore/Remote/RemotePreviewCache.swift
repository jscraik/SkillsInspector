import Foundation

/// Lightweight cache for remote SKILL.md previews and metadata.
public struct RemotePreviewCache: Sendable {
    private let cacheRoot: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ttl: TimeInterval
    private let maxCacheBytes: Int

    /// Default cache configuration: 7 days TTL, 50MB cap
    public static let defaultTTL: TimeInterval = 7 * 24 * 60 * 60 // 7 days in seconds
    public static let defaultMaxCacheBytes: Int = 50 * 1024 * 1024 // 50MB

    public init(
        cacheRoot: URL? = nil,
        ttl: TimeInterval = defaultTTL,
        maxCacheBytes: Int = defaultMaxCacheBytes
    ) {
        if let cacheRoot {
            self.cacheRoot = cacheRoot
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            self.cacheRoot = (base ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("SkillsInspector", isDirectory: true)
                .appendingPathComponent("remote-preview", isDirectory: true)
        }
        self.ttl = ttl
        self.maxCacheBytes = maxCacheBytes
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load(
        slug: String,
        version: String?,
        expectedManifestSHA256: String?,
        expectedETag: String?
    ) -> RemoteSkillPreview? {
        let url = cacheURL(slug: slug, version: version)
        guard let data = try? Data(contentsOf: url),
              let preview = try? decoder.decode(RemoteSkillPreview.self, from: data)
        else { return nil }

        // Check TTL - expire cache entries older than TTL
        let age = Date().timeIntervalSince(preview.fetchedAt)
        guard age < ttl else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        // Validate against expected manifest SHA256
        if let expectedManifestSHA256, let manifestHash = preview.manifest?.sha256, expectedManifestSHA256 != manifestHash {
            return nil
        }

        // Validate against expected ETag
        if let expectedETag, let etag = preview.etag, expectedETag != etag {
            return nil
        }

        return preview
    }

    public func store(_ preview: RemoteSkillPreview) {
        let url = cacheURL(slug: preview.slug, version: preview.version)
        do {
            try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
            let data = try encoder.encode(preview)

            // Check cache size before storing
            if !ensureCacheSizeLimit(additionalBytes: data.count) {
                // Cache eviction failed; skip storing to stay under limit
                return
            }

            try data.write(to: url, options: [.atomic])
        } catch {
            // Cache failures should not block installs.
        }
    }

    /// Evicts expired and excess cache entries to stay under maxCacheBytes.
    /// Returns true if cache is within limits, false if eviction failed.
    private func ensureCacheSizeLimit(additionalBytes: Int) -> Bool {
        guard let enumerator = FileManager.default.enumerator(at: cacheRoot, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return true
        }

        var cacheEntries: [(url: URL, size: Int, modified: Date)] = []
        var currentSize = 0

        while let url = enumerator.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let fileSize = resourceValues.fileSize,
                  let modifiedDate = resourceValues.contentModificationDate else {
                continue
            }
            currentSize += fileSize
            cacheEntries.append((url, fileSize, modifiedDate))
        }

        // Remove expired entries first (older than TTL)
        let now = Date()
        cacheEntries = cacheEntries.filter { entry in
            let age = now.timeIntervalSince(entry.modified)
            if age > ttl {
                try? FileManager.default.removeItem(at: entry.url)
                currentSize -= entry.size
                return false
            }
            return true
        }

        // If still over limit, remove oldest entries until under limit
        let targetSize = currentSize + additionalBytes
        if targetSize > maxCacheBytes {
            cacheEntries.sort { $0.modified < $1.modified }
            for entry in cacheEntries {
                if currentSize + additionalBytes <= maxCacheBytes { break }
                try? FileManager.default.removeItem(at: entry.url)
                currentSize -= entry.size
            }
        }

        return currentSize + additionalBytes <= maxCacheBytes
    }

    public func loadManifest(slug: String, version: String?) -> CachedManifest? {
        let url = manifestCacheURL(slug: slug, version: version)
        guard let data = try? Data(contentsOf: url),
              let manifest = try? decoder.decode(CachedManifest.self, from: data)
        else { return nil }

        // Check TTL - expire manifest entries older than TTL
        let age = Date().timeIntervalSince(manifest.fetchedAt)
        guard age < ttl else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        return manifest
    }

    public func storeManifest(slug: String, version: String?, manifest: RemoteArtifactManifest, etag: String?) {
        let url = manifestCacheURL(slug: slug, version: version)
        do {
            try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
            let payload = CachedManifest(
                slug: slug,
                version: version,
                manifest: manifest,
                etag: etag,
                fetchedAt: Date()
            )
            let data = try encoder.encode(payload)

            // Check cache size before storing
            if !ensureCacheSizeLimit(additionalBytes: data.count) {
                // Cache eviction failed; skip storing to stay under limit
                return
            }

            try data.write(to: url, options: [.atomic])
        } catch {
            // Cache failures should not block installs.
        }
    }

    /// Clears all cached preview and manifest data.
    public func clearAll() {
        try? FileManager.default.removeItem(at: cacheRoot)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    /// Returns the total size of all cached files in bytes.
    public func totalCacheSize() -> Int {
        guard let enumerator = FileManager.default.enumerator(at: cacheRoot, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize = 0
        while let url = enumerator.nextObject() as? URL {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        return totalSize
    }

    private func cacheURL(slug: String, version: String?) -> URL {
        let safeSlug = slug.replacingOccurrences(of: "/", with: "-")
        let safeVersion = (version ?? "latest").replacingOccurrences(of: "/", with: "-")
        return cacheRoot.appendingPathComponent("\(safeSlug)-\(safeVersion).json")
    }

    private func manifestCacheURL(slug: String, version: String?) -> URL {
        let safeSlug = slug.replacingOccurrences(of: "/", with: "-")
        let safeVersion = (version ?? "latest").replacingOccurrences(of: "/", with: "-")
        return cacheRoot.appendingPathComponent("\(safeSlug)-\(safeVersion)-manifest.json")
    }
}

public struct CachedManifest: Codable, Sendable {
    public let slug: String
    public let version: String?
    public let manifest: RemoteArtifactManifest
    public let etag: String?
    public let fetchedAt: Date
}
