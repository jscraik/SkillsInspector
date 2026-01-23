import XCTest

final class TelemetrySchemaTests: XCTestCase {
    func testTelemetrySchemaParses() throws {
        let schemaURL = telemetrySchemaURL()
        let data = try Data(contentsOf: schemaURL)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(obj?["$schema"])
        XCTAssertNotNil(obj?["title"])
        XCTAssertNotNil(obj?["properties"])
        XCTAssertNotNil(obj?["$defs"])
    }

    func testTelemetryFixAppliedSampleValidates() throws {
        let payload = makePayload(
            event: "fix_applied",
            data: [
                "rule_id": "skill-name-format",
                "file_path": "/path/to/skill/SKILL.md",
                "automated": true,
                "result": "success"
            ]
        )
        XCTAssertTrue(validate(payload: payload))
    }

    func testTelemetryFixFailedSampleValidates() throws {
        let payload = makePayload(
            event: "fix_failed",
            data: [
                "rule_id": "frontmatter-structure",
                "file_path": "/path/to/skill/SKILL.md",
                "automated": true,
                "error": "Original text mismatch - file may have changed",
                "result": "not_applicable"
            ]
        )
        XCTAssertTrue(validate(payload: payload))
    }

    func testTelemetrySyncConfirmedSampleValidates() throws {
        let payload = makePayload(
            event: "sync_action_confirmed",
            data: [
                "action": "copy",
                "from_agent": "codex",
                "to_agent": "claude",
                "skill_name": "example-skill"
            ]
        )
        XCTAssertTrue(validate(payload: payload))
    }

    func testTelemetrySyncAppliedSampleValidates() throws {
        let payload = makePayload(
            event: "sync_action_applied",
            data: [
                "action": "bump_align",
                "from_agent": "claude",
                "to_agent": "codex",
                "skill_name": "example-skill",
                "result": "success"
            ]
        )
        XCTAssertTrue(validate(payload: payload))
    }

    func testTelemetrySyncCheckSampleValidates() throws {
        let payload = makePayload(
            event: "sync_check",
            data: [
                "missing_count": "2",
                "diff_count": "1",
                "total_issues": "3"
            ]
        )
        XCTAssertTrue(validate(payload: payload))
    }
}

private extension TelemetrySchemaTests {
    func telemetrySchemaURL() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/schema/telemetry-schema.json")
    }

    func makePayload(event: String, data: [String: Any]) -> [String: Any] {
        [
            "schema_version": "1",
            "event": event,
            "timestamp": "2026-01-23T01:30:00Z",
            "tool_version": "0.0.0",
            "data": data
        ]
    }

    func validate(payload: [String: Any]) -> Bool {
        guard payload["schema_version"] as? String == "1" else { return false }
        guard let event = payload["event"] as? String else { return false }
        guard let timestamp = payload["timestamp"] as? String else { return false }
        guard payload["tool_version"] as? String != nil else { return false }
        guard let data = payload["data"] as? [String: Any] else { return false }
        guard ISO8601DateFormatter().date(from: timestamp) != nil else { return false }

        switch event {
        case "fix_applied":
            return validateFixApplied(data: data)
        case "fix_failed":
            return validateFixFailed(data: data)
        case "sync_action_confirmed":
            return validateSyncConfirmed(data: data)
        case "sync_action_applied":
            return validateSyncApplied(data: data)
        case "sync_check":
            return validateSyncCheck(data: data)
        default:
            return false
        }
    }

    func validateFixApplied(data: [String: Any]) -> Bool {
        guard data["rule_id"] is String else { return false }
        guard data["file_path"] is String else { return false }
        guard data["automated"] is Bool else { return false }
        guard data["result"] as? String == "success" else { return false }
        return true
    }

    func validateFixFailed(data: [String: Any]) -> Bool {
        guard data["rule_id"] is String else { return false }
        guard data["file_path"] is String else { return false }
        guard data["automated"] is Bool else { return false }
        guard data["error"] is String else { return false }
        let result = data["result"] as? String
        return result == "failed" || result == "not_applicable"
    }

    func validateSyncConfirmed(data: [String: Any]) -> Bool {
        guard data["action"] is String else { return false }
        guard data["from_agent"] is String else { return false }
        guard data["to_agent"] is String else { return false }
        guard data["skill_name"] is String else { return false }
        return true
    }

    func validateSyncApplied(data: [String: Any]) -> Bool {
        guard data["action"] is String else { return false }
        guard data["from_agent"] is String else { return false }
        guard data["to_agent"] is String else { return false }
        guard data["skill_name"] is String else { return false }
        let result = data["result"] as? String
        return result == "success" || result == "failed"
    }

    func validateSyncCheck(data: [String: Any]) -> Bool {
        guard data["missing_count"] is String else { return false }
        guard data["diff_count"] is String else { return false }
        guard data["total_issues"] is String else { return false }
        return true
    }
}
