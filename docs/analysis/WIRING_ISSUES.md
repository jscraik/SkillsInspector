# sTools App Wiring Issues & Findings

**Date**: 2026-01-10 **Purpose**: Document missing connections between UI and
SkillsCore logic to enable fixing

---

## Critical Issues

### 1. **Menu Commands Not Reaching Sync/Index Modes** ⚠️

**Problem**: App.swift menu commands only handled in ValidateView

- Menu posts notifications: `.runScan`, `.cancelScan`, `.toggleWatch`,

  `.clearCache`

- **Only ValidateView** listens via `.onReceive()` at lines 55-62
- **SyncView** and **IndexView** never receive these notifications
- Keyboard shortcuts (⌘R, ⌘., ⌘⇧W) fail in Sync/Index modes

**Location**:

- `Sources/SkillsInspector/App.swift` (lines 31-53) - Posts notifications
- `Sources/SkillsInspector/ValidateView.swift` (lines 55-62) -

  Only listener

- `Sources/SkillsInspector/SyncView.swift` - Missing

  notification receivers

- `Sources/SkillsInspector/IndexView.swift` - Missing

  notification receivers

**Impact**: Users can't trigger actions from menu/keyboard when in Sync or
Index modes

**Fix Required**: Add `.onReceive()` handlers to SyncView and IndexView for
relevant notifications

---

### 2. **No UI to Change Skill Roots** 🔴

**Problem**: Codex/Claude root paths stay hardcoded with no UI affordance to
change them

**Current State**:

- `Sources/SkillsInspector/InspectorViewModel.swift` (lines 34-69)

  hardcodes roots in `init()`:

```swift
codexRoots = [home.appendingPathComponent(".codex/skills")]
claudeRoot = home.appendingPathComponent(".claude/skills")
```

- `Sources/SkillsInspector/ContentView.swift` (lines 82-119)
  displays roots in sidebar (read-only)
- `Sources/SkillsInspector/ContentView.swift` (lines 180-219) has
  complete `RootRow` component **but never used**
- `validateRoot()` helper exists but remains **dead code**

**What Exists but Unused**:

```swift

struct RootRow: View {
    let title: String
    let url: URL
    let onPick: (URL) -> Void
    // Has folder picker implementation ✓
}

func validateRoot(_ url: URL) -> Bool {
    // Validates paths, prevents system dirs ✓
}

```

**Impact**:

- Users stuck with default ~/.codex/skills and ~/.claude/skills
- No way to check custom repos or test different configurations
- All scans/sync/index operations fail silently if default roots don't exist

**Fix Required**:

1. Replace static root display in ContentView sidebar with interactive
   `RootRow` components
2. Wire `onPick` callbacks to update `viewModel.codexRoots` /
   `viewModel.claudeRoot`
3. Persist selected roots in UserDefaults or config file
4. Use `validateRoot()` before applying changes

---

### 3. **Divergent Recursive/Exclude Settings** 🟡

**Problem**: Each mode maintains independent scan settings instead of sharing
from InspectorViewModel

**Current State**:

- **InspectorViewModel** (`Validate` mode):
  - `recursive: Bool` at line 8
  - Uses hardcoded excludes in `scan()`: `[".git", ".system", "__pycache__",
    ".DS_Store"]`

- **SyncViewModel** (Sync mode):
  - `SyncView` has local `@State private var recursive = false` at line 53
  - `@State private var maxDepth: Int?`
  - `@State private var excludeInput: String` (user-entered CSV)
  - `@State private var excludeGlobInput: String`
  - Passed to `SyncChecker.byName()` at lines 64-67

- **IndexViewModel** (Index mode):
  - Own `recursive: Bool` at line 9
  - Hardcoded excludes in `generate()`: `[".git", ".system", "__pycache__",
    ".DS_Store"]`

**Impact**:

- User sets "Recursive" in sidebar (binds to InspectorViewModel) but
  Sync/Index ignore it
- No shared exclude patterns across modes
- Confusing UX: toggle appears to work but doesn't affect other modes

**Design Questions**:

1. Should recursive/excludes serve as **global app settings** (shared)?
2. Or **per-mode settings** (current behavior but not reflected in UI)?

