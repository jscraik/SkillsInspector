import ArgumentParser
import Foundation
import SkillsCore

struct QuarantineApprove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "approve",
        abstract: "Approve a quarantined item."
    )

    @Argument(help: "Quarantine item identifier")
    var id: String

    func run() async throws {
        let store = QuarantineStore()
        let updated = await store.approve(id: id)

        print("service: skillsctl")

        guard updated else {
            fputs("Error: No quarantine item found with id \(id)\n", stderr)
            throw ExitCode(1)
        }

        print("Approved quarantine item: \(id)")
    }
}
