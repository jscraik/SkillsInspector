# QA Checklist (SkillsInspector)

**Owner:** jamiecraik **Last updated:** 2026-01-18

## Core Validation

- [ ] Check scan honors excludes, exclude globs, and max depth across
  Check/Index/Search.

- [ ] Search index excludes `.git`, `.system`, `__pycache__`, `.DS_Store` and
  configured globs.

- [ ] Search index file size reflects SKILL.md size (or defined summary rules).

- [ ] Agent classification in search index matches actual root agent
  (Codex/Claude/Copilot).

## Security Settings

- [ ] Security preset selection persists after relaunch.
- [ ] Custom allowlist/blocklist changes persist after relaunch.
- [ ] Remote install honors SecurityConfig (block/quarantine behavior visible
  in UI).

- [ ] Quarantine count updates and review flow opens without error.

## Search UX

- [ ] Search errors display actionable messaging.
- [ ] Clearing search query resets selection and detail panel correctly.
- [ ] Search stats sheet opens and shows index totals.

## Indexing (Search Index)

- [ ] If `skillsctl help index` exposes search-index subcommands, run:
  - `skillsctl index build` completes with correct totals.
  - `skillsctl index rebuild` completes and stats update.
  - `skillsctl index stats` totals match the app Search stats view.

## Watch Mode

- [ ] Watch mode triggers scans only on relevant `.md` / `SKILL` changes.
- [ ] Watch mode stops cleanly when disabled.

## Regression Checks

- [ ] No crash on launch.
- [ ] No blank panes on initial navigation.
- [ ] No stale selection after data refresh.

## Charts Snapshot (GUI)

- [ ] Run chart snapshot in a GUI session (active desktop) with:
  - `ALLOW_CHARTS_SNAPSHOT=1 swift test --filter UISnapshotsTests.testStatsChartsSnapshotHash`

- [ ] When charts change intentionally, update `STATS_CHARTS_HASH` and re-run

  the same command.
