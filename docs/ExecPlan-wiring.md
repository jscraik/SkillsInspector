# sTools wiring and settings integration

This ExecPlan is a living document. The sections `Progress`, `Surprises &
Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up
to date as work proceeds. Followed according to
`/Users/jamiecraik/.codex/instructions/plans.md`.

## Purpose / Big Picture

Enable users to: (a) trigger scan/sync/index from menu shortcuts in any mode,
(b) pick and persist Codex/Claude skill roots via UI, and (c) index all Codex
roots instead of only the first. Acceptance is observable through UI
interactions and tests.

## Progress

- [x] (2026-01-10T00:00Z) Read standards and wiring notes; drafted ExecPlan.
- [x] (2026-01-10T17:45Z) Wired menu commands into SyncView and IndexView with

  cancel support.

- [x] (2026-01-10T17:55Z) Replaced sidebar roots with interactive pickers;

  added persistence and validation.

- [x] (2026-01-10T18:05Z) Shared recursive/exclude/maxDepth settings across

  modes via InspectorViewModel.

- [x] (2026-01-10T18:08Z) Extended SkillIndexer for multi-root Codex; updated

  IndexViewModel and tests.

- [x] (2026-01-10T18:10Z) Ran swift test (all pass, 1 skip expected for

  charts); updated retrospective pending.

## Surprises & Discoveries

- None yet.

## Decision Log

- Decision: Use UserDefaults to persist roots/settings to avoid new deps and

  keep offline behavior. Rationale: Minimal surface change, aligns with
  existing local-only app. Date/Author: 2026-01-10 / assistant.

## Outcomes & Retrospective

- Menu wiring, root management, shared settings, and multi-root index

  implemented; full `swift test` passing (one expected skip for charts). No
  open blockers observed.

## Context and Orientation

Key files: `Sources/SkillsInspector/App.swift` (menu commands),
`ContentView.swift` (sidebar, mode navigation), `InspectorViewModel.swift`
(shared state), `SyncView.swift`, `IndexView.swift`,
`Sources/SkillsCore/Indexer.swift` (index generation),
`Tests/SkillsInspectorTests` (existing coverage). Current issues: menu
notifications only handled in `ValidateView`; roots hardcoded and not
editable; recursive/exclude settings divergent; `SkillIndexer.generate` only
accepts single Codex root.

## Plan of Work

1) Menu dispatch: add listeners in SyncView and IndexView (or shared
dispatcher) for `.runScan`/`.cancelScan`/`.toggleWatch`/`.clearCache` where
applicable, invoking view model actions with current settings and respecting
cancellation. 2) Root management UI: replace static root list in sidebar with
`RootRow` components for each Codex root plus Claude; add add/remove for Codex
roots; reuse `validateRoot`; surface validation errors; persist roots/settings
in shared model backed by UserDefaults (`UserSettings` struct). 3) Shared
settings: move recursive/excludes/maxDepth to `InspectorViewModel`; pass
bindings to Sync/Index views; remove local duplicates; centralize default
excludes constant. 4) Multi-root indexing: extend `SkillIndexer.generate` to
accept `[URL]` or add overload; update IndexViewModel to pass full array;
merge results; ensure stable ordering; adjust index UI to display active roots
state. 5) Tests and validation: add unit tests for multi-root index and
settings persistence/validation; if UI coverage limited, add ViewModel-level
tests for notification handling and UserDefaults serialization.

## Concrete Steps

1) Implement UserSettings persistence in `InspectorViewModel` with load/save
on change (use `@Published` observers). Add shared `defaultExcludes`. 2)
Update `ContentView` sidebar: iterate codexRoots with `RootRow`, add
add/remove buttons, bind recursive/excludes/maxDepth inputs; ensure alert
shows validation errors. 3) Update `SyncView` to accept bindings for settings
and to listen to menu notifications; remove local state copies. 4) Update
`IndexViewModel` to accept `[URL]`; update `IndexView` to use shared settings
and add `.onReceive` for menu commands. 5) Modify `SkillsCore/Indexer.swift`
with overload taking `[URL]` merging entries; keep legacy single-root API
delegating. 6) Add tests in `Tests/SkillsInspectorTests` for multi-root index
generation and settings persistence. 7) Run `swift test` (or subset) and
record results.

## Validation and Acceptance

- Menu shortcuts (`⌘R`, `⌘.`) trigger sync/index when respective mode is

  active; observe operations start/stop.

- Roots can be added/removed and persist across relaunch (UserDefaults);

  invalid paths show alert and are not saved.

- Index includes entries from multiple Codex roots (e.g., two temp dirs with

  distinct skills yield combined list).

- `swift test` passes.

## Idempotence and Recovery

UserDefaults-backed settings are overwritten atomically on change; reloading
app restores last saved settings. Notification handlers are guarded against
invalid roots to avoid crashes. Operations cancel previous tasks before
starting new ones.

## Artifacts and Notes

- None yet.

## Interfaces and Dependencies

- New/updated API: `SkillIndexer.generate(codexRoots: [URL], claudeRoot: URL?,

  include: IndexInclude, recursive: Bool, maxDepth: Int?, excludes: [String],
  excludeGlobs: [String]) -> [SkillIndexEntry]`; legacy single-root overload
  preserved.
