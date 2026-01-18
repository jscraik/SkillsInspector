# Trustworthy Skills Inspector Improvements (verification, UX, cross-IDE installs)

This ExecPlan is a living document. The sections Progress, Surprises &
Discoveries, Decision Log, and Outcomes & Retrospective must be kept up to
date as work proceeds. This plan follows
/Users/jamiecraik/.codex/instructions/plans.md and is additive to
docs/PLANS.md.

## Purpose / Big Picture

After this change, users can preview remote skills safely, verify them before
install, and install once across Codex, Claude Code, and Copilot with clear
provenance signals. The UI makes the source context obvious (local vs remote),
shows a detail preview panel with signer and changelog information, and
provides bulk actions for verification and updates. The CLI gains explicit
preview and verification commands that match the UI flow. A user can verify
success by installing a remote skill and seeing a verified badge, a ledger
entry, and a successful cross-IDE install result.

## Progress

- [x] (2026-01-12) Added remote artifact verification primitives, limits, and

  stricter installer checks; extended tests for checksum and file-count
  limits.

- [x] (2026-01-12) Added remote preview/manifest client support, preview

  cache, and preview state in RemoteViewModel.

- [x] (2026-01-12) Updated RemoteView to split-view navigation with detail

  preview panel, provenance badges, and bulk toolbar actions.

- [x] (2026-01-13) Added TrustStore persistence and consent UI for per-signer

  allowlisting and revocation display.

- [x] (2026-01-13) Added cross-IDE adapter install flow for Codex, Claude, and

  Copilot with per-target validation and rollback.

- [x] (2026-01-13) Extend skillsctl with preview/verify/install targets and

  JSON error output.

- [x] (2026-01-13) Add SQLite ledger + markdown changelog generator and

  integrate into UI.

- [x] (2026-01-13) Add deterministic publish pipeline with signed attestation

  and pinned tool hash enforcement.

- [x] (2026-01-13) Label API-based preview as “Safe preview from server” and

  gate bulk actions via feature flags.

- [x] (2026-01-13) Add manifest caching, per-skill signer trust scopes, and

  telemetry stubs (opt-in).

- [x] (2026-01-16) Integrate ACIP scanning into remote installs with

  quarantine persistence and config-aware filtering.

- [x] (2026-01-16) Enforce archive MIME checks and update multi-target

  installs to all-or-nothing rollback semantics.

- [x] (2026-01-16) Add signed changelog exports with per-device key stored in

  Keychain and embedded signature block.

- [x] (2026-01-16) Enforce telemetry attribute allowlist and include

  appVersion in telemetry records.

- [x] (2026-01-16) Add signed keyset fetch/verification and refresh trust

  store when a pinned root key is available.

- [x] (2026-01-16) Record ledger verify events for bulk verification

  operations.

- [x] (2026-01-16) Add integration tests for ACIP quarantine, changelog

  signing, and keyset verification.

- [ ] (2026-01-16) Run validation: swift test (targeted + full), UI snapshot

  checks, and CLI smoke commands.

## Surprises & Discoveries

- Observation: Remote ZIPs often contain only a single skill directory and

  SKILL.md, but some archives include additional files; this makes file-count
  enforcement critical to avoid zip-bomb abuse. Evidence:
  RemoteSkillInstallerTests failures during limit enforcement.

- Observation: swift test --filter RemoteSkillClientTests terminated with a

  fatalError during build/link. Evidence: Build output ended with "error:
  fatalError" while linking skillsctl-tool.

- Observation: Tests still fail when using a custom build path because SwiftPM

  cannot download Sparkle's SPM zip (GitHub release asset). Evidence: swift
  test --disable-sandbox --build-path .build-codex ended with NSURLErrorDomain
  -1 while fetching Sparkle-for-Swift-Package-Manager.zip.

- Observation: Even with a local Sparkle override, SwiftPM cannot write

  output-file-map.json (skillsctl-tool.build) and fails with
  NSCocoaErrorDomain 513. Evidence: swift test --disable-sandbox --build-path
  /tmp/stools-build2 returned permission error for output-file-map.json.

## Decision Log

- Decision: Use a hexagonal architecture with ports/adapters so verification

  and policy logic are isolated from UI/CLI/network. Rationale: Keeps
  integrity logic testable and swapable for future sources. Date/Author:
  2026-01-12 / Codex

