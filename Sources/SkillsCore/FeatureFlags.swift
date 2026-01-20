import Foundation

public struct FeatureFlags: Sendable {
    public var skillVerification: Bool
    public var pinnedPublishing: Bool
    public var crossIDEAdapters: Bool
    public var telemetryOptIn: Bool
    public var bulkActions: Bool

    public init(
        skillVerification: Bool = true,
        pinnedPublishing: Bool = true,
        crossIDEAdapters: Bool = true,
        telemetryOptIn: Bool = false,
        bulkActions: Bool = true
    ) {
        self.skillVerification = skillVerification
        self.pinnedPublishing = pinnedPublishing
        self.crossIDEAdapters = crossIDEAdapters
        self.telemetryOptIn = telemetryOptIn
        self.bulkActions = bulkActions
    }

    /// Creates feature flags from environment variables.
    /// - Parameter env: Environment variables dictionary (defaults to `ProcessInfo.processInfo.environment`)
    /// - Returns: Feature flags with environment variable overrides applied
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> FeatureFlags {
        // Telemetry opt-in can also be controlled via UserDefaults (for UI settings)
        // Environment variable takes precedence over UserDefaults
        let telemetryFromEnv = env.optionalBool("STOOLS_FEATURE_TELEMETRY")
        let telemetryOptIn: Bool
        if let envValue = telemetryFromEnv {
            telemetryOptIn = envValue
        } else {
            telemetryOptIn = UserDefaults.standard.bool(forKey: "telemetryOptIn")
        }

        return FeatureFlags(
            skillVerification: env.bool("STOOLS_FEATURE_VERIFICATION", defaultValue: true),
            pinnedPublishing: env.bool("STOOLS_FEATURE_PUBLISHING", defaultValue: true),
            crossIDEAdapters: env.bool("STOOLS_FEATURE_ADAPTERS", defaultValue: true),
            telemetryOptIn: telemetryOptIn,
            bulkActions: env.bool("STOOLS_FEATURE_BULK_ACTIONS", defaultValue: true)
        )
    }

    /// Creates feature flags from a `SkillsConfig` instance.
    /// - Parameter config: The configuration to load flags from
    /// - Parameter env: Optional environment variables for override (defaults to `ProcessInfo.processInfo.environment`)
    /// - Returns: Feature flags with config values applied; environment variables take precedence
    public static func fromConfig(_ config: SkillsConfig, env: [String: String] = ProcessInfo.processInfo.environment) -> FeatureFlags {
        // Start with config values (if present), otherwise use defaults
        let fromConfig = FeatureFlags(
            skillVerification: config.features?.skillVerification ?? true,
            pinnedPublishing: config.features?.pinnedPublishing ?? true,
            crossIDEAdapters: config.features?.crossIDEAdapters ?? true,
            telemetryOptIn: config.features?.telemetryOptIn ?? false,
            bulkActions: config.features?.bulkActions ?? true
        )

        // Apply environment variable overrides (env takes precedence over config)
        return FeatureFlags(
            skillVerification: env.optionalBool("STOOLS_FEATURE_VERIFICATION") ?? fromConfig.skillVerification,
            pinnedPublishing: env.optionalBool("STOOLS_FEATURE_PUBLISHING") ?? fromConfig.pinnedPublishing,
            crossIDEAdapters: env.optionalBool("STOOLS_FEATURE_ADAPTERS") ?? fromConfig.crossIDEAdapters,
            telemetryOptIn: env.optionalBool("STOOLS_FEATURE_TELEMETRY") ?? fromConfig.telemetryOptIn,
            bulkActions: env.optionalBool("STOOLS_FEATURE_BULK_ACTIONS") ?? fromConfig.bulkActions
        )
    }
}

private extension Dictionary where Key == String, Value == String {
    func bool(_ key: String, defaultValue: Bool) -> Bool {
        guard let raw = self[key]?.lowercased() else { return defaultValue }
        switch raw {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }

    func optionalBool(_ key: String) -> Bool? {
        guard let raw = self[key]?.lowercased() else { return nil }
        switch raw {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
