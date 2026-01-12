# Remote Skill Catalog & Import (CodexSkillManager parity for sTools)

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. Follow `/Users/jamiecraik/.codex/instructions/plans.md` for required structure.

## Purpose / Big Picture

Deliver CodexSkillManager-equivalent capabilities inside sTools (SkillsInspector + SkillsCore + skillsctl) so operators can browse Clawdhub, search and filter remote skills, preview metadata/owners/changelogs, download/install/update skills into Codex/Claude paths (or custom roots), import local zips/folders, and render reference previews inline. The goal is a single app/CLI that manages both local and remote skill lifecycles with evidence-backed operations (downloads, installs, publishes) and clear status tags.

## Progress

- [ ] (2026-01-11T00:00Z) Draft ExecPlan and align with GOLD baseline.
- [ ] (2026-01-11T00:00Z) Repository discovery: current SkillsInspector UX gaps vs CodexSkillManager.
- [ ] (2026-01-11T00:00Z) Remote catalog client added to SkillsCore with tests.
- [ ] (2026-01-11T00:00Z) CLI `skillsctl remote` commands implemented (list/search/download/detail).
- [ ] (2026-01-11T00:00Z) SkillsInspector UI updated with remote catalog tab and install/update flows.
- [ ] (2026-01-11T00:00Z) Import/export (folder/zip) parity implemented with validation and conflict handling.
- [ ] (2026-01-11T00:00Z) Inline reference previews in detail pane.
- [ ] (2026-01-11T00:00Z) Sparkle update channel wiring (if retained) or equivalent in-app update notice.
- [ ] (2026-01-11T00:00Z) Tests added (unit + integration) and telemetry for remote ops; all checks passing.
- [ ] (2026-01-11T00:00Z) Outcomes & retrospective updated.

## Surprises & Discoveries

- Pending.

## Decision Log

- Pending.

## Outcomes & Retrospective

- Pending.

## Context and Orientation

Current repo (`sTools`) provides SkillsCore (scan/sync/index engine), skillsctl CLI, and SkillsInspector macOS UI (run via `swift run sTools`). Remote catalog features are absent. Key entry points:
- CLI: `Sources/skillsctl/main.swift` (argument parsing, commands), shared utilities `Sources/skillsctl/FileWatcher.swift`.
- Core models/services: `Sources/SkillsCore/` (validation, cache, fix engine, indexing, export service).
- UI: `Sources/SkillsInspector/` (view models, views: `InspectorViewModel.swift`, `ValidateView.swift`, `SyncView.swift`, `StatsView.swift`, `FindingDetailView.swift`, etc.).
- Docs/schemas: `docs/` (config/baseline schemas).

Reference OSS repo: `Dimillian/CodexSkillManager` (SwiftPM macOS app) supplies remote Clawdhub browsing, inline reference previews, import/export from zip/folder, install target selection (Codex/Claude/custom), owner metadata, and Sparkle packaging scripts. We'll port capabilities while aligning with sTools architecture (SkillsCore as source of truth; SkillsInspector as shell; skillsctl parity commands).

## Plan of Work

1) Gap analysis and design
   Perform side-by-side review of CodexSkillManager features vs current sTools UI/CLI. Capture required data models (RemoteSkill, RemoteSkillOwner, RemoteStats, InstallTarget) and flows (latest list, search, detail fetch, version check, download, install, import zip/folder, delete, tags). Decide on configuration surface (endpoints, cache sizes, default roots, concurrency, telemetry fields). Document security/privacy (network calls to clawdhub.com over HTTPS; avoid credential storage; redact logs).

2) Core remote client + data models (SkillsCore)
   Add `RemoteSkillClient` (async) with URLSession + URLCache mirroring CodexSkillManager (10MB memory/50MB disk) and pure functions for fetchLatest/search/fetchDetail/fetchLatestVersion/download. Define DTOs and domain models (`RemoteSkill`, `RemoteSkillOwner`, `RemoteSkillDownload`, `RemoteSkillInstallResult`). Add error taxonomy (network, decode, validation, install conflict, checksum) with user-facing messages. Add download/install pipeline that unzips to temp, validates SKILL.md via existing validator, and copies into selected root with rollback on failure. Include SHA256 verification where possible and preserve file permissions. Provide dependency injection hooks for testing and offline.

3) CLI surface
   Extend `skillsctl` with `remote` command group: `list` (latest), `search <query>`, `detail <slug>`, `download <slug> [--version <v>]`, `install <slug> [--version <v>] [--target codex|claude|path]`, `update <slug>` (checks latest version vs installed). Support JSON/text output, exit codes, cache toggle, and concurrency flags. Add telemetry output (duration, bytes downloaded, cache hits). Ensure commands reuse SkillsCore client and install pipeline. Update completion scripts and help texts.

4) SkillsInspector UI/UX
   Add Remote tab alongside Check/Sync/Index. Components: remote list (latest), search bar, filters (installed/updates available), detail panel with owner info, changelog, stats, tags (Codex/Claude installed), version picker, download/install buttons, open in Finder, delete. Integrate status badges matching CodexSkillManager TagView semantics. Add inline reference previews to existing detail view using Markdown rendering plus collapsible reference list (similar to CodexSkillManager ReferenceDetailInlineView/ReferenceListView). Provide import dialogs for folder/zip and install target selection, with progress HUD and error toasts. Add caching indicator and manual refresh.