- Decision: Standardize the ledger on SQLite (not JSONL) to support queryable

  history, changelog generation, and rollbacks. Rationale: Queryability and
  integrity constraints outweigh flat-file simplicity. Date/Author: 2026-01-12
  / Codex

- Decision: Adopt split-view navigation and a detail preview panel based on

  CodexSkillManager to reduce user confusion and increase trust context.
  Rationale: Proven UX pattern observed in recon and aligns with consent-based
  preview. Date/Author: 2026-01-12 / Codex

- Decision: Treat preview cache as potentially hostile and validate cached

  preview against manifest hash/ETag. Rationale: Prevent cache poisoning and
  stale metadata from bypassing consent. Date/Author: 2026-01-12 / Codex

- Decision: Use a local Sparkle binary override (LocalSparkle) to avoid

  dependency fetch failures during tests. Rationale: GitHub release asset
  downloads fail in this environment; local binary allows SwiftPM to resolve
  without network. Date/Author: 2026-01-13 / Codex

## Outcomes & Retrospective

- (2026-01-13) Ledger-backed changelog generation is now available in the UI,

  with SQLite-backed event storage and a basic ledger history panel. Remote
  installs now emit ledger entries for successful and failed installs.

- (2026-01-13) skillsctl remote now supports preview, verify, and

  install/update flows with structured JSON errors and schema-validated
  outputs.

- (2026-01-13) Publish pipeline now builds deterministic zip artifacts, signs

  attestation with an Ed25519 key, and enforces tool hash pinning before
  running the publisher.

- (2026-01-16) Remote installs now enforce ACIP scanning, MIME checks, and

  all-or-nothing rollback across targets. Changelog exports are signed with a
  per-device key, telemetry is schema-sanitized, and trust stores can refresh
  from a signed remote keyset when configured.

## Context and Orientation

Repository root is /Users/jamiecraik/dev/sTools. The core domain logic is in
Sources/SkillsCore, the macOS UI is in Sources/SkillsInspector, and the CLI is
in Sources/skillsctl. Remote installation logic currently lives in
Sources/SkillsCore/Remote/RemoteSkillInstaller.swift. The remote catalog
client is Sources/SkillsCore/Remote/RemoteSkillClient.swift. The UI remote
list is Sources/SkillsInspector/Remote/RemoteView.swift and its view model is
Sources/SkillsInspector/Remote/RemoteViewModel.swift. Skills are installed
into ~/.codex/skills, ~/.claude/skills, and ~/.copilot/skills.

Split-view navigation means a two-column layout where the left column lists
skills and the right column shows a detail preview. A detail preview panel
means the right column shows SKILL.md, changelog, signer, and verification
status without downloading or unzipping the full archive. A bulk toolbar
action is a top-level control that operates on multiple skills (for example,
Verify All or Update All Verified).

## Plan of Work

Start by extending the remote data flow so the UI can request and cache
preview metadata. In Sources/SkillsCore/Remote/RemoteSkillClient.swift, add a
fetchManifest and fetchPreview method that retrieves the manifest and a safe
SKILL.md preview (via HEAD/Range). Add a small cache in SkillsCore to store
preview content and changelog snippets keyed by slug/version. Wire that into
Sources/SkillsInspector/Remote/RemoteViewModel.swift to keep preview state and
provenance badges.

Update the UI in Sources/SkillsInspector/Remote/RemoteView.swift and
ContentView.swift to move to a split-view layout: list on the left, detail
preview on the right. Add a toolbar with bulk actions (Verify All, Update All
Verified, Export Changelog). The detail preview should show signer status,
manifest hash, changelog, and a button to Download and Verify. Ensure the
button is disabled if the preview is unverified or the manifest is missing.

Introduce TrustStore persistence. Add a simple local JSON file at
~/Library/Application Support/SkillsInspector/trust.json, and create a small
view model (new file Sources/SkillsInspector/TrustStoreViewModel.swift) to
read/write allowlisted keys. Add a consent prompt when a new signer is seen,
and surface revocation status in the detail panel.

