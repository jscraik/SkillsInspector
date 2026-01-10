# sTools

<p align="center">
  <img
    src="brand/sTools-brand-logo.png"
    srcset="brand/sTools-brand-logo.png 1x, brand/sTools-brand-logo@2x.webp 2x"
    alt="sTools brand hero: developer toolkit for skill trees"
    width="720"
  />
</p>

Developer toolkit for Codex/Claude skill trees:

- **SkillsCore** engine (scan/check/sync with incremental cache + parallel validation)
- **skillsctl** CLI (scan, sync-check, index; JSON/text; watch; cache stats; completions)
- **sTools app** (formerly SkillsInspector) SwiftUI macOS experience for interactive scan/sync with quick actions
- **SkillsLintPlugin** SwiftPM command plugin for CI (`swift package plugin skills-lint`)

## Contents

- [Prerequisites](#prerequisites)
- [Build & Test](#build--test)
- [CLI quickstart (repo-first)](#cli-quickstart-repo-first)
- [Shell completion](#shell-completion)
- [SwiftPM plugin (CI)](#swiftpm-plugin-ci)
- [sTools app](#stools-app-macos)
- [Configuration](#configuration)
- [Performance Features](#performance-features)
- [DocC](#docc)
- [Project structure](#project-structure)
- [Verification](#verification)
- [License](#license)

## Prerequisites

- macOS 26 SDK (Xcode 26 / Xcode-beta 26)
- Swift 6.2 toolchain

## Build & Test

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" swift test
```

## CLI quickstart (repo-first)

```bash
# Scan repo-scoped skills (preferred for CI) - uses cache automatically
skillsctl scan --repo . --format json

# Scan home scopes with parallel validation
skillsctl scan --codex ~/.codex/skills --claude ~/.claude/skills --default-excludes

# Watch mode for development (auto-rescan on file changes)
skillsctl scan --repo . --watch

# Disable cache for debugging
skillsctl scan --repo . --no-cache

# Control parallelism (default: CPU count)
skillsctl scan --repo . --jobs 4

# Show cache statistics
skillsctl scan --repo . --show-cache-stats

# Skip one side
skillsctl scan --repo . --skip-claude

# Turn off default excludes (.git, .system, __pycache__, .DS_Store)
skillsctl scan --repo . --no-default-excludes

# Sync-check
skillsctl sync-check --repo .

# Generate index (Skills.md) for both roots and bump version
skillsctl index --repo . --write --bump patch
```

Common flags: `--config <path>` (defaults to `.skillsctl/config.json`), `--baseline <path>` (defaults to `.skillsctl/baseline.json`), `--ignore <path>` (defaults to `.skillsctl/ignore.json`), `--plain`, `--log-level <level>`, `--schema-version 1`, `--allow-empty`, `--recursive`, `--max-depth <n>`, `--exclude <name>`, `--exclude-glob <pattern>`, `--format text|json`.

Exit codes: `0` success; `1` when validation errors exist or no skills appear without `--allow-empty`; `2` usage/config error.

## Shell completion

Generate completion scripts for your shell:

```bash
# Bash
skillsctl completion bash > /usr/local/etc/bash_completion.d/skillsctl

# Zsh (add to ~/.zshrc)
eval "$(skillsctl completion zsh)"

# Fish
skillsctl completion fish > ~/.config/fish/completions/skillsctl.fish
```

## SwiftPM plugin (CI)

```bash
swift package plugin skills-lint
```

Runs `skillsctl scan --repo . --format json` and surfaces diagnostics. Benefits from automatic caching on later runs.

## sTools app (macOS)

Run with SwiftPM:

```bash
swift run sTools
```

### Features

- **Modes**: Check (scan + filters), Sync (compare Codex/Claude trees with diff/copy), Index (placeholder)
- **Quick Actions**: Right-click any finding to open in editor (line-aware), show in Finder, add to baseline (persists to `.skillsctl/baseline.json`), or copy rule ID/path/message
- **Watch Mode**: Toggle to auto-rescan when SKILL.md files change (500ms debounce)
- **Cache Stats**: Cache hits surface in the Check tab; clear cache from the app settings
- **Sync View**: Per-root excludes/globs + depth; see only-in-Codex/Claude and diff buckets with detail pane
- **Keyboard Shortcuts**: ⌘R scan, ⌘W close

## Configuration

- `.skillsctl/config.json` (see `docs/config-schema.json`)
- `.skillsctl/baseline.json` (see `docs/baseline-schema.json`)
- `.skillsctl/cache.json` (auto-generated, invalidated on config changes)
- Ignore file (same shape as baseline) supported via `--ignore`.

CLI defaults:

- Roots: repo mode scans `.codex/skills` and `.claude/skills` under `--repo`; otherwise `~/.codex/skills` and `~/.claude/skills`.
- Default excludes: `.git`, `.system`, `__pycache__`, `.DS_Store` (disable with `--no-default-excludes`).
- Baselining/ignores: auto-load `.skillsctl/baseline.json` and `.skillsctl/ignore.json` when present.
- Cache: stored at `<repo>/.skillsctl/cache.json` (disable with `--no-cache`; stats via `--show-cache-stats`).

## Performance Features

### Incremental Caching

- Automatically caches validation results in `.skillsctl/cache.json`
- Re-validates only files that changed (modification time + SHA-256)
- Cache invalidated when config changes
- Typical speedup: 10-100x for unchanged files
- Use `--no-cache` to disable

### Parallel Validation

- Checks many files concurrently using Swift structured concurrency
- Automatically uses all CPU cores (customize with `--jobs`)
- Typical speedup: 2-4x on multi-core machines

### Watch Mode

- File system monitoring with automatic re-validation
- Debounced to avoid excessive scans (500ms delay)
- Shows only changed results
- CLI: `--watch` flag
- UI: Toggle in toolbar

## DocC

Generate DocC for SkillsCore:

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" \
swift package generate-documentation --target SkillsCore \
  --disable-indexing --output-path Docs.doccarchive
```

Open in DocC viewer:

```bash
open Docs.doccarchive
```

## Project structure

- `Sources/SkillsCore`: core scanning/validation/sync engine
- `Sources/skillsctl`: CLI
- `Sources/SkillsInspector`: SwiftUI app (sTools)
- `Plugins/SkillsLintPlugin`: SwiftPM command plugin
- `docs/`: schemas and usage notes
- `Tests/`: unit tests (core + inspector view models)

## Verification

- Unit tests: `swift test`
- JSON schema references: `docs/schema/findings-schema.json`, `docs/config-schema.json`, `docs/baseline-schema.json`

## License

MIT

---

<img
  src="./brand/brand-mark.webp"
  srcset="./brand/brand-mark.webp 1x, ./brand/brand-mark@2x.webp 2x"
  alt="brAInwav"
  height="28"
  align="left"
/>

<br clear="left" />

**brAInwav**  
_from demo to duty_
