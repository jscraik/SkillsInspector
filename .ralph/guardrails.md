# Guardrails (Signs)

This file accumulates "Signs"—short, reusable rules learned from failures. Each Sign should be:

- **Short**: One or two sentences
- **Actionable**: Clear instruction on what to do/not do
- **Contextual**: Includes what triggered it and when it was added

## Format

```markdown
## Sign: [Short Title]

- **Trigger**: [What situation caused this Sign to be added]
- **Instruction**: [What to do instead]
- **Added after**: [Iteration N or context]
```

## Signs

*Add Signs here as you encounter repeated failures.*

### Example Signs

## Sign: SwiftUI previews must be static

- **Trigger**: SwiftUI previews that depend on external state or complex setup
- **Instruction**: Ensure all View previews use static, dependency-free data
- **Added after**: Initial setup

## Sign: One type per file

- **Trigger**: Multiple structs/classes/enums in a single Swift file
- **Instruction**: Extract additional types to separate files named after the type
- **Added after**: Initial setup

## Sign: Run swift test before marking checkbox complete

- **Trigger**: Marking checkboxes as done without running tests
- **Instruction**: Run `swift test` before changing `[ ]` to `[x]`
- **Added after**: Initial setup

## Sign: Check for existing patterns before inventing new ones

- **Trigger**: Creating new code patterns when existing ones would work
- **Instruction**: Search the codebase with `rg` for similar patterns before introducing new abstractions
- **Added after**: Initial setup

## Sign: Swift 6 strict concurrency

- **Trigger**: Adding code that doesn't comply with Swift 6 concurrency
- **Instruction**: Ensure all new code is Sendable-safe and uses proper actor isolation
- **Added after**: Initial setup
