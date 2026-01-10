import SwiftUI
import SkillsCore

struct SyncDetailView: View {
    let selection: SyncViewModel.SyncSelection
    let codexRoot: URL
    let claudeRoot: URL
    @State private var codexContent: String = ""
    @State private var claudeContent: String = ""
    @State private var loadError: String?
    @State private var statusMessage: String?
    @State private var diffText: String = ""
    @State private var isLoading = false
    @State private var showingCopyConfirmation = false
    @State private var pendingCopyOperation: CopyOperation?

    private var skillName: String {
        switch selection {
        case .onlyCodex(let n), .onlyClaude(let n), .different(let n):
            return n
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(skillName).font(.title3).bold()
            switch selection {
            case .onlyCodex:
                Text("Present only in Codex.")
            case .onlyClaude:
                Text("Present only in Claude.")
            case .different:
                Text("Content differs between Codex and Claude.")
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isDifferent {
                ScrollView {
                    Text(diffText.isEmpty ? "Diff unavailable" : diffText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if let loadError {
                Text(loadError).foregroundStyle(.red)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Codex").font(.headline)
                        ScrollView {
                            Text(codexContent.isEmpty ? "Not available" : codexContent)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isDifferent {
                            Button("Copy Codex → Claude (with backup)") {
                                pendingCopyOperation = CopyOperation(
                                    from: codexFile,
                                    to: claudeFile,
                                    direction: "Codex → Claude"
                                )
                                showingCopyConfirmation = true
                            }
                            .disabled(isLoading)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Claude").font(.headline)
                        ScrollView {
                            Text(claudeContent.isEmpty ? "Not available" : claudeContent)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isDifferent {
                            Button("Copy Claude → Codex (with backup)") {
                                pendingCopyOperation = CopyOperation(
                                    from: claudeFile,
                                    to: codexFile,
                                    direction: "Claude → Codex"
                                )
                                showingCopyConfirmation = true
                            }
                            .disabled(isLoading)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .task { await loadFiles() }
        .alert("Confirm Copy Operation", isPresented: $showingCopyConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingCopyOperation = nil
            }
            Button("Copy with Backup", role: .destructive) {
                if let op = pendingCopyOperation {
                    Task.detached(priority: .userInitiated) {
                        await performCopy(from: op.from, to: op.to)
                    }
                }
                pendingCopyOperation = nil
            }
        } message: {
            if let op = pendingCopyOperation {
                Text("This will copy \(op.direction). A backup of the destination file will be created with a .bak extension.\n\nDestination: \(op.to.lastPathComponent)")
            }
        }
    }

    private var isDifferent: Bool {
        if case .different = selection { return true }
        return false
    }

    private var codexFile: URL {
        codexRoot.appendingPathComponent(skillName).appendingPathComponent("SKILL.md")
    }
    private var claudeFile: URL {
        claudeRoot.appendingPathComponent(skillName).appendingPathComponent("SKILL.md")
    }

    private func loadFiles() async {
        isLoading = true
        loadError = nil
        statusMessage = nil

        let codexURL = codexFile
        let claudeURL = claudeFile

        let (codex, claude, codexErr, claudeErr) = await Task.detached(priority: .userInitiated) { () -> (String, String, String?, String?) in
            let codexResult: (String, String?) = {
                guard FileManager.default.fileExists(atPath: codexURL.path) else {
                    return ("", nil)
                }
                do {
                    return (try String(contentsOf: codexURL, encoding: .utf8), nil)
                } catch {
                    return ("", error.localizedDescription)
                }
            }()

            let claudeResult: (String, String?) = {
                guard FileManager.default.fileExists(atPath: claudeURL.path) else {
                    return ("", nil)
                }
                do {
                    return (try String(contentsOf: claudeURL, encoding: .utf8), nil)
                } catch {
                    return ("", error.localizedDescription)
                }
            }()

            return (codexResult.0, claudeResult.0, codexResult.1, claudeResult.1)
        }.value

        await MainActor.run {
            isLoading = false
            codexContent = codex
            claudeContent = claude

            var errors: [String] = []
            if let err = codexErr { errors.append("Codex: \(err)") }
            if let err = claudeErr { errors.append("Claude: \(err)") }

            if !errors.isEmpty {
                loadError = errors.joined(separator: "\n")
            }

            if isDifferent {
                diffText = unifiedDiff(left: codexContent, right: claudeContent, leftName: "Codex", rightName: "Claude")
            }
        }
    }

    private func performCopy(from: URL, to: URL) async {
        await MainActor.run {
            statusMessage = "Copying..."
            isLoading = true
        }

        let result = await Task.detached(priority: .userInitiated) { () -> CopyResult in
            guard FileManager.default.fileExists(atPath: from.path) else {
                return CopyResult(success: false, message: "Source missing: \(from.lastPathComponent)")
            }

            do {
                let data = try Data(contentsOf: from)
                let dir = to.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                if FileManager.default.fileExists(atPath: to.path) {
                    let backup = to.appendingPathExtension("bak")
                    try? FileManager.default.removeItem(at: backup)
                    try FileManager.default.copyItem(at: to, to: backup)
                }

                try data.write(to: to, options: .atomic)
                return CopyResult(success: true, message: "Copied \(from.lastPathComponent) → \(to.lastPathComponent)")
            } catch {
                return CopyResult(success: false, message: "Copy failed: \(error.localizedDescription)")
            }
        }.value

        await MainActor.run {
            isLoading = false
            statusMessage = result.message

            if result.success {
                // Reload files to show updated content
                Task { await loadFiles() }
            }
        }
    }

    private func unifiedDiff(left: String, right: String, leftName: String, rightName: String) -> String {
        let leftLines = left.split(separator: "\n", omittingEmptySubsequences: false)
        let rightLines = right.split(separator: "\n", omittingEmptySubsequences: false)

        var output: [String] = []
        output.reserveCapacity(leftLines.count + rightLines.count + 2)
        output.append("--- \(leftName)")
        output.append("+++ \(rightName)")

        let maxCount = max(leftLines.count, rightLines.count)
        for i in 0..<maxCount {
            let l = i < leftLines.count ? String(leftLines[i]) : nil
            let r = i < rightLines.count ? String(rightLines[i]) : nil
            if l == r {
                output.append(" \(l ?? "")")
            } else {
                if let l { output.append("-\(l)") }
                if let r { output.append("+\(r)") }
            }
        }
        return output.joined(separator: "\n")
    }
}

// MARK: - Helper Types

private struct CopyOperation: Sendable {
    let from: URL
    let to: URL
    let direction: String
}

private struct CopyResult: Sendable {
    let success: Bool
    let message: String
}
