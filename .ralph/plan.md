# Ralph Plan (linkage-oriented) - Meta Skill Integration

This is the work queue for the meta-skill-integration feature. Each item should be small enough for one loop iteration.

**Principle**: Linkage over invention. Before editing, cite the spec section and exact files.

**Project**: stools-meta-skill-integration
**Branch**: feature/meta-skill-integration

## Work Items

### Story S1: Create Spec module with SkillSpec type

- [x] **Task 1**: Create SkillSpec.swift with core types
  - Spec reference: `.ralph/prd.json` story S1 acceptance criteria (lines 10-18)
  - Files created: `Sources/SkillsCore/Spec/SkillSpec.swift`
  - Expected change: Define SkillSpec with Metadata, Section, ValidationError types
  - **Completed**: Created `SkillSpec` struct with:
    - `Metadata` struct for frontmatter (name, description, version, author, tags, minAgentVersion, targets)
    - `Section` struct for markdown content with heading levels (h1-h6)
    - `ValidationError` struct with code, message, severity, line, column
    - `parse()` static method for SKILL.md → SkillSpec conversion
    - `toMarkdown()` method for SkillSpec → SKILL.md conversion
    - `toJSON()` and `fromJSON()` for JSON serialization
    - `validate(for:)` method for agent-specific validation
    - `diff(_:)` method for semantic comparison
    - Full Swift 6 Sendable compliance

- [x] **Task 2**: Create Spec module directory structure
  - Spec reference: `.ralph/prd.json` story S1 files list (lines 20-24)
  - Files created: `Sources/SkillsCore/Spec/` directory
  - Expected change: Create module directory for Spec-related files
  - **Completed**: Created `Sources/SkillsCore/Spec/` directory structure

- [x] **Task 3**: Create unit tests for SkillSpec
  - Spec reference: `.ralph/prd.json` story S1 acceptance criteria (line 17)
  - Files created: `Tests/SkillsCoreTests/SkillSpecTests.swift`
  - Expected change: Unit tests for round-trip conversion (SKILL.md → Spec → SKILL.md)
  - **Completed**: Created `SkillSpecTests` with 13 tests covering:
    - Round-trip SKILL.md conversion
    - Minimal skill parsing
    - Skills without frontmatter
    - JSON serialization/deserialization
    - All field serialization
    - Agent-specific validation (Codex, Claude)
    - Name pattern validation (kebab-case for Claude)
    - Semantic version validation
    - Diff detection (metadata, sections, counts)
    - ValidationError formatting

### Story S2: Add Spec export/import CLI commands

- [x] **Task 1**: Create SpecCommands.swift
  - Spec reference: `.ralph/prd.json` story S2 acceptance criteria (lines 34-39)
  - Files created: `Sources/skillsctl/Commands/SpecCommands.swift`
  - Expected change: Add AsyncParsableCommand for spec export/import/diff
  - **Completed**: Created SpecCommands with three subcommands:
    - `Export`: Converts SKILL.md to JSON with optional validation
    - `Import`: Converts JSON back to SKILL.md with optional validation
    - `Diff`: Shows semantic differences between two specs (text or JSON output)
    - Agent detection from path for context-aware validation

- [x] **Task 2**: Add spec export command
  - Spec reference: `.ralph/prd.json` story S2 acceptance (line 35)
  - Files modified: `Sources/skillsctl/main.swift`
  - Expected change: `skillsctl spec export <skill> --output <file>`
  - **Completed**: Export command with `--output`, `--format` (json|pretty), `--include-validation` flags

- [x] **Task 3**: Add spec import command
  - Spec reference: `.ralph/prd.json` story S2 acceptance (line 36)
  - Expected change: `skillsctl spec import <file> --validate`
  - **Completed**: Import command with `--output`, `--validate`, `--agent` flags

- [x] **Task 4**: Add spec diff command
  - Spec reference: `.ralph/prd.json` story S2 acceptance (line 37)
  - Expected change: `skillsctl spec diff <file1> <file2>`
  - **Completed**: Diff command with `--format` (text|json) flag, shows metadata/section changes

### Story S3: Implement ACIPScanner for prompt-injection detection

