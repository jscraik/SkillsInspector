import ArgumentParser

struct SecurityCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "security",
        abstract: "Security tools for ACIP scanning.",
        subcommands: [SecurityScan.self]
    )
}
