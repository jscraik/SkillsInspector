# sTools Product Manager Output (R2, Gold Baseline)

## Elevator Pitch

- R2 upgrade of sTools (SwiftUI app + CLI + SwiftPM plugin) that inspects

  Skills.md, scripts, and references, keeps changelog/parity across Codex CLI,
  Claude Code, and Copilot, and interoperates directly with CodexSkillManager
  without cloning copies.

## Problem Statement

- Developers managing multi-agent skill trees lack a unified, accessible way

  to audit, diff, and keep Skills.md + scripts/references in sync across
  ecosystems; current UI/UX friction and missing CodexSkillManager interop
  impede reliable parity and changelog tracking.

## Target Audience

- Developers maintaining Skills.md trees for Codex CLI, Claude Code, and

  Copilot (paths: repo roots, ~/.copilot/skills/, CodexSkillManager working
  tree).

## USP

- Single toolchain-aware inspector that reads live CodexSkillManager checkout,

  aggregates parity/changelog across all AI tool roots, applies best-practice
  lint rules, and surfaces actionable diffs with accessible UI and
  deterministic CLI outputs.

## Target Platforms

- macOS SwiftUI app (sTools), Swift CLI (skillsctl), SwiftPM plugin

  (skills-lint). No new web surface in this slice.

## Features List

- Feature Category: Interop & Parity
  - Feature: CodexSkillManager integration (R2) — Work Packet WP-CSM-01 (≤600

    LOC)

    - User Stories: As a developer, I can point sTools at a live

      CodexSkillManager checkout and run a parity scan, so I can see gaps vs
      Codex/Claude/Copilot skill roots without juggling copies.

    - Acceptance (AC-CSM-01):
      - Given a valid CodexSkillManager path, When I run scan/sync, Then

        parity results include CodexSkillManager data in the combined report.

      - Given a missing/invalid path, When I run scan, Then I get a clear

        error with remediation and no crash.

      - Given path traversal attempts, When validated, Then the operation

        rejects and logs without exposing file contents.

    - Accessibility: keyboardable path entry; status updates via

      role="status"; high-contrast badges; focus returns after scan.

    - Auth/Threat Model: local FS only; no implicit network clone; path

      normalization; reject traversal; redact paths in logs.

    - Logging/PII: structured logs with service id; no secrets/paths;

      summary counts only.

    - Rollout/Rollback: gated by CLI flag `--csm-path <path>` and UI toggle;

      rollback by disabling flag/toggle.

- Feature Category: Parity Dashboard & Changelog
  - Feature: Parity + changelog view (R2) — Work Packet WP-PARITY-02 (≤600

    LOC)

    - User Stories: As a developer, I can see per-model parity status

      (Codex/Claude/Copilot/CodexSkillManager) and view changelog deltas
      derived from Skills.md history to understand drift quickly.

    - Acceptance (AC-PARITY-02):
      - Given roots for the three toolchains and CodexSkillManager, When scan

        completes, Then cards show counts of matched/missing/divergent items
        and a drill-down diff list.

      - Given empty roots, When scan runs, Then an empty-state with guidance

        appears and exit code remains 0.

      - Given long-running scans, When progress updates, Then progress text reads

        in screen readers and keyboard focus stays intact.

    - Accessibility: semantic lists, visible focus, live-region updates, text

      labels on badges, keyboard navigation for drill-down.

    - Logging/PII: only summary counts and hash comparisons; no file

      contents.

    - Rollout/Rollback: default on; feature flag `parity_dashboard=false` to

      disable.

- Feature Category: Best-Practice Validation
  - Feature: Skills.md/scripts/references lint (R1) — Work Packet WP-LINT-03

    (≤400 LOC)

    - User Stories: As a developer, I get actionable findings for missing

      frontmatter/description/version, schema drift, invalid references, or
      incomplete changelog entries.

    - Acceptance (AC-LINT-03):
      - Given a Skills.md missing description/version, When scan runs, Then a

        finding lists rule id and suggested fix.

      - Given malformed frontmatter, When scan runs, Then scan reports an

        error and continues other files.

      - Given a changelog missing for a detected diff, When scan runs, Then a

        warning suggests adding an entry.

    - Accessibility: results list keyboardable; status icons have text

      equivalents.

    - Rollout/Rollback: rules enabled by default; disable via config without

      code change.

## UX/UI Considerations

- States: loading, progress, success, empty, error; non-blocking scans;

  progress % and counts.

- Layout: parity cards per toolchain, diff drawer, changelog timeline, cache

  status chip.

- Interaction: ⌘R rescan, keyboardable toggles, focus return after actions,

  copy-to-clipboard for findings.

- Visuals: text + color badges (no color-only), motion kept minimal; ensure

  contrast.

- Error handling: inline, non-modal; preserves context and retry affordance.

## Advanced Users & Edge Cases

- Large trees (>5k skills): chunked scanning, streaming progress; abortable

  scan.

- Missing/invalid config: surfaced with CTA to create baseline/ignore files.
- Offline: operates on local trees only; no implicit network access.

## Non-Functional Requirements

- Performance: incremental cache + parallel jobs; target <5s for 1k files;

  deterministic ordering.

- Reliability: stable exit codes (0 success/no findings, 1 validation errors,

  2 usage).

- Security: OWASP ASVS 5.0 alignment; path traversal guard; no secret logging;

  structured logs with service id.

- Accessibility: WCAG 2.2 AA; macOS AX roles/labels; keyboard-only flow

  supported.

## Monetization

- None; OSS/internal utility.

## Rollout / Rollback / Monitoring

- Feature flags: `--csm-path`, `parity_dashboard`, lint rule toggles.
- Rollback: disable flags/toggles; revert to prior version; cache clear

  fallback.

- Monitoring signals: scan duration, cache hit rate, counts of

  missing/divergent skills, error rates by rule.

## Work Packets & Traceability

- WP-CSM-01 (R2, ≤600 LOC) ↔ AC-CSM-01.
- WP-PARITY-02 (R2, ≤600 LOC) ↔ AC-PARITY-02.
- WP-LINT-03 (R1, ≤400 LOC) ↔ AC-LINT-03.

## Open Questions

- None pending; user confirmed live CodexSkillManager checkout usage and

  parity fields = all.

## Acceptance References (Given/When/Then)

- AC-CSM-01, AC-PARITY-02, AC-LINT-03 (see above per feature).

## Security, Privacy, Logging

- Local-only FS reads; path normalization; reject traversal; redact

  paths/tokens; structured logs with service field.

## Accessibility Checklist

- Keyboard operable for all controls; visible focus; role="status" for

  progress; text + color badges; screen-reader labels on results, toggles, and
  progress.

## Threat/Trust Boundary (R2)

- New boundary: reading CodexSkillManager working tree; mitigation: path

  validation, no network clone, log redaction, deterministic processing.

## Dependencies/Integrations

- Uses existing sTools stack; no new runtime deps anticipated; interop with

  CodexSkillManager via local path read.

## Testing Strategy

- Unit: rule validations, parity aggregator, changelog parser.
- Integration: end-to-end scan with sample roots

  (Codex/Claude/Copilot/CodexSkillManager).

- A11y smoke: keyboard navigation + VoiceOver for progress/result lists.

## Release Notes Stub

- Added CodexSkillManager interop, parity dashboard across

  Codex/Claude/Copilot, and best-practice lint for
  Skills.md/scripts/references with accessible UI and deterministic CLI
  outputs.
