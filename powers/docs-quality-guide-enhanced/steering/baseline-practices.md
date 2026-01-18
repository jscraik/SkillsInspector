# Documentation Baseline Practices

This guide covers the core standards and practices for creating high-quality
documentation that gets useful information into readers' heads quickly, with
minimal cognitive load.

## Mission

Produce documentation that gets useful information into a reader's head
quickly, with minimal cognitive load, and with practical paths to success
(examples + troubleshooting).

## Operating Procedure

### 1) Locate and Scope

- Identify the canonical doc surface(s): README, /docs, /guides, /runbooks,

  /api, etc.

- Do not rewrite everything. Pick the smallest set of files that solves the

  user task.

### 1a) Capture Doc Requirements

Record these at the top of the doc or in a visible "Doc requirements" section:

- Audience tier (beginner, intermediate, expert)
- Scope and non-scope (what this doc covers and does not cover)
- Doc owner and review cadence
- Required approvals or stakeholders

### 2) Build a Skimmable Structure First

- Create/repair a clear outline with sections that match reader questions
- Add a table of contents for longer docs
- Use headings as informative sentences (not vague nouns)

### 3) Write for Skim-Reading

Apply these rules aggressively:

- Keep paragraphs short; use one-sentence paragraphs for key points
- Start sections/paragraphs with a standalone topic sentence
- Put the topic words at the beginning of topic sentences
- Put takeaways before procedure (results first, then steps)
- Use bullets and tables whenever they reduce scanning time
- Bold truly important phrases sparingly (what to do, what not to do, critical

  constraints)

### 4) Write Clean, Unambiguous Prose

- Prefer simple sentences; split long ones
- Remove filler/adverbs and needless phrasing
- Avoid hard-to-parse phrasing and ambiguous sentence starts
- Prefer right-branching phrasing (tell readers early what the sentence

  connects to)

- Avoid "this/that" references across sentences; repeat the specific noun

  instead

- Be consistent (terminology, casing, naming conventions, punctuation style)

### 4a) Capture Risk and Assumptions

If the doc involves operational steps, safety, or data impact, add a "Risks
and assumptions" section that includes:

- Assumptions the doc relies on
- Failure modes and blast radius
- Rollback or recovery guidance

### 5) Be Broadly Helpful

Optimize for beginners without annoying experts:

- Explain simply; do not assume English fluency
- Avoid abbreviations; write terms out on first use
- Proactively address likely failure points (env vars, PATH, permissions,

  ports, tokens)

- Prefer specific, accurate terminology over insider jargon
- Keep examples general and exportable (minimal dependencies, self-contained

  snippets)

- Focus on common/high-value tasks over edge cases
- Do not teach bad habits (e.g., hardcoding secrets, unsafe defaults)

### 6) Accessibility and Inclusive Design

- Use descriptive link text; avoid "click here"
- Ensure heading order is logical and no levels are skipped
- Provide alt text for non-decorative images; mark decorative images as such
- Avoid instructions that rely only on color, shape, or spatial position
- Prefer inclusive, plain language and avoid ableist or exclusionary phrasing

### 7) Security, Privacy, and Safety Pass

- Never expose real secrets, tokens, or internal endpoints; use placeholders
- Avoid encouraging destructive or irreversible commands without warnings and

  backups

- Call out PII handling and data retention considerations when relevant
- Prefer least-privilege guidance for credentials, access, and permissions

### 8) Check Content Against the Repo

- Never invent commands, flags, file paths, outputs, or version numbers
- Cross-check installation steps with actual configs (package scripts,

  Makefile, Dockerfile, CI)

- If you cannot verify a detail, flag it as needing confirmation

### 9) Run Doc Linters (when available)

- If `.vale.ini` exists, run `vale {doc}` and record results
- If markdownlint config exists, run `markdownlint-cli2 {doc} --config

  {config}`

- If link-check tooling exists, run it and record results
- If tooling is missing, state what is missing and how to enable it
- If readability checking is available, run it and record the score and target

  range (default target: 45-70 Flesch Reading Ease)

### 10) Finish with Verification Hooks

- Add "Verify" steps readers can run (expected output, health checks)
- Add Troubleshooting for the top 3 predictable failures
- Ensure the doc has a clear "Next step" path

### 11) Brand Compliance Pass (when applicable)

If branding, visual formatting, or a root README is in scope:

