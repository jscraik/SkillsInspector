import Foundation

/// Sanitizes content for safe GraphViz DOT output
public actor DOTSanitizer {
    private let maxLabelLength = 1000

    public func sanitizeLabel(_ label: String) -> String {
        let truncated = String(label.prefix(maxLabelLength))
        var sanitized = ""
        for scalar in truncated.unicodeScalars {
            let code = scalar.value
            if code == 34 { sanitized += "\\\"" }  // "
            else if code == 92 { sanitized += "\\\\" }   // \
            else if code == 10 { sanitized += "\\n" }    // \n
            else if code == 13 { sanitized += "\\r" }    // \r
            else if code == 9 { sanitized += "\\t" }     // \t
            else if code == 124 { sanitized += "\\|" }  // |
            else if code == 60 { sanitized += "\\<" }   // <
            else if code == 62 { sanitized += "\\>" }   // >
            else if code == 123 { sanitized += "\\{" }   // {
            else if code == 125 { sanitized += "\\}" }   // }
            else if code >= 32 && code < 127 && code != 34 && code != 92 && code != 60 && code != 62 && code != 123 && code != 125 {
                // Printable ASCII (excluding already-handled quotes, backslash, <, >, braces)
                sanitized += String(describing: scalar)
            }
        }
        return sanitized
    }

    public func sanitizeNodeId(_ nodeId: String) -> String {
        var sanitized = ""
        for scalar in nodeId.unicodeScalars {
            let code = scalar.value
            // Check if alphanumeric or allowed special characters
            let isAlphaNumeric = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
            let isAllowed = code == 95 || code == 45 || code == 46  // _ - .

            if isAlphaNumeric || isAllowed {
                sanitized += String(describing: scalar)
            } else {
                sanitized += "_"
            }
        }
        if sanitized.isEmpty { sanitized = "node_" }
        return sanitized
    }

    public func quotedString(_ content: String) -> String {
        return "\"\(sanitizeLabel(content))\""
    }

    public func sanitizeEdgeLabel(_ label: String) -> String {
        var sanitized = sanitizeLabel(label)
        sanitized = sanitized.replacingOccurrences(of: "&", with: "&amp;")
        sanitized = sanitized.replacingOccurrences(of: "<", with: "&lt;")
        sanitized = sanitized.replacingOccurrences(of: ">", with: "&gt;")
        return sanitized
    }

    public func validateDOT(_ dotString: String) -> Bool {
        let suspiciousPatterns = ["<script", "javascript:", "onerror=", "onload=", "<iframe", "<object", "data:", "vbscript:"]
        let lowercased = dotString.lowercased()
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) { return false }
        }
        let braceBalance = dotString.reduce(0) { $0 + ($1 == "{" ? 1 : $1 == "}" ? -1 : 0) }
        return braceBalance == 0
    }

    public func formatSkillLabel(name: String, agent: String? = nil) -> String {
        var label = sanitizeLabel(name)
        if let agent = agent { label += "\\n" + sanitizeLabel(agent) }
        return quotedString(label)
    }

    public func sanitizePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let display = url.lastPathComponent.isEmpty ? "<file>" : url.lastPathComponent
        return sanitizeLabel(display)
    }

    public func truncate(_ string: String, maxLength: Int = 1000) -> String {
        guard string.count > maxLength else { return string }
        return String(string.prefix(maxLength - 3)) + "..."
    }

    public func makeNode(id: String, label: String) -> String {
        let safeId = sanitizeNodeId(id)
        let safeLabel = quotedString(label)
        return "  \"\(safeId)\" [label=\(safeLabel)]"
    }

    public func makeEdge(from: String, to: String, label: String? = nil) -> String {
        let safeFrom = sanitizeNodeId(from)
        let safeTo = sanitizeNodeId(to)
        if let label = label {
            return "  \"\(safeFrom)\" -> \"\(safeTo)\" [label=\(sanitizeEdgeLabel(label))]"
        }
        return "  \"\(safeFrom)\" -> \"\(safeTo)\""
    }
}
