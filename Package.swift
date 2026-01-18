// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cLog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SkillsCore", targets: ["SkillsCore"]),
        .executable(name: "skillsctl", targets: ["skillsctl"]),
        .executable(name: "SkillsInspector", targets: ["SkillsInspector"]),
        .plugin(name: "SkillsLintPlugin", targets: ["SkillsLintPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SkillsCore",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
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
            dependencies: [
                "SkillsCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources/Icon.icns")
            ],
            swiftSettings: [
                .unsafeFlags(["-default-isolation", "MainActor"]),
                .unsafeFlags(["-strict-concurrency=complete"]),
                .unsafeFlags(["-warn-concurrency"])
            ]
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
        ),
        .testTarget(
            name: "SkillsInspectorTests",
            dependencies: ["SkillsInspector", "SkillsCore"],
            resources: []
        )
    ],
    swiftLanguageModes: [.v6]
)
