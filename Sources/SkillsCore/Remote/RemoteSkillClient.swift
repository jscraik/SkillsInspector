import Foundation

/// Thin async client for Clawdhub remote skills.
public struct RemoteSkillClient: Sendable {
    public var fetchLatest: @Sendable (_ limit: Int) async throws -> [RemoteSkill]
    public var search: @Sendable (_ query: String, _ limit: Int) async throws -> [RemoteSkill]
    public var download: @Sendable (_ slug: String, _ version: String?) async throws -> URL
    public var fetchManifest: @Sendable (_ slug: String, _ version: String?) async throws -> RemoteArtifactManifest?
    public var fetchPreview: @Sendable (_ slug: String, _ version: String?) async throws -> RemoteSkillPreview?
    public var fetchDetail: @Sendable (_ slug: String) async throws -> RemoteSkillOwner?
    public var fetchLatestVersion: @Sendable (_ slug: String) async throws -> String?
    public var fetchLatestVersionInfo: @Sendable (_ slug: String) async throws -> (version: String?, changelog: String?)
    public var fetchKeyset: @Sendable () async throws -> RemoteKeyset?

    public init(
        fetchLatest: @Sendable @escaping (_ limit: Int) async throws -> [RemoteSkill],
        search: @Sendable @escaping (_ query: String, _ limit: Int) async throws -> [RemoteSkill],
        download: @Sendable @escaping (_ slug: String, _ version: String?) async throws -> URL,
        fetchManifest: @Sendable @escaping (_ slug: String, _ version: String?) async throws -> RemoteArtifactManifest?,
        fetchPreview: @Sendable @escaping (_ slug: String, _ version: String?) async throws -> RemoteSkillPreview?,
        fetchDetail: @Sendable @escaping (_ slug: String) async throws -> RemoteSkillOwner?,
        fetchLatestVersion: @Sendable @escaping (_ slug: String) async throws -> String?,
        fetchLatestVersionInfo: @Sendable @escaping (_ slug: String) async throws -> (version: String?, changelog: String?),
        fetchKeyset: @Sendable @escaping () async throws -> RemoteKeyset?
    ) {
        self.fetchLatest = fetchLatest
        self.search = search
        self.download = download
        self.fetchManifest = fetchManifest
        self.fetchPreview = fetchPreview
        self.fetchDetail = fetchDetail
        self.fetchLatestVersion = fetchLatestVersion
        self.fetchLatestVersionInfo = fetchLatestVersionInfo
        self.fetchKeyset = fetchKeyset
    }
}

public extension RemoteSkillClient {
    // Shared URLSession with cache (10MB memory, 50MB disk)
    static let sharedSession: URLSession = {
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        return URLSession(configuration: config)
    }()

