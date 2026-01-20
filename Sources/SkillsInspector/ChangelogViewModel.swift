import Foundation
import SkillsCore

@MainActor
final class ChangelogViewModel: ObservableObject {
    @Published var events: [LedgerEvent] = []
    @Published var generatedMarkdown: String = ""
    @Published var statusMessage: String?
    @Published var changelogPath: URL?
    @Published var ledgerPath: URL?
    @Published var isLoading = false

    private let ledger: SkillLedger?
    private let generator = SkillChangelogGenerator()
    private let signer = ChangelogSigner()

    init(ledger: SkillLedger?) {
        self.ledger = ledger
        self.ledgerPath = SkillLedger.defaultStoreURL()
        self.changelogPath = resolveChangelogPath()
    }

    func refreshEvents(limit: Int = 200) async {
        guard let ledger else {
            statusMessage = "Ledger unavailable"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await ledger.fetchEvents(limit: limit)
        } catch {
            statusMessage = "Ledger read failed: \(error.localizedDescription)"
        }
    }

    func generateChangelog() async {
        if events.isEmpty {
            await refreshEvents()
        }
        generatedMarkdown = generator.generateAppStoreMarkdown(events: events)
        statusMessage = "Generated from ledger"
    }

    func saveChangelog() {
        guard let target = changelogPath else {
            statusMessage = "Save failed: no path"
            return
        }
        do {
            let signed = try signer.sign(markdown: generatedMarkdown)
            try signed.renderSignedMarkdown().write(to: target, atomically: true, encoding: .utf8)
            statusMessage = "Saved to \(target.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func loadChangelog(from url: URL) {
        if let data = try? String(contentsOf: url, encoding: .utf8) {
            changelogPath = url
            generatedMarkdown = data
            statusMessage = "Loaded \(url.lastPathComponent)"
        } else {
            statusMessage = "Load failed"
        }
    }

    private func resolveChangelogPath() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent(".codex/public/skills-changelog.md"),
            home.appendingPathComponent(".claude/skills-changelog.md"),
            home.appendingPathComponent(".copilot/skills-changelog.md"),
            home.appendingPathComponent(".codexskillmanager/skills-changelog.md"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/skills-changelog.md")
        ]
        return candidates.first { url in
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) { return true }
            return (try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)) != nil
        }
    }
}
