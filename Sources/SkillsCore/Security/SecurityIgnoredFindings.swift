import Foundation

/// Manages ignored security findings (false positives) stored in UserDefaults
/// Each ignored finding is tracked by a unique key combining rule ID and file path
public actor SecurityIgnoredFindings {
    /// UserDefaults key for storing ignored findings
    private static let storageKey = "com.stools.security.ignoredFindings"

    /// Create a unique key for a finding (ruleID + file path)
    /// - Parameters:
    ///   - ruleID: The rule that generated the finding
    ///   - fileURL: The file where the finding occurred
    /// - Returns: A unique string key for this finding
    public static func makeKey(ruleID: String, fileURL: URL) -> String {
        // Use the file path to create a stable identifier
        let normalizedPath = fileURL.standardizedFileURL.path
        return "\(ruleID)|\(normalizedPath)"
    }

    /// Check if multiple findings are ignored (bulk operation)
    /// - Parameter findings: Array of findings to check
    /// - Returns: Set of keys that are marked as ignored
    public func bulkCheckIgnored(_ findings: [Finding]) -> Set<String> {
        let defaults = UserDefaults.standard
        var ignoredKeys: Set<String> = []

        for finding in findings {
            let key = Self.makeKey(ruleID: finding.ruleID, fileURL: finding.fileURL)
            if defaults.string(forKey: key) != nil {
                ignoredKeys.insert(key)
            }
        }

        return ignoredKeys
    }

    /// Check if a finding is ignored
    /// - Parameters:
    ///   - ruleID: The rule that generated the finding
    ///   - fileURL: The file where the finding occurred
    /// - Returns: True if this finding is marked as ignored
    public func isIgnored(ruleID: String, fileURL: URL) -> Bool {
        let key = Self.makeKey(ruleID: ruleID, fileURL: fileURL)
        return UserDefaults.standard.string(forKey: key) != nil
    }

    /// Mark a finding as ignored (false positive)
    /// - Parameters:
    ///   - ruleID: The rule that generated the finding
    ///   - fileURL: The file where the finding occurred
    ///   - line: Optional line number for more specific ignoring
    public func ignore(ruleID: String, fileURL: URL, line: Int? = nil) {
        let key = Self.makeKey(ruleID: ruleID, fileURL: fileURL)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var value = timestamp

        // Include line number if provided for more specific ignoring
        if let line = line {
            value += "|line:\(line)"
        }

        UserDefaults.standard.set(value, forKey: key)
    }

    /// Unmark a finding as ignored (restore it)
    /// - Parameters:
    ///   - ruleID: The rule that generated the finding
    ///   - fileURL: The file where the finding occurred
    public func unignore(ruleID: String, fileURL: URL) {
        let key = Self.makeKey(ruleID: ruleID, fileURL: fileURL)
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Get all ignored findings
    /// - Returns: Array of IgnoredFinding records
    public func getAllIgnored() -> [IgnoredFinding] {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        var findings: [IgnoredFinding] = []

        for (key, value) in dictionary {
            // Only process keys that contain our separator (our finding keys)
            // Finding keys have format: "ruleID|path"
            guard key.contains("|") else {
                continue
            }

            // Parse the finding key
            let parts = key.split(separator: "|", maxSplits: 1)
            guard parts.count == 2,
                  let ruleID = parts.first,
                  let filePath = parts.last else {
                continue
            }

            let fileURL = URL(fileURLWithPath: String(filePath))

            // Parse the value to extract timestamp and optional line
            if let stringValue = value as? String {
                let valueParts = stringValue.split(separator: "|")
                let timestampString = String(valueParts[0])
                let line = valueParts.count >= 2 ? Int(String(valueParts[1]).dropFirst(5)) : nil

                findings.append(IgnoredFinding(
                    ruleID: String(ruleID),
                    fileURL: fileURL,
                    line: line,
                    ignoredAt: timestampString
                ))
            }
        }

        return findings.sorted { $0.ignoredAt > $1.ignoredAt }
    }

    /// Clear all ignored findings
    public func clearAll() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()

        for key in dictionary.keys {
            // Our finding keys contain the separator
            if key.contains("|") {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Count of ignored findings
    /// - Returns: Number of ignored findings
    public func count() -> Int {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        return dictionary.keys.filter { $0.contains("|") }.count
    }
}

/// Record of an ignored finding
public struct IgnoredFinding: Identifiable, Sendable, Codable {
    public let id: String
    public let ruleID: String
    public let fileURL: URL
    public let line: Int?
    public let ignoredAt: String

    public init(ruleID: String, fileURL: URL, line: Int? = nil, ignoredAt: String) {
        self.id = UUID().uuidString
        self.ruleID = ruleID
        self.fileURL = fileURL
        self.line = line
        self.ignoredAt = ignoredAt
    }
}
