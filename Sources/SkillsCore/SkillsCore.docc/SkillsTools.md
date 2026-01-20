# ``SkillsCore``

Check and reconcile Codex/Claude skill trees (`SKILL.md`) with a single,
testable engine.

## Overview

`SkillsCore` powers the `skillsctl` CLI, the SwiftUI macOS app now branded as
**sTools** (executable target name `SkillsInspector`), and the
`SkillsLintPlugin` SwiftPM command plugin. It scans skill roots, validates
required frontmatter, enforces Codex/Claude naming rules, detects symlink
issues, and reports findings in JSON for CI consumption.

### Main features

- **Scanning & validation**: required frontmatter, name/description presence,

  length/pattern rules per ecosystem, symlink checks.

- **Sync reporting**: detect skills only in Codex, only in Claude, or with

  differing content.

- **Config/baseline**: load `.skillsctl/config.json`, baseline, and ignore

  lists to control severity and noise.

- **Hashing**: stable SHA-256 content checks for drift detection.

### Data model

- ``AgentKind``: identifies the ecosystem (Codex or Claude).
- ``Severity`` and ``Finding``: normalized validation results (rule ID,

  severity, location, message, optional line/column).

- ``SkillDoc``: parsed frontmatter plus filesystem metadata.
- ``SyncReport``: missing/different skills across roots.
- ``ScanOutput`` / ``FindingOutput``: JSON-friendly payloads for CLI/plugin

  output.

### Scanning

Use ``SkillsScanner/findSkillFiles(roots:excludeDirNames:excludeGlobs:)`` to
locate `SKILL.md` files and ``SkillLoader/load(agent:rootURL:skillFileURL:)``
to parse them. ``SkillValidator/validate(doc:)`` returns findings for each
doc.

### Sync operations

Use
``SyncChecker/byName(codexRoot:claudeRoot:recursive:excludeDirNames:excludeGlobs:)``
to compare roots by skill name and SHA-256 content.

## Topics

### Core Types

- ``AgentKind``
- ``Severity``
- ``RuleID``
- ``Finding``
- ``SkillDoc``
- ``ScanRoot``
- ``SyncReport``
- ``ScanOutput``
- ``FindingOutput``

### Scanning & Validation

- ``SkillsScanner``
- ``SkillLoader``
- ``SkillValidator``
- ``FrontmatterParser``

### Sync

- ``SyncChecker``
- ``SkillHash``

### Configuration

- ``SkillsConfig``
- ``PathUtil``

### Utilities

- ``PathUtil/glob(_:matches:)``
