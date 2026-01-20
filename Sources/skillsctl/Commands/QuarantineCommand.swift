import ArgumentParser

struct QuarantineCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "quarantine",
        abstract: "Review quarantined skills.",
        subcommands: [QuarantineList.self, QuarantineApprove.self, QuarantineBlock.self]
    )
}
