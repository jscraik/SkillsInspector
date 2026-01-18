import Foundation

// MARK: - Telemetry Event Types

public enum TelemetryEventType: String, Sendable {
    case verifiedInstall = "verified_install"
    case blockedDownload = "blocked_download"
    case publishRun = "publish_run"
}

// MARK: - Telemetry Event

public struct TelemetryEvent: Codable, Sendable {
    public let name: String
    public let timestamp: Date
    public let appVersion: String
    public let attributes: [String: String]

    public init(
        name: String,
        timestamp: Date = Date(),
        appVersion: String = AppVersion.current,
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.attributes = attributes
    }

    enum CodingKeys: String, CodingKey {
        case name
        case timestamp
        case appVersion
        case attributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? AppVersion.current
        attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
    }

    public static func verifiedInstall(skillSlug: String, version: String, installerId: String) -> TelemetryEvent {
        return TelemetryEvent(
            name: TelemetryEventType.verifiedInstall.rawValue,
            attributes: [
                "skill_slug": skillSlug,
                "version": version,
                "installer_id": installerId
            ]
        )
    }

    public static func blockedDownload(skillSlug: String, reason: String, installerId: String) -> TelemetryEvent {
        return TelemetryEvent(
            name: TelemetryEventType.blockedDownload.rawValue,
            attributes: [
                "skill_slug": skillSlug,
                "reason": reason,
                "installer_id": installerId
            ]
        )
    }

    public static func publishRun(skillSlug: String, version: String, success: Bool, publisherId: String) -> TelemetryEvent {
        return TelemetryEvent(
            name: TelemetryEventType.publishRun.rawValue,
            attributes: [
                "skill_slug": skillSlug,
                "version": version,
                "success": success ? "true" : "false",
                "publisher_id": publisherId
            ]
        )
    }
}

public enum TelemetrySchema {
    private static let allowedAttributeKeys: Set<String> = [
        "skill_slug",
        "version",
        "reason",
        "installer_id",
        "publisher_id",
        "success"
    ]

    public static func sanitize(_ event: TelemetryEvent) -> TelemetryEvent? {
        let keys = Set(event.attributes.keys)
        guard keys.isSubset(of: allowedAttributeKeys) else {
            return nil
        }
        return event
    }
}

public enum AppVersion {
    public static var current: String {
        let bundle = Bundle.main
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return version
        }
        return "unknown"
    }
}

// MARK: - Telemetry Store

public struct TelemetryStore: Sendable {
    public var record: @Sendable (TelemetryEvent) -> Void
    public var getEvents: @Sendable () -> [TelemetryEvent]
    public var clear: @Sendable () -> Void

    public init(
        record: @Sendable @escaping (TelemetryEvent) -> Void,
        getEvents: @Sendable @escaping () -> [TelemetryEvent],
        clear: @Sendable @escaping () -> Void
    ) {
        self.record = record
        self.getEvents = getEvents
        self.clear = clear
    }

    public static let noop = TelemetryStore(
        record: { _ in },
        getEvents: { [] },
        clear: { }
    )