5) Import/export parity
   Implement `ImportSkillView`-equivalent flows in SkillsInspector: pick folder/zip, validate contents, choose target roots, handle conflicts (prompt overwrite/rename/skip), and show summary. Add CLI counterparts (`skillsctl import --path <zip|dir> --target ...`). Add export/share action from detail to zip. Reuse `ExportService` where possible; extend with zipping and target selection.

6) Remote detail cache + update detection
   Add `RemoteSkillDetailCache`-like store in SkillsCore to cache owners/changelogs with TTL (configurable). Expose update availability by comparing installed version (from SKILL.md frontmatter or metadata) with `fetchLatestVersion`. Surface update badges in UI and `skillsctl remote list --with-updates`.

7) Packaging/update channel decision
   Evaluate need for Sparkle update flow. If we keep Sparkle, align Scripts/ signing instructions (reuse existing `Scripts/` in CodexSkillManager). Otherwise, add in-app update notification (link to release page). Document in README and app About view.

8) Testing and telemetry
   Add unit tests for RemoteSkillClient (mock URLProtocol), installer (temp dir, conflict cases), and CLI commands (argument parsing, JSON output). Add UI snapshot/unit tests for Remote tab view models (no network). Extend telemetry to include network metrics (bytes, latency, cache hits). Ensure tests avoid real network (use DI).

9) Documentation and governance
   Update README (sTools app section) and docs (config schema additions for remote endpoints/cache/targets). Add architecture note describing remote data flow and security posture (no auth, HTTPS only, caching, redaction). Ensure AGENTS.md and CODESTYLE compliance (no hard-coded secrets, deterministic tests).

10) Validation and rollout
   Manual QA: `swift test`, `swift run skillsctl remote list --repo . --format json`, `swift run skillsctl remote install <slug> --target codex --allow-empty` in a sandbox directory, and UI manual run of Remote tab. Capture before/after evidence. Prepare migration notes (new config keys) and feature flag toggles if needed.

## Concrete Steps

- Working dir: repository root `/Users/jamiecraik/dev/sTools`.
- Analysis: compare CodexSkillManager sources in `/tmp/CodexSkillManager` (RemoteSkillClient/ImportSkillView/etc.) and map into SkillsCore/SkillsInspector/skillsctl design.
- Implement core client/models/tests in `Sources/SkillsCore/Remote/` (new folder) and wiring in existing services.
- Wire CLI subcommands in `Sources/skillsctl/main.swift` with shared option parsing helpers; update completions.
- Add UI files under `Sources/SkillsInspector/Remote/` for views, view models, and caches; integrate into `ContentView.swift` navigation and `DesignTokens` for badges.
- Extend Export/Import services in `Sources/SkillsInspector/` and `Sources/SkillsCore/ExportService.swift` for zip support.
- Update docs: `README.md`, `docs/config-schema.json`, `docs/baseline-schema.json` (if needed), add usage examples in `docs/`.
- Commands to run during implementation/validation:
    - `swift test`
    - `swift run skillsctl remote list --repo . --format json --allow-empty`
    - `swift run sTools` (manual QA of Remote tab)
    - Optional: `swift run skillsctl import --help`, `swift run skillsctl remote install --help`

## Validation and Acceptance

Change is acceptable when:
- All tests pass (`swift test`).
- `skillsctl remote list/search/detail/install/update/import` work with mock server or sample slug, returning structured JSON/text with correct exit codes.
- SkillsInspector Remote tab displays latest skills, search results, owner metadata, tags for installed/updates, and allows install/import/export with visible progress and error handling.
- Inline reference previews render within skill detail with collapsible sections.
- Update detection highlights newer versions when available.
- Documentation reflects new commands/config/options and security considerations.

## Idempotence and Recovery

Remote operations must be retryable: downloads write to temp dir then move atomically; installs validate and rollback on failure; caches can be cleared from UI/CLI; repeated imports skip/rename on conflict. CLI commands should be safe to rerun. Provide `--dry-run` where feasible.

## Artifacts and Notes

- New source files under `Sources/SkillsCore/Remote/`, `Sources/SkillsInspector/Remote/`, CLI command additions, and tests.
- Updated docs and schemas capturing remote configuration and usage.
- Evidence: test output, sample JSON from `skillsctl remote list`, screenshots of Remote tab (store in `.ios-web/` or temp, not committed unless requested).

## Interfaces and Dependencies

- New dependency: none beyond Foundation/SwiftUI; reuse existing Markdown renderer. If HTTP image loading is needed, use `AsyncImage` with caching or lightweight loader; avoid third-party additions unless justified.
- RemoteSkillClient interface:
    fetchLatest(limit:Int) async throws -> [RemoteSkill]
    search(query:String, limit:Int) async throws -> [RemoteSkill]
    fetchDetail(slug:String) async throws -> RemoteSkillOwner?
    fetchLatestVersion(slug:String) async throws -> String?
    download(slug:String, version:String?) async throws -> URL
- Installer interface:
    install(from url: URL, target: SkillInstallTarget, overwrite: Bool) async throws -> RemoteSkillInstallResult
- CLI contract: `skillsctl remote <subcommand>` with JSON/text output schemas documented.

