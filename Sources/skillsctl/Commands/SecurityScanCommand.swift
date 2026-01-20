import ArgumentParser
import Foundation
import SkillsCore

struct SecurityScan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Run ACIP security scan on a skill directory."
    )

    @Argument(help: "Path to skill directory or SKILL.md")
    var path: String

    @Option(name: .customLong("mode"), help: "Scan mode: default|strict|permissive")
    var mode: String = "default"

    @Flag(name: .customLong("all"), help: "Include clean files in output")
    var includeClean: Bool = false

    func run() async throws {
        let scanURL = try resolveScanURL(from: path)
        let config = try resolveConfig(for: mode)
        let scanner = ACIPScanner(config: config)

        let results = await scanner.scanSkill(at: scanURL, source: .file)
        let filtered = filterResults(results, includeClean: includeClean, inputPath: path)
        let sorted = filtered.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }

        print("service: skillsctl")
        print("Security scan: \(scanURL.path)")
        print("Mode: \(mode.lowercased())")
        print("Files scanned: \(results.count)")

        if sorted.isEmpty {
            print("✓ No findings")
            return
        }

        print("")
        print("Findings: \(sorted.count)")

        for (filePath, result) in sorted {
            let status = statusLabel(for: result)
            print("- [\(status)] \(filePath)")

            if !result.patterns.isEmpty {
                let names = result.patterns.map { "\($0.name) (\($0.id))" }
                print("  Patterns: \(names.joined(separator: ", "))")
            }
            if !result.matchedLines.isEmpty {
                let lines = result.matchedLines.map(String.init).joined(separator: ", ")
                print("  Lines: \(lines)")
            }

            switch result.action {
            case .quarantine(let reason, let match, let safeExcerpt):
                print("  Action: quarantine")
                print("  Reason: \(reason)")
                print("  Match: \(match)")
                if !safeExcerpt.isEmpty {
                    print("  Excerpt:\n\(safeExcerpt)")
                }
            case .block(let reason, let match):
                print("  Action: block")
                print("  Reason: \(reason)")
                print("  Match: \(match)")
            case .allow:
                if !result.patterns.isEmpty {
                    print("  Action: allow")
                }
            }
        }
    }

    private func resolveScanURL(from path: String) throws -> URL {
        let expanded = PathUtil.expandTilde(path)
        let url = URL(fileURLWithPath: expanded)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ValidationError("Path not found: \(url.path)")
        }
        if isDirectory.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func resolveConfig(for raw: String) throws -> SecurityConfig {
        switch raw.lowercased() {
        case "default": return .default
        case "strict": return .strict
        case "permissive": return .permissive
        default:
            throw ValidationError("Invalid mode '\(raw)'. Use default, strict, or permissive.")
        }
    }

    private func filterResults(
        _ results: [String: ACIPScanner.ScanResult],
        includeClean: Bool,
        inputPath: String
    ) -> [String: ACIPScanner.ScanResult] {
        if includeClean {
            return results
        }

        let expandedInput = PathUtil.expandTilde(inputPath)
        if FileManager.default.fileExists(atPath: expandedInput) {
            let inputURL = URL(fileURLWithPath: expandedInput)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                if let result = results[inputURL.path] {
                    return [inputURL.path: result]
                }
            }
        }

        return results.filter { !$0.value.patterns.isEmpty || !isAllowed($0.value.action) }
    }

    private func statusLabel(for result: ACIPScanner.ScanResult) -> String {
        if isBlocked(result.action) { return "BLOCK" }
        if isQuarantined(result.action) { return "QUARANTINE" }
        if !result.patterns.isEmpty { return "WARN" }
        return "OK"
    }

    private func isAllowed(_ action: ACIPScanner.QuarantineAction) -> Bool {
        if case .allow = action { return true }
        return false
    }

    private func isBlocked(_ action: ACIPScanner.QuarantineAction) -> Bool {
        if case .block = action { return true }
        return false
    }

    private func isQuarantined(_ action: ACIPScanner.QuarantineAction) -> Bool {
        if case .quarantine = action { return true }
        return false
    }
}
