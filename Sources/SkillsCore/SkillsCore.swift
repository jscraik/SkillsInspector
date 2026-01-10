import Foundation
import CryptoKit

/// Supported skill ecosystems.
public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case codex
    case claude
}

/// Normalized finding severity.
public enum Severity: String, Codable, Sendable {
    case error
    case warning
    case info
}

public typealias RuleID = String

/// A single validation result emitted by the scanner.
public struct Finding: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID = UUID()
    public let ruleID: RuleID
    public let severity: Severity
    public let agent: AgentKind
    public let fileURL: URL
    public let message: String
    public let line: Int?
    public let column: Int?
    public var suggestedFix: SuggestedFix?

    public init(
        ruleID: RuleID,
        severity: Severity,
        agent: AgentKind,
        fileURL: URL,
        message: String,
        line: Int? = nil,
        column: Int? = nil,
        suggestedFix: SuggestedFix? = nil
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.agent = agent
        self.fileURL = fileURL
        self.message = message
        self.line = line
        self.column = column
        self.suggestedFix = suggestedFix
    }
}

/// Parsed SKILL.md metadata plus filesystem context.
public struct SkillDoc: Codable, Hashable, Sendable {
    public let agent: AgentKind
    public let rootURL: URL
    public let skillDirURL: URL
    public let skillFileURL: URL
    public let name: String?
    public let description: String?
    public let lineCount: Int
    public let isSymlinkedDir: Bool
    public let hasFrontmatter: Bool
    public let frontmatterStartLine: Int
}

/// Scan root configuration.
public struct ScanRoot: Hashable, Sendable {
    public let agent: AgentKind
    public let rootURL: URL
    public let recursive: Bool
    public let maxDepth: Int?

    public init(agent: AgentKind, rootURL: URL, recursive: Bool = false, maxDepth: Int? = nil) {
        self.agent = agent
        self.rootURL = rootURL
        self.recursive = recursive
        self.maxDepth = maxDepth
    }
}

/// Sync comparison results between Codex and Claude trees.
public struct SyncReport: Hashable, Sendable {
    public var onlyInCodex: [String] = []
    public var onlyInClaude: [String] = []
    public var differentContent: [String] = []

    public init() {}
}

/// Structured scan output for JSON emission.
public struct ScanOutput: Codable, Sendable {
    public let schemaVersion: String
    public let toolVersion: String
    public let generatedAt: String
    public let scanned: Int
    public let errors: Int
    public let warnings: Int
    public let findings: [FindingOutput]

    public init(schemaVersion: String, toolVersion: String, generatedAt: String, scanned: Int, errors: Int, warnings: Int, findings: [FindingOutput]) {
        self.schemaVersion = schemaVersion
        self.toolVersion = toolVersion
        self.generatedAt = generatedAt
        self.scanned = scanned
        self.errors = errors
        self.warnings = warnings
        self.findings = findings
    }
}

/// Public, serializable finding shape for JSON output.
public struct FindingOutput: Codable, Sendable {
    public let ruleID: String
    public let severity: String
    public let agent: String
    public let file: String
    public let message: String
    public let line: Int?
    public let column: Int?

    public init(ruleID: String, severity: String, agent: String, file: String, message: String, line: Int?, column: Int?) {
        self.ruleID = ruleID
        self.severity = severity
        self.agent = agent
        self.file = file
        self.message = message
        self.line = line
        self.column = column
    }
}

// MARK: - Config

/// Repository or user configuration for scanning and sync.
public struct SkillsConfig: Codable, Sendable {
    public struct Policy: Codable, Sendable {
        public var strict: Bool?
        public var codexSymlinkSeverity: Severity?
        public var claudeSymlinkSeverity: Severity?
    }

    public struct ScanConfig: Codable, Sendable {
        public var recursive: Bool?
        public var maxDepth: Int?
        public var excludes: [String]?
        public var excludeGlobs: [String]?
    }

    public struct SyncConfig: Codable, Sendable {
        public var aliases: [String: String]?
    }

    public var schemaVersion: Int?
    public var scan: ScanConfig?
    public var excludes: [String]?
    public var excludeGlobs: [String]?
    public var policy: Policy?
    public var sync: SyncConfig?

