# Ralph Pin (spec anchor)

This file is the authoritative source of truth for what we're building. Treat it as canonical.

## Purpose

SkillsInspector is a **Trustworthy Skills Inspector** for macOS that installs, updates, and publishes skills with explicit consent, cryptographic verification, reproducible builds, versioned history, and unified compatibility across Codex, Claude Code, and GitHub Copilot. It provides:

- **SkillsInspector app** (macOS): Interactive GUI with provenance badges, consent gates, and safe preview
- **skillsctl CLI**: Command-line tool for CI/CD integration with verify/install/publish commands
- **SkillsLintPlugin**: SwiftPM plugin for automated validation

Core capabilities:

- **Artifact Trust**: Ed25519 signature verification, SHA-256 hash checking, fail-closed security
- **Consentful UX**: Safe preview from server, explicit "Download and verify" gate, provenance badges
- **Reproducible Publishing**: Pinned toolchain (clawdhub@0.1.0), deterministic builds, signed attestations
- **Cross-IDE Unification**: Single install registers for Codex, Claude Code (~/.claude/skills/), and Copilot (~/.copilot/skills/)
- **Versioned History**: Append-only ledger (SQLite) with automatic changelog generation
- **Offline-Safe**: Cached manifests, last-known-good installs, local trust store
- **Opt-in Telemetry**: Privacy-first metrics (verified installs, blocked downloads, publish runs)

## Non-goals

Explicitly state what we're NOT doing:

- Not a skill editor or IDE (read-only validation and sync)
- Not a skill execution engine (only validates documentation and manages installation)
- Not a real-time marketplace analytics platform
- Not an enterprise policy engine (v1)
- Not multi-platform GUI beyond macOS (v1)

## Constraints

Technical and business constraints:

- **Platform**: macOS 15+ SDK, Swift 6.0+ toolchain
- **Security**: OWASP Top 10:2025 A8 Software Integrity, fail-closed verification
- **Performance**: Verify 10 MB artifact in <300 ms on M3, parallel validation with caching
- **Reliability**: Atomic installs (stage to temp, then move), rollback on failure
- **Accessibility**: WCAG 2.2 AA compliance, keyboard navigation for all controls
- **Privacy**: Telemetry off by default, no PII collection
- **UI Framework**: SwiftUI with split-view navigation and detail preview patterns
- **Build System**: SwiftPM (Package.swift)
- **Testing**: Swift testing with XCTest, security fixtures for tampered archives
- **Language**: Swift 6 with strict concurrency
- **File organization**: One main type per file, SwiftUI previews on all Views

## Conventions

Code and workflow conventions to follow:

- **Code style**: Follow project AGENTS.md (Swift conventions, 4 spaces indent)
- **Testing approach**: TDD - write failing test → make pass → refactor
- **Security testing**: Semgrep/AST checks for unsafe file operations, zip-bomb fixtures
- **Documentation**: DocC for public APIs
- **Git workflow**: Feature branches, PR reviews, conventional commits
- **Check commands**:
  - `swift test` - Run unit tests including security fixtures
  - `swift build` - Verify compilation
  - `swift run skillsctl --help` - Test CLI interface
  - `open SkillsInspector.app` - Launch GUI after build

## Known System Areas / Links

Key areas of the codebase and their locations:

| Area | Location | Notes |
|------|----------|-------|
| Trust & Verification | `Sources/SkillsCore/TrustStore.swift` | Signature verification, trust management |
| Artifact Fetcher | `Sources/SkillsCore/ArtifactFetcher.swift` | Guarded download with size/MIME limits |
| Archive Sanitizer | `Sources/SkillsCore/Sanitizer.swift` | Zip bomb protection, structure validation |
| Installer | `Sources/SkillsCore/Installer.swift` | Atomic install with staging and rollback |
| Cross-IDE Adapters | `Sources/SkillsCore/Adapters/` | Codex, Claude Code, Copilot registration |
| Ledger | `Sources/SkillsCore/SkillLedger.swift` | Append-only SQLite event log |
| Publisher | `Sources/SkillsCore/Publisher.swift` | Pinned tool runner with attestation |
| CLI interface | `Sources/skillsctl/` | verify/install/publish subcommands |
| macOS app (GUI) | `Sources/SkillsInspector/` | SwiftUI with provenance badges |
| Remote view | `Sources/SkillsInspector/Remote/` | Safe preview, consent gates |
| SwiftPM plugin | `Plugins/SkillsLintPlugin/` | Build integration |
| Unit tests | `Tests/SkillsCoreTests/` | Core engine + security tests |
| UI tests | `Tests/SkillsInspectorTests/` | View model + snapshot tests |
| Trust store | `~/Library/Application Support/SkillsInspector/trust.json` | Allowlisted keys + revocations |
| Configuration schemas | `docs/*.json` | JSON schemas for manifests |
| Package definition | `Package.swift` | Dependencies and targets |

## Spec References

Links to the source spec documents:

- **Primary Spec**: `.spec/spec-<->.md` (PRD + Technical Spec)
- Project instructions: `AGENTS.md`
- Main documentation: `README.md`
- Design tokens: `Sources/SkillsInspector/DesignTokens.swift`
