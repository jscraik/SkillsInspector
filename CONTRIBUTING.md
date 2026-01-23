# Contributing to sTools

**Thank you for your interest in contributing to sTools!**

This document covers everything you need to know to contribute effectively, from setting up your development environment to understanding our code patterns and testing conventions.

---

## Table of Contents

- [Quick Start for Contributors](#quick-start-for-contributors)
- [Development Setup](#development-setup)
- [Project Overview](#project-overview)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Conventions](#code-conventions)
- [Swift 6 Concurrency](#swift-6-concurrency)
- [Debugging](#debugging)
- [Submitting Changes](#submitting-changes)
- [Getting Help](#getting-help)

---

## Quick Start for Contributors

**New contributors? Start here.**

1. **Verify your environment:**
   ```bash
   # Check Swift version (requires 6.0+)
   swift --version
   # Expected output: "Apple Swift version 6.x"

   # Check macOS SDK (requires 15+)
   sw_vers
   # Expected: macOS 15+

   # Check Xcode (optional but recommended)
   xcode-select -p
   # Expected: /Applications/Xcode.app/Contents/Developer or similar
   ```

2. **Clone and build:**
   ```bash
   git clone https://github.com/yourusername/stools.git
   cd stools
   swift build
   # Expected: "Build complete!" with no errors
   ```

3. **Run tests:**
   ```bash
   swift test
   # Expected: All tests pass (some chart snapshots may skip)
   ```

4. **Make your change** (edit files in `Sources/`)

5. **Test locally:**
   ```bash
   # Run affected tests
   swift test --filter TestName

   # Verify CLI still works
   swift run skillsctl scan --repo . --allow-empty
   ```

6. **Submit PR** (see [Submitting Changes](#submitting-changes))

---

## Development Setup

### Prerequisites

| Requirement | Minimum | Recommended | How to Check |
|-------------|---------|-------------|--------------|
| macOS | 15.0+ | Latest | `sw_vers` |
| Swift | 6.0+ | Latest (6.2+) | `swift --version` |
| Xcode | 16.0+ | Latest or beta | `xcode-select -p` |
| RAM | 4 GB | 8 GB+ | Activity Monitor |
| Disk | 2 GB free | 10 GB+ | Finder Info |

### Verification Script

Run this to verify your environment:

```bash
# Save as verify-setup.sh
#!/bin/bash

echo "Checking sTools development environment..."

# Swift version
SWIFT_VERSION=$(swift --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
echo "✓ Swift version: $SWIFT_VERSION"

# macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "✓ macOS version: $MACOS_VERSION"

# Xcode availability
if command -v xcode-select &> /dev/null; then
    XCODE_PATH=$(xcode-select -p)
    echo "✓ Xcode found at: $XCODE_PATH"
else
    echo "⚠ Xcode not found (optional but recommended)"
fi

# Build test
echo ""
echo "Testing build..."
if swift build &> /dev/null; then
    echo "✓ Build successful"
else
    echo "✗ Build failed - check Swift version and dependencies"
    exit 1
fi

# Test run
echo ""
echo "Testing CLI..."
if swift run skillsctl --help &> /dev/null; then
    echo "✓ CLI functional"
else
    echo "✗ CLI failed to run"
    exit 1
fi

echo ""
echo "Environment verified! You're ready to develop."
```

Make it executable and run:
```bash
chmod +x verify-setup.sh
./verify-setup.sh
```

### IDE Setup

**Xcode (Recommended for SwiftUI work):**
```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open sTools.xcodeproj
```

**VS Code (Recommended for CLI work):**
- Install Swift extension (swiftlang.vscode-swift)
- Install CodeLLDB for debugging
- Key bindings: ⌘+B to build, ⇧+⌘+R to run

---

## Project Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        sTools                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   sTools    │  │  skillsctl  │  │ SkillsLintPlugin    │ │
│  │  (SwiftUI)  │  │   (CLI)     │  │   (SwiftPM)          │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                     │            │
│         └────────────────┴─────────────────────┘            │
│                          │                                  │
│                   ┌──────▼──────┐                           │
│                   │  SkillsCore │                           │
│                   │  (Engine)   │                           │
│                   └──────┬──────┘                           │
│                          │                                  │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────────┐      │
│  │  SkillLedger│  │FixEngine │  │ ValidationRules  │      │
│  │ (SQLite)    │  │          │  │                  │      │
│  └─────────────┘  └──────────┘  └──────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SkillsCore` | `Sources/SkillsCore/` | Core scanning, validation, sync engine |
| `skillsctl` | `Sources/skillsctl/` | Command-line interface |
| `sTools` | `Sources/SkillsInspector/` | SwiftUI macOS app |
| `SkillsLintPlugin` | `Plugins/SkillsLintPlugin/` | SwiftPM build plugin |

### Data Flow

```
SKILL.md files → Scanner → Validator → RuleEngine → Findings
                                        ↓
                                  FixEngine
                                        ↓
                                  SkillLedger (SQLite)
```

---

## Development Workflow

### 1. Branch Strategy

```bash
# Main branch is protected
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name

# Or bugfix branch
git checkout -b fix/your-bug-fix
```

### 2. Making Changes

**Edit code:**
- Sources in `Sources/SkillsCore/` for engine changes
- Sources in `Sources/skillsctl/` for CLI changes
- Sources in `Sources/SkillsInspector/` for UI changes

**Build incrementally:**
```bash
# Fast rebuild (debug)
swift build

# Release build for testing
swift build -c release
```

### 3. Testing Your Changes

```bash
# Run all tests
swift test

# Run specific test
swift test --filter MyTestName

# Run tests with verbose output
swift test --verbose

# Run tests for specific module
swift test --filter SkillsCoreTests
```

### 4. Verification Checklist

Before committing, verify:

```bash
# [ ] Build succeeds
swift build

# [ ] Tests pass
swift test

# [ ] CLI help works
swift run skillsctl --help

# [ ] Basic scan works
swift run skillsctl scan --repo . --allow-empty

# [ ] No Swift linter warnings
swift build 2>&1 | grep -i warning
# Should produce no output
```

---

## Testing

### Test Organization

```
Tests/
├── SkillsCoreTests/          # Core engine tests
│   ├── SkillLedgerTests.swift
│   ├── ValidationRuleTests.swift
│   └── FixEngineTests.swift
└── SkillsInspectorTests/     # UI tests
    ├── InspectorViewModelTests.swift
    └── UISnapshotsTests.swift
```

### Writing Tests

**Unit test template:**

```swift
import XCTest
@testable import SkillsCore

final class MyFeatureTests: XCTestCase {
    // Setup runs before each test
    override func setUp() async throws {
        try await super.setUp()
        // Initialize test dependencies
    }

    // Teardown runs after each test
    override func tearDown() async throws {
        // Clean up
        try await super.tearDown()
    }

    // Test: Naming convention: test[What]_[ExpectedResult]
    func testScan_WithValidSkills_ReturnsNoErrors() async throws {
        // Arrange: Set up test data
        let skillPath = testFixturePath("valid-skill")

        // Act: Execute the code under test
        let results = try await Scanner.scan(path: skillPath)

        // Assert: Verify expectations
        XCTAssertEqual(results.errors.count, 0, "Valid skills should have no errors")
        XCTAssertGreaterThan(results.scanned, 0, "Should scan at least one file")
    }

    // Helper: Create test fixtures
    private func testFixturePath(_ name: String) -> String {
        return fixturesDirectory.appendingPathComponent(name).path
    }

    private var fixturesDirectory: URL {
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }
}
```

### Test Fixtures

Create test fixtures in `Tests/SkillsCoreTests/Fixtures/`:

```
Fixtures/
├── valid-skill/
│   └── SKILL.md              # Complete, valid skill
├── invalid-frontmatter/
│   └── SKILL.md              # Missing frontmatter
└── nested/
    └── inner/
        └── SKILL.md          # Nested skill file
```

### Running Specific Tests

```bash
# Run all tests in a file
swift test --filter SkillLedgerTests

# Run specific test method
swift test --filter testScan_WithValidSkills

# Run tests matching pattern
swift test --filter "/Scan/"
```

### Snapshot Tests (UI)

Snapshot tests verify UI consistency:

```bash
# Run snapshot tests (requires environment variable)
ALLOW_CHARTS_SNAPSHOT=1 swift test --filter UISnapshotsTests
```

**To update snapshots:**
```swift
// In your test, use:
// assertSnapshot(matching: view, as: .image, record: true)
```

---

## Code Conventions

### File Organization

**One type per file** (300 LOC limit):
```swift
// File: Sources/SkillsCore/Scanner/Scanner.swift
final class Scanner {
    // Scanner implementation
}

// File: Sources/SkillsCore/Scanner/ScannerConfig.swift
struct ScannerConfig {
    // Configuration
}
```

**Exceptions:**
- Small related types in `Types.swift` or `Models.swift` (<120 LOC)
- SwiftUI previews in the same file as the View

### Naming

**Types:** `PascalCase`
```swift
struct DiagnosticBundle { }
class UsageAnalytics { }
protocol ValidationRule { }
```

**Properties/variables:** `camelCase`
```swift
let cacheKey: String
var scanResults: [Finding]
```

**Constants:** `camelCase` or `UPPER_SNAKE_CASE` for globals
```swift
private let maxCacheSize = 100
public let DEFAULT_TIMEOUT_MS = 5000
```

**Functions:** `camelCase`, verb-first
```swift
func scanDirectory(_ path: String) async throws -> ScanResults
func validateSkill(_ skill: SkillDoc) -> [Finding]
```

**Test methods:** `test[What]_[ExpectedResult]`
```swift
func testScan_WithEmptyPath_ThrowsError()
func testValidation_WithValidSkill_ReturnsNoFindings()
```

### Swift Style Guide

**Indentation:** 4 spaces (no tabs)

**Line length:** Soft limit 100 chars, hard limit 120

**Braces:** Opening brace on same line (K&R style)
```swift
if condition {
    // code
} else {
    // code
}
```

** MARK: comments for organization:**
```swift
// MARK: - Public API

// MARK: - Private Helpers

// MARK: - Scanner Configuration
```

### Documentation

**Public APIs:**
```swift
/// Scans a directory for SKILL.md files and validates them.
///
/// - Parameter path: Absolute path to the directory to scan
/// - Returns: ScanResults containing findings and statistics
/// - Throws: ScanError if the path is inaccessible or invalid
func scan(_ path: String) async throws -> ScanResults
```

**Inline comments:**
```swift
// Defer cleanup to ensure it runs even if an error is thrown
defer { cleanup() }

// Cache key combines path hash and config version for uniqueness
let cacheKey = "\(path.hashValue)_\(config.version)"
```

---

## Swift 6 Concurrency

### Actor Isolation

**Stateful components use actors:**

```swift
@MainActor
final class InspectorViewModel: ObservableObject {
    @Published var findings: [Finding] = []

    func scan() async {
        // Automatically runs on main actor
        findings = await scanner.scan()
    }
}

actor SkillLedger {
    private var database: SQLiteConnection

    func record(_ finding: Finding) async throws {
        // Actor-isolated, safe from concurrent access
        try database.insert(finding)
    }
}
```

### Sendable Requirements

**Types passed across concurrency boundaries must be Sendable:**

```swift
struct Finding: Sendable, Codable {
    let id: String
    let message: String
    let severity: Severity
}
```

### Debugging Actor Isolation

**Common error:** "Expression is 'async' but not marked with 'await'"

```swift
// WRONG: Calling actor-isolated code without await
let ledger = SkillLedger()
ledger.record(finding)  // ❌ Compiler error

// RIGHT: Use await
await ledger.record(finding)  // ✅ Correct
```

**Common error:** "Main actor checker error"

```swift
// WRONG: Updating @Published property from background task
@MainActor
class ViewModel {
    @Published var count = 0

    func incrementInBackground() {
        Task.detached {
            count += 1  // ❌ Error: Not on main actor
        }
    }
}

// RIGHT: Ensure main actor execution
@MainActor
class ViewModel {
    @Published var count = 0

    func incrementInBackground() {
        Task { @MainActor in
            count += 1  // ✅ Correct
        }
    }
}
```

### Testing Async Code

```swift
func testAsyncOperation() async throws {
    // Arrange
    let scanner = Scanner()

    // Act (await the async call)
    let results = await scanner.scan("/path")

    // Assert
    XCTAssertNotNil(results)
}
```

---

## Debugging

### LLDB Commands

```bash
# Breakpoint on function
br set -n scanDirectory

# Breakpoint on file:line
br set -f Scanner.swift -l 42

# Conditional breakpoint
br set -n scanDirectory -c path=="~/test"

# Print variable
po findings

# Print array count
po findings.count

# Continue
c

# Step over
n

# Step into
s
```

### Logging

**Use AppLog for structured logging:**

```swift
import AppLog

AppLog.shared.error("Scan failed", metadata: [
    "path": path,
    "error": error.localizedDescription
])
```

**Console output for debugging:**
```swift
print("DEBUG: Current state = \(state)")
```

### Common Issues

**Issue:** Tests pass individually but fail together
- **Cause:** Shared state or database pollution
- **Fix:** Use `setUp()`/`tearDown()` to isolate tests

**Issue:** "Cannot find 'skillsctl' in scope"
- **Cause:** Module import missing
- **Fix:** Add `import SkillsCore` to test file

**Issue:** Build succeeds but tests fail on CI
- **Cause:** Environment differences (Swift version, SDK)
- **Fix:** Pin Swift version in `.swift-version`

---

## Submitting Changes

### Before Submitting

**[ ] Complete the checklist:**

```bash
# 1. Build succeeds
swift build

# 2. All tests pass
swift test

# 3. New tests added for new features
# 4. Documentation updated (if needed)
# 5. CHANGELOG.md updated (for user-visible changes)
```

### Commit Messages

**Format:** `type(scope): description`

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build process, tooling

**Examples:**
```
feat(scanner): Add recursive directory scanning

fix(ledger): Resolve race condition in concurrent writes

docs(contributing): Add Swift 6 concurrency debugging guide

test(validation): Add fixture tests for edge cases
```

### Pull Request Template

```markdown
## Summary
Brief description of changes (1-2 sentences)

## Motivation / Context
Why this change is needed

## What changed?
- List of key changes
- Files added/modified/deleted

## How to test
Steps to verify the change works

## Risk & rollout
- Risk level: low/medium/high
- Rollback plan: how to revert if issues arise

## Testing level
- [ ] untested
- [ ] lightly tested
- [ ] fully tested

## Security / privacy
- [ ] No security impact
- [ ] Security impact (describe high-level)

## AI assistance
- [ ] This PR was created with AI assistance
- [ ] Testing level declared
- [ ] I understand what the code does and can explain it
- [ ] Prompts or session logs included

## Checklist
- [ ] Tests pass locally
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if user-visible)
```

---

## Getting Help

### Resources

- **README:** `/Users/jamiecraik/dev/sTools/README.md` — User-facing documentation
- **Tech specs:** `.spec/` directory — Detailed feature specifications
- **DocC:** Generate with `swift package generate-documentation`

### Asking Questions

1. **Check existing issues** — Your question may already be answered
2. **Search the codebase** — Use `rg` (ripgrep) for code searches
3. **Provide context** — Include:
   - What you're trying to do
   - What you've tried
   - Expected vs actual behavior
   - Error messages (full output)

### Code Review Best Practices

**As a reviewer:**
- Be constructive and specific
- Explain the "why" behind suggestions
- Approve incremental progress

**As a contributor:**
- Address all review feedback
- Explain your reasoning if you disagree
- Request re-review after changes

---

## Appendix: Quick Reference

### Essential Commands

| Command | Purpose |
|---------|---------|
| `swift build` | Build project |
| `swift test` | Run tests |
| `swift run skillsctl scan --repo .` | Test scan |
| `swift package generate-xcodeproj` | Create Xcode project |
| `swift format .` | Format code (if using formatter) |
| `rg "pattern"` | Search codebase |

### File Locations

| What | Where |
|------|-------|
| Core engine | `Sources/SkillsCore/` |
| CLI | `Sources/skillsctl/` |
| UI app | `Sources/SkillsInspector/` |
| Tests | `Tests/` |
| Schemas | `docs/` |
| Specs | `.spec/` |

### Common Tasks

| Task | How |
|------|-----|
| Add new validation rule | Implement `ValidationRule` protocol, register in `RuleRegistry` |
| Add CLI command | Create new file in `Sources/skillsctl/Commands/` |
| Add UI view | Create SwiftUI view in `Sources/SkillsInspector/` |
| Modify database schema | Update `SkillLedger`, add migration in `init()` |
| Run specific test | `swift test --filter TestName` |

---

**Questions?** Open an issue or discussion. We're glad to have you contribute!

*Last updated: 2026-01-20*
