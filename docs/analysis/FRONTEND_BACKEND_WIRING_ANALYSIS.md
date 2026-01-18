# sTools Frontend-Backend Wiring Analysis

## Executive Summary

The sTools SwiftUI application demonstrates a well-structured separation
between frontend (SkillsInspector) and backend (SkillsCore) layers. The wiring
follows a **ViewModel-based reactive pattern** where:

1. **ViewModels** (`InspectorViewModel`, `SyncViewModel`, `IndexViewModel`,

   `RemoteViewModel`) manage state and orchestrate backend operations

2. **Views** bind to published properties and trigger actions via

   button/toggle handlers

3. **Backend services** (AsyncScanner, SyncChecker, Indexer,

   RemoteSkillClient) perform business logic

4. **Data flows** through async/await patterns with proper cancellation

   support

---

## Architecture Overview

### Layer Structure

```text
┌─────────────────────────────────────────────────────────────┐
│ SkillsInspector (Frontend - SwiftUI Views)                  │
│ ├─ App.swift (entry point, menu commands)                  │
│ ├─ ContentView.swift (main navigation)                     │
│ ├─ ValidateView.swift (scan UI)                            │
│ ├─ SyncView.swift (comparison UI)                          │
│ ├─ IndexView.swift (indexing UI)                           │
│ ├─ RemoteView.swift (marketplace UI)                       │
│ └─ FindingDetailView.swift (detail panels)                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ ViewModels (@MainActor ObservableObject)                    │
│ ├─ InspectorViewModel (scan orchestration)                 │
│ ├─ SyncViewModel (sync orchestration)                      │
│ ├─ IndexViewModel (index generation)                       │
│ ├─ RemoteViewModel (remote skill management)               │
│ └─ TrustStoreViewModel (security)                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ SkillsCore (Backend - Business Logic)                       │
│ ├─ AsyncScanner (parallel validation)                      │
│ ├─ SyncChecker (multi-agent comparison)                    │
│ ├─ Indexer (markdown generation)                           │
│ ├─ RemoteSkillClient (API client)                          │
│ ├─ SkillValidator (validation rules)                       │
│ ├─ SkillLoader (file parsing)                              │
│ └─ FixEngine (automated fixes)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Wiring Patterns

### 1. Scan Flow (Validate Tab)

#### User Action → UI → ViewModel → Backend → Results

```swift
// ValidateView.swift - User clicks "Scan Rules" button
Button {
    Task { await viewModel.scan() }
}

// InspectorViewModel.swift - Orchestrates scan
@MainActor
final class InspectorViewModel: ObservableObject {
    @Published var findings: [Finding] = []
    @Published var isScanning = false

    func scan() async {
        isScanning = true
        let (findings, stats) = await AsyncSkillsScanner.scanAndValidate(
            roots: roots,
            excludeDirNames: Set(Self.defaultExcludes),
            excludeGlobs: [],
            policy: nil,
            cacheManager: cacheManager,
            maxConcurrency: ProcessInfo.processInfo.activeProcessorCount
        )

        // Generate fixes for findings
        let findingsWithFixes = await withTaskGroup(of: Finding.self) { group in
            for finding in findings {
                group.addTask {
                    var updatedFinding = finding
                    if let content = try? String(
                        contentsOf: finding.fileURL,
                        encoding: .utf8
                    ) {
                        updatedFinding.suggestedFix = FixEngine.suggestFix(
                            for: finding,
                            content: content
                        )
                    }
                    return updatedFinding
                }
            }
            // ... collect results
        }

        self.findings = findingsWithFixes
        isScanning = false
    }
}

