import Foundation
import ArgumentParser
import SkillsCore

struct SkillsCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skillsctl",
        abstract: "Scan/validate/sync Codex + Claude SKILL.md directories.",
        subcommands: [Scan.self, Fix.self, SyncCheck.self, Index.self, Remote.self, Completion.self]
    )
}

// MARK: - Remote commands

struct Remote: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Browse and install remote skills from Clawdhub.",
        subcommands: [RemoteList.self, RemoteSearch.self, RemoteDetail.self, RemoteInstall.self, RemoteUpdate.self]
    )
}

struct RemoteList: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List latest skills from Clawdhub.")

    @Option(name: .customLong("limit"), help: "Maximum items to fetch (default 20)")
    var limit: Int = 20

    @Option(name: .customLong("format"), help: "Output format: text|json")
    var format: String = "text"

    func run() async throws {
        let client = RemoteSkillClient.live()
        let items = try await client.fetchLatest(limit)
        try output(items: items, format: format)
    }
}

struct RemoteSearch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search remote skills.")

    @Argument(help: "Search query") var query: String
    @Option(name: .customLong("limit"), help: "Maximum items to fetch (default 20)")
    var limit: Int = 20
    @Option(name: .customLong("format"), help: "Output format: text|json")
    var format: String = "text"

    func run() async throws {
        let client = RemoteSkillClient.live()
        let items = try await client.search(query, limit)
        try output(items: items, format: format)
    }
}

struct RemoteDetail: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch owner detail for a slug.")
    @Argument(help: "Skill slug") var slug: String

    func run() async throws {
        let client = RemoteSkillClient.live()
        async let owner = client.fetchDetail(slug)
        async let latest = client.fetchLatestVersion(slug)
        let detail = RemoteSkillDetail(
            skill: RemoteSkill(id: slug, slug: slug, displayName: slug, summary: nil, latestVersion: try await latest, updatedAt: nil, downloads: nil, stars: nil),
            owner: try await owner,
            changelog: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(detail)
        if let text = String(data: data, encoding: .utf8) {
            if let schema = schemaURL(named: "remote-detail-schema.json"),
               let schemaText = try? String(contentsOf: schema, encoding: .utf8),
               !JSONValidator.validate(json: text, schema: schemaText) {
                fputs("WARNING: JSON output did not validate against remote-detail schema\n", stderr)
            }
            print(text)
        }
    }
}

struct RemoteInstall: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Download and install a remote skill into Codex/Claude/custom root.")
    @Argument(help: "Skill slug") var slug: String
    @Option(name: .customLong("version"), help: "Specific version; defaults to latest") var version: String?
    @Option(name: .customLong("target"), help: "codex|claude|<path>; default codex") var target: String = "codex"
    @Flag(name: .customLong("overwrite"), help: "Overwrite existing skill directory if present") var overwrite: Bool = false
    @Flag(name: .customLong("plain"), help: "Plain output") var plain: Bool = false

    func run() async throws {
        let client = RemoteSkillClient.live()
        let installer = RemoteSkillInstaller()
        let downloadURL = try await client.download(slug, version)
        let targetRoot = resolveTargetRoot(target)
        let result = try await installer.install(
            archiveURL: downloadURL,
            target: targetRoot,
            overwrite: overwrite
        )
        if plain {
            print("Installed to \(result.skillDirectory.path)")
        } else {
            let payload: [String: Any] = [
                "destination": result.skillDirectory.path,
                "filesCopied": result.filesCopied,
                "bytes": result.totalBytes,
                "archiveSHA256": result.archiveSHA256 ?? ""
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                if let schema = schemaURL(named: "remote-install-schema.json"),
                   let schemaText = try? String(contentsOf: schema, encoding: .utf8),
                   !JSONValidator.validate(json: text, schema: schemaText) {
                    fputs("WARNING: JSON output did not validate against remote-install schema\n", stderr)
                }
                print(text)
            } else {
                print("✅ Installed \(slug) to \(result.skillDirectory.path)")
            }
        }
    }
}

