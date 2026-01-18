# Code Documentation Standards

This guide covers in-code documentation standards for
TypeScript/JavaScript/React, Swift, and configuration files.

## TypeScript/JavaScript + React (JSDoc/TSDoc)

Document public APIs (exports), non-obvious utilities, hooks, and any
function/component with constraints.

### Required Content for Public Symbols

- **One-line summary** starting with a verb (e.g., "Creates...", "Renders...")
- **`@param`** for non-trivial params (include units, allowed values,

  defaults)

- **`@returns`** (or React render contract if it returns JSX)
- **`@throws`** for thrown errors (name + condition)
- **`@example`** for anything with more than one "correct" usage
- **`@deprecated`** when applicable (include migration hint)

### React-Specific Documentation

- Document props contract (required/optional, default behavior,

  controlled/uncontrolled)

- Document accessibility contract: keyboard behavior, focus management, ARIA

  expectations

- For hooks: document dependencies, side effects, and SSR constraints

### Example: Function Documentation

```typescript
/**
 * Creates a debounced version of the provided function that delays invoking
 * until after wait milliseconds have elapsed since the last time it was invoked.
 *
 * @param func - The function to debounce
 * @param wait - The number of milliseconds to delay (default: 300)
 * @param immediate - If true, trigger on leading edge instead of trailing
 * @returns A debounced version of the original function
 * @throws {TypeError} When func is not a function
 *
 * @example
 * ```typescript
 * const debouncedSave = debounce(saveData, 500);
 * input.addEventListener('input', debouncedSave);
 * ```
 */
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number = 300,
  immediate: boolean = false
): (...args: Parameters<T>) => void {
  // Implementation...
}
```

### Example: React Component Documentation

```typescript
/**
 * Renders an accessible button with loading state and icon support.
 *
 * @param children - Button text or content
 * @param variant - Visual style variant (default: "primary")
 * @param size - Button size (default: "medium")
 * @param loading - Shows loading spinner and disables interaction
 * @param icon - Optional icon component to display
 * @param onClick - Click handler function
 * @returns JSX element with proper ARIA attributes and keyboard support
 *
 * @example
 * ```tsx
 * <Button variant="secondary" loading={isSubmitting} onClick={handleSubmit}>
 *   Save Changes
 * </Button>
 * ```
 */
export function Button({
  children,
  variant = "primary",
  size = "medium",
  loading = false,
  icon,
  onClick,
  ...props
}: ButtonProps) {
  // Implementation...
}
```

### Rules

- For public symbols, explain what the code does (behavior/contract), not just

  why

- Inline comments explain why/constraints, not what the code already says
- Do not invent; docs must match implementation and tests

## Swift (DocC / SwiftDoc)

Use `///` DocC comments for public types/methods, and anything with tricky
invariants.

### Required Content for Public Symbols (Swift)

- **Summary sentence**
- **`- Parameters:`** and **`- Returns:`** (when applicable)
- **`- Throws:`** (conditions and error meaning)
- **`- Important:`** for invariants/constraints
- **`- Warning:`** for footguns (threading, main-actor, performance, security)
- **`- Example:`** for non-obvious usage

### Best Practice (Richer DocC Directives)

- Add **`### Discussion`** to explain behavior, edge cases, and tradeoffs
- Add **`- Complexity:`** when time/space cost is non-trivial
- Use **`- Note:`** for usage guidance and **`- Attention:`** for

  user-impacting caveats

- Use **`## Topics`** and **`### {Group}`** to cluster related symbols on type

  docs

- Add a "See Also" list when there are close alternatives or companion APIs

### Example: Swift Function Documentation

