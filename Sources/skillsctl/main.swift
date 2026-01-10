import Foundation
import ArgumentParser
import SkillsCore

struct SkillsCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skillsctl",
        abstract: "Scan/validate/sync Codex + Claude SKILL.md directories.",
        subcommands: [Scan.self, SyncCheck.self]
    )
}

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Scan roots and validate SKILL.md files.")

    @Option(name: .customLong("codex"), help: "Codex skills root (default: ~/.codex/skills)")
    var codexPath: String = "~/.codex/skills"

    @Option(name: .customLong("claude"), help: "Claude skills root (default: ~/.claude/skills)")
    var claudePath: String = "~/.claude/skills"

    @Option(name: .customLong("repo"), help: "Repo root; scans <repo>/.codex/skills and <repo>/.claude/skills")
    var repoPath: String?

    @Flag(name: .customLong("skip-codex"), help: "Skip Codex scan")
    var skipCodex: Bool = false

    @Flag(name: .customLong("skip-claude"), help: "Skip Claude scan")
    var skipClaude: Bool = false

    @Flag(name: .customLong("recursive"), help: "Recursively walk for SKILL.md instead of shallow root/<skill>/SKILL.md")
    var recursive: Bool = false

    @Option(name: .customLong("max-depth"), help: "When recursive, limit directory depth (relative to root).")
    var maxDepth: Int?

    @Option(name: .customLong("exclude"), parsing: .upToNextOption, help: "Directory names to exclude (repeatable)")
    var excludes: [String] = []

    @Option(name: .customLong("exclude-glob"), parsing: .upToNextOption, help: "Glob patterns to exclude paths (repeatable, applies to dirs/files)")
    var excludeGlobs: [String] = []

    @Flag(name: .customLong("no-default-excludes"), help: "Disable common excludes like .git, .system, __pycache__")
    var disableDefaultExcludes: Bool = false

    @Flag(name: .customLong("allow-empty"), help: "Exit 0 even if no SKILL.md files are found")
    var allowEmpty: Bool = false

    @Option(name: .customLong("format"), help: "Output format: text|json", completion: .list(["text", "json"]))
    var format: String = "text"

    @Option(name: .customLong("schema-version"), help: "JSON schema version for output")
    var schemaVersion: String = "1"

    @Option(name: .customLong("log-level"), help: "Log level: error|warn|info|debug")
    var logLevel: String = "warn"

    @Flag(name: .customLong("plain"), help: "Plain (no color/special formatting) output for accessibility")
    var plain: Bool = false

    @Option(name: .customLong("config"), help: "Path to config JSON (otherwise .skillsctl/config.json if present)")
    var configPath: String?

    @Option(name: .customLong("baseline"), help: "Path to baseline JSON to suppress known findings")
    var baselinePath: String?

    @Option(name: .customLong("ignore"), help: "Path to ignore rules JSON")
    var ignorePath: String?

    func run() throws {
        var excludeSet: Set<String> = []
        if !disableDefaultExcludes {
            excludeSet.formUnion([".git", ".system", "__pycache__", ".DS_Store"])
        }
        excludeSet.formUnion(excludes)

        var roots: [ScanRoot] = []

        if let repoPath {
            let repoURL = PathUtil.urlFromPath(repoPath)
            let codexURL = repoURL.appendingPathComponent(".codex/skills", isDirectory: true)
            let claudeURL = repoURL.appendingPathComponent(".claude/skills", isDirectory: true)
            if !skipCodex { roots.append(.init(agent: .codex, rootURL: codexURL, recursive: recursive, maxDepth: maxDepth)) }
            if !skipClaude { roots.append(.init(agent: .claude, rootURL: claudeURL, recursive: recursive, maxDepth: maxDepth)) }
        } else {
            if !skipCodex { roots.append(.init(agent: .codex, rootURL: PathUtil.urlFromPath(codexPath), recursive: recursive, maxDepth: maxDepth)) }
            if !skipClaude { roots.append(.init(agent: .claude, rootURL: PathUtil.urlFromPath(claudePath), recursive: recursive, maxDepth: maxDepth)) }
        }

        let config = ConfigLoader.loadConfig(explicitPath: configPath, repoRoot: repoPath.map(PathUtil.urlFromPath))
        let baseline = ConfigLoader.loadBaseline(path: baselinePath ?? repoPath.map { PathUtil.urlFromPath($0).appendingPathComponent(".skillsctl/baseline.json").path })
        let ignores = ConfigLoader.loadIgnore(path: ignorePath ?? repoPath.map { PathUtil.urlFromPath($0).appendingPathComponent(".skillsctl/ignore.json").path })

        let filesByRoot = SkillsScanner.findSkillFiles(
            roots: roots,
            excludeDirNames: excludeSet.union(Set(config.excludes ?? [])).union(Set(config.scan?.excludes ?? [])),
            excludeGlobs: (config.excludeGlobs ?? []) + excludeGlobs + (config.scan?.excludeGlobs ?? [])
        )

        var findings: [Finding] = []
        var scannedCount = 0

        for root in roots {
            for file in filesByRoot[root] ?? [] {
                scannedCount += 1
                if let doc = SkillLoader.load(agent: root.agent, rootURL: root.rootURL, skillFileURL: file) {
                    findings.append(contentsOf: SkillValidator.validate(doc: doc, policy: config.policy))
                } else {
                    findings.append(Finding(
                        ruleID: "skill.unreadable",
                        severity: .error,
                        agent: root.agent,
                        fileURL: file,
                        message: "Unreadable SKILL.md"
                    ))
                }
            }
        }

        let filtered = applyIgnoresAndBaseline(findings: findings, baseline: baseline, ignores: ignores)

        if scannedCount == 0 && !allowEmpty {
            throw ExitCode(1)
        }

        output(findings: filtered, scannedCount: scannedCount)

        let errors = filtered.filter { $0.severity == .error }
        if !errors.isEmpty {
            throw ExitCode(1)
        }
    }

    private func output(findings: [Finding], scannedCount: Int) {
        switch format.lowercased() {
        case "json":
            let output = ScanOutput(
                schemaVersion: schemaVersion,
                toolVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                scanned: scannedCount,
                errors: findings.filter { $0.severity == .error }.count,
                warnings: findings.filter { $0.severity == .warning }.count,
                findings: findings.map { f in
                    FindingOutput(
                        ruleID: f.ruleID,
                        severity: f.severity.rawValue,
                        agent: f.agent.rawValue,
                        file: f.fileURL.path,
                        message: f.message,
                        line: f.line,
                        column: f.column
                    )
                }
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(output),
               let text = String(data: data, encoding: .utf8) {
                // Validate against schema (best-effort; do not fail if validator unavailable)
                let cwdSchema = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("docs/schema/findings-schema.json")
                if FileManager.default.fileExists(atPath: cwdSchema.path),
                   let schemaData = try? Data(contentsOf: cwdSchema),
                   let schemaText = String(data: schemaData, encoding: .utf8),
                   !JSONValidator.validate(json: text, schema: schemaText) {
                    fputs("WARNING: JSON output did not validate against schemaVersion \(schemaVersion)\n", stderr)
                }
                print(text)
            }
        default:
            let errors = findings.filter { $0.severity == .error }.count
            let warnings = findings.filter { $0.severity == .warning }.count
            let prefix = plain ? "" : ""
            print("\(prefix)Scanned SKILL.md files: \(scannedCount)")
            print("\(prefix)Errors: \(errors)  Warnings: \(warnings)")
            for f in findings.sorted(by: sortFindings) {
                let sev = f.severity.rawValue.uppercased()
                print("\(prefix)[\(sev)] \(f.agent.rawValue) \(f.fileURL.path)")
                print("\(prefix)  - (\(f.ruleID)) \(f.message)")
            }
        }
    }

    private func sortFindings(_ lhs: Finding, _ rhs: Finding) -> Bool {
        if lhs.severity != rhs.severity {
            return lhs.severity.rawValue < rhs.severity.rawValue
        }
        if lhs.agent != rhs.agent {
            return lhs.agent.rawValue < rhs.agent.rawValue
        }
        if lhs.fileURL.path != rhs.fileURL.path {
            return lhs.fileURL.path < rhs.fileURL.path
        }
        return lhs.message < rhs.message
    }

    private func applyIgnoresAndBaseline(findings: [Finding], baseline: Set<BaselineEntry>, ignores: [IgnoreRule]) -> [Finding] {
        findings.filter { f in
            // Baseline suppression
            if baseline.contains(where: { $0.ruleID == f.ruleID && $0.file == f.fileURL.path && ($0.agent == nil || $0.agent == f.agent.rawValue) }) {
                return false
            }
            // Ignore rules (glob)
            for ig in ignores where ig.ruleID == f.ruleID {
                if PathUtil.glob(ig.glob, matches: f.fileURL.path) {
                    return false
                }
            }
            return true
        }
    }
}

