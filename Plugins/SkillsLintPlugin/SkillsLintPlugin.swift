import PackagePlugin
import Foundation

@main
struct SkillsLintPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "skillsctl")
        let packageDir = context.package.directoryURL.path

        var cmd = [tool.url.path, "scan", "--repo", packageDir, "--format", "json", "--allow-empty"]
        cmd.append(contentsOf: arguments) // allow forward flags like --recursive if added later

        let result = try runCommand(cmd)
        guard result.exitCode == 0 else {
            Diagnostics.emit(.error, "skills-lint: skillsctl exited with code \(result.exitCode)")
            if !result.stderr.isEmpty {
                Diagnostics.emit(.error, result.stderr)
            }
            throw PluginError.validationFailed
        }

        guard let data = result.stdout.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let findings = payload["findings"] as? [[String: Any]] else {
            Diagnostics.emit(.error, "skills-lint: unable to parse skillsctl JSON output")
            throw PluginError.validationFailed
        }

        var hasErrors = false
        for finding in findings {
            let ruleID = finding["ruleID"] as? String ?? "unknown"
            let severityRaw = finding["severity"] as? String ?? "warning"
            let message = finding["message"] as? String ?? ""
            let file = finding["file"] as? String ?? ""
            let line = finding["line"] as? Int

            let severity: Diagnostics.Severity
            switch severityRaw {
            case "error":
                severity = .error
                hasErrors = true
            case "warning":
                severity = .warning
            default:
                severity = .remark
            }

            var composed = "[\(ruleID)] \(message)"
            if let line {
                composed += " @ \(file):\(line)"
            } else {
                composed += " (\(file))"
            }
            Diagnostics.emit(severity, composed)
        }

        if hasErrors {
            throw PluginError.validationFailed
        }
    }

    private func runCommand(_ command: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.first!)
        process.arguments = Array(command.dropFirst())

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        return CommandResult(exitCode: Int(process.terminationStatus), stdout: stdout, stderr: stderr)
    }
}

struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

enum PluginError: Error {
    case validationFailed
}
