# skillsctl / SkillsLintPlugin / sTools app usage

**Document Requirements:**

- **Audience:** Intermediate developers familiar with Swift/CLI tools
- **Scope:** Complete usage guide for all sTools components
- **Owner:** sTools maintainers
- **Last updated:** 2026-01-17
- **Review cadence:** With each major release

## CLI (skillsctl)

**Repository-scoped scanning (recommended for CI):**

```bash
swift run skillsctl scan --repo .
# Expected: Validation results for .codex/skills and .claude/skills
# Exit codes: 0 (success), 1 (validation errors), 2 (usage error)
```

**Home directory scanning:**

```bash
swift run skillsctl scan --codex ~/.codex/skills --claude ~/.claude/skills
# Expected: Validation results for home skill directories
```

**Verify successful scan:**

- Exit code 0 indicates no validation errors
- JSON output available with `--format json`
- Use `--allow-empty` to succeed when no SKILL.md files found

### Key Options

**Traversal control:**

- `--recursive` and `--max-depth <n>`: Walk nested skill trees
- `--exclude <name>` (repeatable): Skip specific directories/files
- `--exclude-glob <pattern>`: Skip using glob patterns

**Output and behavior:**

- `--format json --schema-version 1`: Machine-readable output (schema:

  `docs/schema/findings-schema.json`)

- `--skip-codex` / `--skip-claude`: Process only one agent's skills
- `--allow-empty`: Exit 0 even when no SKILL.md files found

**Performance:**

- `--no-default-excludes`: Include `.git`, `.system`, `__pycache__`,

  `.DS_Store`

- `--no-cache`: Disable incremental validation cache
- `--show-cache-stats`: Display cache hit rates and performance metrics
- `--jobs <n>`: Control parallel validation (defaults to CPU count)

### Sync Operations

**Compare skill trees between agents:**

```bash
swift run skillsctl sync-check --repo .
# Expected: Report of skills that differ between Codex and Claude
```

**Verify sync results:**

- Lists skills present in only one agent
- Shows content differences for matching skill names
- Use with `--format json` for programmatic processing

### Index Generation

**Create Skills.md index and bump versions:**

```bash
swift run skillsctl index --repo . --write --bump patch
# Expected: Generated Skills.md file with skill inventory
```

**Verify index generation:**

- Skills.md created/updated in skill roots
- Version numbers incremented according to --bump flag
- Index includes all discovered skills with metadata

### Security & Quarantine

**Run ACIP security scan on a skill directory:**

```bash
swift run skillsctl security scan path/to/skill
# Expected: Summary of findings and recommended action (allow/quarantine/block)
```

**Review quarantined items:**

```bash
swift run skillsctl quarantine list
swift run skillsctl quarantine approve <id>
swift run skillsctl quarantine block <id>
# Expected: Approved/rejected status updates for the quarantine item
```

## Command plugin (SkillsLintPlugin)

Run in any SwiftPM project containing `.codex/skills` / `.claude/skills`:

```text
swift package plugin skills-lint
```

The plugin shells to `skillsctl scan --repo . --format json --allow-empty`,
maps JSON findings to SwiftPM diagnostics, and fails on any error severity.

## SwiftUI app (sTools / SkillsInspector executable name)

```text
swift run SkillsInspector
```

- Defaults to home roots; use “Select” buttons to choose folders (shows hidden

  dirs).

- Toggle recursive, filter by severity/agent/rule ID, open file in Finder via

  row action.

- View sync diff summary for Codex vs Claude roots.
- Clear cache from the app settings; toggle watch mode for auto-rescan (500ms

  debounce).

## Troubleshooting

### Common CLI Issues

#### Problem: "No SKILL.md files found" but files exist

```bash
# Check exclusion patterns
skillsctl scan --repo . --no-default-excludes --log-level debug
```

**Solution:** Files may be in excluded directories. Review exclude patterns or
use `--no-default-excludes`.

#### Problem: Validation errors on seemingly valid files

```bash
# Get detailed error information
skillsctl scan --repo . --format json | jq '.findings[] | select(.severity=="error")'
```

**Solution:** Check frontmatter format, required fields, and naming
conventions.

#### Problem: Performance issues with large skill trees

```bash
# Optimize with caching and parallel processing
skillsctl scan --repo . --jobs 8 --show-cache-stats
```

**Solution:** Use caching (default) and adjust `--jobs` for your system.

### App Issues

#### Problem: sTools app won't launch

```bash
# Check build and launch with error output
swift build --product sTools && swift run sTools 2>&1
```

**Solution:** Ensure clean build. Check console for specific errors.

#### Problem: Folder picker doesn't show skill directories

- Enable "Show hidden files" in folder picker
- Check that directories contain SKILL.md files
- Verify directory permissions

### Configuration Issues

#### Problem: Config validation errors

- Check JSON syntax in `.skillsctl/config.json`
- Validate against schema in `docs/config-schema.json`
- Use minimal config and add options incrementally

**Getting Help:**

- Use `--help` flag with any command for options
- Check `--log-level debug` for detailed output
- Review schemas in `docs/schema/` for JSON formats

## Migration & Security Notes

- Remote installs now enforce ACIP scanning; quarantined content blocks

  installs until reviewed.

- Quarantine records are stored at `~/Library/Application

  Support/SkillsInspector/quarantine.json`.

- Use `skillsctl quarantine list` to review pending items and
  `skillsctl quarantine approve <id>` or
  `skillsctl quarantine block <id>` to resolve.
