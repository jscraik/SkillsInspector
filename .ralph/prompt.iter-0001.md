# Ralph Loop — Claude Code

Iteration: 1
Workspace: /Users/jamiecraik/dev/sTools

## Read these files first (anchors + rails)
1) .ralph/pin.md
2) .ralph/plan.md
3) .ralph/guardrails.md
4) .ralph/progress.md

## Also read (repo instructions)
- AGENTS.md

## PRD file
- prd.json

## Operating rules
- Keep context minimal: use targeted search (Grep/Glob) to find relevant files; avoid reading huge files end-to-end.
- Work on ONE objective only (single checkbox OR the single PRD story provided).
- Prefer linkage over invention: before changing code, cite the relevant spec section and file(s) you will edit.
- Follow existing conventions in the repo (style, linting, tests, i18n, etc).
- Add/adjust tests where appropriate.
- Keep changes small and incremental; do not do broad refactors unless required by the pin/spec.
- If something fails repeatedly, add a short reusable "Sign" to guardrails.md.

## Current objective
MODE: PRD
PRD file: prd.json
Stories array key: stories
Selected story index: 13
Selected story id: S14
Selected story title: Feature Flags and Governance

Your single objective this iteration is to make this story pass.
Do NOT edit other stories. Keep changes minimal and linked to the pin/plan.

## Signals (print exactly one at the end)
- If you believe the objective is done and checks are green: <ralph>DONE</ralph>
- If you are blocked after 2 serious attempts: <ralph>GUTTER</ralph>
