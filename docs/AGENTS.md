# AGENTS.md

## Project summary

sTools provides a macOS SwiftUI app plus a Swift CLI and SwiftPM plugin:

- `SkillsInspector`: SwiftUI macOS app
- `skillsctl`: CLI for scanning, sync-check, indexing, security, and workflow
- `SkillsLintPlugin`: SwiftPM command plugin for CI validation

## Working agreements for Codex

- Prefer small, targeted diffs. Avoid refactors unless explicitly requested.
- Do not add new dependencies without approval.
- Follow existing patterns and naming conventions.
- Keep accessibility intact when touching UI.

## Build, test, run

- Build app: `swift build -c debug --product SkillsInspector`
- Launch app after build: `open SkillsInspector.app`
- Run CLI: `swift run skillsctl --help`
- Run tests: `swift test` (set `ALLOW_CHARTS_SNAPSHOT=1` to include chart
  snapshots)
- Plugin: `swift package plugin skills-lint`

## Coding style and naming

- Swift indent 4 spaces; keep trailing commas in multiline literals.
- Use DesignTokens for colors/spacing; prefer `glassBarStyle` and
  `glassPanelStyle`.
- View ordering: Environment/let -> @State/@ObservedObject -> computed vars ->
  `body` -> helpers.
- Naming: PascalCase types; camelCase vars/functions.

## Testing guidelines

- SwiftPM tests; snapshots live in `Tests/SkillsInspectorTests`.
- Update snapshot hashes only for intentional UI changes.
- Add focused tests for new logic.
- Required before PR: `swift test`.

## Commit and PR guidelines

- Commit messages: short, imperative, signed via 1Password SSH agent.
- Avoid `--no-verify`; keep unrelated changes out of commits.
- PRs include summary, scope, tests, and screenshots for UI changes.

## Security and configuration

- Never hardcode secrets; use 1Password or environment variables.
- Respect `PathValidator` and avoid path traversal.
- Keep design tokens authoritative; add tokens before raw hex/spacing.
- Remote flows follow schemas in `docs/schema/`; document API changes.
