import Foundation

/// Post-install validation hook for verifying a skill after installation.
public protocol PostInstallValidator: Sendable {
    /// Validates that a skill is correctly installed for a specific target.
    /// - Parameters:
    ///   - result: The installation result containing the skill directory path.
    ///   - target: The target where the skill was installed.
    /// - Returns: `nil` if validation passes, or an error message describing the failure.
    func validate(result: RemoteSkillInstallResult, target: SkillInstallTarget) -> String?
}

/// Default validator that checks SKILL.md exists and is readable.
public struct DefaultPostInstallValidator: PostInstallValidator {
    public init() {}

    public func validate(result: RemoteSkillInstallResult, target: SkillInstallTarget) -> String? {
        let skillFile = result.skillDirectory.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else {
            return "SKILL.md not found at \(skillFile.path)"
        }
        guard let _ = try? String(contentsOf: skillFile, encoding: .utf8) else {
            return "SKILL.md exists but is not readable at \(skillFile.path)"
        }
        return nil
    }
}

/// Installs a verified skill archive into multiple targets with rollback on partial failure.
public struct MultiTargetSkillInstaller: Sendable {
    private let installer: RemoteSkillInstaller
    private let validator: any PostInstallValidator

    public init(
        installer: RemoteSkillInstaller = RemoteSkillInstaller(),
        validator: (any PostInstallValidator)? = nil
    ) {
        self.installer = installer
        self.validator = validator ?? DefaultPostInstallValidator()
    }

    /// Installs a skill to multiple targets with best-effort semantics.
    /// - Parameters:
    ///   - archiveURL: URL of the verified skill archive
    ///   - targets: Array of target locations to install to
    ///   - overwrite: Whether to overwrite existing installations
    ///   - manifest: The verified manifest for this skill
    ///   - policy: Verification policy to apply
    ///   - trustStore: Trust store for signature verification
    ///   - skillSlug: Optional skill identifier for logging
    /// - Returns: Outcome containing successes and failures per target
    /// - Note: Any failure triggers rollback across all targets (all-or-nothing semantics)
    public func install(
        archiveURL: URL,
        targets: [SkillInstallTarget],
        overwrite: Bool,
        manifest: RemoteArtifactManifest,
        policy: RemoteVerificationPolicy = .default,
        trustStore: RemoteTrustStore = .ephemeral,
        skillSlug: String? = nil,
        securityConfig: SecurityConfig = .default,
        acipScanner: ACIPScanner = ACIPScanner(),
        quarantineStore: QuarantineStore = QuarantineStore()
    ) async throws -> MultiTargetInstallOutcome {
        var successes: [AgentKind: RemoteSkillInstallResult] = [:]
        var installed: [AgentKind: RemoteSkillInstallResult] = [:]
        var failures: [AgentKind: String] = [:]

        for target in targets {
            do {
                let result = try await installer.install(
                    archiveURL: archiveURL,
                    target: target,
                    overwrite: overwrite,
                    manifest: manifest,
                    policy: policy,
                    trustStore: trustStore,
                    skillSlug: skillSlug,
                    securityConfig: securityConfig,
                    acipScanner: acipScanner,
                    quarantineStore: quarantineStore,
                    preserveBackup: true
                )

                installed[target.agentKind] = result

                // Run post-install validation hook
                if let validationError = validator.validate(result: result, target: target) {
                    throw RemoteInstallError.validationFailed(validationError)
                }

                successes[target.agentKind] = result
            } catch {
                failures[target.agentKind] = error.localizedDescription
                break
            }
        }

        if failures.isEmpty {
            cleanupBackups(for: installed)
            return MultiTargetInstallOutcome(
                successes: successes,
                failures: failures,
                didRollback: false
            )
        }

        let rollbackReason = failures.values.first ?? "Install failed"
        rollbackInstallations(for: installed, reason: rollbackReason)

        for target in targets.map(\.agentKind) where failures[target] == nil {
            failures[target] = "Rolled back due to failure: \(rollbackReason)"
        }

        return MultiTargetInstallOutcome(
            successes: [:],
            failures: failures,
            didRollback: true
        )
    }

    private func rollbackInstallations(for successes: [AgentKind: RemoteSkillInstallResult], reason: String) {
        for result in successes.values {
            let destination = result.skillDirectory
            if let backupURL = result.backupURL, FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.moveItem(at: backupURL, to: destination)
            } else {
                try? FileManager.default.removeItem(at: destination)
            }
        }
    }

    private func cleanupBackups(for successes: [AgentKind: RemoteSkillInstallResult]) {
        for result in successes.values {
            if let backupURL = result.backupURL {
                try? FileManager.default.removeItem(at: backupURL)
            }
        }
    }
}

public struct MultiTargetInstallOutcome: Sendable {
    public let successes: [AgentKind: RemoteSkillInstallResult]
    public let failures: [AgentKind: String]
    public let didRollback: Bool

    public init(successes: [AgentKind: RemoteSkillInstallResult], failures: [AgentKind: String], didRollback: Bool) {
        self.successes = successes
        self.failures = failures
        self.didRollback = didRollback
    }
}

public extension SkillInstallTarget {
    var agentKind: AgentKind {
        switch self {
        case .codex: return .codex
        case .claude: return .claude
        case .copilot: return .copilot
        case .custom: return .codex
        }
    }
}
