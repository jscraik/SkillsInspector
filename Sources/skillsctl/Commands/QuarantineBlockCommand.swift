import ArgumentParser
import Foundation
import SkillsCore

struct QuarantineBlock: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "block",
        abstract: "Reject a quarantined item."
    )

    @Argument(help: "Quarantine item identifier")
    var id: String

    func run() async throws {
        let store = QuarantineStore()
        let updated = await store.reject(id: id)

        print("service: skillsctl")

        guard updated else {
            fputs("Error: No quarantine item found with id \(id)\n", stderr)
            throw ExitCode(1)
        }

        print("Rejected quarantine item: \(id)")
    }
}
