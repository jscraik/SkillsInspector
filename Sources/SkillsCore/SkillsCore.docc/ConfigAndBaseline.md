# Config and Baseline Files

How to configure scanning policy and manage baselines/ignores for `skillsctl`.

## Config (`.skillsctl/config.json`)

See `docs/config-schema.json` for the full JSON Schema.

### Config example

```json
{
  "schemaVersion": 1,
  "scan": {
    "recursive": true,
    "maxDepth": 4,
    "excludes": [".git", ".system"],
    "excludeGlobs": ["**/__pycache__/**"]
  },
  "policy": {
    "strict": false,
    "codexSymlinkSeverity": "warning",
    "claudeSymlinkSeverity": "warning"
  },
  "sync": {
    "aliases": {
      "old-skill-name": "new-skill-name"
    }
  }
}
```

### Fields

- `schemaVersion`: integer, current version `1`.
- `scan`: optional defaults for recursion, depth, excludes/globs.
- `policy`: optional severity overrides and strict mode (promote warnings to

  errors).

- `sync.aliases`: optional map to treat skill names as matching during sync.

## Baseline (`.skillsctl/baseline.json`)

Use to suppress known findings until fixed. Shape matches
`FindingOutput` subset.

### Baseline example

```json
{
  "schemaVersion": 1,
  "findings": [
    {
      "ruleID": "frontmatter.missing_description",
      "file": "./.codex/skills/foo/SKILL.md"
    }
  ]
}
```

## Ignore file

Same shape as baseline; intended for local ignores. Pass via `--ignore
<path>`.

## CLI usage

- `--config <path>`: load config.
- `--baseline <path>`: apply baseline suppression.
- `--ignore <path>`: apply extra ignores.

## See Also

- ``SkillsConfig``
- ``FindingOutput``
- ``ScanOutput``
- `docs/config-schema.json`
- `docs/baseline-schema.json`