- Add the documentation signature to root README files
- Ensure `brand/` assets exist and match the approved formats
- Do not add watermarks to technical docs
- Apply color/typography guidance only where visual formatting is requested
- Treat missing signature/assets as blocking; list them in Open questions

### 12) Acceptance Criteria and Evidence Bundle

Add a short acceptance checklist and an evidence bundle at the end of the doc:

- Acceptance criteria: 5-10 checkboxes that must be true before completion
- Evidence bundle: lint output, brand check output, readability output, and

  checklist snapshot

## Quality Checklist

### Structure and Navigation

- [ ] Title states the doc's purpose (not a vague label)
- [ ] Headings are informative sentences where possible
- [ ] Table of contents exists if the doc is long/sectioned
- [ ] Reader can find: prerequisites → quickstart → common tasks →

  troubleshooting

### Skimmability

- [ ] Paragraphs are short; key points are isolated when needed
- [ ] Each section starts with a standalone topic sentence
- [ ] Topic words appear early in topic sentences
- [ ] Bullets/tables used where they improve scanning
- [ ] Takeaways appear before long procedures

### Clarity and Style

- [ ] Sentences are simple and unambiguous
- [ ] No fragile "this/that" references across sentences; nouns are explicit
- [ ] Consistent terminology/casing across the doc
- [ ] No mind-reading phrases ("you probably want...", "now you'll...")

### Broad Helpfulness

- [ ] Terms are explained simply; abbreviations expanded on first use
- [ ] Likely setup pitfalls are addressed (env vars, permissions, ports, PATH)
- [ ] Code examples are minimal, self-contained, and reusable
- [ ] Security hygiene is correct (no secrets in code; safe defaults)

### Correctness and Verification

- [ ] Steps match repo reality (configs/paths verified)
- [ ] Includes a "Verify" section with expected results
- [ ] Troubleshooting covers top failure modes
- [ ] Unknowns are called out explicitly as items to confirm

### Requirements, Risks, and Lifecycle

- [ ] Doc requirements recorded (audience tier, scope/non-scope, owner, review

  cadence)

- [ ] Risks and assumptions documented when operational or data impact exists
- [ ] "Last updated" and owner are present for top-level docs
- [ ] Acceptance criteria included (5-10 items)

### Brand Compliance (when applicable)

- [ ] Root README includes the documentation signature
- [ ] Brand assets exist in `brand/` and match approved formats
- [ ] No watermark usage in README or technical docs
- [ ] Visual styling follows brand guidance only when requested

### Evidence Bundle

- [ ] Lint outputs recorded (Vale/markdownlint/link check)
- [ ] Brand check output recorded when branding applies
- [ ] Readability output recorded when available
- [ ] Checklist snapshot included with the deliverable

## Anti-Patterns to Avoid

- Writing without confirming audience and purpose
- Burying key decisions or risks in long prose
- Shipping drafts without a verification pass
- Using fragile "this/that" references across sentences
- Mind-reading phrases that assume context
- Hardcoding secrets or unsafe defaults in examples
- Inventing commands, flags, or outputs not verified against the repo

## Deliverable Format

When you finish edits, include:

1. Summary of changes (3-7 bullets)
2. Doc QA checklist results
3. Open questions / requires confirmation (explicit list, no hand-waving)
4. Brand compliance results (if applicable) with evidence of signature and

   assets

5. Evidence bundle (lint output, brand check output, readability output,

   checklist snapshot)

## Automation Hooks (Optional)

Use these commands in CI or pre-commit, adjusting paths to your repo:

```bash
vale <doc>
markdownlint-cli2 <doc> --config <config>
# Manual brand compliance verification
# Manual readability assessment
```

## Docs Upkeep

### Versioning

- Add a visible "Last updated" date to top-level docs
- Use semantic versioning for public API docs and note breaking changes
- Keep a changelog for major docs when behavior changes

### Deprecation

- Mark deprecated sections with a date and replacement link
- Keep deprecated content for at least one release cycle
- Remove only after migration guidance is published

### Ownership

- Assign a clear doc owner per major doc
- Require owner approval for structural changes
- Review docs at least once per release

### Metrics Loop (Docs ROI)

- Support deflection: track tickets or questions that docs should prevent
- Onboarding time: measure time-to-first-success for new users
- FAQ deflection: measure repeated questions before/after doc updates
- Search success: track search terms that lead to page exits or "no results"