- [x] **Task 1**: Create ACIPScanner actor
  - Spec reference: `.ralph/prd.json` story S3 acceptance (lines 52-60)
  - Files created: `Sources/SkillsCore/Security/ACIPScanner.swift`
  - Expected change: Actor with scan(), TrustBoundary enum, InjectionPattern types
  - **Completed**: Created ACIPScanner actor with:
    - `TrustBoundary` enum (user, assistant, tool, file, remote, unknown)
    - `InjectionPattern` struct with 7 built-in ACIP v1.3 patterns
    - `QuarantineAction` enum (allow, quarantine, block)
    - `ScanResult` struct with action, patterns, match count, matched lines
    - `scan(content:source:contentID:)` method for single content
    - `scanSkill(at:source:)` method for full directory scanning
    - Swift 6 Sendable compliance (Regex stored as String, compiled on access)

- [x] **Task 2**: Create SecurityConfig
  - Spec reference: `.ralph/prd.json` story S3 acceptance (line 57)
  - Files created: `Sources/SkillsCore/Security/SecurityConfig.swift`
  - Expected change: Allowlist/blocklist management
  - **Completed**: Created SecurityConfig with:
    - `enabledPatterns` array for pattern filtering
    - `allowlist` array of regex patterns to skip
    - `blocklist` array of strings to block immediately
    - `maxFileSize` limit (default 1MB)
    - `scanReferences` and `scanCodeBlocks` booleans
    - Preset configs: `.default`, `.permissive`, `.strict`

- [x] **Task 3**: Create ACIPScanner tests
  - Spec reference: `.ralph/prd.json` story S3 acceptance (line 59)
  - Files created: `Tests/SkillsCoreTests/ACIPScannerTests.swift`
  - Expected change: Unit tests for each injection pattern
  - **Completed**: Created ACIPScannerTests with 15 tests covering:
    - Clean content scanning
    - All 7 injection patterns (ignore-previous, DAN, developer mode, role confusion, prompt leak, safety override, code injection)
    - Allowlist and blocklist configuration
    - Enabled patterns filtering
    - Skill directory scanning
    - Trust boundary handling
    - Performance (1000 lines < 100ms)
    - Quarantine action generation
    - Critical pattern immediate blocking
    - Matched line tracking

### Story S4: Integrate ACIP scanning into remote skill installation

- [x] **Task 1**: Add security types to RemoteArtifactSecurity
  - Spec reference: `.ralph/prd.json` story S4 acceptance (lines 75-81)
  - Files modified: `Sources/SkillsCore/Remote/RemoteArtifactSecurity.swift`
  - Expected change: SecurityCheckResult enum, integration types
  - **Completed**: Added:
    - `SecurityCheckResult` enum (clean, warning, quarantined, blocked)
    - `QuarantineStore` actor with persistent storage
    - `QuarantineItem` struct with pending/approved/rejected status
    - Full CRUD operations (quarantine, approve, reject, list, get, remove, clear)
    - JSON persistence to Application Support

- [x] **Task 2**: Create QuarantineStore
  - Spec reference: `.ralph/prd.json` story S4 acceptance (line 85)
  - Files created: `Sources/SkillsCore/Remote/RemoteArtifactSecurity.swift`
  - Expected change: Persistent store for quarantined skills
  - **Completed**: Integrated QuarantineStore into RemoteArtifactSecurity.swift with:
    - File-based persistence (quarantine.json)
    - Actor isolation for thread safety
    - Automatic load on first access
    - Methods for approve/reject workflow

### Story S6: Implement SkillSearchEngine with SQLite FTS5

- [x] **Task 1**: Create SkillSearchEngine actor
  - Spec reference: `.ralph/prd.json` story S6 acceptance (lines 116-125)
  - Files created: `Sources/SkillsCore/Search/SkillSearchEngine.swift`
  - Expected change: FTS5 virtual table schema, BM25 ranking
  - **Completed**: Created SkillSearchEngine actor with:
    - SQLite FTS5 virtual table for full-text search
    - `indexSkill(_:content:)` method for adding skills to index
    - `search(query:filters:limit:)` method with BM25 ranking
    - `SearchFilter` struct (agent, rootPath, tags, minRank)
    - `SearchResult` struct with highlighted snippets (<mark> tags)
    - `removeSkill(at:)` for index maintenance
    - `rebuildIndex(roots:)` for full reindexing
    - `optimize()` for index compaction
    - `getStats()` for index metrics
    - Swift 6 Sendable compliance

- [x] **Task 2**: Create SearchIndex helper
  - Spec reference: `.ralph/prd.json` story S6 files (line 129)
  - Files created: `Sources/SkillsCore/Search/SearchIndex.swift`
  - Expected change: Index management utilities
  - **Completed**: Created SearchIndex enum with:
    - `defaultIndexURL(for:)` for agent-specific index locations
    - `standardRootPaths()` for Codex/Claude/Copilot skill roots
    - `scanRoots(_:)` for bulk skill discovery
    - `scanRoot(_:)` for single root scanning
    - Automatic SKILL.md detection and metadata extraction