    static func live(baseURL: URL = URL(string: "https://clawdhub.com")!, session: URLSession = Self.sharedSession) -> RemoteSkillClient {
        let decoder = JSONDecoder()

        return RemoteSkillClient(
            fetchLatest: { limit in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/skills"), resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
                guard let url = components?.url else { throw URLError(.badURL) }
                let (data, response) = try await session.data(from: url)
                try validate(response: response)
                let decoded = try decoder.decode(SkillListResponse.self, from: data)
                return decoded.items.map { RemoteSkill(item: $0) }
            },
            search: { query, limit in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/search"), resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "limit", value: String(limit)),
                ]
                guard let url = components?.url else { throw URLError(.badURL) }
                let (data, response) = try await session.data(from: url)
                try validate(response: response)
                let decoded = try decoder.decode(SearchResponse.self, from: data)
                return decoded.results.compactMap { RemoteSkill(result: $0) }
            },
            download: { slug, version in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/download"), resolvingAgainstBaseURL: false)
                var items = [URLQueryItem(name: "slug", value: slug)]
                if let version, !version.isEmpty {
                    items.append(URLQueryItem(name: "version", value: version))
                } else {
                    items.append(URLQueryItem(name: "tag", value: "latest"))
                }
                components?.queryItems = items
                guard let url = components?.url else { throw URLError(.badURL) }
                let (downloadURL, response) = try await session.download(from: url)
                try validate(response: response)
                return downloadURL
            },
            fetchManifest: { slug, version in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/skills").appendingPathComponent(slug).appendingPathComponent("manifest"), resolvingAgainstBaseURL: false)
                if let version, !version.isEmpty {
                    components?.queryItems = [URLQueryItem(name: "version", value: version)]
                }
                guard let url = components?.url else { throw URLError(.badURL) }
                do {
                    let (data, response) = try await session.data(from: url)
                    try validate(response: response)
                    return try decoder.decode(RemoteArtifactManifest.self, from: data)
                } catch let error as URLError where error.code == .fileDoesNotExist {
                    return nil
                } catch {
                    if case RemoteSkillClientError.notFound = error { return nil }
                    throw error
                }
            },
            fetchPreview: { slug, version in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/skills").appendingPathComponent(slug).appendingPathComponent("preview"), resolvingAgainstBaseURL: false)
                if let version, !version.isEmpty {
                    components?.queryItems = [URLQueryItem(name: "version", value: version)]
                }
                guard let url = components?.url else { throw URLError(.badURL) }
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                    return nil
                }
                try validate(response: response)
                let decoded = try decoder.decode(RemoteSkillPreviewResponse.self, from: data)
                let etag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
                return RemoteSkillPreview(
                    slug: slug,
                    version: decoded.version ?? version,
                    skillMarkdown: decoded.skillMarkdown,
                    changelog: decoded.changelog,
                    signerKeyId: decoded.signerKeyId,
                    manifest: decoded.manifest,
                    etag: etag,
                    fetchedAt: Date()
                )
            },
            fetchDetail: { slug in
                var components = URLComponents(url: baseURL.appendingPathComponent("/api/skill"), resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "slug", value: slug)]
                guard let url = components?.url else { throw URLError(.badURL) }
                let (data, response) = try await session.data(from: url)
                try validate(response: response)
                let decoded = try decoder.decode(SkillDetailResponse.self, from: data)
                guard let owner = decoded.owner else { return nil }
                return RemoteSkillOwner(handle: owner.handle, displayName: owner.displayName, imageURL: owner.image)
            },
            fetchLatestVersion: { slug in
                let url = baseURL.appendingPathComponent("/api/v1/skills").appendingPathComponent(slug)
                let (data, response) = try await session.data(from: url)
                try validate(response: response)
                let decoded = try decoder.decode(SkillResponse.self, from: data)
                return decoded.latestVersion?.version
            },
            fetchLatestVersionInfo: { slug in
                let url = baseURL.appendingPathComponent("/api/v1/skills").appendingPathComponent(slug)
                let (data, response) = try await session.data(from: url)
                try validate(response: response)
                let decoded = try decoder.decode(SkillResponse.self, from: data)
                return (decoded.latestVersion?.version, decoded.latestVersion?.changelog)
            },
            fetchKeyset: {
                let url = baseURL.appendingPathComponent("/api/v1/keys")
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                    return nil
                }
                try validate(response: response)
                let keysetDecoder = JSONDecoder()
                keysetDecoder.dateDecodingStrategy = .iso8601
                return try keysetDecoder.decode(RemoteKeyset.self, from: data)
            }
        )
    }

    /// Deterministic mock client for UI previews and screenshots.
    static func mock(forScreenshots: Bool = false) -> RemoteSkillClient {
        RemoteSkillClient(
            fetchLatest: { _ in
                if forScreenshots { return mockScreenshotSkills }
                return mockSkills
            },
            search: { query, _ in
                let pool = forScreenshots ? mockScreenshotSkills : mockSkills
                return pool.filter { $0.displayName.lowercased().contains(query.lowercased()) }
            },
            download: { _, _ in
                FileManager.default.temporaryDirectory
            },
            fetchManifest: { slug, version in
                RemoteArtifactManifest(name: slug, version: version ?? "1.0.0", sha256: String(repeating: "a", count: 64), size: 1024, signature: "mock", signerKeyId: "dev-key", trustedSigners: ["dev-key"], revokedKeys: nil, builtWith: nil, targets: [.codex, .claude, .copilot])
            },
            fetchPreview: { slug, version in
                RemoteSkillPreview(
                    slug: slug,
                    version: version ?? "1.0.0",
                    skillMarkdown: "# \(slug)\n\nPreview content for \(slug).",
                    changelog: "Changes in \(version ?? "1.0.0"):\n- Example change",
                    signerKeyId: "dev-key",
                    manifest: RemoteArtifactManifest(name: slug, version: version ?? "1.0.0", sha256: String(repeating: "a", count: 64), size: 1024, signature: "mock", signerKeyId: "dev-key", trustedSigners: ["dev-key"], revokedKeys: nil, builtWith: nil, targets: [.codex, .claude, .copilot]),
                    etag: "mock-etag",
                    fetchedAt: Date()
                )
            },
            fetchDetail: { slug in
                RemoteSkillOwner(handle: "@\(slug)", displayName: "Owner \(slug)", imageURL: nil)
            },
            fetchLatestVersion: { slug in
                let pool = forScreenshots ? mockScreenshotSkills : mockSkills
                return pool.first(where: { $0.slug == slug })?.latestVersion
            },
            fetchLatestVersionInfo: { slug in
                let pool = forScreenshots ? mockScreenshotSkills : mockSkills
                let version = pool.first(where: { $0.slug == slug })?.latestVersion
                let changelog = version.map { "Changes in v\($0):\n- Improved telemetry\n- Fixed sync bugs\n- Added Remote tab polish" }
                return (version, changelog)
            },
            fetchKeyset: {
                RemoteKeyset(
                    keys: [
                        RemoteTrustStore.TrustedKey(keyId: "dev-key", publicKeyBase64: "ZmFrZS1rZXk=", allowedSlugs: nil)
                    ],
                    revokedKeyIds: [],
                    expiresAt: Date().addingTimeInterval(86400),
                    signature: nil,
                    signatureAlgorithm: "ed25519",
                    signedAt: Date(),
                    keysetVersion: 1
                )
            }
        )
    }
}