struct RemoteUpdate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Download and overwrite with the latest version of a skill.")
    @Argument(help: "Skill slug") var slug: String
    @Option(name: .customLong("target"), help: "codex|claude|<path>; default codex") var target: String = "codex"
    @Flag(name: .customLong("plain"), help: "Plain output") var plain: Bool = false

    func run() async throws {
        let client = RemoteSkillClient.live()
        let installer = RemoteSkillInstaller()
        let targetRoot = resolveTargetRoot(target)
        let downloadURL = try await client.download(slug, nil)
        let result = try await installer.install(archiveURL: downloadURL, target: targetRoot, overwrite: true)
        if plain {
            print("Updated \(slug) at \(targetRoot.root.path)")
        } else {
            let payload: [String: Any] = [
                "destination": result.skillDirectory.path,
                "filesCopied": result.filesCopied,
                "bytes": result.totalBytes,
                "archiveSHA256": result.archiveSHA256 ?? "",
                "contentSHA256": result.contentSHA256 ?? ""
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                if let schema = schemaURL(named: "remote-install-schema.json"),
                   let schemaText = try? String(contentsOf: schema, encoding: .utf8),
                   !JSONValidator.validate(json: text, schema: schemaText) {
                    fputs("WARNING: JSON output did not validate against remote-install schema\n", stderr)
                }
                print(text)
            } else {
                print("Updated \(slug) at \(targetRoot.root.path)")
            }
        }
    }
}

// Shared output helper
private func output(items: [RemoteSkill], format: String) throws {
    switch format.lowercased() {
    case "json":
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        if let text = String(data: data, encoding: .utf8) {
            if let schema = schemaURL(named: "remote-list-schema.json"),
               let schemaText = try? String(contentsOf: schema, encoding: .utf8),
               !JSONValidator.validate(json: text, schema: schemaText) {
                fputs("WARNING: JSON output did not validate against remote-list schema\n", stderr)
            }
            print(text)
        }
    default:
        for item in items {
            var line = "- \(item.displayName) (\(item.slug))"
            if let v = item.latestVersion { line += "  v\(v)" }
            if let updated = item.updatedAt {
                let fmt = ISO8601DateFormatter()
                line += "  updated \(fmt.string(from: updated))"
            }
            if let downloads = item.downloads { line += "  ⬇︎\(downloads)" }
            if let stars = item.stars { line += "  ★\(stars)" }
            print(line)
            if let summary = item.summary { print("  \(summary)") }
        }
    }
}

private func resolveTargetRoot(_ target: String) -> SkillInstallTarget {
    switch target.lowercased() {
    case "codex":
        return .codex(PathUtil.urlFromPath("~/.codex/skills"))
    case "claude":
        return .claude(PathUtil.urlFromPath("~/.claude/skills"))
    default:
        return .custom(PathUtil.urlFromPath(target))
    }
}

