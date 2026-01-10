# skillsctl / SkillsLintPlugin / sTools app usage
Last updated: 2026-01-10

## CLI (skillsctl)

Scan repo roots (preferred for CI):

```
swift run skillsctl scan --repo .
```

Scan home roots:

```
swift run skillsctl scan --codex ~/.codex/skills --claude ~/.claude/skills
```

Key options:
- `--recursive` and `--max-depth <n>`: walk nested trees.
- `--exclude <name>` (repeatable) and `--exclude-glob <pattern>`: skip dirs/files.
- `--allow-empty`: exit 0 even if no SKILL.md found.
- `--format json --schema-version 1`: machine output (schema in `docs/schema/findings-schema.json`).
- `--skip-codex` / `--skip-claude`: skip one side when only one tree exists.
- `--no-default-excludes`: include `.git`, `.system`, `__pycache__`, `.DS_Store`.
- `--no-cache`: disable incremental cache; `--show-cache-stats` prints hit rate.
- `--jobs <n>`: control concurrency (defaults to CPU count).
- Exit codes: 0 success/no errors; 1 validation errors or empty tree without `--allow-empty`; 2 usage/config error.

Sync check:

```
swift run skillsctl sync-check --repo .
```

Generate an index (Skills.md) and optionally bump version:

```
swift run skillsctl index --repo . --write --bump patch
```

## Command plugin (SkillsLintPlugin)

Run in any SwiftPM project containing `.codex/skills` / `.claude/skills`:

```
swift package plugin skills-lint
```

The plugin shells to `skillsctl scan --repo . --format json --allow-empty`, maps JSON findings to SwiftPM diagnostics, and fails on any error severity.

## SwiftUI app (sTools / SkillsInspector executable name)

```
swift run SkillsInspector
```

- Defaults to home roots; use “Select” buttons to choose folders (shows hidden dirs).
- Toggle recursive, filter by severity/agent/rule ID, open file in Finder via row action.
- View sync diff summary for Codex vs Claude roots.
- Clear cache from the app settings; toggle watch mode for auto-rescan (500ms debounce).