Extend the installer path to support cross-IDE adapter installs. Add an
adapter layer in SkillsCore (new folder Sources/SkillsCore/Adapters) that
takes the validated skill directory and copies it to Codex, Claude, and
Copilot roots with per-target validation. Record per-target results in the
ledger.

Add the SQLite ledger and changelog generator under Sources/SkillsCore/Ledger.
Emit ledger events on install, update, and removal. Update the UI
ChangelogView to read from the ledger and export markdown.

Extend skillsctl in Sources/skillsctl/main.swift with preview/verify/install
subcommands and JSON errors that include error codes, messages, and request
IDs. Ensure CLI output matches existing schema validation patterns in
docs/schema.

Close remaining gap items by wiring ACIP scanning into the remote install flow
(quarantine/block), enforcing MIME checks on archives, switching multi-target
installs to rollback on partial failures, and signing changelog exports with a
per-device key stored in Keychain. Add a signed keyset fetch endpoint in the
remote client and refresh the local trust store only when the keyset signature
verifies against a pinned root key. Record ledger verify events during bulk
verification and add integration tests that exercise ACIP quarantine,
changelog signing, and keyset verification.

## Concrete Steps

Work from /Users/jamiecraik/dev/sTools. Use rg to find definitions and add new
files in the directories noted above. Suggested commands and expected outcomes
follow.

rg "RemoteView" Sources/SkillsInspector rg "RemoteSkillClient"
Sources/SkillsCore/Remote

After implementing preview and cache changes, run:

swift test --filter RemoteSkillInstallerTests

After implementing UI and ledger changes, run:

swift test

Optional CLI smoke checks:

swift run skillsctl remote --help swift run skillsctl remote install --help

## Validation and Acceptance

The work is acceptable when all of the following can be verified:

- The UI shows a split-view layout with a detail preview panel for remote

  skills.

- Clicking a remote skill shows SKILL.md preview, changelog, signer

  provenance, and a Download and Verify button.

- A verified install shows a Verified badge and the ledger records per-target

  results for Codex, Claude, and Copilot.

- Running swift test passes, and the targeted RemoteSkillInstallerTests pass.
- The CLI exposes preview and verify commands and returns JSON errors when

  verification fails.

## Idempotence and Recovery

All steps are additive. Re-running installs should be idempotent by archive
hash and target set. If a preview or install fails, no changes should persist
outside the staging directory. If the TrustStore file is corrupted, delete it
and recreate it; the UI must prompt for signer trust again.

## Artifacts and Notes

Key files to be added or updated:

Sources/SkillsCore/Remote/RemoteSkillClient.swift
Sources/SkillsCore/Remote/RemoteSkillInstaller.swift
Sources/SkillsCore/Remote/RemoteArtifactSecurity.swift
Sources/SkillsCore/Adapters/ Sources/SkillsCore/Ledger/
Sources/SkillsCore/Remote/RemotePreviewCache.swift
Sources/SkillsInspector/Remote/RemoteView.swift
Sources/SkillsInspector/Remote/RemoteViewModel.swift
Sources/SkillsInspector/TrustStoreViewModel.swift Sources/skillsctl/main.swift
docs/schema/ (new JSON schemas for preview/verify outputs)

## Interfaces and Dependencies

- RemoteCatalogPort (Swift protocol): fetchLatest, search, fetchManifest,

  fetchPreview, download.

- VerificationPort: verify(archiveURL, manifest, policy, trustStore) ->

  outcome.

- InstallerPort: install(archiveURL, targets) -> per-target results.
- LedgerPort: append/query for audit and changelog.
- PublishPort: build+attest using pinned tool clawdhub@0.1.0 with integrity

  hash.

All new logic stays in SkillsCore and is surfaced via SkillsInspector UI and
skillsctl CLI. No new third-party dependencies are required for the initial
milestones.

Change log: 2026-01-12, created this ExecPlan to map recon-driven improvements
into a concrete, verifiable implementation plan.

Plan update note: 2026-01-13, marked the SQLite ledger + changelog generator
milestone complete and recorded the resulting outcomes after integrating the
UI and ledger paths. Plan update note: 2026-01-13, marked skillsctl
preview/verify/install milestone complete after adding new commands and JSON
error handling. Plan update note: 2026-01-13, marked publishing pipeline,
preview labeling, feature flags/telemetry stubs, and per-skill trust scope
caching as complete after implementation.
