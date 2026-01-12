---
name: "docs-quality-guide"
displayName: "Documentation Quality Guide"
description: "Comprehensive guide for creating high-quality documentation through structured co-authoring workflows, quality standards, and reader testing. Covers everything from technical specs to API documentation with built-in compliance checks."
keywords: ["docs", "documentation", "writing", "quality", "co-authoring", "technical-writing", "standards", "compliance"]
author: "brAInwav"
---

# Documentation Quality Guide

## Overview

This power provides a comprehensive system for creating high-quality documentation through structured workflows and quality standards. It combines proven co-authoring techniques with automated compliance checks to ensure your documentation actually works for readers.

**Key capabilities:**

- **Structured 3-stage workflow**: Context Gathering → Refinement & Structure → Reader Testing
- **Reader-focused approach**: Tests docs with fresh eyes to catch blind spots
- **Quality standards**: Built-in compliance with industry documentation standards
- **Brand compliance**: Includes brAInwav brand styling when needed
- **Multiple doc types**: Supports technical specs, decision docs, READMEs, runbooks, API docs, etc.
- **Automated validation**: Lint checks, readability scoring, and brand compliance verification

## Available Steering Files

This power includes specialized workflow guides for different documentation scenarios:

- **co-authoring-workflow** - Complete 3-stage collaborative document creation process
- **baseline-practices** - Core documentation standards and best practices
- **code-documentation** - In-code documentation for TypeScript/JavaScript, Swift, and config files
- **brand-compliance** - brAInwav brand guidelines and styling requirements

Call action "readSteering" to access specific workflows as needed.

## Philosophy

- **Clarity over completeness**: Prefer smaller, readable docs with explicit gaps
- **Reader-first structure**: Optimize for how someone will consume the doc
- **Evidence over assertion**: Back claims with sources or rationale
- **Skimmable by default**: Structure for scanning and quick comprehension

## When to Use This Power

**Trigger conditions:**

- User mentions writing documentation: "write a doc", "draft a proposal", "create a spec"
- User mentions specific doc types: "PRD", "design doc", "decision doc", "RFC"
- User asks for doc review, QA, or improvement
- User needs templates or checklists for documentation

**Recommended approach:**

1. **For new documents**: Use the full 3-stage co-authoring workflow
2. **For existing docs**: Apply baseline practices and quality checks
3. **For code documentation**: Follow language-specific standards
4. **For brand compliance**: Apply brAInwav guidelines when applicable

## Quick Start Options

### Option 1: Full Co-Authoring Workflow (Recommended)

Best for important documents that need to work well for multiple readers.

**Process:**

1. **Context Gathering**: Collect all relevant information and clarify requirements
2. **Refinement & Structure**: Build document section by section with iterative feedback
3. **Reader Testing**: Validate with fresh perspective to catch blind spots

**When to use:** Technical specs, decision docs, proposals, major READMEs

### Option 2: Lightweight Quality Pass

Best for quick improvements to existing documentation.

**Process:**

1. Collect minimal inputs (audience, purpose, constraints)
2. Propose tight outline and confirm structure
3. Draft highest-impact sections first
4. Run fast QA pass (clarity, missing steps, failure points)

**When to use:** Quick fixes, minor updates, simple guides

### Option 3: Standards Application

Best for applying consistent quality standards across documentation.

**Process:**

1. Identify document type and audience
2. Apply appropriate structural standards
3. Run automated checks (linting, readability, brand compliance)
4. Provide evidence bundle with results

**When to use:** Documentation audits, compliance checks, standardization

## Core Documentation Standards

### Structure and Navigation

- Title states the doc's purpose (not a vague label)
- Headings are informative sentences where possible
- Table of contents exists for long/sectioned documents
- Clear path: prerequisites → quickstart → common tasks → troubleshooting

### Skimmability

- Short paragraphs with isolated key points
- Standalone topic sentences at section starts
- Topic words appear early in sentences
- Bullets/tables used to improve scanning
- Takeaways before long procedures

### Clarity and Style

- Simple, unambiguous sentences
- Explicit nouns instead of fragile "this/that" references
- Consistent terminology and casing
- No mind-reading phrases ("you probably want...")

### Broad Helpfulness

- Terms explained simply; abbreviations expanded on first use
- Common setup pitfalls addressed (env vars, permissions, ports)
- Self-contained, reusable code examples
- Correct security hygiene (no secrets, safe defaults)

### Verification and Lifecycle

- Steps match repository reality
- "Verify" sections with expected results
- Troubleshooting for top failure modes
- Clear ownership and review cadence

## Document Type Templates

### Technical Specification

**Sections:** Summary, Goals/Non-goals, Proposed design, API/Data model, Rollout/Backwards compatibility, Risks/Alternatives

### Decision Document

**Sections:** Context, Decision, Alternatives, Consequences, Rollback/Exit strategy

### README

**Sections:** Overview, Prerequisites, Installation, Usage, Configuration, Troubleshooting

### Runbook

**Sections:** Purpose/Scope, Preconditions, Steps, Verification, Rollback, Escalation

### API Documentation

**Sections:** Overview, Authentication, Endpoints, Examples, Errors, Rate limits

### Proposal/PRD

