import Foundation
import ArgumentParser
import SkillsCore

struct SkillsCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skillsctl",
        abstract: "Scan/validate/sync Codex + Claude SKILL.md directories.",
        subcommands: [Scan.self, SyncCheck.self, Index.self, Completion.self]
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

    @Flag(name: .customLong("no-cache"), help: "Disable cache for this scan")
    var noCache: Bool = false

    @Option(name: .customLong("jobs"), help: "Maximum parallel validation jobs (default: CPU count)")
    var jobs: Int?

    @Flag(name: .customLong("watch"), help: "Watch for file changes and re-validate automatically")
    var watch: Bool = false

    @Flag(name: .customLong("show-cache-stats"), help: "Show cache statistics after scan")
    var showCacheStats: Bool = false

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
        let includeMode = IndexInclude(rawValue: include) ?? .both
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
