import Foundation
import ArgumentParser
import SkillsCore

/// Search commands for full-text skill search
struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Search skills using full-text search with BM25 ranking.",
        discussion: """
        Search skills using SQLite FTS5 full-text search.

        Example:
            skillsctl search 'async/await' --agent codex --limit 10
        """
    )

    @Argument(help: "Search query (supports FTS5 query syntax)")
    var query: String

    @Option(name: .long, help: "Filter by agent type (codex|claude|copilot)")
    var agent: String?

    @Option(name: .long, help: "Minimum rank score (0.0-1.0)")
    var minRank: Double?

    @Option(name: .long, help: "Limit number of results (default: 20)")
    var limit: Int = 20

    @Option(name: .long, help: "Output format: text|json (default: text)")
    var format: String = "text"

    func run() async throws {
        // Get search engine
        let engine = try SkillSearchEngine.default()

        // Build filters
        var filter = SkillSearchEngine.SearchFilter()

        if let agentString = agent {
            guard let agentKind = AgentKind(rawValue: agentString.lowercased()) else {
                fputs("Error: Invalid agent type '\(agentString)'\n", stderr)
                throw ExitCode(1)
            }
            filter.agent = agentKind
        }

        if let minRankValue = minRank {
            filter.minRank = minRankValue
        }

        // Perform search
        let results = try await engine.search(query: query, filters: filter, limit: limit)

        // Output results
        if format.lowercased() == "json" {
            outputJSON(results)
        } else {
            outputText(results)
        }
    }

    private func outputText(_ results: [SkillSearchEngine.SearchResult]) {
        if results.isEmpty {
            print("No results found for query.")
            return
        }

        print("Found \(results.count) result(s):\n")

        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result.skillName)")
            print("    Slug: \(result.skillSlug)")
            print("    Agent: \(result.agent.rawValue)")
            print("    Rank: \(String(format: "%.4f", result.rank))")
            print("    Path: \(result.filePath)")

            // Show snippet with highlights
            let snippet = result.snippet
                .replacingOccurrences(of: "<mark>", with: "\u{001B}[7m") // Reverse video
                .replacingOccurrences(of: "</mark>", with: "\u{001B}[0m") // Reset
            print("    Snippet: \(snippet)")
            print()
        }
    }

    private func outputJSON(_ results: [SkillSearchEngine.SearchResult]) {
        let output: [[String: Any]] = results.map { result in
            [
                "id": result.id,
                "skillName": result.skillName,
                "skillSlug": result.skillSlug,
                "agent": result.agent.rawValue,
                "snippet": result.snippet,
                "rank": result.rank,
                "filePath": result.filePath
            ]
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
        if let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) {
            print(jsonString)
        }
    }
}