    public static func file(url: URL, retentionDays: Int = 30) -> TelemetryStore {
        let retentionSeconds: TimeInterval = Double(retentionDays) * 24 * 60 * 60
        let cutoffDate = Date().addingTimeInterval(-retentionSeconds)

        return TelemetryStore(
            record: { event in
                do {
                    guard let sanitized = TelemetrySchema.sanitize(event) else { return }
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(sanitized)
                    if let line = String(data: data, encoding: .utf8) {
                        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                        if FileManager.default.fileExists(atPath: url.path) {
                            let handle = try FileHandle(forWritingTo: url)
                            try handle.seekToEnd()
                            if let lineData = (line + "\n").data(using: .utf8) {
                                try handle.write(contentsOf: lineData)
                            }
                            try handle.close()
                        } else {
                            try (line + "\n").write(to: url, atomically: true, encoding: .utf8)
                        }
                    }
                } catch {
                    // Telemetry failures should never block workflows.
                }
            },
            getEvents: {
                guard FileManager.default.fileExists(atPath: url.path),
                      let contents = try? String(contentsOfFile: url.path, encoding: .utf8) else {
                    return []
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return contents.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .compactMap { line -> TelemetryEvent? in
                        guard let data = line.data(using: .utf8) else { return nil }
                        return try? decoder.decode(TelemetryEvent.self, from: data)
                    }
                    .filter { $0.timestamp > cutoffDate }
            },
            clear: {
                try? FileManager.default.removeItem(at: url)
            }
        )
    }
}

// MARK: - Telemetry Client (Legacy Alias)

public struct TelemetryClient: Sendable {
    public var record: @Sendable (TelemetryEvent) -> Void

    public init(record: @Sendable @escaping (TelemetryEvent) -> Void) {
        self.record = record
    }

    public static let noop = TelemetryClient { _ in }

    public static func file(url: URL) -> TelemetryClient {
        let store = TelemetryStore.file(url: url)
        return TelemetryClient { event in
            store.record(event)
        }
    }
}

// MARK: - Installer ID Generator

public enum InstallerId {
    private static let key = "stools_installer_id"

    public static func getOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuid8Prefix ?? UUID().uuidString.prefix(8).lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}

private extension UUID {
    /// Returns a UUID v4-like 8-character hex string for anonymized identification.
    var uuid8Prefix: String? {
        let uuidString = uuidString
        let hex = uuidString.replacingOccurrences(of: "-", with: "")
        return String(hex.prefix(8))
    }
}

// MARK: - Path Redactor

public enum PathRedactor {
    /// Redacts sensitive paths from log messages, replacing them with placeholders.
    public static func redact(_ message: String) -> String {
        var result = message

        // Redact home directory paths
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if !homePath.isEmpty {
            result = result.replacingOccurrences(of: homePath, with: "~")
        }

        // Redact common user patterns like /Users/[username]
        let userPattern = #"/Users/[^/\s]+"#
        if let regex = try? NSRegularExpression(pattern: userPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "/Users/[REDACTED]")
        }

        // Redact potential UUIDs/GUIDs
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let regex = try? NSRegularExpression(pattern: uuidPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[UUID-REDACTED]")
        }

        return result
    }
}

// MARK: - Telemetry Counts

public struct TelemetryCounts: Codable, Sendable {
    public let verifiedInstalls: Int
    public let blockedDownloads: Int
    public let publishRuns: Int

    public init(verifiedInstalls: Int = 0, blockedDownloads: Int = 0, publishRuns: Int = 0) {
        self.verifiedInstalls = verifiedInstalls
        self.blockedDownloads = blockedDownloads
        self.publishRuns = publishRuns
    }

    public static func from(events: [TelemetryEvent]) -> TelemetryCounts {
        var counts = TelemetryCounts()
        for event in events {
            switch event.name {
            case TelemetryEventType.verifiedInstall.rawValue:
                counts = TelemetryCounts(
                    verifiedInstalls: counts.verifiedInstalls + 1,
                    blockedDownloads: counts.blockedDownloads,
                    publishRuns: counts.publishRuns
                )
            case TelemetryEventType.blockedDownload.rawValue:
                counts = TelemetryCounts(
                    verifiedInstalls: counts.verifiedInstalls,
                    blockedDownloads: counts.blockedDownloads + 1,
                    publishRuns: counts.publishRuns
                )
            case TelemetryEventType.publishRun.rawValue:
                counts = TelemetryCounts(
                    verifiedInstalls: counts.verifiedInstalls,
                    blockedDownloads: counts.blockedDownloads,
                    publishRuns: counts.publishRuns + 1
                )
            default:
                break
            }
        }
        return counts
    }
}
