import Foundation
import SkillsCore

@MainActor
final class InspectorViewModel: ObservableObject {
    private var isInitializing = true
    @Published private(set) var isAppReady = false
    @Published var codexRoots: [URL] {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var claudeRoot: URL {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var copilotRoot: URL? {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var codexSkillManagerRoot: URL? {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var recursive = false {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var excludeInput: String = "" {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var excludeGlobInput: String = "" {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var maxDepth: Int? = nil {
        didSet { if !isInitializing { persistSettings() } }
    }
    @Published var watchMode = false {
        didSet {
            if !isInitializing {
                if watchMode {
                    // Enable automatic scans when watch mode is active (user has opted in)
                    allowAutomaticScans = true
                    startWatching()
                } else {
                    // Disable automatic scans when watch mode is disabled
                    allowAutomaticScans = false
                    stopWatching()
                }
            }
        }
    }
    @Published var allowAutomaticScans = false
    @Published var findings: [Finding] = []
    @Published var isScanning = false
    @Published var scanTask: Task<Void, Never>?
    @Published var lastScanAt: Date?
    @Published var lastScanDuration: TimeInterval?
    @Published var scanProgress: Double = 0
    @Published var filesScanned = 0
    @Published var totalFiles = 0
    @Published var cacheHits = 0
    @Published var scanError: String?
    @Published var scanSuccessMessage: String?

    private var currentScanID: UUID = UUID()
    private var fileWatcher: FileWatcher?
    private var lastWatchTrigger: Date = Date()
    private let settingsKey = "com.stools.settings"

    static let defaultExcludes = [".git", ".system", "__pycache__", ".DS_Store"]
    private static let suspiciousPaths = ["/System", "/Library", "/usr", "/bin", "/sbin"]

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(UserSettings.self, from: data) {
            codexRoots = saved.codexRoots.isEmpty ? Self.defaultCodexRoots(home: home) : saved.codexRoots
            claudeRoot = saved.claudeRoot
            codexSkillManagerRoot = saved.codexSkillManagerRoot
            copilotRoot = saved.copilotRoot
            recursive = saved.recursive
            excludeInput = saved.excludeInput
            excludeGlobInput = saved.excludeGlobInput
            maxDepth = saved.maxDepth
        } else {
            codexRoots = Self.defaultCodexRoots(home: home)
            claudeRoot = home.appendingPathComponent(".claude/skills", isDirectory: true)
            codexSkillManagerRoot = Self.defaultCodexSkillManagerRoot(home: home)
            copilotRoot = Self.defaultCopilotRoot(home: home)
        }
        isInitializing = false
    }

    /// Marks the app as ready to accept scans. Called after UI appears to prevent launch blocking.
    func markAppReady() {
        isAppReady = true
    }

    /// Backwards-compatible single-root accessor for tests and legacy call sites.
    var codexRoot: URL {
        get { codexRoots.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills", isDirectory: true) }
        set {
            codexRoots = [newValue]
        }
    }

    var effectiveExcludes: [String] {
        let user = excludeInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Array(Set(Self.defaultExcludes).union(user))
    }

    var effectiveGlobExcludes: [String] {
        excludeGlobInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func scan(userInitiated: Bool = false) async {
        // Scan gate: prevent automatic scans during launch
        // Only proceed if:
        // 1. User explicitly triggered the scan (button click, keyboard shortcut, etc.)
        // 2. OR app is fully ready (UI has appeared) AND automatic scans are allowed (watch mode is enabled)
        guard userInitiated || (isAppReady && allowAutomaticScans) else {
            return
        }

        // Cancel any ongoing scan
        scanTask?.cancel()
        scanTask = nil

        // Check if we have any valid roots to scan
        let hasValidRoots = !codexRoots.isEmpty || validateRoot(claudeRoot)
        guard hasValidRoots else {
            // No valid roots configured - don't scan
            await MainActor.run {
                self.isScanning = false
                self.findings = []
                self.filesScanned = 0
                self.totalFiles = 0
                self.scanError = "No valid scan roots configured. Please check your root directories in the sidebar."
            }
            return
        }

        // Generate unique scan ID to track this specific scan
        let scanID = UUID()
        currentScanID = scanID

        // Reset scan state
        isScanning = true
        scanProgress = 0
        filesScanned = 0
        totalFiles = 0
        cacheHits = 0
        scanError = nil  // Clear any previous error
        let started = Date()

        let codexRootsCopy = codexRoots
        let claude = claudeRoot
        let csm = codexSkillManagerRoot
        let copilot = copilotRoot
        let recursiveFlag = recursive
        let validCSM = csm.map(validateRoot) ?? false
        let validCopilot = copilot.map(validateRoot) ?? false
        let cacheURL = Self.findRepoRoot(from: codexRootsCopy.first ?? claude) ?? Self.findRepoRoot(from: claude)
        let useSharedRoot = UserDefaults.standard.bool(forKey: "useSharedSkillsRoot")

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            guard Task.isCancelled == false else { return }

            // Build roots from all Codex directories plus Claude
            var roots: [ScanRoot]
            if useSharedRoot {
                // Single source of truth mode: use only first Codex root
                let masterRoot = codexRootsCopy.first ?? claude
                roots = [ScanRoot(agent: .codex, rootURL: masterRoot, recursive: recursiveFlag)]
            } else {
                // Multi-root mode: scan all configured roots
                roots = codexRootsCopy.map { url in
                    ScanRoot(agent: .codex, rootURL: url, recursive: recursiveFlag)
                }
                roots.append(ScanRoot(agent: .claude, rootURL: claude, recursive: recursiveFlag))
                if let csm, validCSM {
                    roots.append(ScanRoot(agent: .codexSkillManager, rootURL: csm, recursive: recursiveFlag))
                }
                if let copilot, validCopilot {
                    roots.append(ScanRoot(agent: .copilot, rootURL: copilot, recursive: recursiveFlag))
                }
            }
            
            // Set up cache
            let cacheManager: CacheManager?
            if let cacheRoot = cacheURL {
                let cachePath = cacheRoot.appendingPathComponent(".skillsctl/cache.json")
                cacheManager = CacheManager(cacheURL: cachePath, configHash: nil)
            } else {
                cacheManager = nil
            }

            // Use async scanner
            let (findings, stats) = await AsyncSkillsScanner.scanAndValidate(
                roots: roots,
                excludeDirNames: Set(Self.defaultExcludes),
                excludeGlobs: [],
                policy: nil,
                cacheManager: cacheManager,
                maxConcurrency: ProcessInfo.processInfo.activeProcessorCount
            )
            
            // Generate suggested fixes for findings
            let findingsWithFixes = await withTaskGroup(of: Finding.self) { group in
                for finding in findings {
                    group.addTask {
                        var updatedFinding = finding
                        // Try to load file content and generate fix
                        if let content = try? String(contentsOf: finding.fileURL, encoding: .utf8) {
                            updatedFinding.suggestedFix = FixEngine.suggestFix(for: finding, content: content)
                        }
                        return updatedFinding
                    }
                }
                
                var result: [Finding] = []
                for await finding in group {
                    result.append(finding)
                }
                return result
            }
            
            // Save cache
            if let cacheManager {
                await cacheManager.save()
            }

            guard Task.isCancelled == false else { return }

            await MainActor.run {
                guard self.currentScanID == scanID else { return }
                self.findings = findingsWithFixes.sorted(by: { lhs, rhs in
                    if lhs.severity != rhs.severity { return lhs.severity.rawValue < rhs.severity.rawValue }
                    if lhs.agent != rhs.agent { return lhs.agent.rawValue < rhs.agent.rawValue }
                    return lhs.fileURL.path < rhs.fileURL.path
                })
                self.cacheHits = stats.cacheHits
                self.filesScanned = stats.scannedFiles
                self.totalFiles = stats.scannedFiles
                self.isScanning = false
                self.scanTask = nil
                self.lastScanAt = Date()
                self.lastScanDuration = Date().timeIntervalSince(started)
                self.scanProgress = 1.0
                self.scanError = nil

                // Show success message if no findings
                if findingsWithFixes.isEmpty {
                    self.scanSuccessMessage = "All skills are valid! Scanned \(stats.scannedFiles) files."
                } else {
                    self.scanSuccessMessage = nil
                }
            }
        }

        // Ensure callers awaiting scan() get deterministic completion for tests/UI updates.
        await scanTask?.value
    }
    
    private static func findRepoRoot(from url: URL) -> URL? {
        var current = url
        while current.path != "/" {
            let gitPath = current.appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: gitPath) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
    
    private func startWatching() {
        stopWatching()
        
        var roots = codexRoots
        roots.append(claudeRoot)
        if let csm = codexSkillManagerRoot { roots.append(csm) }
        if let copilotRoot { roots.append(copilotRoot) }
        fileWatcher = FileWatcher(roots: roots)
        fileWatcher?.onChange = { [weak self] in
            guard let self else { return }
            
            // Debounce: only trigger if 500ms have passed
            let now = Date()
            guard now.timeIntervalSince(self.lastWatchTrigger) > 0.5 else { return }
            self.lastWatchTrigger = now
            
            Task { @MainActor in
                // File watcher scans are automatic, so they require both app ready AND watch mode enabled
                guard self.isAppReady && self.allowAutomaticScans else { return }
                await self.scan()
            }
        }
        fileWatcher?.start()
    }
    
    private func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    func clearCache() async {
        // Find cache location
        let cacheURL = Self.findRepoRoot(from: codexRoots.first ?? claudeRoot) ?? Self.findRepoRoot(from: claudeRoot)
        if let cacheRoot = cacheURL {
            let cachePath = cacheRoot.appendingPathComponent(".skillsctl/cache.json")
            try? FileManager.default.removeItem(at: cachePath)
        }
        cacheHits = 0
    }

    func validateRoot(_ url: URL) -> Bool {
        guard PathUtil.existsDir(url) else { return false }
        let path = url.path
        if url.pathComponents.contains("..") { return false }
        for suspicious in Self.suspiciousPaths {
            if path.hasPrefix(suspicious) { return false }
        }
        return true
    }

    private func persistSettings() {
        let settings = UserSettings(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: codexSkillManagerRoot,
            copilotRoot: copilotRoot,
            recursive: recursive,
            excludeInput: excludeInput,
            excludeGlobInput: excludeGlobInput,
            maxDepth: maxDepth
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private static func defaultCodexRoots(home: URL) -> [URL] {
        let potentialRoots: [URL] = [
            home.appendingPathComponent(".codex/skills", isDirectory: true),
            home.appendingPathComponent(".codex/public/skills", isDirectory: true)
        ]
        var seenPaths = Set<String>()
        var resolvedRoots: [URL] = []
        for url in potentialRoots {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let resolved = (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path))
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? url
            let canonicalPath = resolved.standardized.path
            if !seenPaths.contains(canonicalPath) {
                seenPaths.insert(canonicalPath)
                resolvedRoots.append(resolved)
            }
        }
        let primaryCodex = home.appendingPathComponent(".codex/skills", isDirectory: true)
        let publicCodex = home.appendingPathComponent(".codex/public/skills", isDirectory: true)

        // Prefer both roots when they exist; otherwise fall back to any detected or primary default.
        var result: [URL] = []
        if FileManager.default.fileExists(atPath: primaryCodex.path) {
            result.append(primaryCodex)
        }
        if FileManager.default.fileExists(atPath: publicCodex.path) {
            if !result.contains(where: { $0.standardizedFileURL == publicCodex.standardizedFileURL }) {
                result.append(publicCodex)
            }
        }
        if result.isEmpty { result = resolvedRoots }
        if result.isEmpty { result = [primaryCodex] }
        return result
    }

    private static func defaultCodexSkillManagerRoot(home: URL) -> URL? {
        let candidates = [
            home.appendingPathComponent("dev/CodexSkillManager", isDirectory: true),
            home.appendingPathComponent("Code/CodexSkillManager", isDirectory: true),
            home.appendingPathComponent("CodexSkillManager", isDirectory: true)
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func defaultCopilotRoot(home: URL) -> URL? {
        let candidate = home.appendingPathComponent(".copilot/skills", isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

// Private helper for scan results with scan ID tracking
private struct ScanResult: Sendable {
    let findings: [Finding]
    let scanID: UUID
}

private struct UserSettings: Codable {
    let codexRoots: [URL]
    let claudeRoot: URL
    let codexSkillManagerRoot: URL?
    let copilotRoot: URL?
    let recursive: Bool
    let excludeInput: String
    let excludeGlobInput: String
    let maxDepth: Int?
}
