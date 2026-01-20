import Foundation
import CryptoKit

/// Supported skill ecosystems.
public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case codex
    case claude
    case codexSkillManager
    case copilot

    public var displayLabel: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .codexSkillManager: return "CodexSkillManager"
        case .copilot: return "Copilot"
        }
    }
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
    public let referencesCount: Int
    public let assetsCount: Int
    public let scriptsCount: Int
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

/// Multi-agent sync comparison results.
public struct MultiSyncReport: Hashable, Sendable, Codable {
    public struct DiffDetail: Hashable, Sendable, Codable {
        public let name: String
        public let hashes: [AgentKind: String]
        public let modified: [AgentKind: Date]
    }

    public var missingByAgent: [AgentKind: [String]] = [:]
    public var differentContent: [DiffDetail] = []

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

    public struct FeatureFlagsConfig: Codable, Sendable {
        public var skillVerification: Bool?
        public var pinnedPublishing: Bool?
        public var crossIDEAdapters: Bool?
        public var telemetryOptIn: Bool?
        public var bulkActions: Bool?
    }

    public var schemaVersion: Int?
    public var scan: ScanConfig?
    public var excludes: [String]?
    public var excludeGlobs: [String]?
    public var policy: Policy?
    public var sync: SyncConfig?
    public var features: FeatureFlagsConfig?

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

// MARK: - Path validation

/// Validates user-provided directories to prevent traversal or missing paths.
public enum PathValidator {
    public enum ValidationError: LocalizedError, Equatable {
        case empty
        case traversal
        case missing
        case notDirectory

        public var errorDescription: String? {
            switch self {
            case .empty: return "Path is empty."
            case .traversal: return "Path contains parent directory traversal (\"..\") and was rejected."
            case .missing: return "Directory does not exist."
            case .notDirectory: return "Path is not a directory."
            }
        }
    }

    /// Validates and normalizes a directory path.
    /// - Parameter path: user-provided path (may include ~).
    /// - Returns: normalized URL or a validation error.
    public static func validatedDirectory(from path: String?) -> Result<URL, ValidationError> {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.empty)
        }
        let expanded = PathUtil.expandTilde(path)
        let url = URL(fileURLWithPath: expanded)
        if url.pathComponents.contains("..") {
            return .failure(.traversal)
        }
        let normalized = url.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized.path, isDirectory: &isDir) else {
            return .failure(.missing)
        }
        guard isDir.boolValue else {
            return .failure(.notDirectory)
        }
        return .success(normalized)
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

        let refs = countFiles(in: skillDirURL.appendingPathComponent("references", isDirectory: true))
        let assets = countFiles(in: skillDirURL.appendingPathComponent("assets", isDirectory: true))
        let scripts = countFiles(in: skillDirURL.appendingPathComponent("scripts", isDirectory: true))

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
            frontmatterStartLine: frontmatterStartLine,
            referencesCount: refs,
            assetsCount: assets,
            scriptsCount: scripts
        )
    }

    private static func countFiles(in directory: URL) -> Int {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else { return 0 }
        let items = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return items.filter { url in
            let rv = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return rv?.isDirectory == false
        }.count
    }
}

// MARK: - Validation Rules

/// Protocol for pluggable validation rules
public protocol ValidationRule: Sendable {
    /// Unique identifier for this rule
    var ruleID: String { get }
    
    /// Human-readable description of what this rule validates
    var description: String { get }
    
    /// Which agent(s) this rule applies to (nil means all agents)
    var appliesToAgent: AgentKind? { get }
    
    /// Default severity for violations of this rule
    var defaultSeverity: Severity { get }
    
    /// Validate a skill document and return findings
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding]
}

/// Registry for managing validation rules
public struct ValidationRuleRegistry: Sendable {
    private let rules: [any ValidationRule]
    
    public init(rules: [any ValidationRule] = defaultRules()) {
        self.rules = rules
    }
    
    /// Validate a document using all applicable rules
    public func validate(doc: SkillDoc, policy: SkillsConfig.Policy? = nil) -> [Finding] {
        var findings: [Finding] = []
        
        for rule in rules {
            // Skip rules that don't apply to this agent
            if let targetAgent = rule.appliesToAgent, targetAgent != doc.agent {
                continue
            }
            
            findings.append(contentsOf: rule.validate(doc: doc, policy: policy))
        }
        
        return findings
    }
    
    /// Default built-in validation rules
    public static func defaultRules() -> [any ValidationRule] {
        [
            FrontmatterMissingRule(),
            FrontmatterMissingNameRule(),
            FrontmatterMissingDescriptionRule(),
            CodexNameLengthRule(),
            CodexDescriptionLengthRule(),
            CodexSymlinkRule(),
            ClaudeNamePatternRule(),
            ClaudeNameMatchesDirRule(),
            ClaudeDescriptionLengthRule(),
            ClaudeLengthWarningRule()
        ]
    }
}

