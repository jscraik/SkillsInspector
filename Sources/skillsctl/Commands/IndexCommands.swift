import Foundation
import ArgumentParser
import SkillsCore

/// SearchIndexCmd commands for building and managing the search index
struct SearchIndexCmd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Build and manage the full-text search index.",
        subcommands: [Build.self, Rebuild.self, Optimize.self, Stats.self]
    )
}

// MARK: - Build

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build the initial search index.",
        discussion: """
        Creates the search index by scanning all standard skill root paths.

        Example:
            skillsctl index build
        """
    )

    @Option(name: .long, help: "Custom skill root paths (comma-separated)")
    var roots: String?

    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
        let engine = try SkillSearchEngine.default()

        // Get root paths
        let scanRoots: [ScanRoot]
        if let rootsString = roots {
            scanRoots = rootsString.split(separator: ",").map {
                ScanRoot(agent: .codex, rootURL: URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)), recursive: true)
            }
        } else {
            scanRoots = SearchIndex.standardScanRoots()
        }

        if verbose {
            print("Scanning \(scanRoots.count) root path(s)...")
            for root in scanRoots {
                print("  - \(root.rootURL.path)")
            }
        }

        // Scan for skills
        let skills = try await SearchIndex.scanRoots(scanRoots)

        if verbose {
            print("Found \(skills.count) skill(s)")
        }

        // Index each skill
        var indexed = 0
        var skipped = 0

        for skill in skills {
            let skillURL = URL(fileURLWithPath: skill.rootPath)
            let skillFile = skillURL.appendingPathComponent("SKILL.md")

            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else {
                if verbose {
                    print("Warning: Cannot read \(skillFile.path)")
                }
                skipped += 1
                continue
            }

            do {
                try await engine.indexSkill(skill, content: content)
                indexed += 1
                if verbose {
                    print("  ✓ \(skill.slug)")
                }
            } catch {
                if verbose {
                    print("  ✗ \(skill.slug): \(error.localizedDescription)")
                }
                skipped += 1
            }
        }

        print("\nIndexed \(indexed) skill(s)")
        if skipped > 0 {
            print("Skipped \(skipped) skill(s)")
        }

        // Show stats
        let stats = try await engine.getStats()
        print("Total indexed: \(stats.totalSkills)")
    }
}

// MARK: - Rebuild

struct Rebuild: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clear and rebuild the search index.",
        discussion: """
        Clears the existing index and rebuilds it from scratch.

        Example:
            skillsctl index rebuild --force
        """
    )

    @Flag(name: .long, help: "Force rebuild without confirmation")
    var force: Bool = false

    @Option(name: .long, help: "Custom skill root paths (comma-separated)")
    var roots: String?

    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
        let engine = try SkillSearchEngine.default()

        // Check for confirmation unless --force
        if !force {
            print("This will clear and rebuild the search index.")
            print("Continue? [y/N] ", terminator: "")

            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Aborted.")
                throw ExitCode(0)
            }
        }

        // Get root paths
        let scanRoots: [ScanRoot]
        if let rootsString = roots {
            scanRoots = rootsString.split(separator: ",").map {
                ScanRoot(agent: .codex, rootURL: URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)), recursive: true)
            }
        } else {
            scanRoots = SearchIndex.standardScanRoots()
        }

        if verbose {
            print("Rebuilding index from \(scanRoots.count) root path(s)...")
        }

        // Rebuild
        try await engine.rebuildIndex(roots: scanRoots)

        print("Index rebuilt successfully")

        // Show stats
        let stats = try await engine.getStats()
        print("Total indexed: \(stats.totalSkills)")
    }
}

// MARK: - Optimize

struct Optimize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Optimize the search index for better performance.",
        discussion: """
        Compacts the FTS5 index to improve search performance.

        Example:
            skillsctl index optimize
        """
    )

    func run() async throws {
        let engine = try SkillSearchEngine.default()

        print("Optimizing index...")
        try await engine.optimize()

        let stats = try await engine.getStats()
        print("Index optimized")
        print("Total indexed: \(stats.totalSkills)")
    }
}

// MARK: - Stats

struct Stats: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show search index statistics.",
        discussion: """
        Display statistics about the search index including size and skill count.

        Example:
            skillsctl index stats
        """
    )

    @Option(name: .long, help: "Output format: text|json (default: text)")
    var format: String = "text"

    func run() async throws {
        let engine = try SkillSearchEngine.default()
        let stats = try await engine.getStats()

        if format.lowercased() == "json" {
            outputJSON(stats)
        } else {
            outputText(stats)
        }
    }

    private func outputText(_ stats: SkillSearchEngine.Stats) {
        print("Search Index Statistics")
        print("=======================")
        print("Total skills: \(stats.totalSkills)")

        let sizeMB = Double(stats.indexSize) / 1_048_576.0
        print("Index size: \(String(format: "%.2f", sizeMB)) MB")

        if let lastIndexed = stats.lastIndexed {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            print("Last indexed: \(formatter.string(from: lastIndexed))")
        } else {
            print("Last indexed: Never")
        }
    }

    private func outputJSON(_ stats: SkillSearchEngine.Stats) {
        let output: [String: Any] = [
            "totalSkills": stats.totalSkills,
            "indexSize": stats.indexSize,
            "lastIndexed": stats.lastIndexed?.ISO8601Format() ?? nil as Any?
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
        if let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) {
            print(jsonString)
        }
    }
}

// MARK: - Helper Extensions

private extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
