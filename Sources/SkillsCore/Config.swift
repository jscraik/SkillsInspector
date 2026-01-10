import Foundation

public enum ConfigLoader {
    public static func loadConfig(explicitPath: String?, repoRoot: URL?) -> SkillsConfig {
        // Priority: explicit --config, then repoRoot/.skillsctl/config.json, then nil
        if let explicitPath, !explicitPath.isEmpty {
            return SkillsConfig.load(from: explicitPath)
        }
        if let repoRoot {
            let candidate = repoRoot.appendingPathComponent(".skillsctl/config.json").path
            let cfg = SkillsConfig.load(from: candidate)
            return cfg
        }
        return SkillsConfig()
    }

    public static func loadBaseline(path: String?) -> Set<BaselineEntry> {
        guard let path, !path.isEmpty else { return [] }
        let url = URL(fileURLWithPath: PathUtil.expandTilde(path))
        guard let data = try? Data(contentsOf: url) else { return [] }
        struct Baseline: Codable { let schemaVersion: Int?; let findings: [BaselineEntry] }
        let decoded = try? JSONDecoder().decode(Baseline.self, from: data)
        return Set(decoded?.findings ?? [])
    }

    public static func loadIgnore(path: String?) -> [IgnoreRule] {
        guard let path, !path.isEmpty else { return [] }
        let url = URL(fileURLWithPath: PathUtil.expandTilde(path))
        guard let data = try? Data(contentsOf: url) else { return [] }
        struct IgnoreFile: Codable { let schemaVersion: Int?; let rules: [IgnoreRule] }
        let decoded = try? JSONDecoder().decode(IgnoreFile.self, from: data)
        return decoded?.rules ?? []
    }
}

public struct BaselineEntry: Codable, Hashable, Sendable {
    public let ruleID: String
    public let file: String
    public let agent: String?
}

public struct IgnoreRule: Codable, Hashable, Sendable {
    public let ruleID: String
    public let glob: String
}