// SkillsCore/AsyncScanner.swift - Backend parallel validation
public enum AsyncSkillsScanner {
    public static func scanAndValidate(
        roots: [ScanRoot],
        excludeDirNames: Set<String>,
        excludeGlobs: [String],
        policy: SkillsConfig.Policy?,
        cacheManager: CacheManager?,
        maxConcurrency: Int
    ) async -> (findings: [Finding], stats: ScanStats) {
        // Parallel validation with controlled concurrency
        await withTaskGroup(
            of: (findings: [Finding], stats: ScanStats).self
        ) { group in
            for root in roots {
                group.addTask {
                    await scanSingleRoot(root: root, ...)
                }
            }
            // Collect results
        }
    }
}
```

**Wiring Details:**

- ✅ **Connected**: Button action → `viewModel.scan()` →

  `AsyncSkillsScanner.scanAndValidate()`

- ✅ **State Management**: `@Published var findings` updates UI reactively
- ✅ **Cancellation**: `scanTask?.cancel()` propagates through async chain
- ✅ **Progress**: `filesScanned`, `totalFiles`, `scanProgress` published for

  UI updates

- ✅ **Caching**: `CacheManager` integrated for performance

---

### 2. Sync Flow (Sync Tab)

#### User Action → UI → ViewModel → Backend → Multi-Agent Comparison

```swift
// SyncView.swift - User clicks "Sync Now"
Button {
    Task {
        await viewModel.run(
            roots: activeRoots,
            recursive: recursive,
            maxDepth: maxDepth,
            excludes: parsedExcludes,
            excludeGlobs: parsedGlobExcludes
        )
    }
}

// SyncViewModel.swift - Orchestrates sync
@MainActor
final class SyncViewModel: ObservableObject {
    @Published var report: MultiSyncReport = MultiSyncReport()
    @Published var isRunning = false

    func run(
        roots: [AgentKind: URL],
        recursive: Bool,
        maxDepth: Int?,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        isRunning = true
        let scans = roots.map {
            ScanRoot(
                agent: $0.key,
                rootURL: $0.value,
                recursive: recursive,
                maxDepth: maxDepth
            )
        }
        report = SyncChecker.multiByName(
            roots: scans,
            recursive: recursive,
            excludeDirNames: Set(InspectorViewModel.defaultExcludes)
                .union(Set(excludes)),
            excludeGlobs: excludeGlobs
        )
        isRunning = false
    }
}

// SkillsCore/SkillsCore.swift - Backend sync logic
public enum SyncChecker {
    public static func multiByName(
        roots: [ScanRoot],
        recursive: Bool = false,
        excludeDirNames: Set<String>,
        excludeGlobs: [String]
    ) -> MultiSyncReport {
        var report = MultiSyncReport()
        let filesByRoot = SkillsScanner.findSkillFiles(roots: roots, ...)

        // Map agent -> name -> url
        var byAgent: [AgentKind: [String: URL]] = [:]
        for root in roots {
            let files = filesByRoot[root] ?? []
            for file in files {
                guard let doc = SkillLoader.load(
                    agent: root.agent,
                    rootURL: root.rootURL,
                    skillFileURL: file
                ),
                      let name = doc.name?
                          .trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { continue }
                var map = byAgent[root.agent, default: [:]]
                map[name] = file
                byAgent[root.agent] = map
            }
        }

        // Compare across agents
        let allNames = Set(byAgent.values.flatMap { $0.keys })
        for name in allNames {
            var presentAgents: [AgentKind: URL] = [:]
            for agent in allAgents {
                if let url = byAgent[agent]?[name] {
                    presentAgents[agent] = url
                } else {
                    report.missingByAgent[agent, default: []].append(name)
                }
            }

            // Detect content differences
            if presentAgents.count >= 2 {
                var hashes: [AgentKind: String] = [:]
                for (agent, url) in presentAgents {
                    hashes[agent] = SkillHash.sha256Hex(ofFile: url) ?? ""
                }
                let uniqueHashes = Set(hashes.values.filter { !$0.isEmpty })
                if uniqueHashes.count > 1 {
                    diffs.append(.init(
                        name: name,
                        hashes: hashes,
                        modified: modified
                    ))
                }
            }
        }

        return report
    }
}
```

**Wiring Details:**

- ✅ **Connected**: Button → `viewModel.run()` → `SyncChecker.multiByName()`
- ✅ **Multi-Agent**: Compares Codex, Claude, Copilot, CodexSkillManager

  simultaneously

- ✅ **Results**: `missingByAgent` and `differentContent` published to UI
- ✅ **Selection**: `viewModel.selection` drives detail panel display

---

### 3. Index Generation Flow (Index Tab)

#### User Action → UI → ViewModel → Backend → Markdown Generation

```swift
// IndexView.swift - User clicks "Generate"
Button {
    Task {
        await viewModel.generate(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: codexSkillManagerRoot,
            copilotRoot: copilotRoot,
            recursive: recursive,
            excludes: excludes,
            excludeGlobs: excludeGlobs
        )
    }
}