- [x] **Task 3**: Create SkillSearchEngine tests
  - Spec reference: `.ralph/prd.json` story S6 acceptance (line 125)
  - Files created: `Tests/SkillsCoreTests/SkillSearchEngineTests.swift`
  - Expected change: Unit tests for indexing and search
  - **Completed**: Created SkillSearchEngineTests with 15+ tests covering:
    - Engine initialization and database creation
    - Indexing single and multiple skills
    - Skill updates and replacement
    - Search with BM25 ranking and snippet generation
    - Agent and rank filtering
    - Skill removal from index
    - Index rebuild and optimization
    - Statistics tracking
    - Performance tests (100 skills indexed efficiently)

### Story S7: Add search CLI commands and index management

- [x] **Task 1**: Create SearchCommands
  - Spec reference: `.ralph/prd.json` story S7 acceptance (lines 140-148)
  - Files created: `Sources/skillsctl/Commands/SearchCommands.swift`
  - Expected change: CLI for searching skills
  - **Completed**: Created SearchCommands with:
    - `skillsctl search '<query>'` command with FTS5 query syntax
    - `--agent` filter (codex|claude|copilot)
    - `--minRank` filter for quality threshold
    - `--limit` option for result count
    - `--format` option (text|json)
    - Text output with ANSI terminal highlighting for snippets
    - JSON output for automation
    - Integration with SkillSearchEngine

- [x] **Task 2**: Create SearchIndexCmd (renamed from IndexCommands to avoid conflict)
  - Spec reference: `.ralph/prd.json` story S7 acceptance (lines 141-143)
  - Files created: `Sources/skillsctl/Commands/IndexCommands.swift`
  - Expected change: CLI for index management
  - **Completed**: Created SearchIndexCmd with subcommands:
    - `skillsctl index build` - Creates initial index from skill roots
    - `skillsctl index rebuild --force` - Clears and rebuilds index
    - `skillsctl index optimize` - Compacts FTS5 index
    - `skillsctl index stats` - Shows index size and skill count
    - `--roots` option for custom skill paths
    - `--verbose` flag for detailed output
    - `--format` option (text|json) for stats
    - Added Search and SearchIndexCmd to main.swift subcommands

### Story S5: Add QuarantineReviewView to SkillsInspector app

- [x] **Task 1**: Create QuarantineReviewView
  - Spec reference: `.ralph/prd.json` story S5 acceptance (lines 96-102)
  - Files created: `Sources/SkillsInspector/Security/QuarantineReviewView.swift`
  - Expected change: SwiftUI view for reviewing quarantined skills
  - **Completed**: Created QuarantineReviewView with:
    - NavigationSplitView with sidebar and detail panel
    - List of quarantined skills with severity-coded icons (low/medium/high/critical)
    - Context snippets showing matched patterns in code blocks
    - Approve/deny buttons with confirmation
    - Integration with QuarantineStore for CRUD operations
    - Status badges (pending/approved/rejected)
    - Empty states for no quarantined items
    - SwiftUI preview with sample data
    - Added Hashable conformance to QuarantineItem and Status

- [x] **Task 2**: Create SecuritySettingsView
  - Spec reference: `.ralph/prd.json` story S5 files (line 106)
  - Files created: `Sources/SkillsInspector/Security/SecuritySettingsView.swift`
  - Expected change: Security settings UI
  - **Completed**: Created SecuritySettingsView with:
    - Security level presets (default/permissive/strict)
    - ACIP scanner configuration (code blocks, references, max file size)
    - Pattern configuration with all 7 ACIP v1.3 patterns
    - Allowlist/blocklist management UI
    - Quarantine statistics and review link
    - Severity icons for each pattern type
    - Toggle controls for enabling/disabling patterns
    - SwiftUI preview
    - Integration with SecurityConfig and QuarantineStore

### Story S8: Add SearchView to SkillsInspector app

- [x] **Task 1**: Create SearchView
  - Spec reference: `.ralph/prd.json` story S8 acceptance (lines 163-171)
  - Files created: `Sources/SkillsInspector/Search/SearchView.swift`
  - Expected change: SwiftUI search interface
  - **Completed**: Created SearchView with:
    - NavigationSplitView with sidebar and detail panel
    - Real-time search with 300ms debouncing
    - Search bar with magnifying glass icon
    - Agent filter (All/Codex/Claude/Copilot)
    - Limit selector (10/20/50/100 results)
    - Statistics sheet showing index size and skill count
    - Empty states for initial state and no results
    - Loading state during search
    - Result list with selection support
    - Detail panel with matched content highlighting
    - Show in Finder and Copy Path context menu actions
    - SwiftUI preview
    - Added public initializer to SkillSearchEngine.SearchResult