// MARK: - Built-in Rules

struct FrontmatterMissingRule: ValidationRule {
    let ruleID = "frontmatter.missing"
    let description = "YAML frontmatter must start with --- on line 1"
    let appliesToAgent: AgentKind? = nil
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        guard !doc.hasFrontmatter else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: doc.agent,
            fileURL: doc.skillFileURL,
            message: "Missing or invalid YAML frontmatter (must start with --- on line 1)",
            line: 1,
            column: 1
        )]
    }
}

struct FrontmatterMissingNameRule: ValidationRule {
    let ruleID = "frontmatter.missing_name"
    let description = "Frontmatter must include a name field"
    let appliesToAgent: AgentKind? = nil
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let name = (doc.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: doc.agent,
            fileURL: doc.skillFileURL,
            message: "Missing required frontmatter field: name",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
            column: nil
        )]
    }
}

struct FrontmatterMissingDescriptionRule: ValidationRule {
    let ruleID = "frontmatter.missing_description"
    let description = "Frontmatter must include a description field"
    let appliesToAgent: AgentKind? = nil
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let desc = (doc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard desc.isEmpty else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: doc.agent,
            fileURL: doc.skillFileURL,
            message: "Missing required frontmatter field: description",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
            column: nil
        )]
    }
}

struct CodexNameLengthRule: ValidationRule {
    let ruleID = "codex.name.max_length"
    let description = "Codex skill name must not exceed 100 characters"
    let appliesToAgent: AgentKind? = .codex
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let name = (doc.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && name.count > 100 else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .codex,
            fileURL: doc.skillFileURL,
            message: "Codex: name exceeds 100 characters",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
            column: nil
        )]
    }
}

struct CodexDescriptionLengthRule: ValidationRule {
    let ruleID = "codex.description.max_length"
    let description = "Codex skill description must not exceed 500 characters"
    let appliesToAgent: AgentKind? = .codex
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let desc = (doc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty && desc.count > 500 else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .codex,
            fileURL: doc.skillFileURL,
            message: "Codex: description exceeds 500 characters",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
            column: nil
        )]
    }
}

struct CodexSymlinkRule: ValidationRule {
    let ruleID = "codex.symlinked_dir"
    let description = "Codex may ignore symlinked skill directories"
    let appliesToAgent: AgentKind? = .codex
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        guard doc.isSymlinkedDir else { return [] }
        let severity = policy?.codexSymlinkSeverity ?? defaultSeverity
        return [Finding(
            ruleID: ruleID,
            severity: severity,
            agent: .codex,
            fileURL: doc.skillFileURL,
            message: "Codex: skill directory is a symlink and may be ignored"
        )]
    }
}

struct ClaudeNamePatternRule: ValidationRule {
    let ruleID = "claude.name.pattern"
    let description = "Claude skill name must match ^[a-z0-9-]{1,64}$"
    let appliesToAgent: AgentKind? = .claude
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let name = (doc.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        let ok = name.range(of: #"^[a-z0-9-]{1,64}$"#, options: .regularExpression) != nil
        guard !ok else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .claude,
            fileURL: doc.skillFileURL,
            message: "Claude: name must match ^[a-z0-9-]{1,64}$",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
            column: nil
        )]
    }
}

struct ClaudeNameMatchesDirRule: ValidationRule {
    let ruleID = "claude.name.matches_dir"
    let description = "Claude skill directory name should match skill name"
    let appliesToAgent: AgentKind? = .claude
    let defaultSeverity: Severity = .warning
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let name = (doc.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        let dirName = doc.skillDirURL.lastPathComponent
        guard dirName != name else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .claude,
            fileURL: doc.skillFileURL,
            message: "Claude: directory name '\(dirName)' should match skill name '\(name)'"
        )]
    }
}

struct ClaudeDescriptionLengthRule: ValidationRule {
    let ruleID = "claude.description.max_length"
    let description = "Claude skill description must not exceed 1024 characters"
    let appliesToAgent: AgentKind? = .claude
    let defaultSeverity: Severity = .error
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        let desc = (doc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty && desc.count > 1024 else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .claude,
            fileURL: doc.skillFileURL,
            message: "Claude: description exceeds 1024 characters",
            line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
            column: nil
        )]
    }
}

struct ClaudeLengthWarningRule: ValidationRule {
    let ruleID = "claude.length.warning"
    let description = "Claude SKILL.md files over 500 lines may be truncated"
    let appliesToAgent: AgentKind? = .claude
    let defaultSeverity: Severity = .warning
    
