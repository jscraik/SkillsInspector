import Foundation

public struct SkillChangelogGenerator: Sendable {
    public init() {}

    /// Generate changelog for all events.
    public func generateAppStoreMarkdown(
        events: [LedgerEvent],
        title: String = "Changelog"
    ) -> String {
        let relevant = events
            .filter { $0.status == .success }
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp { return lhs.id > rhs.id }
                return lhs.timestamp > rhs.timestamp
            }
        guard !relevant.isEmpty else {
            return "## \(title)\n(No entries yet.)"
        }

        let grouped = Dictionary(grouping: relevant) { dayKey(for: $0.timestamp) }
        let sortedKeys = grouped.keys.sorted(by: >)
        var lines: [String] = []
        lines.append("## \(title)")
        lines.append("_Generated: \(DateFormatter.shortDateTime.string(from: Date()))_")
        lines.append("")

        for key in sortedKeys {
            guard let events = grouped[key] else { continue }
            lines.append("### \(key)")
            for event in events {
                lines.append("- \(formatEvent(event))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Generate auditor-focused changelog with cryptographic provenance.
    /// Includes ALL events (success and failure) with signer keys and hashes.
    public func generateAuditorMarkdown(
        events: [LedgerEvent],
        title: String = "Audit Trail"
    ) -> String {
        let sorted = events.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp { return lhs.id > rhs.id }
            return lhs.timestamp > rhs.timestamp
        }
        guard !sorted.isEmpty else {
            return "## \(title)\n(No entries yet.)"
        }

        let grouped = Dictionary(grouping: sorted) { dayKey(for: $0.timestamp) }
        let sortedKeys = grouped.keys.sorted(by: >)
        var lines: [String] = []
        lines.append("## \(title)")
        lines.append("_Generated: \(DateFormatter.shortDateTime.string(from: Date()))_")
        lines.append("")
        lines.append("**This audit trail is tamper-evident and cryptographically verifiable when exported with a signature.**")
        lines.append("")

        for key in sortedKeys {
            guard let events = grouped[key] else { continue }
            lines.append("### \(key)")
            for event in events {
                lines.append("- \(formatAuditorEvent(event))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Generate per-skill changelog filtered by skill slug.
    public func generatePerSkillMarkdown(
        events: [LedgerEvent],
        skillSlug: String,
        skillName: String? = nil,
        title: String? = nil
    ) -> String {
        let filtered = events.filter { $0.skillSlug == skillSlug }
        let displayTitle = title ?? "Changelog: \(skillName ?? skillSlug)"
        return generateAppStoreMarkdown(events: filtered, title: displayTitle)
    }

    /// Generate changelog with optional filters.
    public func generateFilteredMarkdown(
        events: [LedgerEvent],
        skillSlug: String? = nil,
        eventTypes: [LedgerEventType]? = nil,
        dateRange: ClosedRange<Date>? = nil,
        title: String = "Changelog"
    ) -> String {
        var filtered = events

        if let skillSlug {
            filtered = filtered.filter { $0.skillSlug == skillSlug }
        }
        if let eventTypes, !eventTypes.isEmpty {
            filtered = filtered.filter { eventTypes.contains($0.eventType) }
        }
        if let dateRange {
            filtered = filtered.filter { dateRange.contains($0.timestamp) }
        }

        return generateAppStoreMarkdown(events: filtered, title: title)
    }

    /// Generate auditor changelog with optional filters.
    /// Includes ALL events (success and failure) with cryptographic provenance.
    public func generateFilteredAuditorMarkdown(
        events: [LedgerEvent],
        skillSlug: String? = nil,
        eventTypes: [LedgerEventType]? = nil,
        dateRange: ClosedRange<Date>? = nil,
        title: String = "Audit Trail"
    ) -> String {
        var filtered = events

        if let skillSlug {
            filtered = filtered.filter { $0.skillSlug == skillSlug }
        }
        if let eventTypes, !eventTypes.isEmpty {
            filtered = filtered.filter { eventTypes.contains($0.eventType) }
        }
        if let dateRange {
            filtered = filtered.filter { dateRange.contains($0.timestamp) }
        }

        return generateAuditorMarkdown(events: filtered, title: title)
    }

    /// Generate per-skill auditor changelog filtered by skill slug.
    public func generatePerSkillAuditorMarkdown(
        events: [LedgerEvent],
        skillSlug: String,
        skillName: String? = nil,
        title: String? = nil
    ) -> String {
        let filtered = events.filter { $0.skillSlug == skillSlug }
        let displayTitle = title ?? "Audit Trail: \(skillName ?? skillSlug)"
        return generateAuditorMarkdown(events: filtered, title: displayTitle)
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatEvent(_ event: LedgerEvent) -> String {
        let verb = verbForType(event.eventType)
        var parts: [String] = []
        parts.append("\(verb) \(event.skillName)")
        if let version = event.version {
            parts.append("v\(version)")
        }
        if let agent = event.agent {
            parts.append("(\(agent.displayLabel))")
        }
        if let note = event.note, !note.isEmpty {
            parts.append("— \(note)")
        }
        return parts.joined(separator: " ")
    }

    /// Format event for auditor view with cryptographic provenance.
    private func formatAuditorEvent(_ event: LedgerEvent) -> String {
        let verb = verbForType(event.eventType)
        let statusIndicator = event.status == .success ? "✓" : "✗"
        var parts: [String] = []
        parts.append("\(statusIndicator) **\(verb)** \(event.skillName)")

        if let version = event.version {
            parts.append("v`\(version)`")
        }

        if let agent = event.agent {
            parts.append("via \(agent.displayLabel)")
        }

        if event.status != .success {
            parts.append("[FAILED]")
        }

        var provenance: [String] = []

        if let signerKey = event.signerKeyId {
            provenance.append("signer: `\(signerKey)`")
        } else {
            provenance.append("signer: *(unsigned)*")
        }

        if let hash = event.manifestSHA256 {
            provenance.append("SHA256: `\(hash)`")
        }

        if !provenance.isEmpty {
            parts.append("(\(provenance.joined(separator: ", ")))")
        }

        if let note = event.note, !note.isEmpty {
            parts.append("— \(note)")
        }

        return parts.joined(separator: " ")
    }

    private func verbForType(_ type: LedgerEventType) -> String {
        switch type {
        case .install: return "Installed"
        case .update: return "Updated"
        case .remove: return "Removed"
        case .verify: return "Verified"
        case .sync: return "Synced"
        }
    }
}
