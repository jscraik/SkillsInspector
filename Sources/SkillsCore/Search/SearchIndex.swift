import Foundation

/// Helper utilities for search index management
public enum SearchIndex {
    /// Default index locations for each agent
    public static func defaultIndexURL(for agent: AgentKind) -> URL {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupportURL.appendingPathComponent("SkillsInspector", isDirectory: true)

        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        return supportDir.appendingPathComponent("skills-fts.db")
    }

    /// Get all standard skill root paths
    public static func standardRootPaths() -> [URL] {
        standardScanRoots().map { $0.rootURL }
    }

    /// Get all standard skill scan roots with agent identity
    public static func standardScanRoots() -> [ScanRoot] {
        var roots: [ScanRoot] = []

        if let codexRoot = getCodexRoot() {
            roots.append(ScanRoot(agent: .codex, rootURL: codexRoot, recursive: true))
        }

        if let claudeRoot = getClaudeRoot() {
            roots.append(ScanRoot(agent: .claude, rootURL: claudeRoot, recursive: true))
        }

        if let copilotRoot = getCopilotRoot() {
            roots.append(ScanRoot(agent: .copilot, rootURL: copilotRoot, recursive: true))
        }

        return roots
    }

    /// Scan a root path for all skills
    public static func scanRoots(_ roots: [URL]) async throws -> [SkillSearchEngine.Skill] {
        let scanRootList = roots.map { ScanRoot(agent: .codex, rootURL: $0, recursive: true) }
        return try await scanRoots(scanRootList, excludeDirNames: [".git", ".system", "__pycache__", ".DS_Store"], excludeGlobs: [])
    }

    /// Scan roots for skills with exclusion support
    public static func scanRoots(
        _ roots: [ScanRoot],
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) async throws -> [SkillSearchEngine.Skill] {
        let filesByRoot = SkillsScanner.findSkillFiles(
            roots: roots,
            excludeDirNames: excludeDirNames,
            excludeGlobs: excludeGlobs
        )
        var skills: [SkillSearchEngine.Skill] = []

        for root in roots {
            let files = filesByRoot[root] ?? []
            for skillFile in files {
                skills.append(makeSkill(from: skillFile, root: root))
            }
        }

        return skills
    }

    private static func makeSkill(from skillFile: URL, root: ScanRoot) -> SkillSearchEngine.Skill {
        let skillDir = skillFile.deletingLastPathComponent()
        let content = try? String(contentsOf: skillFile, encoding: .utf8)
        let frontmatter = content.map { FrontmatterParser.parseTopBlock($0) } ?? [:]
        let tags = frontmatter["tags"]?.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: skillFile.path)
        let fileSize = attrs?[.size] as? Int

        return SkillSearchEngine.Skill(
            slug: skillDir.lastPathComponent,
            name: frontmatter["name"],
            description: frontmatter["description"],
            agent: root.agent,
            rootPath: skillDir.path,
            tags: tags,
            rank: nil,
            fileSize: fileSize
        )
    }

    /// Get Codex skills root
    private static func getCodexRoot() -> URL? {
        // Standard Codex location
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexPath = home.appendingPathComponent(".codex/skills")

        if FileManager.default.fileExists(atPath: codexPath.path) {
            return codexPath
        }

        // Alternative: ~/Skills/codex
        let altPath = home.appendingPathComponent("Skills/codex")
        if FileManager.default.fileExists(atPath: altPath.path) {
            return altPath
        }

        return nil
    }

    /// Get Claude skills root
    private static func getClaudeRoot() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudePath = home.appendingPathComponent(".claude/skills")

        if FileManager.default.fileExists(atPath: claudePath.path) {
            return claudePath
        }

        let altPath = home.appendingPathComponent("Skills/claude")
        if FileManager.default.fileExists(atPath: altPath.path) {
            return altPath
        }

        return nil
    }

    /// Get Copilot skills root
    private static func getCopilotRoot() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let copilotPath = home.appendingPathComponent(".copilot/skills")

        if FileManager.default.fileExists(atPath: copilotPath.path) {
            return copilotPath
        }

        let altPath = home.appendingPathComponent("Skills/copilot")
        if FileManager.default.fileExists(atPath: altPath.path) {
            return altPath
        }

        return nil
    }
}
