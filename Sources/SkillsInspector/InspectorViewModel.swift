import Foundation
import SkillsCore

@MainActor
final class InspectorViewModel: ObservableObject {
    @Published var codexRoot: URL
    @Published var claudeRoot: URL
    @Published var recursive = false
    @Published var findings: [Finding] = []
    @Published var isScanning = false
    @Published var scanTask: Task<Void, Never>?
    @Published var lastScanAt: Date?
    @Published var lastScanDuration: TimeInterval?
    @Published var scanProgress: Double = 0
    @Published var filesScanned = 0
    @Published var totalFiles = 0

    private var currentScanID: UUID = UUID()

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        codexRoot = home.appendingPathComponent(".codex/skills", isDirectory: true)
        claudeRoot = home.appendingPathComponent(".claude/skills", isDirectory: true)
    }

    func scan() async {
        // Cancel any ongoing scan
        scanTask?.cancel()
        scanTask = nil

        // Generate unique scan ID to track this specific scan
        let scanID = UUID()
        currentScanID = scanID

        // Reset scan state
        isScanning = true
        scanProgress = 0
        filesScanned = 0
        totalFiles = 0
        let started = Date()

        let codex = codexRoot
        let claude = claudeRoot
        let recursiveFlag = recursive

        scanTask = Task { [weak self] in
            guard Task.isCancelled == false else { return }

            let operation: @Sendable () -> ScanResult = {
                let roots = [
                    ScanRoot(agent: .codex, rootURL: codex, recursive: recursiveFlag),
                    ScanRoot(agent: .claude, rootURL: claude, recursive: recursiveFlag)
                ]

                let files = SkillsScanner.findSkillFiles(roots: roots)
                var collected: [Finding] = []
                var scannedCount = 0
                let total = files.values.reduce(0) { $0 + $1.count }

                let reportProgress: @Sendable (Int) -> Void = { current in
                    Task { @MainActor in
                        guard let self = self, self.currentScanID == scanID else { return }
                        self.filesScanned = current
                        self.totalFiles = total
                        self.scanProgress = total > 0 ? Double(current) / Double(total) : 0
                    }
                }

                for root in roots {
                    for file in files[root] ?? [] {
                        if Task.isCancelled {
                            return ScanResult(findings: collected, scanID: scanID)
                        }

                        scannedCount += 1
                        reportProgress(scannedCount)

                        if let doc = SkillLoader.load(agent: root.agent, rootURL: root.rootURL, skillFileURL: file) {
                            collected.append(contentsOf: SkillValidator.validate(doc: doc))
                        } else {
                            collected.append(Finding(
                                ruleID: "skill.unreadable",
                                severity: .error,
                                agent: root.agent,
                                fileURL: file,
                                message: "Unreadable SKILL.md"
                            ))
                        }
                    }
                }

                return ScanResult(
                    findings: collected.sorted(by: { lhs, rhs in
                        if lhs.severity != rhs.severity { return lhs.severity.rawValue < rhs.severity.rawValue }
                        if lhs.agent != rhs.agent { return lhs.agent.rawValue < rhs.agent.rawValue }
                        return lhs.fileURL.path < rhs.fileURL.path
                    }),
                    scanID: scanID
                )
            }

            let results = await Task.detached(priority: .userInitiated, operation: operation).value

            guard let self = self, currentScanID == scanID else { return }
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                self.findings = results.findings
                self.isScanning = false
                self.scanTask = nil
                self.lastScanAt = Date()
                self.lastScanDuration = Date().timeIntervalSince(started)
                self.scanProgress = 1.0
            }
        }

        // Do not await scanTask here to keep main actor responsive; results arrive via MainActor.run above.
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
}

// Private helper for scan results with scan ID tracking
private struct ScanResult: Sendable {
    let findings: [Finding]
    let scanID: UUID
}
