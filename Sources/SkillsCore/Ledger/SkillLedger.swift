import Foundation
import SQLite3

internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public actor SkillLedger {
    private let dbURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?


    public init(url: URL = SkillLedger.defaultStoreURL()) throws {
        self.dbURL = url
        let db = try SkillLedger.openDatabase(at: url)
        self.db = db
        
        // configureDatabase logic inlined
        let pragmas = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA foreign_keys = ON;
        """
        if sqlite3_exec(db, pragmas, nil, nil, nil) != SQLITE_OK {
            throw LedgerStoreError(String(cString: sqlite3_errmsg(db)))
        }
        
        // createSchemaIfNeeded logic inlined
        let schema = """
        CREATE TABLE IF NOT EXISTS ledger_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            event_type TEXT NOT NULL,
            skill_name TEXT NOT NULL,
            skill_slug TEXT,
            version TEXT,
            agent TEXT,
            status TEXT NOT NULL,
            note TEXT,
            source TEXT,
            verification TEXT,
            manifest_sha256 TEXT,
            target_path TEXT,
            targets TEXT,
            per_target_results TEXT,
            signer_key_id TEXT,
            timeout_count INTEGER DEFAULT 0,
            retry_count INTEGER DEFAULT 0,
            timeout_duration REAL
        );
        CREATE INDEX IF NOT EXISTS idx_ledger_events_time ON ledger_events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_ledger_events_skill ON ledger_events(skill_name);
        """
        if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
            throw LedgerStoreError(String(cString: sqlite3_errmsg(db)))
        }
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "source", type: "TEXT")
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "targets", type: "TEXT")
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "per_target_results", type: "TEXT")
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "signer_key_id", type: "TEXT")
        // Network resilience metrics (P3)
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "timeout_count", type: "INTEGER")
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "retry_count", type: "INTEGER")
        try SkillLedger.addColumnIfNeeded(db: db, table: "ledger_events", column: "timeout_duration", type: "REAL")
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    public static func defaultStoreURL(appName: String = "SkillsInspector") -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newRoot = base.appendingPathComponent(appName, isDirectory: true)
        let legacyRoot = base.appendingPathComponent("sTools", isDirectory: true)
        if !FileManager.default.fileExists(atPath: newRoot.path),
           FileManager.default.fileExists(atPath: legacyRoot.path) {
            return legacyRoot.appendingPathComponent("ledger.sqlite3")
        }
        return newRoot.appendingPathComponent("ledger.sqlite3")
    }

    public func record(_ input: LedgerEventInput) throws -> LedgerEvent {
        guard let db else { throw LedgerStoreError("Ledger unavailable") }
        let sql = """
        INSERT INTO ledger_events (
            timestamp,
            event_type,
            skill_name,
            skill_slug,
            version,
            agent,
            status,
            note,
            source,
            verification,
            manifest_sha256,
            target_path,
            targets,
            per_target_results,
            signer_key_id,
            timeout_count,
            retry_count,
            timeout_duration
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        let stmt = try prepare(sql: sql)
        defer { sqlite3_finalize(stmt) }
        let timestamp = SkillLedger.isoFormatter.string(from: input.timestamp ?? Date())
        var index: Int32 = 1
        bindText(stmt, index, timestamp); index += 1
        bindText(stmt, index, input.eventType.rawValue); index += 1
        bindText(stmt, index, input.skillName); index += 1
        bindText(stmt, index, input.skillSlug); index += 1
        bindText(stmt, index, input.version); index += 1
        bindText(stmt, index, input.agent?.rawValue); index += 1
        bindText(stmt, index, input.status.rawValue); index += 1
        bindText(stmt, index, input.note); index += 1
        bindText(stmt, index, input.source); index += 1
        bindText(stmt, index, input.verification?.description); index += 1
        bindText(stmt, index, input.manifestSHA256); index += 1
        bindText(stmt, index, input.targetPath); index += 1
        bindText(stmt, index, SkillLedger.encodeAgentArray(input.targets)); index += 1
        bindText(stmt, index, SkillLedger.encodePerTargetResults(input.perTargetResults)); index += 1
        bindText(stmt, index, input.signerKeyId); index += 1
        // Network resilience metrics (P3)
        sqlite3_bind_int(stmt, index, Int32(input.timeoutCount ?? 0)); index += 1
        sqlite3_bind_int(stmt, index, Int32(input.retryCount ?? 0)); index += 1
        if let duration = input.timeoutDuration {
            sqlite3_bind_double(stmt, index, duration); index += 1
        } else {
            sqlite3_bind_null(stmt, index); index += 1
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw LedgerStoreError(String(cString: sqlite3_errmsg(db)))
        }
        let rowId = sqlite3_last_insert_rowid(db)
        return LedgerEvent(
            id: rowId,
            timestamp: SkillLedger.isoFormatter.date(from: timestamp) ?? Date(),
            eventType: input.eventType,
            skillName: input.skillName,
            skillSlug: input.skillSlug,
            version: input.version,
            agent: input.agent,
            status: input.status,
            note: input.note,
            source: input.source,
            verification: input.verification,
            manifestSHA256: input.manifestSHA256,
            targetPath: input.targetPath,
            targets: input.targets,
            perTargetResults: input.perTargetResults,
            signerKeyId: input.signerKeyId
        )
    }

    public func fetchEvents(
        limit: Int = 200,
        since: Date? = nil,
        eventTypes: [LedgerEventType]? = nil,
        statuses: [LedgerEventStatus]? = nil
    ) throws -> [LedgerEvent] {
        guard db != nil else { throw LedgerStoreError("Ledger unavailable") }
        var sql = """
        SELECT id, timestamp, event_type, skill_name, skill_slug, version, agent, status, note, source, verification, manifest_sha256, target_path, targets, per_target_results, signer_key_id
        FROM ledger_events
        WHERE 1 = 1
        """
        if since != nil {
            sql += " AND timestamp >= ?"
        }
        if let eventTypes, !eventTypes.isEmpty {
            sql += " AND event_type IN (" + placeholders(count: eventTypes.count) + ")"
        }
        if let statuses, !statuses.isEmpty {
            sql += " AND status IN (" + placeholders(count: statuses.count) + ")"
        }
        sql += " ORDER BY timestamp DESC, id DESC LIMIT ?"

        let stmt = try prepare(sql: sql)
        defer { sqlite3_finalize(stmt) }
        var index: Int32 = 1
        if let since {
            bindText(stmt, index, SkillLedger.isoFormatter.string(from: since)); index += 1
        }
        if let eventTypes {
            for type in eventTypes {
                bindText(stmt, index, type.rawValue); index += 1
            }
        }
        if let statuses {
            for status in statuses {
                bindText(stmt, index, status.rawValue); index += 1
            }
        }
        sqlite3_bind_int(stmt, index, Int32(limit))

        var events: [LedgerEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let timestamp = stringColumn(stmt, 1)
            let eventType = stringColumn(stmt, 2)
            let skillName = stringColumn(stmt, 3) ?? "Unknown"
            let skillSlug = stringColumn(stmt, 4)
            let version = stringColumn(stmt, 5)
            let agent = stringColumn(stmt, 6).flatMap(AgentKind.init(rawValue:))
            let status = stringColumn(stmt, 7).flatMap(LedgerEventStatus.init(rawValue:)) ?? .success
            let note = stringColumn(stmt, 8)
            let source = stringColumn(stmt, 9)
            let verification = stringColumn(stmt, 10).flatMap(RemoteVerificationMode.init(description:))
            let manifest = stringColumn(stmt, 11)
            let target = stringColumn(stmt, 12)
            let targets = SkillLedger.decodeAgentArray(stringColumn(stmt, 13))
            let perTargetResults = SkillLedger.decodePerTargetResults(stringColumn(stmt, 14))
            let signerKeyId = stringColumn(stmt, 15)
            events.append(
                LedgerEvent(
                    id: id,
                    timestamp: SkillLedger.parseDate(timestamp) ?? Date(),
                    eventType: LedgerEventType(rawValue: eventType ?? "") ?? .install,
                    skillName: skillName,
                    skillSlug: skillSlug,
                    version: version,
                    agent: agent,
                    status: status,
                    note: note,
                    source: source,
                    verification: verification,
                    manifestSHA256: manifest,
                    targetPath: target,
                    targets: targets,
                    perTargetResults: perTargetResults,
                    signerKeyId: signerKeyId
                )
            )
        }
        return events
    }

    /// Fetch the last successful install event for a specific skill.
    /// - Parameters:
    ///   - skillSlug: The slug identifying the skill
    ///   - agent: Optional agent filter (Codex, Claude, Copilot)
    /// - Returns: The most recent successful install event, or nil if none found
    public func fetchLastSuccessfulInstall(
        skillSlug: String,
        agent: AgentKind? = nil
    ) throws -> LedgerEvent? {
        guard db != nil else { throw LedgerStoreError("Ledger unavailable") }
        var sql = """
        SELECT id, timestamp, event_type, skill_name, skill_slug, version, agent, status, note, source, verification, manifest_sha256, target_path, targets, per_target_results, signer_key_id
        FROM ledger_events
        WHERE skill_slug = ? AND event_type IN ('install', 'update') AND status = 'success'
        """
        if agent != nil {
            sql += " AND agent = ?"
        }
        sql += " ORDER BY timestamp DESC, id DESC LIMIT 1"

        let stmt = try prepare(sql: sql)
        defer { sqlite3_finalize(stmt) }
        var index: Int32 = 1
        bindText(stmt, index, skillSlug); index += 1
        if let agent {
            bindText(stmt, index, agent.rawValue); index += 1
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let id = sqlite3_column_int64(stmt, 0)
        let timestamp = stringColumn(stmt, 1)
        let eventType = stringColumn(stmt, 2)
        let skillName = stringColumn(stmt, 3) ?? "Unknown"
        let slug = stringColumn(stmt, 4)
        let version = stringColumn(stmt, 5)
        let agentValue = stringColumn(stmt, 6).flatMap(AgentKind.init(rawValue:))
        let status = stringColumn(stmt, 7).flatMap(LedgerEventStatus.init(rawValue:)) ?? .success
        let note = stringColumn(stmt, 8)
        let source = stringColumn(stmt, 9)
        let verification = stringColumn(stmt, 10).flatMap(RemoteVerificationMode.init(description:))
        let manifest = stringColumn(stmt, 11)
        let target = stringColumn(stmt, 12)
        let targets = SkillLedger.decodeAgentArray(stringColumn(stmt, 13))
        let perTargetResults = SkillLedger.decodePerTargetResults(stringColumn(stmt, 14))
        let signerKeyId = stringColumn(stmt, 15)
        return LedgerEvent(
            id: id,
            timestamp: SkillLedger.parseDate(timestamp) ?? Date(),
            eventType: LedgerEventType(rawValue: eventType ?? "") ?? .install,
            skillName: skillName,
            skillSlug: slug,
            version: version,
            agent: agentValue,
            status: status,
            note: note,
            source: source,
            verification: verification,
            manifestSHA256: manifest,
            targetPath: target,
            targets: targets,
            perTargetResults: perTargetResults,
            signerKeyId: signerKeyId
        )
    }

    /// Delete ledger entries older than the specified number of days.
    /// - Parameter days: Number of days to retain (default: 30)
    /// - Returns: Number of entries deleted
    public func cleanup(olderThan days: Int = 30) throws -> Int {
        guard let db else { throw LedgerStoreError("Ledger unavailable") }
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let cutoffTimestamp = SkillLedger.isoFormatter.string(from: cutoffDate)

        let sql = "DELETE FROM ledger_events WHERE timestamp < ?;"
        let stmt = try prepare(sql: sql)
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, cutoffTimestamp)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw LedgerStoreError(String(cString: sqlite3_errmsg(db)))
        }

        let changes = sqlite3_changes(db)
        return Int(changes)
    }

    private static func openDatabase(at url: URL) throws -> OpaquePointer {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            throw LedgerStoreError("Unable to open ledger database")
        }
        return db!
    }

    // configureDatabase and createSchemaIfNeeded removed (inlined into init)

    private func prepare(sql: String) throws -> OpaquePointer {
        guard let db else { throw LedgerStoreError("Ledger unavailable") }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw LedgerStoreError(String(cString: sqlite3_errmsg(db)))
        }
        guard let stmt else { throw LedgerStoreError("Failed to prepare statement") }
        return stmt
    }

    private func bindText(_ stmt: OpaquePointer, _ index: Int32, _ value: String?) {
        guard let value else {
            sqlite3_bind_null(stmt, index)
            return
        }
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private func stringColumn(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    private func placeholders(count: Int) -> String {
        guard count > 0 else { return "" }
        return Array(repeating: "?", count: count).joined(separator: ", ")
    }

    private static func addColumnIfNeeded(db: OpaquePointer, table: String, column: String, type: String) throws {
        let sql = "ALTER TABLE \(table) ADD COLUMN \(column) \(type);"
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        if result == SQLITE_ERROR {
            let message = String(cString: sqlite3_errmsg(db))
            if !message.contains("duplicate column") {
                throw LedgerStoreError(message)
            }
        }
    }

    private static func encodeAgentArray(_ agents: [AgentKind]?) -> String? {
        guard let agents else { return nil }
        return agents.map { $0.rawValue }.joined(separator: ",")
    }

    private static func decodeAgentArray(_ raw: String?) -> [AgentKind]? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ",").map { String($0) }
        let agents = parts.compactMap(AgentKind.init(rawValue:))
        return agents.isEmpty ? nil : agents
    }

    private static func encodePerTargetResults(_ results: [AgentKind: String]?) -> String? {
        guard let results else { return nil }
        let payload = results.reduce(into: [String: String]()) { dict, item in
            dict[item.key.rawValue] = item.value
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }

    private static func decodePerTargetResults(_ raw: String?) -> [AgentKind: String]? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return nil }
        var results: [AgentKind: String] = [:]
        for (key, value) in payload {
            if let agent = AgentKind(rawValue: key) {
                results[agent] = value
            }
        }
        return results.isEmpty ? nil : results
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) { return date }
        return isoFormatterNoFraction.date(from: value)
    }

    private static var isoFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var isoFormatterNoFraction: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
