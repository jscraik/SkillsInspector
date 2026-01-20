import Foundation

/// Configuration for security scanning and pattern matching
public struct SecurityConfig: Codable, Sendable, Equatable {
    /// List of pattern IDs that are enabled for scanning
    /// Empty array means all built-in patterns are enabled
    public var enabledPatterns: [String]

    /// Regular expression patterns that are allowed (allowlist)
    /// Content matching these patterns will be skipped during scanning
    public var allowlist: [String]

    /// String patterns that trigger immediate blocking (blocklist)
    /// Content matching these patterns will be blocked regardless of other checks
    public var blocklist: [String]

    /// Maximum file size to scan (in bytes)
    /// Files larger than this will be automatically quarantined
    public var maxFileSize: Int

    /// Whether to scan file references (assets/, references/, etc.)
    public var scanReferences: Bool

    /// Whether to scan code blocks within markdown files
    public var scanCodeBlocks: Bool

    public init(
        enabledPatterns: [String] = [],
        allowlist: [String] = [],
        blocklist: [String] = [],
        maxFileSize: Int = 1_000_000, // 1MB default
        scanReferences: Bool = false,
        scanCodeBlocks: Bool = true
    ) {
        self.enabledPatterns = enabledPatterns
        self.allowlist = allowlist
        self.blocklist = blocklist
        self.maxFileSize = maxFileSize
        self.scanReferences = scanReferences
        self.scanCodeBlocks = scanCodeBlocks
    }

    /// Default security configuration for production use
    /// Allowlist Mermaid start/end state markers to avoid false positives in docs.
    public static let `default` = SecurityConfig(
        allowlist: [
            "\\[\\*\\]\\s*-->",
            "-->\\s*\\[\\*\\]",
            "You'?ve probably run into this\\.",
            "Reveal the hidden issues \\(race conditions, cleanup\\)",
            "Run these when available and record results:",
            "Run a fast QA pass \\(clarity, missing steps, top 3 failure points\\)\\.",
            "If `\\.vale\\.ini` exists, run `vale <doc>` and record results\\.",
            "If markdownlint config exists, run `markdownlint-cli2 <doc> --config <config>`\\.",
            "If `scripts/check_readability\\.py` exists, run it and record the score and target range .*",
            "If `scripts/check_brand_guidelines\\.py` exists, run it against the repo root\\.",
            "python scripts/check_readability\\.py <doc>",
            "python scripts/check_brand_guidelines\\.py --repo \\. --docs <doc>",
            "vale <doc>",
            "markdownlint-cli2 <doc> --config <config>",
            "Use `str_replace` to make edits \\(never reprint the whole doc\\)"
        ]
    )

    /// Permissive configuration for trusted sources
    public static let permissive = SecurityConfig(
        enabledPatterns: [], // All patterns enabled
        allowlist: [
            // Common safe patterns
            "\\[\\s*Note\\s*\\]",
            "\\[\\s*WARNING\\s*\\]",
            "\\[\\s*INFO\\s*\\]"
        ],
        blocklist: [],
        scanReferences: false,
        scanCodeBlocks: false
    )

    /// Strict configuration for untrusted sources
    public static let strict = SecurityConfig(
        enabledPatterns: [], // All patterns enabled
        allowlist: [],
        blocklist: [
            // Known dangerous patterns
            "eval(",
            "exec(",
            "system(",
            "__import__"
        ],
        maxFileSize: 500_000, // 500KB
        scanReferences: true,
        scanCodeBlocks: true
    )
}