private let mockSkills: [RemoteSkill] = [
    RemoteSkill(id: "sql-helper", slug: "sql-helper", displayName: "SQL Helper", summary: "Query and format SQL quickly.", latestVersion: "1.4.0", updatedAt: Date(), downloads: 1200, stars: 42),
    RemoteSkill(id: "obsidian-sync", slug: "obsidian-sync", displayName: "Obsidian Sync", summary: "Sync notes to Obsidian vaults.", latestVersion: "0.9.1", updatedAt: Date().addingTimeInterval(-86400 * 2), downloads: 320, stars: 18),
    RemoteSkill(id: "ios-ui-kit", slug: "ios-ui-kit", displayName: "iOS UI Kit", summary: "SwiftUI component recipes.", latestVersion: "2.0.0", updatedAt: Date().addingTimeInterval(-86400 * 7), downloads: 980, stars: 55)
]

private let mockScreenshotSkills: [RemoteSkill] = [
    RemoteSkill(id: "sql-helper", slug: "sql-helper", displayName: "SQL Helper", summary: "Query and format SQL quickly.", latestVersion: "1.4.0", updatedAt: Date(), downloads: 1200, stars: 42),
    RemoteSkill(id: "obsidian-sync", slug: "obsidian-sync", displayName: "Obsidian Sync", summary: "Sync notes to Obsidian vaults. Now with auto-merge.", latestVersion: "1.0.0", updatedAt: Date().addingTimeInterval(-86400 * 2), downloads: 320, stars: 18),
    RemoteSkill(id: "ios-ui-kit", slug: "ios-ui-kit", displayName: "iOS UI Kit", summary: "SwiftUI component recipes with dynamic type and dark mode.", latestVersion: "2.0.0", updatedAt: Date().addingTimeInterval(-86400 * 7), downloads: 980, stars: 55),
    RemoteSkill(id: "claude-chat-tools", slug: "claude-chat-tools", displayName: "Claude Chat Tools", summary: "Chat-enhancing snippets and safety rails.", latestVersion: "0.8.0", updatedAt: Date().addingTimeInterval(-86400 * 1), downloads: 2100, stars: 77)
]

// MARK: - DTOs

private struct SkillListResponse: Decodable {
    let items: [SkillListItem]
}

private struct SkillListItem: Decodable {
    let slug: String
    let displayName: String
    let summary: String?
    let updatedAt: TimeInterval
    let latestVersion: LatestVersion?
    let stats: Stats?
}

private struct Stats: Decodable {
    let downloads: Int?
    let stars: Int?
}

private struct LatestVersion: Decodable { let version: String; let createdAt: TimeInterval; let changelog: String? }

private struct SearchResponse: Decodable { let results: [SearchResult] }

private struct SearchResult: Decodable {
    let slug: String?
    let displayName: String?
    let summary: String?
    let version: String?
    let updatedAt: TimeInterval?
}

private struct SkillDetailResponse: Decodable { let owner: Owner? }

private struct SkillResponse: Decodable {
    let latestVersion: LatestVersion?
    let owner: Owner?
    let skill: SkillSummary?
}

private struct SkillSummary: Decodable {
    let slug: String
    let displayName: String
    let summary: String?
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
}

private struct Owner: Decodable { let handle: String?; let displayName: String?; let image: String? }

private struct RemoteSkillPreviewResponse: Decodable {
    let skillMarkdown: String?
    let changelog: String?
    let version: String?
    let signerKeyId: String?
    let manifest: RemoteArtifactManifest?
}

// MARK: - Mappers

private extension RemoteSkill {
    init(item: SkillListItem) {
        self.init(
            id: item.slug,
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: item.updatedAt / 1000),
            downloads: item.stats?.downloads,
            stars: item.stats?.stars
        )
    }
}

private extension RemoteSkill {
    init?(result: SearchResult) {
        guard let slug = result.slug, let displayName = result.displayName else { return nil }
        self.init(
            id: slug,
            slug: slug,
            displayName: displayName,
            summary: result.summary,
            latestVersion: result.version,
            updatedAt: result.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            downloads: nil,
            stars: nil
        )
    }
}

// MARK: - Helpers

private func validate(response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw RemoteSkillClientError.notFound
        }
        throw URLError(.badServerResponse)
    }
}