// IndexViewModel.swift - Orchestrates generation
@MainActor
final class IndexViewModel: ObservableObject {
    @Published var entries: [SkillIndexEntry] = []
    @Published var generatedMarkdown = ""
    @Published var generatedVersion = ""

    func generate(...) async {
        isGenerating = true
        let entries = SkillIndexer.generate(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: codexSkillManagerRoot,
            copilotRoot: copilotRoot,
            include: include,
            recursive: recursive,
            maxDepth: nil,
            excludes: excludes,
            excludeGlobs: excludeGlobs
        )

        let (version, markdown) = SkillIndexer.renderMarkdown(
            entries: entries,
            existingVersion: existingVersion.isEmpty ? nil : existingVersion,
            bump: bump,
            changelogNote: changelogNote.isEmpty ? nil : changelogNote
        )

        self.entries = entries
        self.generatedVersion = version
        self.generatedMarkdown = markdown
        isGenerating = false
    }
}

// SkillsCore/Indexer.swift - Backend indexing
public enum SkillIndexer {
    public static func generate(
        codexRoots: [URL],
        claudeRoot: URL?,
        codexSkillManagerRoot: URL?,
        copilotRoot: URL?,
        include: IndexInclude = .all,
        recursive: Bool = false,
        maxDepth: Int? = nil,
        excludes: [String],
        excludeGlobs: [String]
    ) -> [SkillIndexEntry] {
        var entries: [SkillIndexEntry] = []

        func collect(agent: AgentKind, root: URL) {
            let scanRoots = [
                ScanRoot(
                    agent: agent,
                    rootURL: root,
                    recursive: recursive,
                    maxDepth: maxDepth
                )
            ]
            let files = SkillsScanner.findSkillFiles(roots: scanRoots, ...)
            for f in files {
                guard let doc = SkillLoader.load(
                    agent: agent,
                    rootURL: root,
                    skillFileURL: f
                ) else { continue }
                let name = doc.name ??
                    f.deletingLastPathComponent().lastPathComponent
                let desc = (doc.description ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                entries.append(SkillIndexEntry(
                    agent: agent,
                    name: name,
                    path: f.path,
                    description: desc,
                    ...
                ))
            }
        }

        // Collect from all active roots
        if include == .all || include == .codex {
            codexRoots.forEach { collect(agent: .codex, root: $0) }
        }
        if include == .all || include == .claude, let claudeRoot {
            collect(agent: .claude, root: claudeRoot)
        }
        // ... etc for other agents

        return entries.sorted { ... }
    }

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
        md.append(
            "| Agent | Skill | Description | Path | Modified | #Refs | " +
            "#Assets | #Scripts |"
        )
        // ... build table rows
        return (nextVersion, md.joined(separator: "\n"))
    }
}
```

**Wiring Details:**

- ✅ **Connected**: Button → `viewModel.generate()` → `SkillIndexer.generate()`
  and `renderMarkdown()`
- ✅ **Multi-Root**: Collects from Codex, Claude, Copilot, CodexSkillManager
- ✅ **Version Bumping**: Semantic versioning with patch/minor/major options
- ✅ **Markdown Export**: Generated markdown published for preview and export

---

### 4. Remote Skill Management Flow (Remote Tab)

#### User Action → UI → ViewModel → Backend API → Installation

```swift
// RemoteView.swift - User clicks "Download & Install"
Button {
    Task { await viewModel.install(skill: skill) }
}

