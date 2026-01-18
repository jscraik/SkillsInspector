---
name: "swiftui-ui-patterns"
displayName: "SwiftUI UI Patterns"
description: "Best practices and example-driven guidance for building SwiftUI views and components. Covers navigation architecture, state management, and component-specific patterns with real-world examples."
keywords: ["swiftui", "ui", "patterns", "ios", "components", "navigation", "tabview", "state", "architecture"]
author: "Jamie Craik"
---

# SwiftUI UI Patterns

## Overview

This power provides comprehensive guidance for building SwiftUI applications
with modern patterns and best practices. It covers everything from basic
component composition to complex navigation architectures, emphasizing native
SwiftUI patterns over heavy abstractions.

The power includes detailed component-specific guides accessible through
steering files, covering 25+ SwiftUI components and patterns with real-world
examples and best practices from production iOS apps.

## Philosophy

- **Prefer native SwiftUI patterns** over heavy view-model scaffolding
- **Keep views small, composable, and predictable**
- **Preserve project conventions** and avoid premature abstraction
- **Use modern SwiftUI state** (`@State`, `@Binding`, `@Observable`,

  `@Environment`)

- **Favor composition** over complex inheritance hierarchies

## When to Use This Power

Use this power when you're:

- Building or refactoring SwiftUI screens and components
- Designing navigation with TabView/NavigationStack
- Choosing component-specific patterns or examples
- Need guidance on state management and data flow
- Looking for accessibility and performance best practices
- Working with sheets, modals, and presentation patterns

## Available Steering Files

### Core Architecture & Wiring

- **app-wiring** - Complete app shell setup with TabView + NavigationStack +

  sheets and dependency injection patterns

- **components-index** - Master index of all available component guides with

  usage recommendations

### Navigation & Structure

- **tabview** - Tab-based app architecture and per-tab navigation patterns
- **navigationstack** - Push navigation, programmatic routing, and navigation

  state management

- **sheets** - Modal presentation patterns with enum-driven routing and proper

  state management

- **deeplinks** - URL routing and in-app navigation from external links
- **split-views** - iPad/macOS multi-column layouts and adaptive interfaces

### Lists & Data Display

- **list** - Feed-style content, settings rows, and list performance

  optimization

- **scrollview** - Custom layouts, horizontal scrollers, and lazy loading

  patterns

- **grids** - Icon pickers, media galleries, and tiled layout patterns
- **searchable** - Native search UI with scopes, filtering, and async results

### Forms & Input

- **form** - Settings screens, grouped inputs, and structured data entry
- **controls** - Toggles, pickers, sliders, and other input controls
- **input-toolbar** - Bottom-anchored input bars for chat and composer screens
- **focus** - Keyboard focus management and field chaining

### Media & Content

- **media** - Remote images, video previews, and media viewer patterns
- **loading-placeholders** - Skeleton screens, empty states, and loading UX

  patterns

- **matched-transitions** - Smooth animations between source and destination

  views

### Layout & Styling

- **theming** - App-wide theme tokens, colors, and dynamic type scaling
- **design-guidelines-summary** - Quick reference for design tokens and

  styling

- **design-guidelines-canonical** - Complete design system guidelines and

  standards

- **overlay** - Transient UI like banners, toasts, and temporary overlays
- **top-bar** - Pinned selectors and pills above scroll content

### Advanced Patterns

- **lightweight-clients** - Small, closure-based API clients for dependency

  injection

- **haptics** - Tactile feedback patterns tied to user actions
- **title-menus** - Filter and context menus in navigation titles

## Quick Start Guide

### For Existing Projects

1. **Identify your feature** - Determine the primary interaction model (list,

   detail, editor, settings, tabbed)

2. **Find similar patterns** - Use the components-index steering file to

   locate relevant guides

3. **Read the specific guide** - Load the appropriate steering file for

   detailed patterns

4. **Apply local conventions** - Adapt patterns to your project's existing

   style

5. **Build incrementally** - Start with small, focused subviews and expand

### For New Projects

1. **Start with app wiring** - Read the app-wiring steering file for TabView +

   NavigationStack setup

2. **Choose your first component** - Pick the UI pattern you need first

   (TabView, List, Form, etc.)

3. **Read the component guide** - Load the specific steering file for detailed

   implementation

4. **Expand gradually** - Add routes and sheets as new screens are needed

## Core Principles

### State Management

- Use `@State` for local view state
- Use `@Binding` when parent needs to control state
- Use `@Observable` for shared models and stores
- Use `@Environment` for dependency injection
- Avoid unnecessary ViewModels for simple views

### Component Composition

- Keep views small and focused on single responsibilities
- Extract repeated UI patterns into reusable components
- Use composition over complex view hierarchies
- Prefer SwiftUI-native data flow patterns

### Performance & Accessibility

- Use explicit IDs for better list diffing performance
- Add accessibility labels for interactive elements
- Include accessibility identifiers for UI testing
- Optimize async loading with proper state management

## Common Workflows

### Building a New SwiftUI View

1. Define the view's state and ownership location
2. Identify dependencies to inject via @Environment
3. Sketch the view hierarchy and extract subviews
4. Implement async loading with .task and explicit states
5. Add accessibility labels and identifiers
6. Test and validate in different contexts

### Refactoring Existing Views

1. Identify state that can be simplified or moved
2. Extract reusable components from repeated patterns
3. Modernize state management (@Observable, @Environment)
4. Improve accessibility and performance
5. Test thoroughly after changes

## How to Use Steering Files

To access detailed guidance for any component or pattern:

```text
Call action "readSteering" with powerName="swiftui-ui-patterns", steeringFile="{filename}.md"
```

**Examples:**

- For TabView patterns: `steeringFile="tabview.md"`
- For sheet presentation: `steeringFile="sheets.md"`
- For app architecture: `steeringFile="app-wiring.md"`
- For complete component index: `steeringFile="components-index.md"`

Each steering file contains:

- Intent and best-fit scenarios
- Minimal usage patterns with examples
- Performance notes and common pitfalls
- References to production code patterns

## Best Practices Summary

- Use modern SwiftUI state (`@State`, `@Binding`, `@Observable`,

  `@Environment`)

- Prefer composition; keep views small and focused
- Use async/await with `.task` and explicit loading/error states
- Maintain existing project conventions when editing legacy files
- Sheets: Prefer `.sheet(item:)` over `.sheet(isPresented:)` when possible
- Sheets should own their actions and call `dismiss()` internally
- Add accessibility labels for interactive elements
- Use accessibility identifiers for UI testing
- Optimize list performance with explicit IDs when needed

## Design System Integration

For projects using design tokens and shared styling:

- Read **design-guidelines-summary** for quick token reference
- Read **design-guidelines-canonical** for complete design system standards
- Follow DesignTokens for colors and spacing
- Use glassEffect helpers (`glassBarStyle`, `glassPanelStyle`) when available

---

**Framework:** SwiftUI **Platform:** iOS, macOS, watchOS, tvOS **Minimum
Version:** iOS 14.0+
