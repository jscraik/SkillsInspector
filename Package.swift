// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cLog",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "SkillsCore", targets: ["SkillsCore"]),
        .executable(name: "skillsctl", targets: ["skillsctl"]),
        .executable(name: "SkillsInspector", targets: ["SkillsInspector"]),
        .plugin(name: "SkillsLintPlugin", targets: ["SkillsLintPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SkillsCore",
            dependencies: []
        ),
        .executableTarget(
            name: "skillsctl",
            dependencies: [
                "SkillsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "SkillsInspector",
            dependencies: ["SkillsCore"]
        ),
        .plugin(
            name: "SkillsLintPlugin",
            capability: .command(
                intent: .custom(verb: "skills-lint", description: "Scan Codex/Claude skill roots for SKILL.md issues"),
                permissions: []
            ),
            dependencies: ["skillsctl"]
        ),
        .testTarget(
            name: "SkillsCoreTests",
            dependencies: ["SkillsCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ],
    swiftLanguageVersions: [.v6]
)