```swift
/// Creates a secure hash of the input data using SHA-256 algorithm.
///
/// This function provides a cryptographically secure hash suitable for
/// password verification and data integrity checks.
///
/// - Parameters:
///   - data: The input data to hash
///   - salt: Optional salt value for additional security (recommended for passwords)
/// - Returns: A hexadecimal string representation of the hash
/// - Throws: `CryptoError.invalidInput` if data is empty
///
/// - Important: Always use a unique salt when hashing passwords to prevent
///   rainbow table attacks.
///
/// - Complexity: O(n) where n is the length of the input data
///
/// - Example:
/// ```swift
/// let password = "userPassword123"
/// let salt = generateRandomSalt()
/// let hash = try createSecureHash(data: password.data(using: .utf8)!, salt: salt)
/// ```
///
/// - Warning: This function performs cryptographic operations and may be slow
///   for large inputs. Consider using background queues for large data sets.
public func createSecureHash(data: Data, salt: Data? = nil) throws -> String {
    // Implementation...
}
```

### Example: Swift Type Documentation

```swift
/// A thread-safe cache that stores key-value pairs with automatic expiration.
///
/// `ExpiringCache` provides a high-performance caching solution with built-in
/// memory management and configurable expiration policies.
///
/// ## Topics
///
/// ### Creating a Cache
/// - ``init(maxSize:defaultTTL:)``
/// - ``init(configuration:)``
///
/// ### Storing and Retrieving Values
/// - ``set(_:forKey:ttl:)``
/// - ``get(_:)``
/// - ``remove(_:)``
///
/// ### Cache Management
/// - ``clear()``
/// - ``evictExpired()``
/// - ``statistics``
///
/// ### Discussion
///
/// The cache uses a combination of LRU eviction and TTL-based expiration to
/// manage memory efficiently. All operations are thread-safe and can be called
/// from any queue.
///
/// - Note: Cache performance is optimized for read-heavy workloads. Write
///   operations may be slower due to internal bookkeeping.
///
/// - Attention: The cache holds strong references to stored values. Ensure
///   proper memory management when storing large objects.
@MainActor
public class ExpiringCache<Key: Hashable, Value> {
    // Implementation...
}
```

### Concurrency Documentation

Document actor/isolation expectations (`@MainActor`, thread-safety)
explicitly:

```swift
/// Updates the user interface with new data.
///
/// - Important: This method must be called from the main actor context.
///   Use `await MainActor.run` if calling from a background context.
///
/// - Parameters:
///   - data: The new data to display
/// - Throws: `UIError.invalidData` if data format is incorrect
@MainActor
func updateUI(with data: DisplayData) throws {
    // Implementation...
}
```

## Configuration Files (JSON / TOML / YAML)

Goal: readers can safely edit config without guessing.

### Schema + Documentation Approach

- **JSON**: `.schema.json` + examples (since JSON cannot have comments)
- **YAML/TOML**: inline comments are allowed, but still link to schema/spec

### Document Each Key

- Each key's meaning, type, defaults, allowed values
- Security-sensitive keys (tokens, paths, network endpoints)
- Migration notes when keys change

### Provide Examples

- At least one minimal example and one full example

### Example: JSON Schema Documentation

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Application Configuration",
  "description": "Configuration schema for the application server",
  "type": "object",
  "properties": {
    "server": {
      "type": "object",
      "description": "HTTP server configuration",
      "properties": {
        "port": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535,
          "default": 3000,
          "description": "Port number for the HTTP server"
        },
        "host": {
          "type": "string",
          "default": "localhost",
          "description": "Hostname to bind the server to"
        }
      },
      "required": ["port"]
    },
    "database": {
      "type": "object",
      "description": "Database connection settings",
      "properties": {
        "url": {
          "type": "string",
          "format": "uri",
          "description": "Database connection URL (do not commit real values)"
        },
        "maxConnections": {
          "type": "integer",
          "minimum": 1,
          "default": 10,
          "description": "Maximum number of concurrent database connections"
        }
      },
      "required": ["url"]
    }
  },
  "required": ["server", "database"]
}
```

### Example: YAML with Inline Comments

```yaml
# Application Configuration
# See config.schema.json for full validation rules

# HTTP Server Settings
server:
  port: 3000              # Port number (1024-65535)
  host: "localhost"       # Hostname to bind to

# Database Configuration
database:
  # Connection URL - SECURITY: Use environment variables in production
  # Format: postgresql://user:password@host:port/database
  url: "${DATABASE_URL}"

  # Connection pool settings
  maxConnections: 10      # Maximum concurrent connections (default: 10)
  timeout: 30000          # Connection timeout in milliseconds

# Feature Flags
features:
  enableMetrics: true     # Enable Prometheus metrics endpoint
  enableDebug: false      # Enable debug logging (never true in production)

# Migration Notes:
# v2.0.0: Renamed 'db' to 'database'
# v1.5.0: Added 'features' section
```

### Validation Rule

Config docs must reference the validating mechanism (Zod schema, JSON Schema,
or typed config loader).

## Code Documentation QA Checklist

### TypeScript/JavaScript/React

- [ ] All exported/public functions/classes/hooks/components have docblocks
- [ ] Docblocks include constraints: units, allowed values, defaults, side

  effects

- [ ] `@throws` used where errors can occur; conditions are explicit
- [ ] At least one `@example` for multi-step or easy-to-misuse APIs
- [ ] React components document a11y contract (keyboard/focus/ARIA) when

  interactive

- [ ] No "narration" comments; comments explain intent/tradeoffs

### Swift

- [ ] Public APIs have DocC (`///`) with Parameters/Returns/Throws as needed
- [ ] Concurrency expectations documented (MainActor, thread-safety,

  isolation)

- [ ] Invariants/footguns captured with Important/Warning
- [ ] Rich DocC used: Discussion for behavior/edge cases, Complexity included

  when non-trivial

- [ ] Type docs group related symbols with Topics, and include See Also when

  close alternatives exist

- [ ] Note used for usage tips or common pitfalls when they exist

### JSON / TOML / YAML

- [ ] A schema exists (JSON Schema or Zod-derived) and is referenced by docs
- [ ] Minimal + full examples exist and match the schema
- [ ] Sensitive keys flagged with safe handling guidance
- [ ] Migration notes exist for renamed/removed keys

## Best Practices

### General Principles

- Document the contract (what), not the implementation (how)
- Include examples for anything non-obvious
- Flag security-sensitive parameters
- Document error conditions and recovery
- Keep docs close to code (same file/directory)

### Maintenance

- Update docs when changing function signatures
- Validate examples in CI/testing
- Review docs during code review
- Use linting tools to enforce documentation standards

### Accessibility

- Document keyboard interactions for UI components
- Include ARIA expectations for interactive elements
- Note screen reader behavior when relevant
- Document focus management patterns