    /// Loads configuration from a JSON file if provided; returns an empty config on failure.
    public static func load(from path: String?) -> SkillsConfig {
        guard let path, !path.isEmpty else { return SkillsConfig() }
        let url = URL(fileURLWithPath: PathUtil.expandTilde(path))
        guard let data = try? Data(contentsOf: url) else { return SkillsConfig() }
        return (try? JSONDecoder().decode(SkillsConfig.self, from: data)) ?? SkillsConfig()
    }
}

// MARK: - Path utilities

/// Filesystem helpers used throughout the scanner and sync flows.
public enum PathUtil {
    /// Expands `~` to the user's home directory.
    public static func expandTilde(_ path: String) -> String {
        if path.hasPrefix("~") {
            return (path as NSString).expandingTildeInPath
        }
        return path
    }

    /// Builds a file URL from a path, expanding `~`.
    public static func urlFromPath(_ path: String) -> URL {
        URL(fileURLWithPath: expandTilde(path))
    }

    /// Returns true when the URL exists and is a directory.
    public static func existsDir(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Returns true when the URL exists and is a file.
    public static func existsFile(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }

    /// Minimal glob matcher supporting `*` and `?` wildcards.
    public static func glob(_ pattern: String, matches path: String) -> Bool {
        // Simple glob: * and ? wildcards, no character classes.
        let escaped = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "+", with: "\\+")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "^", with: "\\^")
            .replacingOccurrences(of: "$", with: "\\$")
        let regexPattern = "^" + escaped
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".") + "$"
        return (try? NSRegularExpression(pattern: regexPattern)).map {
            $0.firstMatch(in: path, range: NSRange(location: 0, length: path.utf16.count)) != nil
        } ?? false
    }
}

// MARK: - Frontmatter parsing

public enum FrontmatterParser {
    /// Parses a top-of-file YAML-like frontmatter block.
    /// Only simple `key: value` pairs without nesting are supported.
    public static func parseTopBlock(_ text: String) -> [String: String] {
        if !(text.hasPrefix("---\n") || text.hasPrefix("---\r\n") || text == "---") {
            return [:]
        }

        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.first == "---" else { return [:] }

        var dict: [String: String] = [:]
        var index = 1

        while index < lines.count {
            let line = String(lines[index])
            if line == "---" { break }

            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                index += 1
                continue
            }

            guard let colon = line.firstIndex(of: ":") else {
                index += 1
                continue
            }

            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !key.isEmpty {
                dict[key] = value
            }
            index += 1
        }

        return dict
    }
}

// MARK: - Scanner

