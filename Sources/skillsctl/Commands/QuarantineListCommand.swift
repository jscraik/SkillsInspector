import ArgumentParser
import Foundation
import SkillsCore

struct QuarantineList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List quarantined items pending review."
    )

    func run() async throws {
        let store = QuarantineStore()
        let pending = await store.list().filter { $0.status == .pending }

        print("service: skillsctl")

        guard !pending.isEmpty else {
            print("No pending quarantine items.")
            return
        }

        let formatter = ISO8601DateFormatter()
        print("Pending items: \(pending.count)")

        for item in pending {
            print("- ID: \(item.id)")
            print("  Skill: \(item.skillName) (\(item.skillSlug))")
            print("  Quarantined: \(formatter.string(from: item.quarantinedAt))")
            if !item.reasons.isEmpty {
                print("  Reasons: \(item.reasons.joined(separator: "; "))")
            }
            if !item.safeExcerpt.isEmpty {
                print("  Excerpt:\n\(item.safeExcerpt)")
            }
        }
    }
}
