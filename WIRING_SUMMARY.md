# sTools Wiring Review - Quick Reference

## 🔴 Critical Blockers

### 1. Menu Commands Missing in Sync/Index Modes

```text
App.swift (lines 31-53) posts notifications:
  ├─ ✅ ValidateView.onReceive() → InspectorViewModel
  ├─ ❌ SyncView (NO listeners)
  └─ ❌ IndexView (NO listeners)

Result: ⌘R, ⌘., ⌘⇧W shortcuts broken in Sync/Index
```

### 2. Root Paths Not Editable

```text
InspectorViewModel.init() (lines 34-69):
  └─ Hardcoded: ~/.codex/skills, ~/.claude/skills

ContentView sidebar (lines 82-119):
  └─ Read-only display

ContentView.RootRow (lines 180-219):
  └─ 🔴 Complete picker UI exists BUT NEVER USED

Result: Users stuck with defaults, can't test other repos
```

### 3. Index Ignores More Than One Root

```text
IndexViewModel.generate() (line 19):
  let codexRoot = codexRoots.first  // ⚠️ Drops rest

Result: If user has 2+ codex roots, only first is indexed
```

---

## 🟡 Design Inconsistencies

### Settings Divergence

```text
InspectorViewModel:
  └─ recursive: Bool (bound to sidebar toggle)

SyncView:
  └─ @State private var recursive = false (local, ignores sidebar)

IndexViewModel:
  └─ recursive: Bool (separate instance, ignores sidebar)

Result: Sidebar "Recursive" toggle only affects Validate mode
```

### Hardcoded Excludes (3 locations)

```text
InspectorViewModel.scan(): [".git", ".system", "__pycache__", ".DS_Store"]
IndexViewModel.generate(): [".git", ".system", "__pycache__", ".DS_Store"]
SyncViewModel.run():       [".git", ".system", "__pycache__", ".DS_Store"]

Recommendation: Define SkillsConfig.defaultExcludes
```

---

## ✅ What Works

- `Validate` mode: Full scan/watch/cache/export/baseline
- Stats mode: Charts display correctly
- Sync/Index core logic: SyncChecker, SkillIndexer APIs functional
- File watchers, caching, fix suggestions all operational
- Tests cover ViewModel logic (not UI wiring)

---

## 🔧 Quick Fixes

### Fix 1: Add Notification Receivers (10 min)

**SyncView.swift**, after line 80 add:

```swift
.onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
    guard rootsValid else { return }
    Task {
        await viewModel.run(
            codexRoot: codexRoot,
            claudeRoot: claudeRoot,
            recursive: recursive,
            maxDepth: maxDepth,
            excludes: parsedExcludes,
            excludeGlobs: parsedGlobExcludes
        )
    }
}
```

**IndexView.swift**, after toolbar add:

```swift
.onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
    Task {
        await viewModel.generate(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot
        )
    }
}
```

### Fix 2: Wire Root Pickers (30 min)

**ContentView.swift**, replace lines 82-119 with:

```swift
Section {
    ForEach(
        Array(viewModel.codexRoots.enumerated()),
        id: \.offset
    ) { index, url in
        RootRow(title: "Codex \(index + 1)", url: url) { newURL in
            if validateRoot(newURL) {
                viewModel.codexRoots[index] = newURL
            }
        }
    }

    RootRow(title: "Claude", url: viewModel.claudeRoot) { newURL in
        if validateRoot(newURL) {
            viewModel.claudeRoot = newURL
        }
    }
} header: {
    Text("Scan Roots")
}
```

### Fix 3: Shared Settings (20 min)

Pass `viewModel.recursive` to child views:

```swift
SyncView(viewModel: syncVM, codexRoot: ..., claudeRoot: ...,
         recursive: viewModel.recursive)  // Add binding
IndexView(viewModel: indexVM, ...,
          recursive: viewModel.recursive)  // Add binding
```

Remove `@State` from SyncView/IndexView, accept `@Binding` instead.

---

## 📊 Impact Assessment

| Issue | Users Affected | Severity |
| ------- | --------------- | ---------- |
| Menu shortcuts in Sync/Index | 100% | High |
| Can't change roots | 100% | High |
| Index multi-root | Users w/ 2+ roots | Medium |
| Settings divergence | Power users | Low |

**Total Fix Time**: ~2 hours for all critical issues

---

## 📁 Files Needing Changes

```text
Sources/SkillsInspector/
  ├─ SyncView.swift        (+6 lines: add onReceive)
  ├─ IndexView.swift       (+6 lines: add onReceive)
  ├─ ContentView.swift     (~30 lines: wire RootRow)
  └─ InspectorViewModel.swift (optional: persist roots)

Sources/SkillsCore/
  └─ Indexer.swift         (optional: multi-root support)
```

---

See [WIRING_ISSUES.md](WIRING_ISSUES.md) for detailed analysis.
