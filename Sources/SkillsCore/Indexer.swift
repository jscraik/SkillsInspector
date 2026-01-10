import Foundation

public enum IndexInclude: String, CaseIterable, Sendable {
    case codex
    case claude
    case both
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
}

public enum SkillIndexer {
    /// Generate a markdown Skills index from the provided roots.
    public static func generate(
        codexRoot: URL?,
        claudeRoot: URL?,
        include: IndexInclude = .both,
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
                entries.append(SkillIndexEntry(agent: agent, name: name, path: f.path, description: desc))
            }
        }

        switch include {
        case .codex:
            if let c = codexRoot { collect(agent: .codex, root: c) }
        case .claude:
            if let c = claudeRoot { collect(agent: .claude, root: c) }
        case .both:
            if let c = codexRoot { collect(agent: .codex, root: c) }
            if let c = claudeRoot { collect(agent: .claude, root: c) }
        }

        return entries.sorted { lhs, rhs in
            if lhs.agent == rhs.agent {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.agent.rawValue < rhs.agent.rawValue
        }
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
        md.append("| Agent | Skill | Description | Path |")
        md.append("| --- | --- | --- | --- |")
        for e in entries {
            let desc = e.description.isEmpty ? "" : e.description.replacingOccurrences(of: "|", with: "\\|")
            let path = e.path.replacingOccurrences(of: "|", with: "\\|")
            md.append("| \(e.agent.rawValue) | \(e.name) | \(desc) | `\(path)` |")
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

private extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
