import Foundation

/// Metadata for a remote skill entry from Clawdhub.
public struct RemoteSkill: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let slug: String
    public let displayName: String
    public let summary: String?
    public let latestVersion: String?
    public let updatedAt: Date?
    public let downloads: Int?
    public let stars: Int?

    public init(
        id: String,
        slug: String,
        displayName: String,
        summary: String?,
        latestVersion: String?,
        updatedAt: Date?,
        downloads: Int?,
        stars: Int?
    ) {
        self.id = id
        self.slug = slug
        self.displayName = displayName
        self.summary = summary
        self.latestVersion = latestVersion
        self.updatedAt = updatedAt
        self.downloads = downloads
        self.stars = stars
    }
}

/// Owner profile for a remote skill.
public struct RemoteSkillOwner: Codable, Hashable, Sendable {
    public let handle: String?
    public let displayName: String?
    public let imageURL: String?

    public init(handle: String?, displayName: String?, imageURL: String?) {
        self.handle = handle
        self.displayName = displayName
        self.imageURL = imageURL
    }
}

/// Detailed information for a remote skill.
public struct RemoteSkillDetail: Codable, Hashable, Sendable {
    public let skill: RemoteSkill
    public let owner: RemoteSkillOwner?
    public let changelog: String?

    public init(skill: RemoteSkill, owner: RemoteSkillOwner?, changelog: String?) {
        self.skill = skill
        self.owner = owner
        self.changelog = changelog
    }
}

/// Target installation root.
public enum SkillInstallTarget: Sendable {
    case codex(URL)
    case claude(URL)
    case copilot(URL)
    case custom(URL)

    public var root: URL {
        switch self {
        case let .codex(url): return url
        case let .claude(url): return url
        case let .copilot(url): return url
        case let .custom(url): return url
        }
    }
}

/// Result of an install operation.
public struct RemoteSkillInstallResult: Sendable {
    public let verification: RemoteVerificationMode
    public let skillDirectory: URL
    public let filesCopied: Int
    public let totalBytes: Int64
    public let archiveSHA256: String?
    public let contentSHA256: String?
    public let backupURL: URL?
}
