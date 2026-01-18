import Foundation
import SQLite3

/// Class to manage database handle with proper cleanup
private final class DatabaseHandle {
    private var ptr: OpaquePointer?

    init(_ pointer: OpaquePointer?) {
        self.ptr = pointer
    }

    func get() -> OpaquePointer? {
        return ptr
    }

    func set(_ pointer: OpaquePointer?) {
        ptr = pointer
    }

    deinit {
        if let ptr = ptr {
            sqlite3_close(ptr)
        }
    }
}

/// Actor providing full-text search over skills using SQLite FTS5
public actor SkillSearchEngine {
    private let dbHandle: DatabaseHandle
    private var db: OpaquePointer? {
        get { dbHandle.get() }
        set { dbHandle.set(newValue) }
    }
    private let dbPath: URL

    /// Search filter options
    public struct SearchFilter: Sendable {
        public var agent: AgentKind?
        public var rootPath: String?
        public var tags: [String]?
        public var minRank: Double?

        public init(
            agent: AgentKind? = nil,
            rootPath: String? = nil,
            tags: [String]? = nil,
            minRank: Double? = nil
        ) {
            self.agent = agent
            self.rootPath = rootPath
            self.tags = tags
            self.minRank = minRank
        }
    }

    /// Search result with BM25 score
    public struct SearchResult: Identifiable, Sendable {
        public let id: String
        public let skillName: String
        public let skillSlug: String
        public let agent: AgentKind
        public let snippet: String
        public let rank: Double
        public let filePath: String

        public init(
            id: String,
            skillName: String,
            skillSlug: String,
            agent: AgentKind,
            snippet: String,
            rank: Double,
            filePath: String
        ) {
            self.id = id
            self.skillName = skillName
            self.skillSlug = skillSlug
            self.agent = agent
            self.snippet = snippet
            self.rank = rank
            self.filePath = filePath
        }
    }

    /// Engine statistics
    public struct Stats: Sendable {
        public let totalSkills: Int
        public let indexSize: Int64
        public let lastIndexed: Date?
    }

    /// Initialize search engine with database path
    public init(dbPath: URL) throws {
        self.dbPath = dbPath
        self.dbHandle = DatabaseHandle(nil)
        var dbPtr: OpaquePointer?
        try Self.openDatabase(&dbPtr, dbPath: dbPath)
        try Self.createSchema(db: &dbPtr)
        dbHandle.set(dbPtr)
    }

    /// Initialize with default path in Application Support
    public static func `default`() throws -> SkillSearchEngine {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupportURL.appendingPathComponent("SkillsInspector", isDirectory: true)

        if !fm.fileExists(atPath: supportDir.path) {
            try fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        let dbPath = supportDir.appendingPathComponent("skills-fts.db")
        return try SkillSearchEngine(dbPath: dbPath)
    }

    private nonisolated static func openDatabase(_ db: inout OpaquePointer?, dbPath: URL) throws {
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            throw SearchError.databaseOpenFailed
        }
    }

    private nonisolated static func createSchema(db: inout OpaquePointer?) throws {
        guard db != nil else { throw SearchError.databaseNotOpen }

        // Enable FTS5
        let createFTS = """
        CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(
            skillName,
            skillSlug,
            content,
            tags,
            agent,
            filePath,
            rankUnindexed,
            tokenize='porter unicode61'
        );
        """

        // Create index metadata table
        let createMeta = """
        CREATE TABLE IF NOT EXISTS skills_meta (
            skillSlug TEXT PRIMARY KEY,
            indexedAt REAL,
            fileSize INTEGER,
            agent TEXT,
            filePath TEXT
        );
        """

        Self.execSQL(db: db, createFTS)
        Self.execSQL(db: db, createMeta)
    }

    /// Index a skill for searching
    public func indexSkill(
        _ skill: Skill,
        content: String
    ) throws {
        guard db != nil else { throw SearchError.databaseNotOpen }

        // Remove any existing entry for this slug to avoid duplicate rows in FTS.
        let deleteExisting = "DELETE FROM skills_fts WHERE skillSlug = ?;"
        let deleteStmt = prepare(deleteExisting)
        if let deleteStmt {
            sqlite3_bind_text(deleteStmt, 1, (skill.slug as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStmt)
            sqlite3_finalize(deleteStmt)
        }

        // Combine extracted metadata with provided content
        let allContent = [extractContent(from: skill), content]
            .joined(separator: " ")
        let tags = skill.tags?.joined(separator: " ") ?? ""
        let agent = skill.agent.rawValue

        // Insert into FTS table
        let insert = """
        INSERT OR REPLACE INTO skills_fts(
            skillName, skillSlug, content, tags, agent, filePath, rankUnindexed
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        let stmt = prepare(insert)
        defer { sqlite3_finalize(stmt) }

        // Bind parameters with null handling for optional values
        let name = skill.name ?? ""
        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (skill.slug as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (allContent as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (tags as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (agent as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (skill.rootPath as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 7, skill.rank ?? 0.5)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchError.indexFailed
        }

        // Update metadata
        let now = Date().timeIntervalSince1970
        let updateMeta = """
        INSERT OR REPLACE INTO skills_meta(
            skillSlug, indexedAt, fileSize, agent, filePath
        ) VALUES (?, ?, ?, ?, ?);
        """

        let metaStmt = prepare(updateMeta)
        defer { sqlite3_finalize(metaStmt) }

        sqlite3_bind_text(metaStmt, 1, (skill.slug as NSString).utf8String, -1, nil)
        sqlite3_bind_double(metaStmt, 2, now)
        sqlite3_bind_int64(metaStmt, 3, Int64(skill.fileSize ?? 0))
        sqlite3_bind_text(metaStmt, 4, (agent as NSString).utf8String, -1, nil)
        sqlite3_bind_text(metaStmt, 5, (skill.rootPath as NSString).utf8String, -1, nil)

        guard sqlite3_step(metaStmt) == SQLITE_DONE else {
            throw SearchError.indexFailed
        }
    }

    /// Search for skills using FTS5 with BM25 ranking
    public func search(
        query: String,
        filters: SearchFilter = SearchFilter(),
        limit: Int = 20
    ) throws -> [SearchResult] {
        guard db != nil else { throw SearchError.databaseNotOpen }

        var sql = """
        SELECT
            skillName,
            skillSlug,
            snippet(skills_fts, 2, '<mark>', '</mark>', '...', 64) AS snippet,
            agent,
            filePath,
            bm25(skills_fts) AS rank
        FROM skills_fts
        WHERE skills_fts MATCH ?
        """

        let normalizedQuery = normalizeQuery(query)

        // Apply filters
        if filters.agent != nil {
            sql += " AND agent = ?"
        }

        if filters.minRank != nil {
            sql += " AND rankUnindexed >= ?"
        }

        sql += " ORDER BY rank LIMIT \(limit)"

        let stmt = prepare(sql)
        defer { sqlite3_finalize(stmt) }

        var bindIndex: Int32 = 1
        sqlite3_bind_text(stmt, bindIndex, (normalizedQuery as NSString).utf8String, -1, nil)
        bindIndex += 1

        if let agent = filters.agent {
            sqlite3_bind_text(stmt, bindIndex, (agent.rawValue as NSString).utf8String, -1, nil)
            bindIndex += 1
        }

        if let minRank = filters.minRank {
            sqlite3_bind_double(stmt, bindIndex, minRank)
            bindIndex += 1
        }

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let skillName = String(cString: sqlite3_column_text(stmt, 0))
            let skillSlug = String(cString: sqlite3_column_text(stmt, 1))
            let snippet = String(cString: sqlite3_column_text(stmt, 2))
            let agentRaw = String(cString: sqlite3_column_text(stmt, 3))
            let filePath = String(cString: sqlite3_column_text(stmt, 4))
            let rank = sqlite3_column_double(stmt, 5)

            results.append(SearchResult(
                id: skillSlug,
                skillName: skillName,
                skillSlug: skillSlug,
                agent: AgentKind(rawValue: agentRaw) ?? .codex,
                snippet: snippet,
                rank: rank,
                filePath: filePath
            ))
        }

        return results
    }

    /// Remove a skill from the index
    public func removeSkill(at slug: String) throws {
        guard db != nil else { throw SearchError.databaseNotOpen }

        let deleteFTS = "DELETE FROM skills_fts WHERE skillSlug = ?;"
        let deleteMeta = "DELETE FROM skills_meta WHERE skillSlug = ?;"

        for sql in [deleteFTS, deleteMeta] {
            let stmt = prepare(sql)
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (slug as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw SearchError.removeFailed
            }
        }
    }

    /// Rebuild the entire index from skill roots
    public func rebuildIndex(
        roots: [ScanRoot],
        excludeDirNames: Set<String> = [".git", ".system", "__pycache__", ".DS_Store"],
        excludeGlobs: [String] = []
    ) async throws {
        // Clear existing index
        try clear()

        // Re-index all skills using SearchIndex helper
        let skills = try await SearchIndex.scanRoots(
            roots,
            excludeDirNames: excludeDirNames,
            excludeGlobs: excludeGlobs
        )

        for skill in skills {
            let skillURL = URL(fileURLWithPath: skill.rootPath)
            let content = try? String(contentsOf: skillURL.appendingPathComponent("SKILL.md"))
            if let content = content {
                try? indexSkill(skill, content: content)
            }
        }
    }

    /// Rebuild the entire index from raw URLs (defaults to Codex agent)
    public func rebuildIndex(roots: [URL]) async throws {
        let scanRoots = roots.map { ScanRoot(agent: .codex, rootURL: $0, recursive: true) }
        try await rebuildIndex(roots: scanRoots)
    }

    /// Optimize the FTS index
    public func optimize() throws {
        execSQL("INSERT INTO skills_fts(skills_fts) VALUES('optimize');")
    }

    /// Get index statistics
    public func getStats() throws -> Stats {
        guard db != nil else { throw SearchError.databaseNotOpen }

        let countSQL = "SELECT COUNT(*) FROM skills_meta;"
        let sizeSQL = "SELECT SUM(fileSize) FROM skills_meta;"
        let lastSQL = "SELECT MAX(indexedAt) FROM skills_meta;"

        var totalSkills = 0
        var indexSize: Int64 = 0
        var lastIndexed: Date?

        if let stmt = prepare(countSQL) {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalSkills = Int(sqlite3_column_int64(stmt, 0))
            }
        }

        if let stmt = prepare(sizeSQL) {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                indexSize = sqlite3_column_int64(stmt, 0)
            }
        }

        if let stmt = prepare(lastSQL) {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(stmt, 0)
                if timestamp > 0 {
                    lastIndexed = Date(timeIntervalSince1970: timestamp)
                }
            }
        }

        return Stats(
            totalSkills: totalSkills,
            indexSize: indexSize,
            lastIndexed: lastIndexed
        )
    }

    /// Clear all indexed data
    public func clear() throws {
        execSQL("DELETE FROM skills_fts;")
        execSQL("DELETE FROM skills_meta;")
    }

    // MARK: - Private Helpers

    private func execSQL(_ sql: String) {
        guard let db = db else { return }
        Self.execSQL(db: db, sql)
    }

    private nonisolated static func execSQL(db: OpaquePointer?, _ sql: String) {
        guard let db = db else { return }
        var errMsg: UnsafeMutablePointer<CChar>?
        sqlite3_exec(db, sql, nil, nil, &errMsg)
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        return stmt
    }

    private func extractContent(from skill: Skill) -> String {
        var content: [String] = []

        // Add metadata
        if let name = skill.name { content.append(name) }
        if let desc = skill.description { content.append(desc) }

        // Add SKILL.md content
        let skillURL = URL(fileURLWithPath: skill.rootPath)
        let skillFile = skillURL.appendingPathComponent("SKILL.md")

        if let skillContent = try? String(contentsOf: skillFile) {
            // Strip frontmatter
            let lines = skillContent.split(separator: "\n")
            var inFrontmatter = false
            for line in lines {
                if line == "---" {
                    inFrontmatter.toggle()
                    continue
                }
                if !inFrontmatter {
                    content.append(String(line))
                }
            }
        }

        return content.joined(separator: " ")
    }

    private func normalizeQuery(_ query: String) -> String {
        query
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Types

    public struct Skill: Sendable {
        public let slug: String
        public let name: String?
        public let description: String?
        public let agent: AgentKind
        public let rootPath: String
        public let tags: [String]?
        public let rank: Double?
        public let fileSize: Int?
    }

    public enum SearchError: LocalizedError {
        case databaseOpenFailed
        case databaseNotOpen
        case indexFailed
        case removeFailed

        public var errorDescription: String? {
            switch self {
            case .databaseOpenFailed: return "Failed to open search database"
            case .databaseNotOpen: return "Search database not open"
            case .indexFailed: return "Failed to index skill"
            case .removeFailed: return "Failed to remove skill from index"
            }
        }
    }
}
