# Performance Targets (SkillsInspector)

**Owner:** jamiecraik **Last updated:** 2026-01-18

## Scope

Local-first performance budgets for scan/index/search workflows. Targets:
for macOS on an Apple Silicon laptop unless stated otherwise.

## Budgets

| Area | Target |
| --- | ---: |
| Scan (validation, 1k skills) | <= 5.0s |
| Scan (validation, 1k skills, cold) | <= 8.0s |
| Search index rebuild (1k skills) | <= 6.0s |
| Search query (simple term) | <= 250ms |
| Search query (complex term) | <= 500ms |
| Remote install preflight (manifest check) | <= 300ms |

## Measurement Notes

- Record machine details: model, RAM, OS version.
- Run each measurement 3x and report median.
- Capture cache hit rate for scan results when applicable.
- For UI latency, capture timestamps around async tasks.

## Regression Policy

- Any regression > 20% in any metric requires investigation and a mitigation

  plan before release.