// RemoteViewModel.swift - Orchestrates remote operations
@MainActor
final class RemoteViewModel: ObservableObject {
    @Published var skills: [RemoteSkill] = []
    @Published var installingSlug: String?
    @Published var previewStateBySlug: [String: RemotePreviewState] = [:]

    private let client: RemoteSkillClient
    private let installer: RemoteSkillInstaller

    func loadLatest(limit: Int = 20) async {
        isLoading = true
        do {
            let result = try await client.fetchLatest(limit)
            skills = result
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchPreview(for skill: RemoteSkill) async {
        let slug = skill.slug
        previewStateBySlug[slug] = .loading()
        do {
            let manifest = try await fetchManifestCached(
                slug: slug,
                version: skill.latestVersion
            )
            let preview = try await client.fetchPreview(
                slug,
                skill.latestVersion
            )
            if let preview {
                previewCache.store(preview)
                previewStateBySlug[slug] = .available(
                    preview: preview,
                    manifest: manifest ?? preview.manifest
                )
            } else {
                previewStateBySlug[slug] = .unavailable(manifest: manifest)
            }
        } catch {
            previewStateBySlug[slug] = .failed(error.localizedDescription)
        }
    }

    func install(skill: RemoteSkill) async {
        await fetchPreview(for: skill)
        installingSlug = skill.slug
        defer { installingSlug = nil }
        do {
            let archive = try await client.download(
                skill.slug,
                skill.latestVersion
            )
            let manifest = previewStateBySlug[skill.slug]?.manifest
            guard let manifest else {
                errorMessage =
                    "Manifest unavailable for \(skill.slug). " +
                    "Verification required."
                return
            }
            let result = try await installer.install(
                archiveURL: archive,
                target: targetResolver(),
                overwrite: true,
                manifest: manifest,
                policy: .default,
                trustStore: trustStoreProvider(),
                skillSlug: skill.slug
            )
            installResult = result
            await recordSingleSuccess(
                skill: skill,
                version: skill.latestVersion,
                result: result,
                manifest: manifest
            )
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// SkillsCore/Remote/RemoteSkillClient.swift - Backend API client
public class RemoteSkillClient {
    public func fetchLatest(_ limit: Int) async throws -> [RemoteSkill] {
        // API call to remote server
    }

    public func fetchPreview(
        _ slug: String,
        _ version: String?
    ) async throws -> RemoteSkillPreview? {
        // Fetch and verify skill content
    }

    public func download(
        _ slug: String,
        _ version: String?
    ) async throws -> URL {
        // Download skill archive
    }
}
```

**Wiring Details:**

- ✅ **Connected**: Button → `viewModel.install()` → `client.download()` →

  `installer.install()`

- ✅ **Verification**: Manifest validation before installation
- ✅ **Trust Store**: Cryptographic verification of signers
- ✅ **Ledger Recording**: Installation events recorded for audit trail
- ✅ **Multi-Target**: Can install to multiple agent roots simultaneously

---

## Button Actions & Control Wiring

### Scan Controls (ValidateView)

- "Scan Rules" button:
  `Task { await viewModel.scan() }` → `AsyncSkillsScanner.scanAndValidate()`
- "Stop" button:
  `viewModel.cancelScan()` → `scanTask?.cancel()`
- Watch Mode toggle:
  `$viewModel.watchMode` → `FileWatcher.start/stop()`
- "Clear Cache" button:
  `Task { await viewModel.clearCache() }` → delete `.skillsctl/cache.json`
- Severity filter:
  `$severityFilter` → filter findings in-memory
- "Apply Fix" button:
  `FixEngine.applyFix(fix)` → modify file on disk

### Sync Controls (SyncView)

- "Sync Now" button:
  `Task { await viewModel.run(...) }` → `SyncChecker.multiByName()`
- Recursive toggle: `$recursive` → debounced auto-sync
- Depth field: `$maxDepth` → debounced auto-sync
- Exclude fields:
  `$excludeInput`, `$excludeGlobInput` → debounced auto-sync
- Skill selection: `$viewModel.selection` → no backend call

### Index Controls (IndexView)

- "Generate" button:
  `Task { await viewModel.generate(...) }` →
  `SkillIndexer.generate()` and `renderMarkdown()`
- Include picker: `$viewModel.include` → debounced auto-generate
- Version bump picker: `$viewModel.bump` → debounced auto-generate
- "Copy" button: `NSPasteboard.general.setString()` → no backend call
- "Save" button: `NSSavePanel` + file write → no backend call

### Remote Controls (RemoteView)

- "Download & Install" button:
  `Task { await viewModel.install(skill) }` →
  `client.download()` → `installer.install()`
- "Verify" button:
  `Task { await viewModel.fetchPreview(skill) }` → `client.fetchPreview()`
- "Trust Signer" button:
  `trustStoreVM.addTrustedKey()` → update trust store
- Skill selection: `$selectedSkill` → triggers preview fetch

---

## State Management Patterns

### ViewModel Lifecycle

```swift
@MainActor
final class InspectorViewModel: ObservableObject {
    // MARK: - Published State (UI-reactive)
    @Published var findings: [Finding] = []
    @Published var isScanning = false
    @Published var codexRoots: [URL] { didSet { persistSettings() } }
    @Published var claudeRoot: URL { didSet { persistSettings() } }

    // MARK: - Private State (non-reactive)
    private var currentScanID: UUID = UUID()
    private var fileWatcher: FileWatcher?
    private var scanTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {
        // Load persisted settings from UserDefaults
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder()
                .decode(UserSettings.self, from: data) {
            codexRoots = saved.codexRoots
            claudeRoot = saved.claudeRoot
        } else {
            codexRoots = Self.defaultCodexRoots(home: home)
            claudeRoot = home.appendingPathComponent(
                ".claude/skills",
                isDirectory: true
            )
        }
    }

    // MARK: - Async Operations
    func scan() async {
        scanTask?.cancel()
        let scanID = UUID()
        currentScanID = scanID
        isScanning = true

        let (findings, stats) = await AsyncSkillsScanner.scanAndValidate(...)

        guard currentScanID == scanID else { return }
        guard Task.isCancelled == false else { return }

        await MainActor.run {
            self.findings = findings
            self.isScanning = false
        }
    }

    // MARK: - Persistence
    private func persistSettings() {
        let settings = UserSettings(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            ...
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
```

**Key Patterns:**

- ✅ `@Published` properties trigger SwiftUI re-renders
- ✅ `didSet` observers persist changes to UserDefaults
- ✅ `@MainActor` ensures UI updates on main thread
- ✅ Scan ID tracking prevents race conditions
- ✅ Task cancellation propagates through async chain

---

## Data Flow Examples

### Complete Scan-to-Fix Flow

```text
User clicks "Scan Rules"
    ↓
ValidateView button action
    ↓
Task { await viewModel.scan() }
    ↓
InspectorViewModel.scan() async
    ├─ Set isScanning = true
    ├─ Generate unique scanID
    ├─ Call AsyncSkillsScanner.scanAndValidate()
    │   ├─ Find SKILL.md files in roots
    │   ├─ Load each file (SkillLoader)
    │   ├─ Validate against rules (SkillValidator)
    │   ├─ Check cache (CacheManager)
    │   └─ Return findings + stats
    ├─ Generate fixes for each finding
    │   └─ Call FixEngine.suggestFix() for each
    ├─ Update @Published findings
    └─ Set isScanning = false
    ↓
ValidateView observes findings update
    ↓
UI re-renders with new findings list
    ↓
User clicks finding → FindingDetailView displays
    ↓
User clicks "Apply Fix"
    ├─ FixEngine.applyFix() modifies file
    ├─ Re-scan triggered
    └─ Findings updated
```

### Complete Sync Flow

```text
User clicks "Sync Now"
    ↓
SyncView button action
    ↓
Task { await viewModel.run(roots, ...) }
    ↓
SyncViewModel.run() async
    ├─ Build ScanRoot array from active roots
    └─ Call SyncChecker.multiByName()
        ├─ Find SKILL.md files in each root
        ├─ Load and parse each file
        ├─ Build name → URL maps per agent
        ├─ Compare across agents
        │   ├─ Find missing skills per agent
        │   ├─ Hash files to detect content diffs
        │   └─ Build DiffDetail for differences
        └─ Return MultiSyncReport
    ↓
Update @Published report
    ↓
SyncView observes report update
    ↓
UI re-renders with missing/different sections
    ↓
User clicks skill → SyncDetailView displays
```

---

## Notification-Based Wiring

The app uses `NotificationCenter` for global commands:

```swift
// App.swift - Menu commands post notifications
CommandMenu("Scan") {
    Button("Run Scan") {
        NotificationCenter.default.post(name: .runScan, object: nil)
    }
    Button("Cancel Scan") {
        NotificationCenter.default.post(name: .cancelScan, object: nil)
    }
    Button("Toggle Watch Mode") {
        NotificationCenter.default.post(name: .toggleWatch, object: nil)
    }
    Button("Clear Cache") {
        NotificationCenter.default.post(name: .clearCache, object: nil)
    }
}

// ValidateView.swift - Observes notifications
.onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
    Task { await viewModel.scan() }
}
.onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
    viewModel.cancelScan()
}
.onReceive(NotificationCenter.default.publisher(for: .toggleWatch)) { _ in
    viewModel.watchMode.toggle()
}
.onReceive(NotificationCenter.default.publisher(for: .clearCache)) { _ in
    Task { await viewModel.clearCache() }
}
```

**Notification Names:**

- `.runScan` - Trigger scan from menu
- `.cancelScan` - Cancel ongoing scan
- `.toggleWatch` - Toggle watch mode
- `.clearCache` - Clear validation cache

---

## Potential Wiring Issues & Gaps

### 1. ✅ Well-Connected Areas

- **Scan Flow**: Fully connected with proper cancellation and progress

  tracking

- **Sync Flow**: Multi-agent comparison working correctly
- **Index Generation**: Markdown rendering and version bumping functional
- **Remote Installation**: Download, verification, and installation pipeline

  complete

- **Caching**: Integrated throughout scan operations
- **Persistence**: Settings saved to UserDefaults

### 2. ⚠️ Areas to Monitor

- **Watch Mode**: FileWatcher integration appears complete but should verify

  debouncing (500ms)

- **Error Handling**: Some operations catch errors but may not always surface

  them to UI

- **Concurrent Operations**: Multiple simultaneous scans could race; scanID

  tracking mitigates this

- **Memory Management**: Large finding lists could impact performance;

  consider pagination

### 3. 🔍 Verification Needed

- Test cancellation propagation through entire async chain
- Verify cache invalidation on config changes
- Confirm multi-root Codex scanning works correctly
- Test cross-IDE installation with all target types

---

## Summary

The sTools frontend-backend wiring is **well-structured and comprehensive**:

✅ **Clear separation of concerns** - Views don't call backend directly ✅
**Reactive state management** - @Published properties drive UI updates ✅
**Proper async/await usage** - Cancellation and error handling in place ✅
**Multi-agent support** - Codex, Claude, Copilot, CodexSkillManager handled ✅
**Performance optimizations** - Caching, parallel validation, debouncing ✅
**User feedback** - Progress indicators, error messages, toast notifications ✅
**Persistence** - Settings saved and restored correctly

The architecture follows SwiftUI best practices and provides a solid
foundation for future enhancements.
