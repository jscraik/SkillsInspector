import Foundation

public enum IndexInclude: String, CaseIterable, Sendable {
    case codex
    case claude
    case codexSkillManager
    case copilot
    case all
}

public enum IndexBump: String, Sendable {
    case none
    case patch
    case minor
    case major
}

public struct SkillIndexEntry: Sendable, Hashable {
    public let agent: AgentKind
    public let name: String
    public let path: String
    public let description: String
    public let modified: Date?
    public let referencesCount: Int
    public let assetsCount: Int
    public let scriptsCount: Int
}

public enum SkillIndexer {
    /// Generate a markdown Skills index from the provided roots.
    public static func generate(
        codexRoots: [URL],
        claudeRoot: URL?,
        codexSkillManagerRoot: URL? = nil,
        copilotRoot: URL? = nil,
        include: IndexInclude = .all,
        recursive: Bool = false,
        maxDepth: Int? = nil,
        excludes: [String] = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) -> [SkillIndexEntry] {
        var entries: [SkillIndexEntry] = []

        func collect(agent: AgentKind, root: URL) {
            let roots = [ScanRoot(agent: agent, rootURL: root, recursive: recursive, maxDepth: maxDepth)]
            let files = SkillsScanner.findSkillFiles(roots: roots, excludeDirNames: Set(excludes), excludeGlobs: excludeGlobs)[roots[0]] ?? []
            for f in files {
                guard let doc = SkillLoader.load(agent: agent, rootURL: root, skillFileURL: f) else { continue }
                let name = doc.name ?? f.deletingLastPathComponent().lastPathComponent
                let desc = (doc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let attrs = try? FileManager.default.attributesOfItem(atPath: f.path)
                let modified = attrs?[.modificationDate] as? Date
                entries.append(
                    SkillIndexEntry(
                        agent: agent,
                        name: name,
                        path: f.path,
                        description: desc,
                        modified: modified,
                        referencesCount: doc.referencesCount,
                        assetsCount: doc.assetsCount,
                        scriptsCount: doc.scriptsCount
                    )
                )
            }
        }

        switch include {
        case .codex:
            codexRoots.forEach { collect(agent: .codex, root: $0) }
        case .claude:
            if let c = claudeRoot { collect(agent: .claude, root: c) }
        case .codexSkillManager:
            if let csm = codexSkillManagerRoot { collect(agent: .codexSkillManager, root: csm) }
        case .copilot:
            if let cp = copilotRoot { collect(agent: .copilot, root: cp) }
        case .all:
            codexRoots.forEach { collect(agent: .codex, root: $0) }
            if let c = claudeRoot { collect(agent: .claude, root: c) }
            if let csm = codexSkillManagerRoot { collect(agent: .codexSkillManager, root: csm) }
            if let cp = copilotRoot { collect(agent: .copilot, root: cp) }
        }

        return entries.sorted { lhs, rhs in
            if lhs.agent == rhs.agent {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.agent.rawValue < rhs.agent.rawValue
        }
    }

    /// Backwards-compatible single-root API.
    public static func generate(
        codexRoot: URL?,
        claudeRoot: URL?,
        include: IndexInclude = .all,
        recursive: Bool = false,
        maxDepth: Int? = nil,
        excludes: [String] = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) -> [SkillIndexEntry] {
        let roots = codexRoot.map { [$0] } ?? []
        return generate(
            codexRoots: roots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            include: include,
            recursive: recursive,
            maxDepth: maxDepth,
            excludes: excludes,
            excludeGlobs: excludeGlobs
        )
    }

    /// Render markdown for a set of index entries. Optionally bump version and append a changelog line.
    public static func renderMarkdown(
        entries: [SkillIndexEntry],
        existingVersion: String? = nil,
        bump: IndexBump = .none,
        changelogNote: String? = nil
    ) -> (version: String, markdown: String) {
        let nextVersion = bumpVersion(existing: existingVersion, bump: bump)
        var md: [String] = []
        md.append("---")
        md.append("version: \(nextVersion)")
        md.append("generated: \(ISO8601DateFormatter().string(from: Date()))")
        md.append("---\n")
        md.append("# Skills Index\n")
        md.append("| Agent | Skill | Description | Path | Modified | #Refs | #Assets | #Scripts |")
        md.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
        for e in entries {
            let desc = e.description.isEmpty ? "" : e.description.replacingOccurrences(of: "|", with: "\\|")
            let path = e.path.replacingOccurrences(of: "|", with: "\\|")
            let modified = e.modified.map { DateFormatter.shortDateTime.string(from: $0) } ?? ""
            md.append("| \(e.agent.rawValue) | \(e.name) | \(desc) | `\(path)` | \(modified) | \(e.referencesCount) | \(e.assetsCount) | \(e.scriptsCount) |")
        }
        md.append("\n## Changelog")
        if let note = changelogNote, !note.isEmpty {
            md.append("- \(DateFormatter.shortDateTime.string(from: Date())) — \(note) (v\(nextVersion))")
        }
        return (nextVersion, md.joined(separator: "\n"))
    }

    private static func bumpVersion(existing: String?, bump: IndexBump) -> String {
        guard let existing, bump != .none else { return existing ?? "0.1.0" }
        let comps = existing.split(separator: ".").compactMap { Int($0) }
        var major = comps.count > 0 ? comps[0] : 0
        var minor = comps.count > 1 ? comps[1] : 0
        var patch = comps.count > 2 ? comps[2] : 0
        switch bump {
        case .major:
            major += 1; minor = 0; patch = 0
        case .minor:
            minor += 1; patch = 0
        case .patch:
            patch += 1
        case .none:
            break
        }
        return "\(major).\(minor).\(patch)"
    }
}

public extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
