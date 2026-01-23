import Foundation

/// Security scanner for detecting security issues in skill files
public actor SecurityScanner {
    /// Registered security rules
    private var rules: [SecurityRule]

    /// Ignored findings (false positives) manager
    private let ignoredFindings: SecurityIgnoredFindings

    /// Ledger for telemetry (optional, for graceful degradation)
    private let ledger: SkillLedger?

    /// Create scanner with default rules
    public init() {
        self.rules = Self.defaultRules()
        self.ignoredFindings = SecurityIgnoredFindings()
        self.ledger = try? SkillLedger()
    }

    /// Create scanner with specific rules
    /// - Parameter rules: Security rules to use
    public init(rules: [SecurityRule]) {
        self.rules = rules
        self.ignoredFindings = SecurityIgnoredFindings()
        self.ledger = try? SkillLedger()
    }

    /// Create scanner with specific rules and ignored findings manager
    /// - Parameters:
    ///   - rules: Security rules to use
    ///   - ignoredFindings: Ignored findings manager
    public init(rules: [SecurityRule], ignoredFindings: SecurityIgnoredFindings) {
        self.rules = rules
        self.ignoredFindings = ignoredFindings
        self.ledger = try? SkillLedger()
    }

    /// Create scanner with specific rules, ignored findings manager, and ledger
    /// - Parameters:
    ///   - rules: Security rules to use
    ///   - ignoredFindings: Ignored findings manager
    ///   - ledger: Ledger for telemetry (pass nil to disable telemetry)
    public init(rules: [SecurityRule], ignoredFindings: SecurityIgnoredFindings, ledger: SkillLedger?) {
        self.rules = rules
        self.ignoredFindings = ignoredFindings
        self.ledger = ledger
    }

    /// Create scanner with specific rules, ignored findings manager, and ledger
    /// - Parameters:
    ///   - rules: Security rules to use
    ///   - ignoredFindings: Ignored findings manager
    ///   - ledger: Ledger for telemetry
    public init(rules: [SecurityRule], ignoredFindings: SecurityIgnoredFindings, ledger: SkillLedger) {
        self.rules = rules
        self.ignoredFindings = ignoredFindings
        self.ledger = ledger
    }

    /// Scan a skill document for security issues
    /// - Parameter doc: Skill document to scan
    /// - Returns: Array of security findings (excluding ignored findings)
    public func scan(doc: SkillDoc) async throws -> [Finding] {
        let startTime = Date()
        var findings: [Finding] = []
        var triggeredRules: Set<String> = []

        // Scan the main skill file
        if let skillContent = try? String(contentsOf: doc.skillFileURL, encoding: .utf8) {
            let contentFindings = try await scanContent(
                skillContent,
                file: doc.skillFileURL,
                skillDoc: doc
            )
            findings.append(contentsOf: contentFindings)
            triggeredRules.formUnion(contentFindings.map { $0.ruleID })
        }

        // Scan scripts if they exist
        if doc.scriptsCount > 0 {
            let scriptsURL = doc.skillDirURL.appendingPathComponent("scripts")
            if FileManager.default.fileExists(atPath: scriptsURL.path) {
                let scriptFindings = try await scanScripts(in: scriptsURL, skillDoc: doc)
                findings.append(contentsOf: scriptFindings)
                triggeredRules.formUnion(scriptFindings.map { $0.ruleID })
            }
        }

        // Filter out ignored findings
        let filteredFindings = await filterIgnored(findings)

        // Log telemetry (if ledger is available)
        if let ledger = ledger {
            let duration = Date().timeIntervalSince(startTime)
            await logSecurityTelemetry(
                ledger: ledger,
                skillName: doc.name ?? "unknown",
                duration: duration,
                findingsCount: filteredFindings.count,
                triggeredRules: Array(triggeredRules).sorted()
            )
        }

        return filteredFindings
    }

    // MARK: - Telemetry

    /// Log security scan telemetry to ledger
    /// - Parameters:
    ///   - ledger: The ledger to record to
    ///   - skillName: Name of the skill scanned
    ///   - duration: Scan duration in seconds
    ///   - findingsCount: Number of findings detected
    ///   - triggeredRules: Rules that were triggered
    private func logSecurityTelemetry(
        ledger: SkillLedger,
        skillName: String,
        duration: TimeInterval,
        findingsCount: Int,
        triggeredRules: [String]
    ) async {
        let note: String
        if triggeredRules.isEmpty {
            note = "Security scan completed in \(String(format: "%.2f", duration))s, no findings"
        } else {
            note = "Security scan completed in \(String(format: "%.2f", duration))s, \(findingsCount) finding(s), rules: \(triggeredRules.joined(separator: ", "))"
        }

        let input = LedgerEventInput(
            eventType: .securityScan,
            skillName: skillName,
            status: findingsCount == 0 ? .success : .failure,
            note: note
        )

        do {
            _ = try await ledger.record(input)
        } catch {
            // Silently fail if telemetry recording fails
            // Telemetry is best-effort and shouldn't break the scan
        }
    }

    /// Scan all script files in a directory
    /// - Parameters:
    ///   - scriptsURL: Directory containing scripts
    ///   - skillDoc: Associated skill document
    /// - Returns: Array of security findings (excluding ignored findings)
    public func scanAllScripts(in doc: SkillDoc) async throws -> [Finding] {
        let scriptsURL = doc.skillDirURL.appendingPathComponent("scripts")
        let findings = try await scanScripts(in: scriptsURL, skillDoc: doc)
        return await filterIgnored(findings)
    }

    /// Scan a single script file
    /// - Parameters:
    ///   - file: URL of the script file
    ///   - skillDoc: Associated skill document
    /// - Returns: Array of security findings (excluding ignored findings)
    public func scanScript(at file: URL, skillDoc: SkillDoc) async throws -> [Finding] {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            return []
        }
        let findings = try await scanContent(content, file: file, skillDoc: skillDoc)
        return await filterIgnored(findings)
    }

    /// Scan content for security issues
    /// - Parameters:
    ///   - content: File content to scan
    ///   - file: URL of the file
    ///   - skillDoc: Associated skill document
    /// - Returns: Array of security findings
    private func scanContent(
        _ content: String,
        file: URL,
        skillDoc: SkillDoc
    ) async throws -> [Finding] {
        var findings: [Finding] = []

        for rule in rules {
            let ruleFindings = try await rule.scan(content: content, file: file, skillDoc: skillDoc)
            findings.append(contentsOf: ruleFindings)
        }

        return findings
    }

    /// Scan all scripts in a directory
    /// - Parameters:
    ///   - scriptsURL: Directory containing scripts
    ///   - skillDoc: Associated skill document
    /// - Returns: Array of security findings
    private func scanScripts(in scriptsURL: URL, skillDoc: SkillDoc) async throws -> [Finding] {
        var findings: [Finding] = []

        // Use contentsOfDirectory instead of enumerator for async safety
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: scriptsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        // Now scan each file
        for fileURL in fileURLs {
            // Skip directories
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory == true {
                continue
            }

            // Only scan code files
            let ext = fileURL.pathExtension.lowercased()
            guard ["swift", "js", "ts", "py", "sh", "bash"].contains(ext) else {
                continue
            }

            let fileFindings = try await scanScript(at: fileURL, skillDoc: skillDoc)
            findings.append(contentsOf: fileFindings)
        }

        return findings
    }

    /// Default built-in security rules
    public static func defaultRules() -> [SecurityRule] {
        [
            HardcodedSecretRule(),
            CommandInjectionRule(),
            // Additional rules will be added here:
            // InsecureFileOperationRule(),
            // EvalUsageRule(),
        ]
    }

    /// Register a new security rule
    /// - Parameter rule: Rule to register
    public func registerRule(_ rule: SecurityRule) {
        rules.append(rule)
    }

    /// Remove a rule by ID
    /// - Parameter ruleID: ID of rule to remove
    public func unregisterRule(ruleID: String) {
        rules.removeAll { $0.ruleID == ruleID }
    }

    /// Get all registered rule IDs
    /// - Returns: Array of rule IDs
    public func registeredRuleIDs() -> [String] {
        rules.map { $0.ruleID }
    }

    // MARK: - Ignored Findings Management

    /// Mark a finding as ignored (false positive)
    /// - Parameter finding: The finding to ignore
    public func ignoreFinding(_ finding: Finding) async {
        await ignoredFindings.ignore(
            ruleID: finding.ruleID,
            fileURL: finding.fileURL,
            line: finding.line
        )
    }

    /// Unmark a finding as ignored (restore it)
    /// - Parameter finding: The finding to restore
    public func unignoreFinding(_ finding: Finding) async {
        await ignoredFindings.unignore(
            ruleID: finding.ruleID,
            fileURL: finding.fileURL
        )
    }

    /// Check if a finding is ignored
    /// - Parameter finding: The finding to check
    /// - Returns: True if the finding is marked as ignored
    public func isIgnored(_ finding: Finding) async -> Bool {
        return await ignoredFindings.isIgnored(
            ruleID: finding.ruleID,
            fileURL: finding.fileURL
        )
    }

    /// Get all ignored findings
    /// - Returns: Array of ignored finding records
    public func getAllIgnored() async -> [IgnoredFinding] {
        return await ignoredFindings.getAllIgnored()
    }

    /// Clear all ignored findings
    public func clearAllIgnored() async {
        await ignoredFindings.clearAll()
    }

    /// Get count of ignored findings
    /// - Returns: Number of ignored findings
    public func ignoredCount() async -> Int {
        return await ignoredFindings.count()
    }

    // MARK: - Private Helpers

    /// Filter out ignored findings from results using bulk checking
    /// - Parameter findings: All findings
    /// - Returns: Findings that are not ignored
    private func filterIgnored(_ findings: [Finding]) async -> [Finding] {
        // Use bulk check for better performance (N findings = 1 operation instead of N)
        let ignoredKeys = await ignoredFindings.bulkCheckIgnored(findings)
        let ignoredSet = Set(ignoredKeys)

        return findings.filter { finding in
            let key = SecurityIgnoredFindings.makeKey(
                ruleID: finding.ruleID,
                fileURL: finding.fileURL
            )
            return !ignoredSet.contains(key)
        }
    }
}
