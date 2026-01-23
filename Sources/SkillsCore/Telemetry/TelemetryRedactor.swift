import Foundation
import CryptoKit

// MARK: - Telemetry Redactor

/// Redacts sensitive information from telemetry data.
/// Ensures privacy by redacting paths and hashing identifiers.
public enum TelemetryRedactor: Sendable {
    /// Redact a file path by replacing the home directory with ~
    public static func redactPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }

    /// Redact a URL by replacing the home directory with ~
    /// - Returns: A redacted URL string, ensuring the home directory is always redacted
    public static func redactURL(_ url: URL) -> URL {
        // Use the path-based redaction which handles home directory replacement
        let redactedPath = redactPath(url.path)

        // Return a file URL with the redacted path
        // This ensures the home directory is always redacted, even if URL construction fails
        return URL(fileURLWithPath: redactedPath)
    }

    /// Hash a sensitive identifier (user ID, email, etc.) with salt for privacy
    /// Returns a stable hash that cannot be reversed to the original value
    public static func hashIdentifier(_ identifier: String, salt: String = "stools-telemetry-salt-v1") -> String {
        let data = (identifier + salt).data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.prefix(16).joined()
    }

    /// Scrub potential PII from a string by replacing with placeholder
    /// - Uses simple patterns for email addresses, phone numbers, etc.
    /// - Returns the string with PII replaced by [REDACTED]
    public static func scrubPII(_ text: String) -> String {
        var result = text

        // Email pattern (simple)
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[EMAIL-REDACTED]")
        }

        // Phone pattern (simple)
        let phonePattern = #"\+?\d{1,3}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[PHONE-REDACTED]")
        }

        // IP address pattern
        let ipPattern = #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#
        if let regex = try? NSRegularExpression(pattern: ipPattern) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[IP-REDACTED]")
        }

        return result
    }

    /// Redact a skill name by removing potential PII
    public static func redactSkillName(_ name: String) -> String {
        scrubPII(name)
    }

    /// Redact hostname to <redacted> for privacy
    /// Hostnames can contain user-identifiable information (e.g., username-based naming)
    public static func redactHostName(_ hostName: String) -> String {
        // Always redact hostnames to prevent potential PII leakage
        // Hostnames often contain usernames or device identifiers
        return "<redacted>"
    }
}

// MARK: - Redacted Types

/// A redacted string wrapper for type safety
public struct RedactedString: Sendable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = TelemetryRedactor.redactPath(value)
    }

    public var description: String { value }
}
