# Repository Guidelines

## Project Structure & Modules

- `Sources/SkillsInspector/`: macOS SwiftUI app (`Validate`, `Stats`, `Sync`,
  `Index`,

  Remote, Changelog) plus glass styling helpers.

- `Sources/SkillsCore/`: indexing/validation logic, loaders, remote skill

  client.

- `Sources/skillsctl/`: CLI entrypoint.
- `Tests/SkillsInspectorTests`, `Tests/SkillsCoreTests`: unit + snapshot

  coverage.

- `docs/` and `docs/schema/`: schemas, exec plans, configuration references.

## Build, Test, Run

- Build app: `swift build -c debug --product SkillsInspector`
- Launch app after build: `open SkillsInspector.app`
- Run CLI: `swift run skillsctl --help`
- CLI security scan: `swift run skillsctl security scan {skill-path}`
- CLI quarantine review:
  - `swift run skillsctl quarantine list`
  - `swift run skillsctl quarantine approve {id}`
  - `swift run skillsctl quarantine block {id}`

- Run tests: `swift test` (set `ALLOW_CHARTS_SNAPSHOT=1` to include chart

  snapshots)

## Coding Style & Naming

- Swift indent 4 spaces; keep trailing commas in multiline literals.
- Use DesignTokens for colors/spacing; prefer `glassBarStyle` /

  `glassPanelStyle` over ad-hoc materials.

- View ordering: Environment/let → @State/@ObservedObject → computed vars →

  `body` → helpers.

- Naming: PascalCase types, camelCase vars/funcs; tests
  `test{Feature}{Expectation}()`.

## Testing Guidelines

- Framework: SwiftPM tests; snapshots in `UISnapshotsTests`.
- Update snapshot hashes only when intentional UI changes occur.
- Add focused tests for new logic; prefer async/await for concurrency flows.
- Required before PR: `swift test`; note skipped chart snapshot

  unless env set.

## Commit & PR Guidelines

- Commit messages: short, imperative (e.g., "Fix index sidebar scroll"); sign

  via 1Password SSH agent.

- Avoid `--no-verify`; keep unrelated changes out of the commit.
- PRs: include summary, scope, tests run, screenshots/GIFs for UI, and linked

  issue/Work Packet ID; call out schema/token changes explicitly.

## Security & Configuration Tips

- Never hardcode secrets; use 1Password/ENV. Respect `PathValidator` (reject

  traversal).

- Keep design tokens authoritative; add tokens before using raw hex/spacing.
- Remote flows follow schemas in `docs/schema/`; keep API changes documented.

## Agent Instructions

- Read before significant work: `~/.codex/AGENTS.override.md`, `AGENTS.md`,

  `~/.codex/instructions/**.md`.

- Stay within planned scope/diff budget; avoid drive-by refactors.
- If signing fails, unlock 1Password agent, then commit/push.
