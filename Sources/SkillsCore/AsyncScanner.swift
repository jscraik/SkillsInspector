import Foundation

// MARK: - Async Scanner with Parallel Validation

public enum AsyncSkillsScanner {
    /// Async version of findSkillFiles with parallel validation support.
    public static func scanAndValidate(
        roots: [ScanRoot],
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = [],
        policy: SkillsConfig.Policy? = nil,
        cacheManager: CacheManager? = nil,
        maxConcurrency: Int = ProcessInfo.processInfo.activeProcessorCount
    ) async -> (findings: [Finding], stats: ScanStats) {
        if Task.isCancelled { return ([], ScanStats()) }
        var allFindings: [Finding] = []
        var stats = ScanStats()
        
        // Scan each root in parallel
        await withTaskGroup(of: (findings: [Finding], stats: ScanStats).self) { group in
            for root in roots {
                group.addTask {
                    if Task.isCancelled { return ([], ScanStats()) }
                    return await scanSingleRoot(
                        root: root,
                        excludeDirNames: excludeDirNames,
                        excludeGlobs: excludeGlobs,
                        policy: policy,
                        cacheManager: cacheManager,
                        maxConcurrency: maxConcurrency
                    )
                }
            }
            
            for await result in group {
                if Task.isCancelled { continue }
                allFindings.append(contentsOf: result.findings)
                stats.merge(with: result.stats)
            }
        }
        
        return (allFindings, stats)
    }
    
    private static func scanSingleRoot(
        root: ScanRoot,
        excludeDirNames: Set<String>,
        excludeGlobs: [String],
        policy: SkillsConfig.Policy?,
        cacheManager: CacheManager?,
        maxConcurrency: Int
    ) async -> (findings: [Finding], stats: ScanStats) {
        if Task.isCancelled { return ([], ScanStats()) }
        let files = SkillsScanner.findSkillFiles(
            roots: [root],
            excludeDirNames: excludeDirNames,
            excludeGlobs: excludeGlobs
        )[root] ?? []
        
        var allFindings: [Finding] = []
        var stats = ScanStats()
        stats.scannedFiles = files.count
        
        // Validate files in parallel with controlled concurrency
        await withTaskGroup(of: (findings: [Finding], cacheHit: Bool).self) { group in
            var activeCount = 0
            var fileIterator = files.makeIterator()
            
            func scheduleNext() {
                guard let file = fileIterator.next(), !Task.isCancelled else { return }
                activeCount += 1
                group.addTask {
                    if Task.isCancelled { return ([], false) }
                    return await validateFile(
                        agent: root.agent,
                        rootURL: root.rootURL,
                        fileURL: file,
                        policy: policy,
                        cacheManager: cacheManager
                    )
                }
            }
            
            // Fill initial batch
            for _ in 0..<min(maxConcurrency, files.count) {
                scheduleNext()
            }
            
            // Process results and schedule remaining
            for await result in group {
                allFindings.append(contentsOf: result.findings)
                if result.cacheHit {
                    stats.cacheHits += 1
                }
                activeCount -= 1
                if activeCount < maxConcurrency && !Task.isCancelled {
                    scheduleNext()
                }
            }
        }
        
        return (allFindings, stats)
    }
    
    private static func validateFile(
        agent: AgentKind,
        rootURL: URL,
        fileURL: URL,
        policy: SkillsConfig.Policy?,
        cacheManager: CacheManager?
    ) async -> (findings: [Finding], cacheHit: Bool) {
        if Task.isCancelled { return ([], false) }
        // Check cache first
        if let cacheManager, let cached = await cacheManager.getCached(for: fileURL) {
            let findings = cached.findings.map { $0.toFinding(fileURL: fileURL) }
            return (findings, true)
        }
        
        // Load and validate
        guard let doc = SkillLoader.load(agent: agent, rootURL: rootURL, skillFileURL: fileURL) else {
            return ([], false)
        }
        
        let findings = SkillValidator.validate(doc: doc, policy: policy)
        
        // Update cache
        if let cacheManager {
            await cacheManager.setCached(for: fileURL, findings: findings)
        }
        
        return (findings, false)
    }
}

// MARK: - Scan Statistics

public struct ScanStats: Sendable {
    public var scannedFiles: Int = 0
    public var cacheHits: Int = 0
    
    public init() {}
    
    public mutating func merge(with other: ScanStats) {
        scannedFiles += other.scannedFiles
        cacheHits += other.cacheHits
    }
    
    public var cacheHitRate: Double {
        guard scannedFiles > 0 else { return 0 }
        return Double(cacheHits) / Double(scannedFiles)
    }
}
