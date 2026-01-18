import Foundation

/// Persistence for security configuration used by ACIP scanning.
public actor SecuritySettingsStore {
    private var cached: SecurityConfig?
    private let fileURL: URL

    public init(fileURL: URL = SecuritySettingsStore.defaultURL()) {
        self.fileURL = fileURL
    }

    public func load() -> SecurityConfig {
        if let cached { return cached }
        guard let data = try? Data(contentsOf: fileURL) else {
            let config = SecurityConfig.default
            cached = config
            return config
        }
        let decoder = JSONDecoder()
        if let config = try? decoder.decode(SecurityConfig.self, from: data) {
            cached = config
            return config
        }
        let fallback = SecurityConfig.default
        cached = fallback
        return fallback
    }

    public func save(_ config: SecurityConfig) {
        cached = config
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        let parent = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    public func reset() {
        cached = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    public static func defaultURL(appName: String = "SkillsInspector") -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = base.appendingPathComponent(appName, isDirectory: true)
        return root.appendingPathComponent("security-config.json")
    }
}