- [x] **Task 2**: Create SearchResultRow
  - Spec reference: `.ralph/prd.json` story S8 files (line 175)
  - Files created: `Sources/SkillsInspector/Search/SearchResultRow.swift`
  - Expected change: Search result row component
  - **Completed**: Created SearchResultRow with:
    - Skill name and agent badge with icons
    - BM25 score display with color coding (green/yellow/orange)
    - Highlighted snippet with <mark> tag parsing
    - AttributedString for highlighted terms
    - Agent-specific icons and colors (Codex=cube.blue, Claude=sparkles.purple, Copilot=brain.green)
    - Context menu (Open in Finder, Copy Path, Show Info)
    - Rounded background with border
    - SwiftUI preview with sample data
    - NSWorkspace.open() for Finder integration

### Story S9: Implement SkillLifecycleCoordinator for workflow orchestration

- [x] **Task 1**: Create SkillLifecycleCoordinator actor
  - Spec reference: `.ralph/prd.json` story S9 acceptance (lines 185-195)
  - Files created: `Sources/SkillsCore/Workflow/SkillLifecycleCoordinator.swift`
  - Expected change: Workflow state machine
  - **Completed**: Created SkillLifecycleCoordinator actor with:
    - `createSkill()` for creating new skills with SKILL.md template
    - `validateSkill()` for running ACIP scans and spec validation
    - `approve()` for transitioning to approved stage
    - `publish()` for version bumping and search index updates
    - `syncAcrossAgents()` for multi-target skill synchronization
    - `getWorkflowState()` and `listWorkflows()` for querying
    - WorkflowError enum with descriptive error types
    - Stage.canApprove extension for transition validation
    - SkillSpec.ValidationError → WorkflowValidationError conversion
    - Full Swift 6 async/await support with proper actor isolation

- [x] **Task 2**: Create WorkflowState types
  - Spec reference: `.ralph/prd.json` story S9 files (line 199)
  - Files created: `Sources/SkillsCore/Workflow/WorkflowState.swift`
  - Expected change: Stage enum, WorkflowState struct
  - **Completed**: Created WorkflowState types with:
    - `Stage` enum with 6 stages (draft→validating→reviewed→approved→published→archived)
    - Display names and SF Symbol icons for each stage
    - `nextStage`/`previousStage` computed properties for navigation
    - `isEditable` property to control modification permissions
    - `WorkflowState` struct with validation results, review notes, version history
    - `VersionEntry` struct for tracking workflow transitions
    - `WorkflowValidationError` struct with Severity enum (error/warning/info)
    - State transition methods with automatic version entry creation
    - Validation state checking (isValid, errorCount, warningCount)

- [x] **Task 3**: Create WorkflowStateStore
  - Spec reference: `.ralph/prd.json` story S9 files (line 200)
  - Files created: `Sources/SkillsCore/Workflow/WorkflowStateStore.swift`
  - Expected change: Persistent state storage
  - **Completed**: Created WorkflowStateStore actor with:
    - In-memory state dictionary with JSON persistence
    - Automatic loading from Application Support directory
    - CRUD operations (create, get, update, delete)
    - Filtering by stage and agent
    - Clear all method for reset
    - Deferred loading on first access
    - Sorted listing by updatedAt timestamp

- [x] **Task 4**: Create Workflow tests
  - Spec reference: `.ralph/prd.json` story S9 acceptance (line 196)
  - Files created: `Tests/SkillsCoreTests/WorkflowTests.swift`
  - Expected change: Tests for stage transitions
  - **Completed**: Created WorkflowTests with 20+ tests covering:
    - Stage display names, icons, transitions, editability, canApprove
    - WorkflowState initialization, validation results, state transitions
    - WorkflowValidationError with severity and location
    - WorkflowStateStore CRUD operations and filtering
    - SkillLifecycleCoordinator create, validate, approve, publish workflows
    - Invalid transition error handling
    - VersionEntry initialization and unique IDs

### Story S10: Add workflow CLI commands

