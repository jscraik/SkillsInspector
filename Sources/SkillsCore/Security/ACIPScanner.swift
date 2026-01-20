import Foundation

/// Actor for scanning content for ACIP (AI Content Injection Protection) v1.3 patterns.
/// Detects prompt injection, jailbreak attempts, and other adversarial content.
public actor ACIPScanner {
    /// Trust boundary classification for content sources
    public enum TrustBoundary: String, Codable, Sendable {
        case user
        case assistant
        case tool
        case file
        case remote
        case unknown
    }

    /// Injection pattern definition
    public struct InjectionPattern: Identifiable, Codable, Sendable {
        public let id: String
        public let name: String
        private let patternString: String
        public let severity: Severity
        public let description: String

        /// Compile the pattern string to a Regex
        public var pattern: Regex<AnyRegexOutput> {
            get throws {
                try Regex(patternString)
            }
        }

        public enum Severity: String, Codable, Sendable {
            case critical
            case high
            case medium
            case low
        }

        public init(
            id: String,
            name: String,
            pattern: String,
            severity: Severity,
            description: String
        ) {
            self.id = id
            self.name = name
            self.patternString = pattern
            self.severity = severity
            self.description = description
        }

        // Custom coding for Regex type
        enum CodingKeys: String, CodingKey {
            case id, name, patternString, severity, description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            patternString = try container.decode(String.self, forKey: .patternString)
            severity = try container.decode(Severity.self, forKey: .severity)
            description = try container.decode(String.self, forKey: .description)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(patternString, forKey: .patternString)
            try container.encode(severity, forKey: .severity)
            try container.encode(description, forKey: .description)
        }

        /// Built-in ACIP v1.3 compatible patterns
        public static let builtInPatterns: [InjectionPattern] = {
            let patternStrings: [(id: String, name: String, pattern: String, severity: Severity, description: String)] = [
                (
                    "ignore-previous",
                    "Ignore Previous Instructions",
                    "(?i)(ignore|disregard|forget)\\s+(all\\s+)?(previous|above|earlier|the\\s+following)",
                    .high,
                    "Attempts to override system instructions"
                ),
                (
                    "jailbreak-dan",
                    "DAN Jailbreak",
                    "(?i)(do\\s+anything\\s+now|you\\s+are\\s+dan|you\\s+don'?t\\s+have\\s+to\\s+follow|hello\\s+chatgpt)",
                    .critical,
                    "DAN (Do Anything Now) jailbreak pattern"
                ),
                (
                    "jailbreak-developer",
                    "Developer Mode Jailbreak",
                    "(?i)(developer\\s+mode|\\[\\s*\\*\\s*\\]|\\[\\s*##\\s*\\]|\\(\\s*\\*\\s*\\))",
                    .critical,
                    "Developer mode override attempt"
                ),
                (
                    "role-confusion",
                    "Role Confusion",
                    "(?i)(you\\s+are\\s+now\\s+(a|an)|pretend\\s+(you\\s+are|to\\s+be)|act\\s+as\\s+(if\\s+you\\s+are)\\s+(a\\s+)?(human|user|admin))",
                    .high,
                    "Attempts to confuse role boundaries"
                ),
                (
                    "prompt-leak",
                    "Prompt Extraction",
                    "(?i)(show\\s+me\\s+your|print\\s+(your|the)|reveal\\s+(your|the)|what\\s+(are\\s+)?your\\s+(instructions|prompt|system))",
                    .high,
                    "Attempts to extract system prompt"
                ),
                (
                    "override-safety",
                    "Safety Override",
                    "(?i)(disable|turn\\s+off|bypass|ignore)\\s+(your|all)?\\s*(safety\\s+filters?|safety|security|ethical|moral|filters?)",
                    .critical,
                    "Attempts to disable safety measures"
                ),
                (
                    "code-injection",
                    "Code Injection",
                    "(?i)(execute|run|eval|exec)\\s+\\(?.*?\\)?",
                    .medium,
                    "Suspicious code execution patterns"
                )
            ]

            return patternStrings.map { def in
                InjectionPattern(
                    id: def.id,
                    name: def.name,
                    pattern: def.pattern,
                    severity: def.severity,
                    description: def.description
                )
            }
        }()
    }

    /// Action to take on quarantined content
    public enum QuarantineAction: Sendable {
        case allow(content: String)
        case quarantine(reason: String, match: String, safeExcerpt: String)
        case block(reason: String, match: String)

        var isAllowed: Bool {
            if case .allow = self { return true }
            return false
        }

        var isQuarantined: Bool {
            if case .quarantine = self { return true }
            return false
        }

        var isBlocked: Bool {
            if case .block = self { return true }
            return false
        }
    }

    /// Scan result with context
    public struct ScanResult: Sendable {
        public let action: QuarantineAction
        public let patterns: [InjectionPattern]
        public let matchCount: Int
        public let matchedLines: [Int]
    }

    private var config: SecurityConfig

    public init(config: SecurityConfig = SecurityConfig()) {
        self.config = config
    }

    /// Scan text content for injection patterns
    /// - Parameters:
    ///   - content: The text content to scan
    ///   - source: The trust boundary of the content source
    ///   - contentID: Optional identifier for the content
    /// - Returns: Scan result with recommended action
    public func scan(
        content: String,
        source: TrustBoundary = .unknown,
        contentID: String? = nil
    ) -> ScanResult {
        var matchedPatterns: [InjectionPattern] = []
        var matchedLines: Set<Int> = []
        var totalMatches = 0

        // Select patterns to use based on config
        let patternsToUse = config.enabledPatterns.isEmpty
            ? InjectionPattern.builtInPatterns
            : InjectionPattern.builtInPatterns.filter { config.enabledPatterns.contains($0.id) }

        let allowlistRegexes = config.allowlist.compactMap { pattern in
            try? Regex(pattern)
        }
        let compiledPatterns: [(InjectionPattern, Regex<AnyRegexOutput>)] = patternsToUse.compactMap { pattern in
            guard let regex = try? pattern.pattern else { return nil }
            return (pattern, regex)
        }

        let lines = content.split(whereSeparator: \.isNewline)

        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1

            // Skip allowlisted patterns for this line
            if allowlistRegexes.contains(where: { line.firstMatch(of: $0) != nil }) {
                continue
            }

            // Check against blocklist first
            for blockPattern in config.blocklist {
                if line.contains(blockPattern) {
                    return ScanResult(
                        action: .block(
                            reason: "Content matches blocklist pattern",
                            match: blockPattern
                        ),
                        patterns: [],
                        matchCount: 1,
                        matchedLines: [lineNumber]
                    )
                }
            }

            // Scan for injection patterns
            for (pattern, regex) in compiledPatterns {
                if line.firstMatch(of: regex) != nil {
                    matchedPatterns.append(pattern)
                    matchedLines.insert(lineNumber)
                    totalMatches += 1

                    // Early exit for critical matches
                    if pattern.severity == .critical {
                        return ScanResult(
                            action: .block(
                                reason: "Critical pattern detected: \(pattern.name)",
                                match: pattern.id
                            ),
                            patterns: [pattern],
                            matchCount: 1,
                            matchedLines: [lineNumber]
                        )
                    }
                }
            }
        }

        // Determine action based on matches
        let action: QuarantineAction
        if matchedPatterns.isEmpty {
            action = .allow(content: content)
        } else {
            let hasHighOrCritical = matchedPatterns.contains {
                $0.severity == .high || $0.severity == .critical
            }

            if hasHighOrCritical {
                let excerpt = generateSafeExcerpt(from: content, lines: Array(matchedLines))
                action = .quarantine(
                    reason: "Suspicious patterns detected",
                    match: matchedPatterns.map { $0.id }.joined(separator: ", "),
                    safeExcerpt: excerpt
                )
            } else {
                action = .allow(content: content)
            }
        }

        return ScanResult(
            action: action,
            patterns: matchedPatterns,
            matchCount: totalMatches,
            matchedLines: Array(matchedLines).sorted()
        )
    }

    /// Scan an entire skill directory
    /// - Parameters:
    ///   - path: Path to the skill directory
    ///   - source: Trust boundary of the content
    /// - Returns: Dictionary of file path to scan result
    public func scanSkill(
        at path: URL,
        source: TrustBoundary = .unknown
    ) -> [String: ScanResult] {
        var results: [String: ScanResult] = [:]
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(at: path, includingPropertiesForKeys: nil) else {
            return results
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" || fileURL.pathExtension == "swift" else {
                continue
            }

            if !config.scanReferences, isReferencePath(fileURL) {
                continue
            }

            let resolvedPath = fileURL.resolvingSymlinksInPath().path

            if let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
               fileSize > config.maxFileSize {
                results[resolvedPath] = ScanResult(
                    action: .quarantine(
                        reason: "File exceeds max size limit",
                        match: "file_size",
                        safeExcerpt: ""
                    ),
                    patterns: [],
                    matchCount: 0,
                    matchedLines: []
                )
                continue
            }

            guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            if fileURL.pathExtension == "md", !config.scanCodeBlocks {
                content = stripMarkdownCodeBlocks(from: content)
            }

            let result = scan(content: content, source: source, contentID: resolvedPath)
            results[resolvedPath] = result
        }

        return results
    }

    /// Update the scanner configuration
    public func updateConfig(_ newConfig: SecurityConfig) {
        self.config = newConfig
    }

    /// Generate a safe excerpt showing matched context without including malicious content
    private func generateSafeExcerpt(from content: String, lines: [Int]) -> String {
        let contentLines = content.split(whereSeparator: \.isNewline)
        var excerptLines: [String] = []

        for lineNum in lines.prefix(5) { // Max 5 lines
            let index = max(0, lineNum - 1)
            if index < contentLines.count {
                let line = String(contentLines[index])
                // Truncate long lines and add ellipsis
                let truncated = line.count > 100 ? String(line.prefix(100)) + "..." : line
                excerptLines.append("[L\(lineNum)]: \(truncated)")
            }
        }

        return excerptLines.joined(separator: "\n")
    }

    private func isReferencePath(_ fileURL: URL) -> Bool {
        let path = fileURL.path
        return path.contains("/references/") || path.contains("/assets/") || path.contains("/scripts/")
    }

    private func stripMarkdownCodeBlocks(from content: String) -> String {
        let lines = content.split(whereSeparator: \.isNewline)
        var output: [Substring] = []
        var inCodeBlock = false
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            if !inCodeBlock {
                output.append(line)
            }
        }
        return output.joined(separator: "\n")
    }
}
