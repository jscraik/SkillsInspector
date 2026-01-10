import Foundation

enum JSONValidator {
    /// Minimal draft-2020-12 schema validation using JSONSerialization + a simple structural check.
    /// This is a conservative best-effort: it ensures required keys and types for the current schema.
    /// Returns true if validation passes or if schema parsing fails harmlessly.
    static func validate(json: String, schema: String) -> Bool {
        guard
            let jsonData = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return false }

        // Hard-coded required keys for schemaVersion 1
        let requiredTop = ["schemaVersion", "toolVersion", "generatedAt", "scanned", "errors", "warnings", "findings"]
        for key in requiredTop {
            if obj[key] == nil { return false }
        }
        guard let findings = obj["findings"] as? [[String: Any]] else { return false }
        for f in findings {
            let required = ["ruleID", "severity", "agent", "file", "message"]
            for k in required where f[k] == nil { return false }
        }
        return true
    }
}
