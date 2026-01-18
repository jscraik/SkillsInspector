---
task: "sTools Ralph Loop - placeholder task"
test_command: "swift test"
typecheck_command: "swift build"
lint_command: "swift format --lint ."
---

# Ralph Task - sTools

This is the default checkbox mode task file. Replace the placeholder task
below with your actual work.

## Success Criteria (checkboxes)

Work through these checkboxes one at a time. Each checkbox should be small
enough for 1-2 iterations.

### Example: Add a New Feature

1. [ ] **Add failing test** for the desired behavior
   - Create test file in `Tests/SkillsCoreTests/` or appropriate test

     directory

   - Test should fail initially (TDD red phase)

2. [ ] **Implement the behavior** to make test pass
   - Modify source files in `Sources/SkillsCore/` or appropriate source

     directory

   - Run `swift test` to verify

3. [ ] **All checks pass**
   - `swift test` - All tests pass
   - `swift build` - Code compiles without errors
   - `swift format --lint .` - Code formatting is clean (if configured)

4. [ ] **Update documentation** (if applicable)
   - Update README.md or relevant docs
   - Add DocC comments for public APIs
   - Update CHANGELOG if user-facing

## Current Task

*Replace this section with your actual task description.*

## Constraints / Notes

- Keep each checkbox small enough for 1-2 iterations.
- Tests should fail before implementation (TDD approach).
- Run checks (test/typecheck/lint) before marking a checkbox complete.
- Link changes to spec sections in `.ralph/pin.md`.
- Follow Swift 6 strict concurrency conventions.
- One type per file - use SwiftUI previews for Views.
