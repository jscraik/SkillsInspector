import XCTest
@testable import SkillsCore
import Foundation

final class SkillSearchEngineTests: XCTestCase {

    // MARK: - Test Setup

    private var testEngine: SkillSearchEngine!
    private var testDBURL: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        testDBURL = tempDir.appendingPathComponent("test-search-\(UUID().uuidString).db")

        // Create engine with test database
        testEngine = try SkillSearchEngine(dbPath: testDBURL)
    }

    override func tearDown() async throws {
        // Close engine and delete test database
        testEngine = nil
        if FileManager.default.fileExists(atPath: testDBURL.path) {
            try? FileManager.default.removeItem(at: testDBURL)
        }

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testEngineInitialization() throws {
        // Engine should initialize successfully
        XCTAssertNotNil(testEngine)

        // Database file should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDBURL.path))
    }

    func testDefaultEngineInitialization() async throws {
        // Test default initialization (Application Support)
        let defaultEngine = try SkillSearchEngine.default()

        XCTAssertNotNil(defaultEngine)

        // Verify stats show empty index
        let stats = try await defaultEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 0, "New index should be empty")
    }

    // MARK: - Indexing Tests

    func testIndexSingleSkill() async throws {
        let skill = createTestSkill(
            slug: "test-skill",
            name: "Test Skill",
            description: "A test skill for searching"
        )

        let content = """
        ---
        name: test-skill
        description: A test skill for searching
        tags: test, search
        ---

        # Test Skill

        This is a test skill that can be searched.
        """

        try await testEngine.indexSkill(skill, content: content)

        // Verify stats
        let stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 1, "Should have one indexed skill")
    }

    func testIndexMultipleSkills() async throws {
        // Index multiple skills
        for i in 1...5 {
            let skill = createTestSkill(
                slug: "skill-\(i)",
                name: "Skill \(i)",
                description: "Description \(i)"
            )

            let content = """
            ---
            name: skill-\(i)
            description: Description \(i)
            tags: test, number-\(i)
            ---

            # Skill \(i)

            Content for skill number \(i).
            """

            try await testEngine.indexSkill(skill, content: content)
        }

        // Verify stats
        let stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 5, "Should have five indexed skills")
    }

    func testIndexSkillUpdatesExisting() async throws {
        let skill = createTestSkill(
            slug: "updatable-skill",
            name: "Original Name",
            description: "Original description"
        )

        let originalContent = "# Original Content"
        let updatedContent = "# Updated Content with new text"

        // Index original
        try await testEngine.indexSkill(skill, content: originalContent)

        var stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 1)

        // Index updated (should replace)
        try await testEngine.indexSkill(skill, content: updatedContent)

        stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 1, "Should still have one skill after update")

        // Search for updated content
        let results = try await testEngine.search(query: "Updated Content")
        XCTAssertEqual(results.count, 1, "Should find updated content")
        guard let first = results.first else {
            XCTFail("Expected search results for updated content")
            return
        }
        XCTAssertTrue(first.snippet.contains("Updated"))
    }

    // MARK: - Search Tests

    func testSearchFindsMatchingSkill() async throws {
        let skill = createTestSkill(
            slug: "searchable-skill",
            name: "Searchable Skill",
            description: "A skill about searching"
        )

        let content = """
        # Searchable Skill

        This skill demonstrates full-text search capabilities.
        You can search for any word in the content.
        """

        try await testEngine.indexSkill(skill, content: content)

        // Search for "full-text"
        let results = try await testEngine.search(query: "full-text")

        XCTAssertEqual(results.count, 1, "Should find one result")
        XCTAssertEqual(results[0].skillSlug, "searchable-skill")
        XCTAssertTrue(results[0].snippet.contains("<mark>"), "Snippet should have highlight marks")
    }

    func testSearchWithNoMatches() async throws {
        let skill = createTestSkill(
            slug: "different-skill",
            name: "Different Skill",
            description: "About something else"
        )

        let content = "# Different Content\n\nThis content is about something completely different."

        try await testEngine.indexSkill(skill, content: content)

        // Search for non-existent term
        let results = try await testEngine.search(query: "nonexistent")

        XCTAssertEqual(results.count, 0, "Should find no results")
    }

    func testSearchRanking() async throws {
        // Index skills with different relevance
        let highRelevance = createTestSkill(
            slug: "high-relevance",
            name: "Search Engine",
            description: "A search engine tool"
        )

        let lowRelevance = createTestSkill(
            slug: "low-relevance",
            name: "Other Tool",
            description: "Some other tool"
        )

        try await testEngine.indexSkill(highRelevance, content: "This search engine provides search functionality.")
        try await testEngine.indexSkill(lowRelevance, content: "This tool does something else.")

        // Search for "search"
        let results = try await testEngine.search(query: "search")

        XCTAssertGreaterThan(results.count, 0, "Should find results")
        // Higher relevance should appear first (lower BM25 score is better)
        if results.count >= 2 {
            XCTAssertEqual(results[0].skillSlug, "high-relevance", "High relevance should rank first")
        }
    }

    func testSearchWithLimit() async throws {
        // Index multiple skills
        for i in 1...10 {
            let skill = createTestSkill(slug: "skill-\(i)", name: "Skill \(i)", description: "Test")
            try await testEngine.indexSkill(skill, content: "Content \(i) with test keyword")
        }

        // Search with limit
        let results = try await testEngine.search(query: "test", limit: 5)

        XCTAssertEqual(results.count, 5, "Should respect limit")
    }

    // MARK: - Filter Tests

    func testSearchWithAgentFilter() async throws {
        let codexSkill = createTestSkill(
            slug: "codex-skill",
            name: "Codex Skill",
            description: "For Codex",
            agent: .codex
        )

        let claudeSkill = createTestSkill(
            slug: "claude-skill",
            name: "Claude Skill",
            description: "For Claude",
            agent: .claude
        )

        try await testEngine.indexSkill(codexSkill, content: "Codex content")
        try await testEngine.indexSkill(claudeSkill, content: "Claude content")

        // Search with agent filter
        let filter = SkillSearchEngine.SearchFilter(agent: .claude)
        let results = try await testEngine.search(query: "content", filters: filter)

        XCTAssertEqual(results.count, 1, "Should only find Claude skill")
        XCTAssertEqual(results[0].agent, .claude)
    }

    func testSearchWithMinRankFilter() async throws {
        let highRankSkill = createTestSkill(
            slug: "high-rank",
            name: "High Rank",
            description: "High quality skill",
            rank: 0.9
        )

        let lowRankSkill = createTestSkill(
            slug: "low-rank",
            name: "Low Rank",
            description: "Low quality skill",
            rank: 0.3
        )

        try await testEngine.indexSkill(highRankSkill, content: "High quality content")
        try await testEngine.indexSkill(lowRankSkill, content: "Low quality content")

        // Search with minRank filter
        let filter = SkillSearchEngine.SearchFilter(minRank: 0.5)
        let results = try await testEngine.search(query: "content", filters: filter)

        XCTAssertEqual(results.count, 1, "Should only find high rank skill")
        XCTAssertEqual(results[0].skillSlug, "high-rank")
    }

    // MARK: - Remove Tests

    func testRemoveSkill() async throws {
        let skill = createTestSkill(
            slug: "removable-skill",
            name: "Removable Skill",
            description: "Can be removed"
        )

        try await testEngine.indexSkill(skill, content: "Content to be removed")

        var stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 1)

        // Remove the skill
        try await testEngine.removeSkill(at: "removable-skill")

        stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 0, "Skill should be removed")

        // Search should return nothing
        let results = try await testEngine.search(query: "content")
        XCTAssertEqual(results.count, 0)
    }

    func testRemoveNonExistentSkill() async throws {
        // Should not throw error
        try await testEngine.removeSkill(at: "does-not-exist")

        let stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 0)
    }

    // MARK: - Rebuild Tests

    func testRebuildIndex() async throws {
        // Index some skills
        for i in 1...3 {
            let skill = createTestSkill(slug: "skill-\(i)", name: "Skill \(i)", description: "Test")
            try await testEngine.indexSkill(skill, content: "Content \(i)")
        }

        let statsBefore = try await testEngine.getStats()
        XCTAssertEqual(statsBefore.totalSkills, 3)

        // Clear and rebuild with different skills
        let newRoot = FileManager.default.temporaryDirectory.appendingPathComponent("test-rebuild")

        try await testEngine.rebuildIndex(roots: [newRoot])

        // Index should be empty (no skills in test directory)
        let stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 0, "Rebuild should clear existing index")
    }

    // MARK: - Optimize Tests

    func testOptimizeIndex() async throws {
        // Index and remove some skills to create fragmentation
        for i in 1...10 {
            let skill = createTestSkill(slug: "temp-\(i)", name: "Temp \(i)", description: "Temp")
            try await testEngine.indexSkill(skill, content: "Temporary content \(i)")
        }

        // Remove some skills
        try await testEngine.removeSkill(at: "temp-1")
        try await testEngine.removeSkill(at: "temp-3")
        try await testEngine.removeSkill(at: "temp-5")

        // Optimize should not throw
        try await testEngine.optimize()

        // Stats should still be accurate
        let stats = try await testEngine.getStats()
        XCTAssertEqual(stats.totalSkills, 7)
    }

    // MARK: - Stats Tests

    func testGetStats() async throws {
        let skill = createTestSkill(
            slug: "stats-skill",
            name: "Stats Skill",
            description: "For testing stats",
            fileSize: 1024
        )

        try await testEngine.indexSkill(skill, content: "Content for stats")

        let stats = try await testEngine.getStats()

        XCTAssertEqual(stats.totalSkills, 1)
        XCTAssertGreaterThanOrEqual(stats.indexSize, 0, "Index size should be non-negative")
        XCTAssertNotNil(stats.lastIndexed, "Should have last indexed time")
    }

    func testGetStatsOnEmptyIndex() async throws {
        let stats = try await testEngine.getStats()

        XCTAssertEqual(stats.totalSkills, 0)
        XCTAssertEqual(stats.indexSize, 0)
        XCTAssertNil(stats.lastIndexed, "Empty index should have no last indexed time")
    }

    // MARK: - Snippet Tests

    func testSearchSnippetGeneration() async throws {
        let skill = createTestSkill(
            slug: "snippet-skill",
            name: "Snippet Test",
            description: "Testing snippet generation"
        )

        let content = """
        # Snippet Test

        This is a long piece of content that contains the search term
        somewhere in the middle of the text. The snippet should highlight
        the matched term and show context around it.
        """

        try await testEngine.indexSkill(skill, content: content)

        let results = try await testEngine.search(query: "search term")

        XCTAssertEqual(results.count, 1)
        let snippet = results[0].snippet

        // Verify snippet has markup
        XCTAssertTrue(snippet.contains("<mark>"), "Snippet should contain mark tags")
        XCTAssertTrue(snippet.contains("search"), "Snippet should contain search term")
        XCTAssertTrue(snippet.contains("</mark>"), "Snippet should close mark tags")
    }

    // MARK: - Performance Tests

    func testIndexPerformance() async throws {
        // Basic performance sanity: index 100 skills without errors
        for i in 1...100 {
            let skill = createTestSkill(
                slug: "perf-\(i)",
                name: "Performance \(i)",
                description: "Testing performance"
            )
            try await testEngine.indexSkill(skill, content: "Content \(i) for performance testing")
        }
    }

    func testSearchPerformance() async throws {
        // Index 100 skills first
        for i in 1...100 {
            let skill = createTestSkill(slug: "search-perf-\(i)", name: "Search \(i)", description: "Test")
            try await testEngine.indexSkill(skill, content: "Content \(i) with various words for testing")
        }

        // Basic performance sanity: search should return results
        let results = try await testEngine.search(query: "content", limit: 20)
        XCTAssertFalse(results.isEmpty)
    }

    // MARK: - Helper Methods

    private func createTestSkill(
        slug: String,
        name: String,
        description: String,
        agent: AgentKind = .codex,
        rank: Double? = nil,
        fileSize: Int? = nil
    ) -> SkillSearchEngine.Skill {
        return SkillSearchEngine.Skill(
            slug: slug,
            name: name,
            description: description,
            agent: agent,
            rootPath: "/tmp/skills/\(slug)",
            tags: nil,
            rank: rank,
            fileSize: fileSize
        )
    }
}