**Fix Required**:

- **Option A (Shared)**: ContentView passes `viewModel.recursive` to all child
  views; centralize excludes
- **Option B (Per-mode)**: Move recursive toggle into each mode's toolbar;
  remove from sidebar
- Document intended behavior in architecture

---

### 4. **StatsView Referenced but Mode Selection Removed** 🟠

**Problem**: AppMode enum includes `.stats` but sidebar doesn't show it

**Current State**:

- [App.swift](Sources/SkillsInspector/App.swift#L73-L77) defines
  `AppMode.stats`
- [ContentView.swift](Sources/SkillsInspector/ContentView.swift#L28) switches
  on `.stats` case → shows `StatsView(viewModel: viewModel)`
- [ContentView.swift](Sources/SkillsInspector/ContentView.swift#L60-L74)
  sidebar only shows `Validate`/Stats/Sync/Index links

Wait — checking again:

```swift

NavigationLink(value: AppMode.stats) {
    Label("Statistics", systemImage: "chart.bar.fill")
}

```

This **does** exist at line 63-66!

**Resolution**: Stats mode wires correctly. No issue here. ✅

---

### 5. **Index Mode Only Uses First Codex Root** ⚠️

**Problem**: IndexViewModel ignores more than one codex root

**Location**: [IndexView.swift](Sources/SkillsInspector/IndexView.swift#L19)

```swift

func generate(codexRoots: [URL], claudeRoot: URL) async {
    let codexRoot = codexRoots.first  // ⚠️ Ignores rest
    // ...
    let entries = SkillIndexer.generate(
        codexRoot: codexRoot,  // Only first root passed
        claudeRoot: claude,
        // ...
    )
}

```

**Impact**: If a user has more than one codex root (e.g., `.codex/skills` +
`.codex/public/skills`), index only scans first one

**Core API Support**:

- [Indexer.swift](Sources/SkillsCore/Indexer.swift#L10-L20)
  `SkillIndexer.generate()` signature:

```swift public static func generate( codexRoot: URL?, // ⚠️ Single root only

claudeRoot: URL?, include: IndexInclude = .both, recursive: Bool = false, //
... ) -> [SkillIndexEntry] ```

**Fix Required**:

1. **Option A**: Update `SkillIndexer.generate()` to accept `[URL]` for codex

   roots

2. **Option B**: Call `SkillIndexer.generate()` multiple times and merge

   results

3. Update IndexViewModel to handle all roots

---

### 6. **Sync Mode Hardcoded Root Fallback** 🟡

**Problem**: SyncView uses fallback logic if first codex root missing

**Location**:
[ContentView.swift](Sources/SkillsInspector/ContentView.swift#L32-L34)

```swift
SyncView(
    viewModel: syncVM,
    codexRoot: viewModel.codexRoots.first ??
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/skills"),
    claudeRoot: viewModel.claudeRoot
)
```

**Impact**:

- If `codexRoots` stays empty, silently falls back to hardcoded path
- Inconsistent with IndexView which trusts `codexRoots` array
- User might think they sync their custom root but actually using

  default

**Fix Required**: Handle empty roots consistently (either error state or allow
user to pick)

---

## Configuration Inconsistencies

### Hardcoded Excludes Across Codebase

Hardcoded exclude lists need centralization:

1. **InspectorViewModel.scan()** (line 126):

```swift
excludeDirNames: [".git", ".system", "__pycache__", ".DS_Store"]
```

1. **IndexViewModel.generate()** (line 36):

```swift
excludes: [".git", ".system", "__pycache__", ".DS_Store"]
```

1. **SyncViewModel.run()** (line 35):

```swift
excludeDirNames: Set([".git", ".system", "__pycache__", ".DS_Store"])
    .union(Set(excludes))
```

**Recommendation**: Define shared constant in SkillsCore or Config:

```swift

public extension SkillsConfig {
    static let defaultExcludes = [".git", ".system", "__pycache__", ".DS_Store"]
}

```

---

## Architecture Observations

### Notification-Based Menu Commands (Working for `Validate` Only)

**Current Flow**:

```text

App.swift Menu Commands
    ↓ NotificationCenter.post()
ValidateView.onReceive()
    ↓ calls
InspectorViewModel methods

```

**Missing Flows**:

```text

App.swift Menu Commands
    ↓ NotificationCenter.post()
SyncView.onReceive() ❌ NOT IMPLEMENTED
    ↓ should call
SyncViewModel.run()

App.swift Menu Commands
    ↓ NotificationCenter.post()
IndexView.onReceive() ❌ NOT IMPLEMENTED
    ↓ should call
IndexViewModel.generate()

```

**Design Note**: Notification pattern works but requires each view to
explicitly subscribe. Consider alternative:

- Pass menu actions down via `@Environment` or callbacks
- Use app-level state machine to dispatch to active mode

---

## Test Coverage Gaps

`Tests/SkillsInspectorTests/SkillsInspectorTests.swift`:

- ✅ InspectorViewModel scan/cancel/cache tested
- ✅ SyncViewModel recursive/exclude logic tested
- ❌ No tests for notification delivery to views
- ❌ No tests for root validation/picker logic
- ❌ No tests for IndexViewModel multi-root handling

---

## Recommendations for Next Model

### Priority 1: Menu Command Wiring

1. Add `.onReceive()` handlers to SyncView for:
   - `.runScan` → trigger `viewModel.run()`
   - `.cancelScan` → cancel ongoing sync task
1. Add `.onReceive()` handlers to IndexView for:
   - `.runScan` → trigger `viewModel.generate()`
   - `.cancelScan` → cancel ongoing generation

### Priority 2: Root Management UI

1. Replace static root display in ContentView sidebar with `RootRow` instances
1. Add "Add Root" / "Remove Root" buttons for codex roots array
1. Wire picker callbacks:

```swift
RootRow(title: "Codex", url: viewModel.codexRoots[0]) { newURL in
    if validateRoot(newURL) {
        viewModel.codexRoots[0] = newURL
    }
}
```

1. Persist roots in UserDefaults on change
1. Add validation feedback for missing/invalid roots

### Priority 3: Standardize Settings

Decide on shared vs per-mode settings:

- If shared: bind all views to InspectorViewModel recursive/exclude state
- If per-mode: move controls into each mode's toolbar, remove from sidebar

### Priority 4: Multi-Root Index Support

Update SkillIndexer.generate() to handle more than one codex root or call it in a
loop and merge results

---

## File Reference Map

- App menu commands:
  `Sources/SkillsInspector/App.swift` (lines 31-53)
- Notification listeners:
  `Sources/SkillsInspector/ValidateView.swift` (lines 55-62)
- Root initialization:
  `Sources/SkillsInspector/InspectorViewModel.swift` (lines 34-69)
- Root display:
  `Sources/SkillsInspector/ContentView.swift` (lines 82-119)
- Root picker (unused):
  `Sources/SkillsInspector/ContentView.swift` (lines 180-219)
- Sync settings:
  `Sources/SkillsInspector/SyncView.swift` (lines 53-56)
- Index settings:
  `Sources/SkillsInspector/IndexView.swift` (line 9)
- Index multi-root:
  `Sources/SkillsInspector/IndexView.swift` (line 19)
- Core indexer API:
  `Sources/SkillsCore/Indexer.swift` (lines 10-20)

---

## Summary

**Blocking Issues**:

1. ❌ Menu shortcuts don't work in Sync/Index modes (missing notification

   receivers)

2. ❌ No way to change roots from UI (RootRow exists but unused)
3. ❌ Index mode only scans first codex root (silently ignores others)

**Design Clarifications Needed**:

1. Should recursive/exclude settings stay shared or per-mode?
2. How should multi-root codex scanning work for index generation?
3. Should roots persist in UserDefaults, config file, or app state?

**Working Correctly**:

- ✅ `Validate` mode full feature set (scan/watch/cache/export/baseline)
- ✅ Stats mode displays charts and metrics
- ✅ Sync mode logic (just needs menu wiring)
- ✅ Index mode generation (just needs menu wiring + multi-root)
- ✅ Core SkillsCore APIs (scanner/validator/sync/indexer all functional)

**Next Steps**: Address Priority 1 (menu wiring) as quick win, then tackle
root management UI for full functionality.
