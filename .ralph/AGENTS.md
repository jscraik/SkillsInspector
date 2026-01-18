# AGENTS.md

This file is **project-specific operational memory**.
Keep it short and deterministic. Add only what you repeatedly need.

## Stack

- **Language**: Swift 6.0+ (Swift 6 language mode, strict concurrency complete)
- **Platform**: macOS 14+ SDK
- **Package Manager**: SwiftPM (Package.swift)
- **Dependencies**:
  - swift-argument-parser (CLI)
  - swift-markdown-ui (Markdown rendering)
  - Sparkle (Auto-updates)
  - sqlite3 (system library, linked)

## Repo Commands

### Install Dependencies

```bash
# SwiftPM handles dependencies automatically
swift build
```

### Build

```bash
# Build all products
swift build

# Build specific product
swift build -c debug --product SkillsInspector
swift build --product skillsctl
```

### Test

```bash
# Run all tests
swift test

# Run specific test
swift test --filter testAsyncScanner

# Include chart snapshots (requires ALLOW_CHARTS_SNAPSHOT=1)
ALLOW_CHARTS_SNAPSHOT=1 swift test
```

### Lint / Format

```bash
# Lint (SkillsLintPlugin)
swift package skills-lint

# Formatting: no repo formatter configured
```

### Type Check

```bash
# Swift compiler performs type checking during build
swift build  # Fails on type errors
```

### CLI Verification

```bash
# Test CLI is working
swift run skillsctl --help

# Test basic scan
swift run skillsctl scan --repo . --allow-empty
```

## Quality Gates

Commands that MUST pass before marking a task done:

```bash
# 1. Build check (Swift 6 compilation)
swift build -c debug --product SkillsInspector

# 2. Tests
swift test

# 3. Lint check
swift package skills-lint

# 4. CLI smoke test
swift run skillsctl scan --repo . --allow-empty
```

## Conventions

- **One type per file**: Each `struct`/`class`/`enum`/`actor`/`protocol` in its own file
- **SwiftUI previews**: Every View has a static SwiftUI preview
- **File organization**:
  - `Sources/SkillsCore/` - Core scanning/validation/sync engine
  - `Sources/skillsctl/` - CLI
  - `Sources/SkillsInspector/` - SwiftUI app (SkillsInspector)
  - `Plugins/SkillsLintPlugin/` - SwiftPM command plugin
  - `Tests/` - Unit tests (core + inspector view models)
- **Code length**: ~300 LOC per file, ~30 LOC per function
- **Write small, focused commits**
- **One task per iteration**
- **Prefer editing existing code over creating parallel implementations**
- **Run quality gates before committing**

## Project-Specific Notes

### Skill File Format

Skills are stored as `SKILL.md` files with YAML frontmatter:

```yaml
---
name: skill-name
description: Brief description
version: 1.0.0
author: Author Name
tags: [tag1, tag2]
---
```

### Agent Support

- **Codex**: `~/.codex/skills/`
- **Claude**: `~/.claude/skills/`
- **Copilot**: `~/.copilot/skills/`

### Configuration Files

- `.skillsctl/config.json` - Validation and sync configuration
- `.skillsctl/baseline.json` - Known validation issues to ignore
- `.skillsctl/cache.json` - Incremental validation cache
- `.skillsctl/ignore.json` - Same shape as baseline
- `STOOLS_KEYSET_ROOT_KEY` - Base64 Ed25519 root public key for verifying signed keysets
  - When set, Remote fetches `/api/v1/keys` and updates the trust store only if the signature verifies and the keyset is not expired.

### Product Targets

1. **SkillsInspector** (macOS app): Formerly SkillsInspector - GUI for skill validation/sync
2. **skillsctl** (CLI): Command-line tool for CI/CD and scripting
3. **SkillsLintPlugin** (SwiftPM): Build-time validation plugin

### Current Development Focus

**Integration of meta_skill patterns into SkillsInspector** (without external dependencies):
1. Structured SkillSpec type (SKILL.md ↔ JSON round-trip)
2. ACIP security scanning (prompt-injection quarantine)
3. SQLite FTS search (O(log n) full-text search)
4. Complementary workflow (skill lifecycle coordination)

### New Directories to Create

When implementing integration features:

```
Sources/SkillsCore/
├── Spec/           # SkillSpec type and parsing
├── Security/       # ACIP scanner and quarantine
├── Search/         # SQLite FTS search engine
└── Workflow/       # Skill lifecycle coordination
```

### Swift 6 Concurrency

- Use `Sendable` for all public types
- Isolate mutable state with `actor` or `@MainActor`
- Default isolation: `MainActor` for UI components
- Strict concurrency: All code must be data-race free

### File Watching

- Watch mode available: `skillsctl scan --repo . --watch`
- Debounced to 500ms to avoid excessive scans
- Implemented via FileWatcher.swift

### Remote Skills

- Browse catalog: `skillsctl remote list --limit 10`
- Search: `skillsctl remote search "sql"`
- Install: `skillsctl remote install my-skill --target codex`
- Remote installs enforce MIME/type checks, ACIP scanning, and all-or-nothing rollback across targets.
- Changelog exports are signed with a per-device Ed25519 key stored in Keychain by default (file-based store only when explicitly configured).