// Entry point
SkillsCtl.main()

struct SyncCheck: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compare Codex vs Claude by skill name + content hash.")

    @Option(name: .customLong("codex"), help: "Codex skills root (default: ~/.codex/skills)")
    var codexPath: String = "~/.codex/skills"

    @Option(name: .customLong("claude"), help: "Claude skills root (default: ~/.claude/skills)")
    var claudePath: String = "~/.claude/skills"

    @Flag(name: .customLong("recursive"), help: "Recursively walk for SKILL.md instead of shallow root/<skill>/SKILL.md")
    var recursive: Bool = false

    @Option(name: .customLong("max-depth"), help: "When recursive, limit directory depth (relative to root).")
    var maxDepth: Int?

    @Option(name: .customLong("exclude"), parsing: .upToNextOption, help: "Directory names to exclude (repeatable)")
    var excludes: [String] = []

    @Option(name: .customLong("exclude-glob"), parsing: .upToNextOption, help: "Glob patterns to exclude paths")
    var excludeGlobs: [String] = []

    @Option(name: .customLong("format"), help: "Output format: text|json", completion: .list(["text", "json"]))
    var format: String = "text"

    func run() throws {
        let codexURL = PathUtil.urlFromPath(codexPath)
        let claudeURL = PathUtil.urlFromPath(claudePath)

        let report = SyncChecker.byName(
            codexRoot: codexURL,
            claudeRoot: claudeURL,
            recursive: recursive,
            excludeDirNames: Set(excludes).union([".git", ".system", "__pycache__", ".DS_Store"]),
            excludeGlobs: excludeGlobs
        )

        output(report: report)

        let ok = report.onlyInCodex.isEmpty && report.onlyInClaude.isEmpty && report.differentContent.isEmpty
        if !ok { throw ExitCode(1) }
    }

    private func output(report: SyncReport) {
        switch format.lowercased() {
        case "json":
            let payload: [String: Any] = [
                "onlyInCodex": report.onlyInCodex,
                "onlyInClaude": report.onlyInClaude,
                "differentContent": report.differentContent
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
               let text = String(data: data, encoding: .utf8) {
                print(text)
            }
        default:
            if report.onlyInCodex.isEmpty &&
                report.onlyInClaude.isEmpty &&
                report.differentContent.isEmpty {
                print("Codex and Claude skill trees are in sync.")
                return
            }
            if !report.onlyInCodex.isEmpty {
                print("Only in Codex:")
                report.onlyInCodex.forEach { print("  - \($0)") }
            }
            if !report.onlyInClaude.isEmpty {
                print("Only in Claude:")
                report.onlyInClaude.forEach { print("  - \($0)") }
            }
            if !report.differentContent.isEmpty {
                print("Different content (same name):")
                report.differentContent.forEach { print("  - \($0)") }
            }
        }
    }
}