- [x] **Task 1**: Create WorkflowCommands
  - Spec reference: `.ralph/prd.json` story S10 acceptance (lines 211-221)
  - Files created: `Sources/skillsctl/Commands/WorkflowCommands.swift`
  - Expected change: CLI for workflow operations
  - **Completed**: Created WorkflowCommands with 9 subcommands:
    - `create`: Create new skills from templates with --template, --agent, --author options
    - `validate`: Run validation and advance workflow with ACIP scanning
    - `review`: Submit skill for review with optional notes
    - `approve`: Approve skill for publication with reviewer info
    - `publish`: Publish skill with version bump and search index update
    - `sync`: Sync skills across multiple agent targets (Codex/Claude/Copilot)
    - `status`: Show workflow status with validation results and history
    - `list`: List skills by stage or agent with text/JSON output
    - `dashboard`: Overview of all workflows with statistics and recent activity
    - Agent auto-detection from path or explicit --agent option
    - Template listing with `--list-templates` flag
    - Added LocalizedError conformance to WorkflowValidationError for CLI error handling

- [x] **Task 2**: Create SkillTemplate
  - Spec reference: `.ralph/prd.json` story S10 files (line 225)
  - Files created: `Sources/SkillsCore/Workflow/SkillTemplate.swift`
  - Expected change: Skill creation templates
  - **Completed**: Created SkillTemplate system with:
    - `SkillTemplate` struct with name, description, category, defaultAgent
    - `TemplateCategory` enum (automation, analysis, development, security, testing, documentation, utility)
    - `TemplateMetadata` struct for dependencies, tags, minAgentVersion, exampleUsage
    - `TemplateSection` struct for markdown content with heading levels
    - `render()` method to generate skill markdown from template
    - 5 built-in templates: automation, analysis, development, security, testing
    - Each template includes relevant sections (overview, usage, configuration, examples)
    - Category-specific SF Symbol icons for UI
    - Template discovery with `find(named:)` and `builtInTemplates()`
    - Added to main.swift subcommands as WorkflowCommand

### Story S11: Add WorkflowDashboardView to SkillsInspector app

- [x] **Task 1**: Create WorkflowDashboardView
  - Spec reference: `.ralph/prd.json` story S11 acceptance (lines 236-243)
  - Files created: `Sources/SkillsInspector/Workflow/WorkflowDashboardView.swift`
  - Expected change: Dashboard with stage picker
  - **Completed**: Dashboard view with stage picker and summary cards.

- [x] **Task 2**: Create WorkflowDetailView
  - Spec reference: `.ralph/prd.json` story S11 files (line 247)
  - Files created: `Sources/SkillsInspector/Workflow/WorkflowDetailView.swift`
  - Expected change: Drill-down detail view
  - **Completed**: Detail view with stage history and validation details.

- [x] **Task 3**: Create WorkflowRow component
  - Spec reference: `.ralph/prd.json` story S11 files (line 248)
  - Files created: `Sources/SkillsInspector/Workflow/WorkflowRow.swift`
  - Expected change: Row component for workflow list
  - **Completed**: Row component with stage badge and metadata.

- [x] **Task 4**: Create WorkflowProgressIndicator
  - Spec reference: `.ralph/prd.json` story S11 files (line 249)
  - Files created: `Sources/SkillsInspector/Workflow/WorkflowProgressIndicator.swift`
  - Expected change: Visual progress indicator
  - **Completed**: Progress indicator with stage markers.

### Story S12: Add comprehensive integration tests

- [x] **Task 1**: Create integration test suite
  - Spec reference: `.ralph/prd.json` story S12 acceptance (lines 259-268)
  - Files created: `Tests/SkillsCoreTests/IntegrationTests.swift`
  - Expected change: End-to-end workflow tests
  - **Completed**: Added ACIP quarantine, changelog signing, and keyset verification tests.

### Story S13: Update documentation and README

- [x] **Task 1**: Update README.md
  - Spec reference: `.ralph/prd.json` story S13 acceptance (lines 281-288)
  - Files to modify: `README.md`
  - Expected change: Document new CLI commands and architecture
  - **Completed**: Added remote verification, cross-IDE installs, and signed changelog features.

- [ ] **Task 2**: Update AGENTS.md
  - Spec reference: `.ralph/prd.json` story S13 files (line 292)
  - Files to modify: `.ralph/AGENTS.md`
  - Expected change: Update with integration features

- [ ] **Task 3**: Add DocC comments
  - Spec reference: `.ralph/prd.json` story S13 acceptance (line 285)
  - Files to modify: All Spec/, Security/, Search/, Workflow/ files
  - Expected change: Comprehensive documentation

## Notes

- Keep items atomic—one clear change per item
- If an item seems too large, break it down
- Cross-reference `.ralph/prd.json` sections for context
- Story S1 is foundation for all other integration features