**Sections:** Problem, Goals, Success metrics, Requirements, UX/Flows, Timeline

## Quality Assurance Checklist

### Structure ✓

- [ ] Title states purpose clearly
- [ ] Informative headings
- [ ] Table of contents (if needed)
- [ ] Logical information flow

### Content ✓

- [ ] Simple, unambiguous language
- [ ] Consistent terminology
- [ ] Self-contained examples
- [ ] Security best practices

### Usability ✓

- [ ] Prerequisites clearly stated
- [ ] Verification steps included
- [ ] Troubleshooting for common issues
- [ ] Clear next steps

### Compliance ✓

- [ ] Lint checks passed
- [ ] Readability score in target range
- [ ] Brand guidelines followed (if applicable)
- [ ] Accessibility standards met

## Automated Validation

### Available Checks

- **Vale**: Prose linting and style checking
- **markdownlint**: Markdown formatting and structure
- **Readability**: Flesch Reading Ease scoring (target: 45-70)
- **Brand compliance**: brAInwav guidelines verification
- **Link checking**: Verify all links are accessible

### Running Checks

```bash
# Prose and style
vale document.md

# Markdown formatting
markdownlint-cli2 document.md

# Readability scoring
python scripts/check_readability.py document.md

# Brand compliance
python scripts/check_brand_guidelines.py --docs document.md
```

## Brand Compliance (brAInwav)

### When Required

- Root README files (automatic)
- Visual formatting requests
- Official documentation
- Public-facing materials

### Requirements

- Documentation signature (image or ASCII fallback)
- Brand assets in `brand/` directory
- Approved color palette usage
- Typography guidelines (Poppins/Lora fonts)
- No watermarks in technical docs

### Colors

- **Dark**: `#141413` - Primary text and dark backgrounds
- **Light**: `#faf9f5` - Light backgrounds and text on dark
- **Mid Gray**: `#b0aea5` - Secondary elements
- **Orange**: `#d97757` - Primary accent
- **Blue**: `#6a9bcc` - Secondary accent
- **Green**: `#788c5d` - Tertiary accent

## Code Documentation Standards

### TypeScript/JavaScript/React

- All exported functions/classes/hooks/components have docblocks
- Include constraints: units, allowed values, defaults, side effects
- Use `@throws` for error conditions
- Provide `@example` for complex APIs
- Document accessibility contracts for interactive components

### Swift

- Public APIs use DocC (`///`) comments
- Document concurrency expectations (MainActor, thread-safety)
- Include Important/Warning for invariants/footguns
- Use Discussion for behavior and edge cases
- Group related symbols with Topics

### Configuration Files

- Reference validation schema (JSON Schema, Zod)
- Provide minimal and full examples
- Flag sensitive keys with safe handling guidance
- Include migration notes for changed keys

## Troubleshooting

### Common Issues

**Problem:** Document feels too long or overwhelming
**Solution:**

1. Break into smaller sections with clear headings
2. Use progressive disclosure (overview → details)
3. Consider splitting into multiple documents
4. Add table of contents for navigation

**Problem:** Readers can't follow instructions
**Solution:**

1. Test instructions with someone unfamiliar
2. Add verification steps after each major action
3. Include expected outputs and error messages
4. Provide troubleshooting for common failures

**Problem:** Documentation gets outdated quickly
**Solution:**

1. Assign clear ownership and review schedule
2. Link docs to code/config files when possible
3. Use automation to detect changes
4. Keep changelog for major updates

### Validation Errors

**Vale/Lint Errors:**

- Review specific rule violations
- Check for consistent terminology
- Verify heading structure and formatting
- Ensure proper link formatting

**Readability Issues:**

- Simplify complex sentences
- Break up long paragraphs
- Use active voice
- Define technical terms

**Brand Compliance Failures:**

- Add required documentation signature
- Verify brand assets are present
- Check color usage against guidelines
- Ensure proper typography application

## Best Practices

### Writing Process

- Start with audience and purpose clarity
- Use templates for consistent structure
- Write for scanning and skimming
- Test with fresh readers before publishing

### Maintenance

- Review docs with each major release
- Track support questions that docs should answer
- Measure time-to-success for new users
- Update based on real user feedback

### Collaboration

- Use structured co-authoring for important docs
- Get stakeholder review before publication
- Version control all documentation changes
- Maintain clear ownership and approval processes

### Accessibility

- Use descriptive link text (avoid "click here")
- Ensure logical heading hierarchy
- Provide alt text for images
- Use inclusive, plain language

## Configuration

**No additional configuration required** - this power works as pure documentation guidance.

**Optional tooling setup:**

- Install Vale for prose linting
- Configure markdownlint for formatting checks
- Set up readability scoring scripts
- Enable brand compliance checking

## Evidence Bundle Template

When completing documentation work, provide:

1. **Summary of changes** (3-7 bullets)
2. **Quality checklist results** (structure, content, usability, compliance)
3. **Automated check outputs** (lint, readability, brand compliance)
4. **Open questions** requiring confirmation
5. **Review artifacts** (self-review or peer feedback)

---

**Documentation Philosophy:** The best documentation gets useful information into readers' heads quickly, with minimal cognitive load, and provides practical paths to success.
