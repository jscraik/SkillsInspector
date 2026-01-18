# sTools Project Structure

This document describes the organization of the sTools project.

## Root Directory

```text
sTools/
├── .github/          # GitHub workflows and CI/CD
├── .ralph/           # Ralph AI assistant logs and planning
├── .spec/            # Product specifications and technical specs
├── bin/              # Build and utility scripts
├── brand/            # Brand assets (logos, icons)
├── docs/             # Documentation
├── Plugins/          # SwiftPM plugins
├── powers/           # Kiro AI powers for development
├── Sources/          # Source code
├── Tests/            # Test suites
├── sTools.app/       # Built macOS application
├── AGENTS.md         # AI agent instructions
├── Package.swift     # Swift package definition
└── README.md         # Project overview
```

## Source Code (`Sources/`)

- **SkillsCore/** - Core validation, trust, and sync logic
  - Trust & verification components
  - Artifact fetcher and sanitizer
  - Cross-IDE adapters
  - Ledger and publisher

- **SkillsInspector/** - macOS SwiftUI application
  - Main app views and navigation
  - Remote skill browser with provenance
  - Design tokens and styling

- **skillsctl/** - Command-line interface
  - verify/install/publish commands
  - CI/CD integration

## Documentation (`docs/`)

- **schema/** - JSON schemas for manifests and configuration
- **diagrams/** - Architecture and flow diagrams
- **analysis/** - Technical analysis documents
- **archive/** - Archived documentation
- **planning/** - Project planning documents
- **ExecPlan-*.md** - Execution plans for features
- **AGENTS.md** - Detailed agent instructions

## Tests (`Tests/`)

- **SkillsCoreTests/** - Unit tests for core logic
  - Trust and verification tests
  - Security fixture tests

- **SkillsInspectorTests/** - UI and integration tests
  - View model tests
  - Snapshot tests

## Build Artifacts

- **.build/** - Swift build artifacts (gitignored)
- **.tmp/** - Temporary build files (gitignored)
- **sTools.app/** - Built application bundle

## Configuration

- **.spec/** - Product and technical specifications
- **.ralph/** - Ralph AI assistant state
- **.github/** - CI/CD workflows
- **version.env** - Version configuration

## Scripts (`bin/`)

- **package_app.sh** - Main build and packaging script
- **make-dmg.sh** - DMG creation for distribution
- **configure-sparkle.sh** - Auto-update configuration
- Various utility scripts for development

## Key Files

- **Package.swift** - Swift package manifest with dependencies
- **AGENTS.md** - Instructions for AI development assistants
- **README.md** - Project overview and quick start
- **.ralph/pin.md** - Authoritative spec anchor
- **.spec/spec-<->.md** - Complete PRD and technical spec
