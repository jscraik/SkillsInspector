# CLI Usage

Learn how to run the `skillsctl` command-line tool to scan and sync
Codex/Claude skill trees.

## Overview

`skillsctl` provides fast validation of SKILL.md files and drift detection
between Codex and Claude roots. It supports repo-scoped and home-scoped roots,
JSON output for CI, and policy controls via config/baseline/ignore files.

## Install

Built from this SwiftPM package. From the repo root:

```bash
swift build -c release
```

The binary will be under `.build/release/skillsctl`.

## Common commands

- **Scan (repo mode, preferred for CI):**

  ```bash
  skillsctl scan --repo . --format json
  ```

- **Scan home skills:**

  ```bash
  skillsctl scan --codex ~/.codex/skills --claude ~/.claude/skills \
    --default-excludes
  ```

- **Sync check:**

  ```bash
  skillsctl sync-check --repo .
  ```

## Key flags

- `--format json|text` (default: text)
- `--config <path>`: load `.skillsctl/config.json` (see Config Schema article)
- `--baseline <path>`: suppress known findings
- `--ignore <path>`: additional ignore list
- `--default-excludes`: skip common system dirs
- `--exclude <glob>` (repeatable): extra directory globs to skip
- `--recursive`: recursively scan for SKILL.md
- `--max-depth <n>`: limit recursion depth
- `--plain`: disable styled output
- `--log-level <level>`: control verbosity
- `--schema-version 1`: emit JSON with schema version

## Exit codes

- `0`: no errors
- `1`: validation errors present
- `2`: usage/config failure

## JSON output

Use `--format json` to emit `ScanOutput` with `FindingOutput` entries matching
`docs/schema/findings-schema.json`.

## Examples

- Repo scan with baseline and ignores:

  ```bash
  skillsctl scan --repo . \
    --baseline .skillsctl/baseline.json \
    --ignore .skillsctl/ignore.json \
    --format json
  ```

- Home scan with recursive search and excludes:

  ```bash
  skillsctl scan --codex ~/.codex/skills --claude ~/.claude/skills \
    --recursive \
    --exclude "*/vendor/*" \
    --format json
  ```

- Sync check with globs excluded:

  ```bash
  skillsctl sync-check --repo . \
    --exclude "*/.system/*" \
    --exclude "*/__pycache__/*"
  ```

## See Also

- ``SkillsCore``
- ``SkillsConfig``
- ``ScanOutput``
- ``FindingOutput``