    func validate(doc: SkillDoc, policy: SkillsConfig.Policy?) -> [Finding] {
        guard doc.lineCount > 500 else { return [] }
        return [Finding(
            ruleID: ruleID,
            severity: defaultSeverity,
            agent: .claude,
            fileURL: doc.skillFileURL,
            message: "Claude: SKILL.md is \(doc.lineCount) lines (> 500), which may be truncated in some contexts"
        )]
    }
}

// MARK: - Validator

public enum SkillValidator {
    private static let registry = ValidationRuleRegistry()
    
    public static func validate(doc: SkillDoc, policy: SkillsConfig.Policy? = nil) -> [Finding] {
        return registry.validate(doc: doc, policy: policy)
    }
}

// Legacy implementation preserved for reference (can be removed after migration)
extension SkillValidator {
    public static func validateLegacy(doc: SkillDoc, policy: SkillsConfig.Policy? = nil) -> [Finding] {
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
        case .codex, .codexSkillManager, .copilot:
            if !name.isEmpty && name.count > 100 {
                findings.append(.init(
                    ruleID: "\(doc.agent.rawValue).name.max_length",
                    severity: .error,
                    agent: doc.agent,
                    fileURL: doc.skillFileURL,
                    message: "\(doc.agent.displayLabel): name exceeds 100 characters",
                    line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 1 : nil,
                    column: nil
                ))
            }
            if !desc.isEmpty && desc.count > 500 {
                findings.append(.init(
                    ruleID: "\(doc.agent.rawValue).description.max_length",
                    severity: .error,
                    agent: doc.agent,
                    fileURL: doc.skillFileURL,
                    message: "\(doc.agent.displayLabel): description exceeds 500 characters",
                    line: doc.frontmatterStartLine > 0 ? doc.frontmatterStartLine + 2 : nil,
                    column: nil
                ))
            }
            if doc.isSymlinkedDir {
                let severity = policy?.codexSymlinkSeverity ?? .error
                findings.append(.init(
                    ruleID: "\(doc.agent.rawValue).symlinked_dir",
                    severity: severity,
                    agent: doc.agent,
                    fileURL: doc.skillFileURL,
                    message: "\(doc.agent.displayLabel): skill directory is a symlink and may be ignored"
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
    public static func multiByName(
        roots: [ScanRoot],
        recursive: Bool = false,
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) -> MultiSyncReport {
        if Task.isCancelled { return MultiSyncReport() }
        var report = MultiSyncReport()
        let filesByRoot = SkillsScanner.findSkillFiles(
            roots: roots,
            excludeDirNames: excludeDirNames,
            excludeGlobs: excludeGlobs
        )

        // Map agent -> name -> url
        var byAgent: [AgentKind: [String: URL]] = [:]
        for root in roots {
            if Task.isCancelled { return MultiSyncReport() }
            let files = filesByRoot[root] ?? []
            for file in files {
                if Task.isCancelled { return MultiSyncReport() }
                guard let doc = SkillLoader.load(agent: root.agent, rootURL: root.rootURL, skillFileURL: file),
                      let name = doc.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { continue }
                var map = byAgent[root.agent, default: [:]]
                map[name] = file
                byAgent[root.agent] = map
            }
        }

        let allAgents = Set(roots.map { $0.agent })
        let allNames = Set(byAgent.values.flatMap { $0.keys })

        for agent in allAgents {
            report.missingByAgent[agent] = []
        }

        var diffs: [MultiSyncReport.DiffDetail] = []

        for name in allNames {
            if Task.isCancelled { return MultiSyncReport() }
            var presentAgents: [AgentKind: URL] = [:]
            for agent in allAgents {
                if Task.isCancelled { return MultiSyncReport() }
                if let url = byAgent[agent]?[name] {
                    presentAgents[agent] = url
                } else {
                    report.missingByAgent[agent, default: []].append(name)
                }
            }

            if presentAgents.count >= 2 {
                var hashes: [AgentKind: String] = [:]
                var modified: [AgentKind: Date] = [:]
                for (agent, url) in presentAgents {
                    if Task.isCancelled { return MultiSyncReport() }
                    hashes[agent] = SkillHash.sha256Hex(ofFile: url) ?? ""
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let m = attrs[.modificationDate] as? Date {
                        modified[agent] = m
                    }
                }
                let uniqueHashes = Set(hashes.values.filter { !$0.isEmpty })
                if uniqueHashes.count > 1 {
                    diffs.append(.init(name: name, hashes: hashes, modified: modified))
                }
            }
        }

        for agent in allAgents {
            report.missingByAgent[agent]?.sort()
        }
        report.differentContent = diffs.sorted { $0.name < $1.name }
        return report
    }

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