private func schemaURL(named name: String) -> URL? {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let local = cwd.appendingPathComponent("docs/schema").appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: local.path) { return local }
    return Bundle.main.url(forResource: name.replacingOccurrences(of: ".json", with: ""), withExtension: "json", subdirectory: "docs/schema")
}

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Scan roots and validate SKILL.md files.")

    @Option(name: .customLong("codex"), help: "Codex skills root (default: ~/.codex/skills)")
    var codexPath: String = "~/.codex/skills"

    @Option(name: .customLong("claude"), help: "Claude skills root (default: ~/.claude/skills)")
    var claudePath: String = "~/.claude/skills"

    @Option(name: .customLong("csm-path"), help: "Path to CodexSkillManager working tree (optional)")
    var codexSkillManagerPath: String?

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

    @Flag(name: .customLong("no-cache"), help: "Disable cache for this scan")
    var noCache: Bool = false

    @Option(name: .customLong("jobs"), help: "Maximum parallel validation jobs (default: CPU count)")
    var jobs: Int?

    @Flag(name: .customLong("watch"), help: "Watch for file changes and re-validate automatically")
    var watch: Bool = false

    @Flag(name: .customLong("show-cache-stats"), help: "Show cache statistics after scan")
    var showCacheStats: Bool = false

    @Flag(name: .customLong("telemetry"), help: "Output performance telemetry as JSON")
    var telemetry: Bool = false

    func run() throws {
        var excludeSet: Set<String> = []
        if !disableDefaultExcludes {
            excludeSet.formUnion([".git", ".system", "__pycache__", ".DS_Store"])
        }
        excludeSet.formUnion(excludes)

        var roots: [ScanRoot] = []

        let csmRoot: URL?
        switch PathValidator.validatedDirectory(from: codexSkillManagerPath) {
        case .success(let url):
            csmRoot = url
        case .failure(.empty):
            csmRoot = nil
        case .failure(let error):
            fputs("CodexSkillManager path invalid: \(error.localizedDescription)\n", stderr)
            throw ExitCode(1)
        }

        if let repoPath {
            let repoURL = PathUtil.urlFromPath(repoPath)
            let codexURL = repoURL.appendingPathComponent(".codex/skills", isDirectory: true)
            let claudeURL = repoURL.appendingPathComponent(".claude/skills", isDirectory: true)
            if !skipCodex {
                roots.append(.init(agent: .codex, rootURL: codexURL, recursive: recursive, maxDepth: maxDepth))
                // Also scan nested public if present
                let publicRoot = codexURL.appendingPathComponent("public", isDirectory: true)
                if PathUtil.existsDir(publicRoot) {
                    roots.append(.init(agent: .codex, rootURL: publicRoot, recursive: recursive, maxDepth: maxDepth))
                }
            }
            if !skipClaude { roots.append(.init(agent: .claude, rootURL: claudeURL, recursive: recursive, maxDepth: maxDepth)) }
        } else {
            let codexRoot = PathUtil.urlFromPath(codexPath)
            if !skipCodex {
                roots.append(.init(agent: .codex, rootURL: codexRoot, recursive: recursive, maxDepth: maxDepth))
                let publicRoot = codexRoot.appendingPathComponent("public", isDirectory: true)
                if PathUtil.existsDir(publicRoot) {
                    roots.append(.init(agent: .codex, rootURL: publicRoot, recursive: recursive, maxDepth: maxDepth))
                }
            }
            if !skipClaude { roots.append(.init(agent: .claude, rootURL: PathUtil.urlFromPath(claudePath), recursive: recursive, maxDepth: maxDepth)) }
        }

        if let csmRoot {
            roots.append(.init(agent: .codexSkillManager, rootURL: csmRoot, recursive: recursive, maxDepth: maxDepth))
        }

        let config = ConfigLoader.loadConfig(explicitPath: configPath, repoRoot: repoPath.map(PathUtil.urlFromPath))
        
        // Validate config against schema if present
        if let configPath = configPath, !configPath.isEmpty {
            let configURL = URL(fileURLWithPath: PathUtil.expandTilde(configPath))
            if let configData = try? Data(contentsOf: configURL),
               let configJSON = String(data: configData, encoding: .utf8),
               let schemaPath = Bundle.main.url(forResource: "config-schema", withExtension: "json", subdirectory: "docs"),
               let schemaData = try? Data(contentsOf: schemaPath),
               let schemaJSON = String(data: schemaData, encoding: .utf8) {
                if !JSONValidator.validate(json: configJSON, schema: schemaJSON) {
                    fputs("❌ Config file validation failed: \(configPath) does not match schema\n", stderr)
                    throw ExitCode(2)
                }
            }
        }
        
        let baseline = ConfigLoader.loadBaseline(path: baselinePath ?? repoPath.map { PathUtil.urlFromPath($0).appendingPathComponent(".skillsctl/baseline.json").path })
        let ignores = ConfigLoader.loadIgnore(path: ignorePath ?? repoPath.map { PathUtil.urlFromPath($0).appendingPathComponent(".skillsctl/ignore.json").path })

        if watch {
            try runWatch(
                roots: roots,
                excludeSet: excludeSet,
                config: config,
                baseline: baseline,
                ignores: ignores,
                excludeGlobs: excludeGlobs
            )
        } else {
            try runScan(
                roots: roots,
                excludeSet: excludeSet,
                config: config,
                baseline: baseline,
                ignores: ignores,
                excludeGlobs: excludeGlobs
            )
        }
    }

    private func runScan(
        roots: [ScanRoot],
        excludeSet: Set<String>,
        config: SkillsConfig,
        baseline: Set<BaselineEntry>,
        ignores: [IgnoreRule],
        excludeGlobs: [String]
    ) throws {
        let (findings, stats) = runBlocking {
            await runScanAsync(
                roots: roots,
                excludeSet: excludeSet,
                config: config,
                excludeGlobs: excludeGlobs
            )
        }

        let filtered = applyIgnoresAndBaseline(findings: findings, baseline: baseline, ignores: ignores)

        if stats.scannedFiles == 0 && !allowEmpty {
            fputs("No SKILL.md files found\n", stderr)
            throw ExitCode(1)
        }

        output(findings: filtered, scannedCount: stats.scannedFiles, stats: showCacheStats ? stats : nil)

        let errors = filtered.filter { $0.severity == .error }
        if !errors.isEmpty {
            throw ExitCode(1)
        }
    }

    private func runScanAsync(
        roots: [ScanRoot],
        excludeSet: Set<String>,
        config: SkillsConfig,
        excludeGlobs: [String]
    ) async -> (findings: [Finding], stats: ScanStats) {
        let cacheManager: CacheManager?
        if !noCache {
            let cacheURL = repoPath.map { PathUtil.urlFromPath($0).appendingPathComponent(".skillsctl/cache.json") }
            let configHash = SkillHash.sha256Hex(ofString: (try? JSONEncoder().encode(config)).map { String(data: $0, encoding: .utf8) ?? "" } ?? "")
            cacheManager = CacheManager(cacheURL: cacheURL, configHash: configHash)
        } else {
            cacheManager = nil
        }

        let maxConcurrency = jobs ?? ProcessInfo.processInfo.activeProcessorCount
        let (findings, stats) = await AsyncSkillsScanner.scanAndValidate(
            roots: roots,
            excludeDirNames: excludeSet.union(Set(config.excludes ?? [])).union(Set(config.scan?.excludes ?? [])),
            excludeGlobs: (config.excludeGlobs ?? []) + excludeGlobs + (config.scan?.excludeGlobs ?? []),
            policy: config.policy,
            cacheManager: cacheManager,
            maxConcurrency: maxConcurrency
        )

        if let cacheManager {
            await cacheManager.save()
        }

        return (findings, stats)
    }

    private func runWatch(
        roots: [ScanRoot],
        excludeSet: Set<String>,
        config: SkillsConfig,
        baseline: Set<BaselineEntry>,
        ignores: [IgnoreRule],
        excludeGlobs: [String]
    ) throws {
        fputs("👀 Watching for changes... (Ctrl+C to stop)\n", stderr)
        
        let watcher = FileWatcher(roots: roots.map { $0.rootURL })
        var lastRun = Date()
        
        // Initial scan
        try runScan(
            roots: roots,
            excludeSet: excludeSet,
            config: config,
            baseline: baseline,
            ignores: ignores,
            excludeGlobs: excludeGlobs
        )
        
        watcher.onChange = {
            // Debounce: only run if 500ms have passed
            let now = Date()
            guard now.timeIntervalSince(lastRun) > 0.5 else { return }
            lastRun = now
            
            fputs("\n🔄 Change detected, re-scanning...\n", stderr)
            try? self.runScan(
                roots: roots,
                excludeSet: excludeSet,
                config: config,
                baseline: baseline,
                ignores: ignores,
                excludeGlobs: excludeGlobs
            )
        }
        
        watcher.start()
        RunLoop.main.run()
    }

    private func output(findings: [Finding], scannedCount: Int, stats: ScanStats? = nil) {
        // Output telemetry if requested
        if telemetry, let stats {
            let telemetryData = ScanTelemetry(
                scanDuration: 0, // Will be tracked in caller
                stats: stats,
                validationsByRule: [:]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(telemetryData),
               let text = String(data: data, encoding: .utf8) {
                fputs("\n--- TELEMETRY ---\n", stderr)
                fputs(text, stderr)
                fputs("\n--- END TELEMETRY ---\n", stderr)
            }
        }
        
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
            if let stats, stats.cacheHits > 0 {
                let hitRate = Int(stats.cacheHitRate * 100)
                print("\(prefix)Cache hits: \(stats.cacheHits)/\(stats.scannedFiles) (\(hitRate)%)")
            }
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

struct Index: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate a Skills.md index from skill roots")

    @Option(name: .customLong("codex"), help: "Codex skills root (default: ~/.codex/skills)")
    var codexPath: String = "~/.codex/skills"

    @Option(name: .customLong("claude"), help: "Claude skills root (default: ~/.claude/skills)")
    var claudePath: String = "~/.claude/skills"

    @Option(name: .customLong("repo"), help: "Repo root; scans <repo>/.codex/skills and <repo>/.claude/skills")
    var repoPath: String?

    @Option(name: .customLong("include"), help: "codex|claude|both (default both)")
    var include: String = "both"

    @Flag(name: .customLong("recursive"), help: "Recursively search for SKILL.md")
    var recursive: Bool = false

    @Option(name: .customLong("max-depth"), help: "Maximum recursion depth")
    var maxDepth: Int?

    @Option(name: .customLong("exclude"), parsing: .upToNextOption, help: "Directory names to exclude")
    var excludes: [String] = []

    @Option(name: .customLong("exclude-glob"), parsing: .upToNextOption, help: "Glob patterns to exclude")
    var excludeGlobs: [String] = []

    @Option(name: .customLong("out"), help: "Output path (default Skills.md)")
    var outPath: String = "Skills.md"

    @Option(name: .customLong("bump"), help: "none|patch|minor|major (default none)")
    var bump: String = "none"

    @Flag(name: .customLong("write"), help: "Write file instead of printing preview")
    var write: Bool = false

    func run() throws {
        let includeMode = IndexInclude(rawValue: include) ?? .all
        let bumpMode = IndexBump(rawValue: bump) ?? .none

        let resolvedRoots = roots(fromRepo: repoPath, codexPath: codexPath, claudePath: claudePath)

        let entries = SkillIndexer.generate(
            codexRoot: resolvedRoots.codex,
            claudeRoot: resolvedRoots.claude,
            include: includeMode,
            recursive: recursive,
            maxDepth: maxDepth,
            excludes: excludes,
            excludeGlobs: excludeGlobs
        )

        let existingVersion = readExistingVersion(outPath: outPath)
        let (version, markdown) = SkillIndexer.renderMarkdown(
            entries: entries,
            existingVersion: existingVersion,
            bump: bumpMode,
            changelogNote: "Index generated with skillsctl"
        )

        if write {
            let url = URL(fileURLWithPath: PathUtil.expandTilde(outPath))
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            print("Wrote \(entries.count) skills to \(url.path) (v\(version))")
        } else {
            print(markdown)
        }
    }

    private func readExistingVersion(outPath: String) -> String? {
        let url = URL(fileURLWithPath: PathUtil.expandTilde(outPath))
        guard FileManager.default.fileExists(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = text.split(whereSeparator: \.isNewline)
        for line in lines {
            if line.hasPrefix("version:") {
                return line.replacingOccurrences(of: "version:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func roots(fromRepo repoPath: String?, codexPath: String, claudePath: String) -> (codex: URL?, claude: URL?) {
        if let repoPath {
            let repoURL = PathUtil.urlFromPath(repoPath)
            return (
                repoURL.appendingPathComponent(".codex/skills", isDirectory: true),
                repoURL.appendingPathComponent(".claude/skills", isDirectory: true)
            )
        }
        return (PathUtil.urlFromPath(codexPath), PathUtil.urlFromPath(claudePath))
    }
}

// Entry point
SkillsCtl.main()

// Helper to run async code from synchronous context
func runBlocking<T: Sendable>(_ operation: @Sendable @escaping () async -> T) -> T {
    let group = DispatchGroup()
    group.enter()
    var result: T?
    Task.detached {
        result = await operation()
        group.leave()
    }
    group.wait()
    return result!
}

// MARK: - Fix Command

struct Fix: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Apply suggested fixes to SKILL.md files interactively")

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

    @Flag(name: .customLong("yes"), help: "Apply all fixes without prompting")
    var applyAll: Bool = false

    @Option(name: .customLong("rule"), help: "Only fix specific rule ID")
    var ruleFilter: String?

    func run() throws {
        let roots: [ScanRoot]

        if let repoPath {
            let repoURL = PathUtil.urlFromPath(repoPath)
            let codexURL = repoURL.appendingPathComponent(".codex/skills", isDirectory: true)
            let claudeURL = repoURL.appendingPathComponent(".claude/skills", isDirectory: true)
            var tempRoots: [ScanRoot] = []
            if !skipCodex { tempRoots.append(.init(agent: .codex, rootURL: codexURL, recursive: false, maxDepth: nil)) }
            if !skipClaude { tempRoots.append(.init(agent: .claude, rootURL: claudeURL, recursive: false, maxDepth: nil)) }
            roots = tempRoots
        } else {
            var tempRoots: [ScanRoot] = []
            if !skipCodex { tempRoots.append(.init(agent: .codex, rootURL: PathUtil.urlFromPath(codexPath), recursive: false, maxDepth: nil)) }
            if !skipClaude { tempRoots.append(.init(agent: .claude, rootURL: PathUtil.urlFromPath(claudePath), recursive: false, maxDepth: nil)) }
            roots = tempRoots
        }

        // Scan for findings
        let result = runBlocking {
            await AsyncSkillsScanner.scanAndValidate(
                roots: roots,
                excludeDirNames: [".git", ".system", "__pycache__", ".DS_Store"],
                excludeGlobs: [],
                policy: nil,
                cacheManager: nil
            )
        }

        var findings = result.findings

        // Filter by rule if specified
        if let ruleFilter {
            findings = findings.filter { $0.ruleID == ruleFilter }
        }

        // Filter to only findings with suggested fixes
        let fixableFindings = findings.filter { $0.suggestedFix != nil }

        if fixableFindings.isEmpty {
            Swift.print("✅ No fixable issues found")
            return
        }

        Swift.print("Found \(fixableFindings.count) fixable issue(s)\n")

        var appliedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for finding in fixableFindings {
            guard let fix = finding.suggestedFix else { continue }

            Swift.print("---")
            Swift.print("📁 File: \(finding.fileURL.path)")
            Swift.print("🔍 Rule: \(finding.ruleID)")
            Swift.print("💬 Issue: \(finding.message)")
            Swift.print("🔧 Fix: \(fix.description)")

            if !applyAll {
                Swift.print("\nApply this fix? [y/N/q] ", terminator: "")
                fflush(stdout)
                
                guard let response = readLine()?.lowercased() else {
                    skippedCount += 1
                    continue
                }

                if response == "q" || response == "quit" {
                    Swift.print("\nAborted by user")
                    break
                }

                if response != "y" && response != "yes" {
                    Swift.print("⏭️  Skipped")
                    skippedCount += 1
                    continue
                }
            }

            let result = FixEngine.applyFix(fix)
            switch result {
            case .success:
                Swift.print("✅ Applied")
                appliedCount += 1
            case .failed(let error):
                Swift.print("❌ Failed: \(error)")
                failedCount += 1
            case .notApplicable:
                Swift.print("⚠️  Not applicable")
                skippedCount += 1
            }
            Swift.print()
        }

        Swift.print("\n--- Summary ---")
        Swift.print("Applied: \(appliedCount)")
        Swift.print("Skipped: \(skippedCount)")
        Swift.print("Failed: \(failedCount)")
    }

    func runBlocking<T: Sendable>(_ operation: @Sendable @escaping () async -> T) -> T {
        let group = DispatchGroup()
        var result: T!
        group.enter()
        Task {
            result = await operation()
            group.leave()
        }
        group.wait()
        return result!
    }
}

struct Completion: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate shell completion script for skillsctl"
    )
    
    @Argument(help: "Shell type: bash, zsh, or fish")
    var shell: String = "zsh"
    
    func run() throws {
        let script: String
        
        switch shell.lowercased() {
        case "bash":
            script = bashCompletion
        case "zsh":
            script = zshCompletion
        case "fish":
            script = fishCompletion
        default:
            throw ValidationError("Unsupported shell: \\(shell). Use bash, zsh, or fish.")
        }
        
        print(script)
    }
    
    private var bashCompletion: String {
        #"""
        # skillsctl bash completion
        _skillsctl_completions() {
            local cur prev
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            
            local commands="scan sync-check index completion"
            local flags="--help --version"
            
            case "$prev" in
                scan)
                    flags="--codex --claude --repo --recursive --max-depth --exclude --exclude-glob --allow-empty --format --schema-version --log-level --plain --config --baseline --ignore --no-cache --jobs --watch --show-cache-stats"
                    ;;
                sync-check)
                    flags="--codex --claude --recursive --max-depth --exclude --exclude-glob --format"
                    ;;
                index)
                    flags="--codex --claude --repo --include --recursive --max-depth --exclude --exclude-glob --out --bump --write"
                    ;;
                --format)
                    COMPREPLY=( $(compgen -W "text json" -- "$cur") )
                    return 0
                    ;;
                --include)
                    COMPREPLY=( $(compgen -W "codex claude both" -- "$cur") )
                    return 0
                    ;;
                --bump)
                    COMPREPLY=( $(compgen -W "none patch minor major" -- "$cur") )
                    return 0
                    ;;
            esac
            
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            fi
        }
        
        complete -F _skillsctl_completions skillsctl
        """#
    }
    
    private var zshCompletion: String {
        #"""
        #compdef skillsctl
        
        _skillsctl() {
            local -a commands
            commands=(
                'scan:Scan roots and validate SKILL.md files'
                'sync-check:Compare Codex vs Claude by skill name + content hash'
                'index:Generate a Skills.md index from skill roots'
                'completion:Generate shell completion script'
            )
            
            local -a scan_flags
            scan_flags=(
                '--codex[Codex skills root]:path:_files -/'
                '--claude[Claude skills root]:path:_files -/'
                '--repo[Repo root]:path:_files -/'
                '--recursive[Recursively walk for SKILL.md]'
                '--max-depth[Maximum directory depth]:depth:'
                '--exclude[Directory names to exclude]:name:'
                '--exclude-glob[Glob patterns to exclude]:pattern:'
                '--allow-empty[Exit 0 even if no SKILL.md files found]'
                '--format[Output format]:format:(text json)'
                '--schema-version[JSON schema version]:version:'
                '--log-level[Log level]:level:(error warn info debug)'
                '--plain[Plain output for accessibility]'
                '--config[Path to config JSON]:path:_files'
                '--baseline[Path to baseline JSON]:path:_files'
                '--ignore[Path to ignore rules JSON]:path:_files'
                '--no-cache[Disable cache for this scan]'
                '--jobs[Maximum parallel validation jobs]:jobs:'
                '--watch[Watch for file changes and re-validate]'
                '--show-cache-stats[Show cache statistics after scan]'
            )
            
            if (( CURRENT == 2 )); then
                _describe 'command' commands
            else
                case "$words[2]" in
                    scan)
                        _arguments -s $scan_flags
                        ;;
                    sync-check)
                        _arguments -s \
                            '--codex[Codex skills root]:path:_files -/' \
                            '--claude[Claude skills root]:path:_files -/' \
                            '--recursive[Recursively walk for SKILL.md]' \
                            '--format[Output format]:format:(text json)'
                        ;;
                    index)
                        _arguments -s \
                            '--codex[Codex skills root]:path:_files -/' \
                            '--claude[Claude skills root]:path:_files -/' \
                            '--repo[Repo root]:path:_files -/' \
                            '--include[Which skills to include]:include:(codex claude both)' \
                            '--out[Output path]:path:_files' \
                            '--bump[Version bump]:bump:(none patch minor major)' \
                            '--write[Write file instead of printing preview]'
                        ;;
                    completion)
                        _arguments '1:shell:(bash zsh fish)'
                        ;;
                esac
            fi
        }
        
        _skillsctl
        """#
    }
    
    private var fishCompletion: String {
        #"""
        # skillsctl fish completion
        
        complete -c skillsctl -f
        
        # Commands
        complete -c skillsctl -n "__fish_use_subcommand" -a scan -d "Scan roots and validate SKILL.md files"
        complete -c skillsctl -n "__fish_use_subcommand" -a sync-check -d "Compare Codex vs Claude"
        complete -c skillsctl -n "__fish_use_subcommand" -a index -d "Generate Skills.md index"
        complete -c skillsctl -n "__fish_use_subcommand" -a completion -d "Generate shell completion script"
        
        # scan command flags
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l codex -d "Codex skills root" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l claude -d "Claude skills root" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l repo -d "Repo root" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l recursive -d "Recursively walk"
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l max-depth -d "Maximum depth" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l exclude -d "Exclude directory" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l exclude-glob -d "Exclude glob" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l allow-empty -d "Allow empty results"
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l format -d "Output format" -xa "text json"
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l no-cache -d "Disable cache"
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l jobs -d "Parallel jobs" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l watch -d "Watch for changes"
        complete -c skillsctl -n "__fish_seen_subcommand_from scan" -l show-cache-stats -d "Show cache stats"
        
        # sync-check command flags
        complete -c skillsctl -n "__fish_seen_subcommand_from sync-check" -l codex -d "Codex skills root" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from sync-check" -l claude -d "Claude skills root" -r
        complete -c skillsctl -n "__fish_seen_subcommand_from sync-check" -l format -d "Output format" -xa "text json"
        
        # index command flags
        complete -c skillsctl -n "__fish_seen_subcommand_from index" -l include -d "Include skills" -xa "codex claude both"
        complete -c skillsctl -n "__fish_seen_subcommand_from index" -l bump -d "Version bump" -xa "none patch minor major"
        complete -c skillsctl -n "__fish_seen_subcommand_from index" -l write -d "Write to file"
        
        # completion command arguments
        complete -c skillsctl -n "__fish_seen_subcommand_from completion" -xa "bash zsh fish"
        """#
    }
}

struct SyncCheck: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compare Codex vs Claude by skill name + content hash.")

    @Option(name: .customLong("codex"), help: "Codex skills root (default: ~/.codex/skills)")
    var codexPath: String = "~/.codex/skills"

    @Option(name: .customLong("claude"), help: "Claude skills root (default: ~/.claude/skills)")
    var claudePath: String = "~/.claude/skills"

    @Option(name: .customLong("copilot"), help: "Copilot skills root (optional, default: ~/.copilot/skills)")
    var copilotPath: String?

    @Option(name: .customLong("csm-path"), help: "CodexSkillManager working tree (optional)")
    var codexSkillManagerPath: String?

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
        var roots: [ScanRoot] = [
            .init(agent: .codex, rootURL: PathUtil.urlFromPath(codexPath), recursive: recursive, maxDepth: maxDepth),
            .init(agent: .claude, rootURL: PathUtil.urlFromPath(claudePath), recursive: recursive, maxDepth: maxDepth)
        ]

        if let copilotPath {
            switch PathValidator.validatedDirectory(from: copilotPath) {
            case .success(let url):
                roots.append(.init(agent: .copilot, rootURL: url, recursive: recursive, maxDepth: maxDepth))
            case .failure(let err):
                fputs("Copilot path invalid: \(err.localizedDescription)\n", stderr)
                throw ExitCode(1)
            }
        }

        if let codexSkillManagerPath {
            switch PathValidator.validatedDirectory(from: codexSkillManagerPath) {
            case .success(let url):
                roots.append(.init(agent: .codexSkillManager, rootURL: url, recursive: recursive, maxDepth: maxDepth))
            case .failure(let err):
                fputs("CodexSkillManager path invalid: \(err.localizedDescription)\n", stderr)
                throw ExitCode(1)
            }
        }

        let report = SyncChecker.multiByName(
            roots: roots,
            recursive: recursive,
            excludeDirNames: Set(excludes).union([".git", ".system", "__pycache__", ".DS_Store"]),
            excludeGlobs: excludeGlobs
        )

        output(report: report)

        let ok = report.missingByAgent.values.allSatisfy { $0.isEmpty } && report.differentContent.isEmpty
        if !ok { throw ExitCode(1) }
    }

    private func output(report: MultiSyncReport) {
        switch format.lowercased() {
        case "json":
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(report),
               let text = String(data: data, encoding: .utf8) {
                print(text)
            }
        default:
            let missing = report.missingByAgent.filter { !$0.value.isEmpty }
            if missing.isEmpty && report.differentContent.isEmpty {
                print("Skill trees are in sync across provided agents.")
                return
            }
            for (agent, names) in missing.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("Missing in \(agent.displayLabel):")
                names.forEach { print("  - \($0)") }
            }
            if !report.differentContent.isEmpty {
                print("Different content (hash mismatch):")
                for diff in report.differentContent {
                    let hashSummary = diff.hashes.map { "\($0.key.displayLabel)=\($0.value.prefix(8))" }.joined(separator: ", ")
                    let modifiedSummary = diff.modified.map { key, date in "\(key.displayLabel)=\(ISO8601DateFormatter().string(from: date))" }
                        .sorted()
                        .joined(separator: ", ")
                    print("  - \(diff.name) [\(hashSummary)]\(modifiedSummary.isEmpty ? "" : " modified: \(modifiedSummary)")")
                }
            }
        }
    }
}
