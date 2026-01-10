# UI Snapshot Testing Guide (SkillsInspector)

## Purpose
Lock visually significant surfaces (cards, charts, markdown preview) with deterministic snapshot hashes to catch unintended drift when tokens or layouts change.

## Targets
- StatsView (Charts-based) — uses deterministic renderer.
- MarkdownPreviewView — rendered markdown content.

## How snapshots are produced
- `Tests/SkillsInspectorTests/UISnapshotsTests.swift` uses `ImageRenderer` to render SwiftUI views offscreen and SHA256s the raw image bytes.
- Hashes are asserted in tests; update them only after visual review/approval.

## Running tests
- Run only snapshots: `swift test --parallel --filter UISnapshotsTests`
- Run full suite: `swift test --parallel`

## Updating hashes (when visuals intentionally change)
1) Run `swift test --filter UISnapshotsTests` to see failing expected/actual hashes.
2) Visually review the affected UI in the app or via temporary renders.
3) Replace the expected hash constants in `UISnapshotsTests.swift` with the new values.
4) Re-run `swift test --filter UISnapshotsTests` to confirm green.
5) Commit with a note explaining the intentional visual change.

## Determinism tips
- Keep renderer size fixed per snapshot (see tests).
- Avoid non-deterministic data (timestamps, random values); seed any sample data.
- For Charts, prefer fixed datasets and disable animations.

## Accessibility & preferences
- Prefer Reduced Motion safe states in snapshots to avoid animation variance.
- Use light mode unless a dark/HC variant is explicitly added with its own hash.
