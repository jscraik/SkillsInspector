# Build SwiftPM Skills Tools (scan/sync + CLI/UI/plugin)

This ExecPlan is a living document. Keep `Progress`, `Surprises &
Discoveries`, `Decision Log`, and `Outcomes & Retrospective` up to date as
work proceeds. Follow `/Users/jamiecraik/.codex/instructions/plans.md` for
required structure.

## Purpose / Big Picture

Deliver a SwiftPM package that validates and compares Codex/Claude skill trees
(`SKILL.md` files) with three entry points: a reusable library, a CLI
(`skillsctl`), and a SwiftUI macOS inspector (`SkillsInspector`). Also include
a SwiftPM command plugin so external projects can run the scan in CI. Users
will be able to scan repo or home skill roots, detect missing/differing
skills, and view results in text/JSON or an interactive UI.

## Progress

- [x] (2026-01-10) Scaffold SwiftPM package structure (Products: SkillsCore,

  skillsctl, SkillsInspector; Plugin: SkillsLintPlugin; Tests folder).

- [x] (2026-01-10) Implement SkillsCore: scanning, frontmatter parser,

  validation rules, sync-check logic.

- [x] (2026-01-10) Implement `skillsctl` CLI with `scan` and `sync-check`

  commands (text/JSON output, exit codes).

- [x] (2026-01-10) Implement SwiftUI app `SkillsInspector` with basic scan UI.
- [x] (2026-01-10) Implement SwiftPM command plugin `SkillsLintPlugin`

  invoking skillsctl and emitting diagnostics.

- [x] (2026-01-10) Add fixtures/tests for parser/validator/sync-check; run

  `swift test`.

- [x] (2026-01-10) Validation: run `swift test`; run `swift run skillsctl scan

  --help` and `sync-check --help`.

- [x] (2026-01-10) Outcomes & retrospective update.

## Surprises & Discoveries

- SwiftPM command plugins cannot depend on library targets directly; they can

  only use executable or binary tools. Resolved by invoking `skillsctl` and
  parsing its JSON output.

## Decision Log

- Chose to have `SkillsLintPlugin` invoke the `skillsctl` executable (via JSON

  output) instead of linking `SkillsCore`, because SwiftPM command plugins
  cannot depend on library targets.

## Outcomes & Retrospective

- Delivered SwiftPM package with library, CLI, SwiftUI app, and command

  plugin. Core scan/sync logic in `SkillsCore`; CLI provides text/JSON output;
  plugin shells to `skillsctl`.

- Test suite (5 tests) passes via `swift test`. CLI help commands succeed.
- Remaining future work: add Outcomes section updates when extending features

  (index/changelog, additional rules).

## Context and Orientation

Repository `cLog` is newly created and currently contains only `Package.swift`
from `swift package init --type empty`. We will add:

- `Sources/SkillsCore/` for the reusable engine.
- `Sources/skillsctl/` for the CLI.
- `Sources/SkillsInspector/` for the SwiftUI macOS executable.
- `Plugins/SkillsLintPlugin/` for the SwiftPM command plugin.
- `Tests/SkillsCoreTests/` for unit tests and fixtures.

Skill roots the tools operate on:

- Repo roots: `./.codex/skills`, `./.claude/skills`
- Home roots: `~/.codex/skills`, `~/.claude/skills`

## Plan of Work

1. Scaffold package layout and update `Package.swift` to declare products:
   `SkillsCore` (library), `skillsctl` and `SkillsInspector` (executables),
   `SkillsLintPlugin` (command plugin), and `SkillsCoreTests`.
2. Implement `SkillsCore`:
   - Data models: `AgentKind`, `Severity`, `RuleID`, `Finding`, `SkillDoc`,
     `ScanRoot`, `SyncReport`.
   - Frontmatter parser (strict top-of-file `---` block, simple `key: value`
     scalars).
   - Scanner to discover `SKILL.md` under roots (shallow by default, optional
     recursive) with excludes.
   - Validators with rule IDs: missing frontmatter, missing name/description,
     length/pattern limits per agent, symlinked skill dir warning/error hook.
   - Sync checker by skill `name` comparing SHA-256 hashes.
3. Implement CLI `skillsctl` (ArgumentParser):
   - Commands: `scan` and `sync-check`.
   - Options: roots (repo/home), excludes, default excludes toggle, JSON/text
     output, exit codes (errors -> 1, usage -> 2).
4. Implement SwiftUI app `SkillsInspector`:
   - Folder pickers (hidden files enabled), default to home roots.
   - Run scan using SkillsCore, display findings list with severity filters
     and counts.
5. Implement SwiftPM command plugin `SkillsLintPlugin`:
   - Command `skills-lint` invoking SkillsCore scan for repo roots.
   - Emit diagnostics for errors/warnings; fail on errors.
6. Add tests in `SkillsCoreTests` with fixtures for valid/invalid SKILL.md,
   length and pattern checks, sync-check diff detection.
7. Validate:
   - `swift test`
   - `swift run skillsctl scan --help`
   - `swift run skillsctl sync-check --help`
   - Optional: `swift run skillsctl scan --allow-empty --repo .`

## Concrete Steps

- Working directory: `/Users/jamiecraik/dev/cLog`
- Commands to run during implementation/validation:
  - `swift build`
  - `swift test`
  - `swift run skillsctl scan --help`
  - `swift run skillsctl sync-check --help`

Expected outcomes:

- CLI help shows `scan` and `sync-check` with described options.
- Tests pass.
- `swift run skillsctl scan --allow-empty --repo .` exits 0 with “No SKILL.md

  files found” message.

## Validation and Acceptance

Implementation is acceptable when:

- `swift test` passes.
- `swift run skillsctl scan --help` and `sync-check --help` work without

  error.

- Running `swift run skillsctl scan --allow-empty --repo .` reports zero

  errors on an empty repo and exits 0.

- Plugin builds with `swift build` (ensuring the command plugin compiles).

## Idempotence and Recovery

All steps are additive. Re-running `swift build`/`swift test` is safe. If a
scan fails due to bad SKILL.md content, fix the files and rerun. No
destructive actions are planned.

## Artifacts and Notes

Artifacts to be produced:

- `Package.swift` defining products and dependencies.
- Source files under `Sources/SkillsCore/`, `Sources/skillsctl/`,

  `Sources/SkillsInspector/`.

- Plugin under `Plugins/SkillsLintPlugin/`.
- Tests under `Tests/SkillsCoreTests/`.

## Interfaces and Dependencies

- Dependencies: Swift ArgumentParser (for CLI). No other external dependencies

  planned.

- Library APIs:
  - `SkillsScanner.findSkillFiles(roots:excludeDirNames:recursive:) ->

    [ScanRoot:[URL]]`

  - `SkillLoader.load(...) -> SkillDoc?`
  - `SkillValidator.validate(doc:) -> [Finding]`
  - `SyncChecker.byName(codexRoot:claudeRoot:recursive:) -> SyncReport`
- CLI commands: `skillsctl scan`, `skillsctl sync-check`.
- Plugin command: `swift package plugin skills-lint`.