public enum SkillsScanner {
    public static func findSkillFiles(
        roots: [ScanRoot],
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) -> [ScanRoot: [URL]] {
        var out: [ScanRoot: [URL]] = [:]
        let fm = FileManager.default

        for root in roots {
            guard PathUtil.existsDir(root.rootURL) else {
                out[root] = []
                continue
            }

            var files: [URL] = []
            if root.recursive {
                let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
                guard let enumerator = fm.enumerator(
                    at: root.rootURL,
                    includingPropertiesForKeys: keys,
                    options: [.skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else {
                    out[root] = []
                    continue
                }

                for case let url as URL in enumerator {
                    let resourceValues = try? url.resourceValues(forKeys: Set(keys))
                    if let name = resourceValues?.name,
                       excludeDirNames.contains(name) {
                        enumerator.skipDescendants()
                        continue
                    }

                    if excludeGlobs.contains(where: { PathUtil.glob($0, matches: url.path) }) {
                        if (resourceValues?.isDirectory ?? false) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }

                    if url.lastPathComponent == "SKILL.md" {
                        if let maxDepth = root.maxDepth {
                            let rel = url.path.replacingOccurrences(of: root.rootURL.path, with: "")
                            let depth = rel.split(separator: "/").count - 1
                            if depth > maxDepth { continue }
                        }
                        files.append(url)
                    }
                }
            } else {
                let childDirs = (try? fm.contentsOfDirectory(
                    at: root.rootURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                    options: [.skipsPackageDescendants]
                )) ?? []

                for dir in childDirs {
                    let values = try? dir.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
                    guard values?.isDirectory == true else { continue }
                    let name = values?.name ?? dir.lastPathComponent
                    if excludeDirNames.contains(name) { continue }
                    if excludeGlobs.contains(where: { PathUtil.glob($0, matches: dir.path) }) {
                        continue
                    }
                    let skill = dir.appendingPathComponent("SKILL.md", isDirectory: false)
                    if PathUtil.existsFile(skill) {
                        files.append(skill)
                    }
                }
            }

            out[root] = files.sorted(by: { $0.path < $1.path })
        }

        return out
    }
}

// MARK: - Loader

public enum SkillLoader {
    public static func load(agent: AgentKind, rootURL: URL, skillFileURL: URL) -> SkillDoc? {
        let skillDirURL = skillFileURL.deletingLastPathComponent()
        let isSymlinkedDir = (try? skillDirURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false

        guard let text = try? String(contentsOf: skillFileURL, encoding: .utf8) else { return nil }
        let fm = FrontmatterParser.parseTopBlock(text)
        let name = fm["name"]
        let description = fm["description"]
        let lineCount = max(1, text.split(whereSeparator: \.isNewline).count)
        let hasFrontmatter = !fm.isEmpty

        let frontmatterStartLine = text.hasPrefix("---") ? 1 : -1

        return SkillDoc(
            agent: agent,
            rootURL: rootURL,
            skillDirURL: skillDirURL,
            skillFileURL: skillFileURL,
            name: name,
            description: description,
            lineCount: lineCount,
            isSymlinkedDir: isSymlinkedDir,
            hasFrontmatter: hasFrontmatter,
            frontmatterStartLine: frontmatterStartLine
        )
    }
}

// MARK: - Validator

public enum SkillValidator {
    public static func validate(doc: SkillDoc, policy: SkillsConfig.Policy? = nil) -> [Finding] {
        var findings: [Finding] = []

        let name = (doc.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = (doc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !doc.hasFrontmatter {
            findings.append(.init(
                ruleID: "frontmatter.missing",
                severity: .error,
                agent: doc.agent,
                fileURL: doc.skillFileURL,
                message: "Missing or invalid YAML frontmatter (must start with --- on line 1)",
                line: 1,
                column: 1
            ))
        }

        if name.isEmpty {
            findings.append(.init(
                ruleID: "frontmatter.missing_name",
                severity: .error,
                agent: doc.agent,
                fileURL: doc.skillFileURL,
                message: "Missing required frontmatter field: name",
                line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
                column: nil
            ))
        }

        if desc.isEmpty {
            findings.append(.init(
                ruleID: "frontmatter.missing_description",
                severity: .error,
                agent: doc.agent,
                fileURL: doc.skillFileURL,
                message: "Missing required frontmatter field: description",
                line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
                column: nil
            ))
        }

        switch doc.agent {
        case .codex:
            if !name.isEmpty && name.count > 100 {
                findings.append(.init(
                    ruleID: "codex.name.max_length",
                    severity: .error,
                    agent: .codex,
                    fileURL: doc.skillFileURL,
                    message: "Codex: name exceeds 100 characters",
                    line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
                    column: nil
                ))
            }
            if !desc.isEmpty && desc.count > 500 {
                findings.append(.init(
                    ruleID: "codex.description.max_length",
                    severity: .error,
                    agent: .codex,
                    fileURL: doc.skillFileURL,
                    message: "Codex: description exceeds 500 characters",
                    line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
                    column: nil
                ))
            }
            if doc.isSymlinkedDir {
                let severity = policy?.codexSymlinkSeverity ?? .error
                findings.append(.init(
                    ruleID: "codex.symlinked_dir",
                    severity: severity,
                    agent: .codex,
                    fileURL: doc.skillFileURL,
                    message: "Codex: skill directory is a symlink and may be ignored"
                ))
            }

        case .claude:
            if !name.isEmpty {
                let ok = name.range(of: #"^[a-z0-9-]{1,64}$"#, options: .regularExpression) != nil
                if !ok {
                    findings.append(.init(
                        ruleID: "claude.name.pattern",
                        severity: .error,
                        agent: .claude,
                        fileURL: doc.skillFileURL,
                        message: "Claude: name must match ^[a-z0-9-]{1,64}$",
                        line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
                        column: nil
                    ))
                }
                let dirName = doc.skillDirURL.lastPathComponent
                if dirName != name {
                    findings.append(.init(
                        ruleID: "claude.name.matches_dir",
                        severity: .warning,
                        agent: .claude,
                        fileURL: doc.skillFileURL,
                        message: "Claude: directory name '\(dirName)' should match skill name '\(name)'"
                    ))
                }
            }

            if !desc.isEmpty && desc.count > 1024 {
                findings.append(.init(
                    ruleID: "claude.description.max_length",
                    severity: .error,
                    agent: .claude,
                    fileURL: doc.skillFileURL,
                    message: "Claude: description exceeds 1024 characters",
                    line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
                    column: nil
                ))
            }
            if doc.lineCount > 500 {
                findings.append(.init(
                    ruleID: "claude.length.warning",
                    severity: .warning,
                    agent: .claude,
                    fileURL: doc.skillFileURL,
                    message: "Claude: SKILL.md is \(doc.lineCount) lines; guidance suggests staying under ~500"
                ))
            }
            if doc.isSymlinkedDir {
                let severity = policy?.claudeSymlinkSeverity ?? .warning
                findings.append(.init(
                    ruleID: "claude.symlinked_dir",
                    severity: severity,
                    agent: .claude,
                    fileURL: doc.skillFileURL,
                    message: "Claude: symlinked skill directories may not be detected"
                ))
            }
        }

        if policy?.strict == true {
            return findings.map { f in
                if f.severity == .warning {
                    return Finding(ruleID: f.ruleID, severity: .error, agent: f.agent, fileURL: f.fileURL, message: f.message, line: f.line, column: f.column)
                }
                return f
            }
        }
        return findings
    }
}

// MARK: - Hashing

public enum SkillHash {
    public static func sha256Hex(ofFile url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(ofString string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Sync

public enum SyncChecker {
    public static func byName(
        codexRoot: URL,
        claudeRoot: URL,
        recursive: Bool = false,
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) -> SyncReport {
        var report = SyncReport()
        let codexRootScan = ScanRoot(agent: .codex, rootURL: codexRoot, recursive: recursive)
        let claudeRootScan = ScanRoot(agent: .claude, rootURL: claudeRoot, recursive: recursive)

        let all = SkillsScanner.findSkillFiles(
            roots: [codexRootScan, claudeRootScan],
            excludeDirNames: excludeDirNames,
            excludeGlobs: excludeGlobs
        )
        let codexFiles = all[codexRootScan] ?? []
        let claudeFiles = all[claudeRootScan] ?? []

        func nameMap(agent: AgentKind, root: URL, files: [URL]) -> [String: URL] {
            var map: [String: URL] = [:]
            for file in files {
                guard let doc = SkillLoader.load(agent: agent, rootURL: root, skillFileURL: file),
                      let n = doc.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !n.isEmpty else { continue }
                map[n] = file
            }
            return map
        }

        let codexByName = nameMap(agent: .codex, root: codexRoot, files: codexFiles)
        let claudeByName = nameMap(agent: .claude, root: claudeRoot, files: claudeFiles)

        let codexNames = Set(codexByName.keys)
        let claudeNames = Set(claudeByName.keys)

        report.onlyInCodex = Array(codexNames.subtracting(claudeNames)).sorted()
        report.onlyInClaude = Array(claudeNames.subtracting(codexNames)).sorted()

        let both = codexNames.intersection(claudeNames)
        for name in both.sorted() {
            guard let codexURL = codexByName[name], let claudeURL = claudeByName[name] else { continue }
            let h1 = SkillHash.sha256Hex(ofFile: codexURL)
            let h2 = SkillHash.sha256Hex(ofFile: claudeURL)
            if h1 != nil && h2 != nil && h1 != h2 {
                report.differentContent.append(name)
            }
        }

        return report
    }
}
