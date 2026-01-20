import Foundation
import AppKit
import SkillsCore

@MainActor
final class RemoteViewModel: ObservableObject {
    @Published var skills: [RemoteSkill] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var ownerBySlug: [String: RemoteSkillOwner?] = [:]
    @Published var installingSlug: String?
    @Published var installResult: RemoteSkillInstallResult?
    @Published var installedVersions: [String: String] = [:]
    @Published var changelogBySlug: [String: String?] = [:]
    @Published var previewStateBySlug: [String: RemotePreviewState] = [:]
    @Published var multiTargetOutcome: MultiTargetInstallOutcome?
    @Published var bulkOperationProgress: BulkOperationProgress?
    @Published var exportedChangelogURL: URL?

    private let client: RemoteSkillClient
    private let installer: RemoteSkillInstaller
    private let multiInstaller: MultiTargetSkillInstaller
    private let targetResolver: () -> SkillInstallTarget
    private let trustStoreProvider: () -> RemoteTrustStore
    private let previewCache = RemotePreviewCache()
    private let ledger: SkillLedger?
    private let telemetry: TelemetryClient
    private let features: FeatureFlags
    private let keysetUpdater: (RemoteKeyset) -> Void
    private let securitySettingsStore: SecuritySettingsStore
    private let changelogGenerator = SkillChangelogGenerator()

    init(
        client: RemoteSkillClient,
        installer: RemoteSkillInstaller = RemoteSkillInstaller(),
        ledger: SkillLedger? = nil,
        telemetry: TelemetryClient = .noop,
        features: FeatureFlags = .fromEnvironment(),
        targetResolver: @escaping () -> SkillInstallTarget = { .codex(PathUtil.urlFromPath("~/.codex/skills")) },
        trustStoreProvider: @escaping () -> RemoteTrustStore = { .ephemeral },
        keysetUpdater: @escaping (RemoteKeyset) -> Void = { _ in },
        securitySettingsStore: SecuritySettingsStore = SecuritySettingsStore()
    ) {
        let env = ProcessInfo.processInfo.environment
        if env["SKILLS_MOCK_REMOTE_SCREENSHOT"] == "1" {
            self.client = RemoteSkillClient.mock(forScreenshots: true)
        } else if env["SKILLS_MOCK_REMOTE"] == "1" {
            self.client = RemoteSkillClient.mock()
        } else {
            self.client = client
        }
        self.installer = installer
        self.multiInstaller = MultiTargetSkillInstaller(installer: installer)
        self.targetResolver = targetResolver
        self.trustStoreProvider = trustStoreProvider
        self.ledger = ledger
        self.telemetry = telemetry
        self.features = features
        self.keysetUpdater = keysetUpdater
        self.securitySettingsStore = securitySettingsStore
    }

    func loadLatest(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await client.fetchLatest(limit)
            skills = result
            await refreshInstalledVersions()
            await refreshKeysetIfConfigured()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshLocalSkills() async {
        await refreshInstalledVersions()
    }

    func fetchOwner(for slug: String) async {
        if ownerBySlug[slug] != nil { return }
        do {
            let owner = try await client.fetchDetail(slug)
            ownerBySlug[slug] = owner
        } catch {
            ownerBySlug[slug] = nil
        }
    }

    func fetchChangelog(for slug: String) async {
        if changelogBySlug[slug] != nil { return }
        do {
            let info = try await client.fetchLatestVersionInfo(slug)
            changelogBySlug[slug] = info.changelog
        } catch {
            changelogBySlug[slug] = nil
        }
    }

    func fetchPreview(for skill: RemoteSkill) async {
        let slug = skill.slug
        if previewStateBySlug[slug]?.status == .loading { return }
        previewStateBySlug[slug] = .loading()
        do {
            let manifest = try await fetchManifestCached(slug: slug, version: skill.latestVersion)
            let cached = previewCache.load(
                slug: slug,
                version: skill.latestVersion,
                expectedManifestSHA256: manifest?.sha256,
                expectedETag: nil
            )
            if let cached {
                previewStateBySlug[slug] = .available(preview: cached, manifest: manifest)
                if let changelog = cached.changelog {
                    changelogBySlug[slug] = changelog
                }
                return
            }
            let preview = try await client.fetchPreview(slug, skill.latestVersion)
            if let preview {
                previewCache.store(preview)
                if let manifest = preview.manifest {
                    previewCache.storeManifest(slug: slug, version: preview.version ?? skill.latestVersion, manifest: manifest, etag: preview.etag)
                }
                previewStateBySlug[slug] = .available(preview: preview, manifest: manifest ?? preview.manifest)
                if let changelog = preview.changelog {
                    changelogBySlug[slug] = changelog
                }
            } else {
                previewStateBySlug[slug] = .unavailable(manifest: manifest)
            }
        } catch {
            previewStateBySlug[slug] = .failed(error.localizedDescription)
        }
    }

    func install(skill: RemoteSkill) async {
        await fetchPreview(for: skill)
        await install(slug: skill.slug, version: skill.latestVersion)
    }

    func installToAllTargets(skill: RemoteSkill) async {
        guard features.crossIDEAdapters else {
            errorMessage = "Cross-IDE installs are disabled."
            return
        }
        await fetchPreview(for: skill)
        guard let manifest = previewStateBySlug[skill.slug]?.manifest else {
            errorMessage = "Manifest unavailable for \(skill.slug). Verification required."
            return
        }

        // Pre-download validation: check size limits from manifest
        if let declaredSize = manifest.size,
           declaredSize > RemoteVerificationLimits.default.maxArchiveBytes {
            let limitMB = RemoteVerificationLimits.default.maxArchiveBytes / 1_048_576
            let sizeMB = declaredSize / 1_048_576
            errorMessage = "Download blocked: artifact size (\(sizeMB)MB) exceeds safety limit (\(limitMB)MB)"
            telemetry.record(
                TelemetryEvent.blockedDownload(
                    skillSlug: skill.slug,
                    reason: "size_limit",
                    installerId: InstallerId.getOrCreate()
                )
            )
            return
        }

        installingSlug = skill.slug
        multiTargetOutcome = nil  // Clear previous outcome
        defer { installingSlug = nil }
        let targets: [SkillInstallTarget] = [
            .codex(PathUtil.urlFromPath("~/.codex/skills")),
            .claude(PathUtil.urlFromPath("~/.claude/skills")),
            .copilot(PathUtil.urlFromPath("~/.copilot/skills"))
        ]
        do {
            let securityConfig = await securitySettingsStore.load()
            let archive = try await client.download(skill.slug, skill.latestVersion)
            let outcome = try await multiInstaller.install(
                archiveURL: archive,
                targets: targets,
                overwrite: true,
                manifest: manifest,
                policy: .default,
                trustStore: trustStoreProvider(),
                skillSlug: skill.slug,
                securityConfig: securityConfig
            )
            multiTargetOutcome = outcome  // Store outcome for UI display

            if outcome.didRollback {
                let summary = outcome.failures
                    .map { "\($0.key.displayLabel): \($0.value)" }
                    .joined(separator: ", ")
                errorMessage = "Rolled back: \(summary)"
                await recordFailureEvents(for: skill, version: skill.latestVersion, failures: outcome.failures, message: "Rolled back after failure")
                return
            }

            if !outcome.failures.isEmpty {
                let summary = outcome.failures
                    .map { "\($0.key.displayLabel): \($0.value)" }
                    .joined(separator: ", ")
                errorMessage = "Partial failure: \(summary)"
                await recordFailureEvents(for: skill, version: skill.latestVersion, failures: outcome.failures)
            } else {
                installResult = outcome.successes[.codex]
                await recordSuccessEvents(for: skill, version: skill.latestVersion, results: outcome.successes, manifest: manifest)
                telemetry.record(
                    TelemetryEvent.verifiedInstall(
                        skillSlug: skill.slug,
                        version: skill.latestVersion ?? "unknown",
                        installerId: InstallerId.getOrCreate()
                    )
                )
            }
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
            await recordFailureEvents(for: skill, version: skill.latestVersion, failures: [:], message: error.localizedDescription)
        }
    }

    func install(slug: String, version: String? = nil) async {
        installingSlug = slug
        defer { installingSlug = nil }

        // Pre-download validation: check size limits from manifest
        if let manifest = previewStateBySlug[slug]?.manifest,
           let declaredSize = manifest.size,
           declaredSize > RemoteVerificationLimits.default.maxArchiveBytes {
            let limitMB = RemoteVerificationLimits.default.maxArchiveBytes / 1_048_576
            let sizeMB = declaredSize / 1_048_576
            errorMessage = "Download blocked: artifact size (\(sizeMB)MB) exceeds safety limit (\(limitMB)MB)"
            telemetry.record(
                TelemetryEvent.blockedDownload(
                    skillSlug: slug,
                    reason: "size_limit",
                    installerId: InstallerId.getOrCreate()
                )
            )
            return
        }

        do {
            let archive = try await client.download(slug, version)
            let manifest = previewStateBySlug[slug]?.manifest
            guard let manifest else {
                errorMessage = "Manifest unavailable for \(slug). Verification required."
                return
            }
            let securityConfig = await securitySettingsStore.load()
            let result = try await installer.install(
                archiveURL: archive,
                target: targetResolver(),
                overwrite: true,
                manifest: manifest,
                policy: .default,
                trustStore: trustStoreProvider(),
                skillSlug: slug,
                securityConfig: securityConfig
            )
            installResult = result
            let skill = skills.first { $0.slug == slug }
            let resolvedVersion = version ?? skill?.latestVersion ?? "unknown"
            if let skill {
                await recordSingleSuccess(skill: skill, version: resolvedVersion, result: result, manifest: manifest)
            }
            telemetry.record(
                TelemetryEvent.verifiedInstall(
                    skillSlug: slug,
                    version: resolvedVersion,
                    installerId: InstallerId.getOrCreate()
                )
            )
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
            if let skill = skills.first(where: { $0.slug == slug }) {
                await recordFailureEvents(for: skill, version: version ?? skill.latestVersion, failures: [:], message: error.localizedDescription)
            }
        }
    }

    func isUpdateAvailable(for skill: RemoteSkill) -> Bool {
        guard let latest = skill.latestVersion else { return false }
        guard let installed = installedVersions[skill.slug] else { return false }
        return installed != latest
    }

    func localSkillURL(slug: String) -> URL? {
        let root = targetResolver().root
        let skillDir = root.appendingPathComponent(slug, isDirectory: true)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else { return nil }
        return skillFile
    }

    func loadLocalSkillMarkdown(slug: String) -> String? {
        guard let skillFile = localSkillURL(slug: slug) else { return nil }
        return try? String(contentsOf: skillFile, encoding: .utf8)
    }

    private func refreshInstalledVersions() async {
        let target = targetResolver().root
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: target, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
        var versions: [String: String] = [:]
        for dir in items {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let skillFile = dir.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillFile.path) else { continue }
            if let text = try? String(contentsOf: skillFile, encoding: .utf8) {
                let fm = FrontmatterParser.parseTopBlock(text)
                if let version = fm["version"] {
                    versions[dir.lastPathComponent] = version
                }
            }
        }
        installedVersions = versions
    }

    func verifyAll() async {
        guard !skills.isEmpty else { return }
        let progress = BulkOperationProgress(
            operation: .verifyAll,
            total: skills.count,
            completed: 0,
            failures: [:]
        )
        bulkOperationProgress = progress

        for (index, skill) in skills.enumerated() {
            await fetchPreview(for: skill)
            await recordVerifyIfAvailable(skill: skill)
            let updatedProgress = BulkOperationProgress(
                operation: .verifyAll,
                total: skills.count,
                completed: index + 1,
                failures: progress.failures
            )
            bulkOperationProgress = updatedProgress
        }

        bulkOperationProgress = nil
    }

    func updateAllVerified() async {
        let skillsToUpdate = skills.filter { isUpdateAvailable(for: $0) }
        guard !skillsToUpdate.isEmpty else { return }

        let progress = BulkOperationProgress(
            operation: .updateAllVerified,
            total: skillsToUpdate.count,
            completed: 0,
            failures: [:]
        )
        bulkOperationProgress = progress

        for (index, skill) in skillsToUpdate.enumerated() {
            if previewStateBySlug[skill.slug]?.manifest == nil {
                await fetchPreview(for: skill)
            }

            await install(slug: skill.slug, version: skill.latestVersion)

            let finalProgress = BulkOperationProgress(
                operation: .updateAllVerified,
                total: skillsToUpdate.count,
                completed: index + 1,
                failures: progress.failures
            )
            bulkOperationProgress = finalProgress
        }

        bulkOperationProgress = nil
    }

    func exportChangelog() async {
        guard let ledger else {
            errorMessage = "Ledger unavailable for changelog export"
            return
        }

        do {
            let events = try await ledger.fetchEvents(limit: 1000)
            let markdown = changelogGenerator.generateAuditorMarkdown(events: events)
            let signer = ChangelogSigner()
            let signed = try signer.sign(markdown: markdown)

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.plainText]
            savePanel.nameFieldStringValue = "skills-changelog-\(Date().timeIntervalSince1970).md"
            savePanel.title = "Export Changelog"
            savePanel.prompt = "Export"

            #if os(macOS)
            if savePanel.runModal() == .OK, let url = savePanel.url {
                try signed.renderSignedMarkdown().write(to: url, atomically: true, encoding: .utf8)
                exportedChangelogURL = url
                errorMessage = nil
            }
            #endif
        } catch {
            errorMessage = "Failed to export changelog: \(error.localizedDescription)"
        }
    }

    func provenanceStatus(for slug: String) -> RemoteProvenanceStatus {
        guard let state = previewStateBySlug[slug] else { return .unknown }
        if state.status == .failed { return .failed }
        if state.manifest != nil { return .verified }
        return .unknown
    }

    func isBulkActionsEnabled() -> Bool {
        features.bulkActions
    }

    func isCrossIDEEnabled() -> Bool {
        features.crossIDEAdapters
    }

    private func recordSingleSuccess(
        skill: RemoteSkill,
        version: String?,
        result: RemoteSkillInstallResult,
        manifest: RemoteArtifactManifest
    ) async {
        let target = targetResolver()
        let eventType = eventTypeForInstall(slug: skill.slug, version: version, targetRoot: target.root)
        await recordLedgerEvent(
            LedgerEventInput(
                eventType: eventType,
                skillName: skill.displayName,
                skillSlug: skill.slug,
                version: version,
                agent: target.agentKind,
                status: .success,
                note: "Installed via remote",
                source: "remote",
                verification: result.verification,
                manifestSHA256: manifest.sha256,
                targetPath: result.skillDirectory.path,
                targets: [target.agentKind],
                perTargetResults: [target.agentKind: "success"],
                signerKeyId: manifest.signerKeyId
            )
        )
    }

    private func recordSuccessEvents(
        for skill: RemoteSkill,
        version: String?,
        results: [AgentKind: RemoteSkillInstallResult],
        manifest: RemoteArtifactManifest
    ) async {
        for (agent, result) in results {
            let eventType = eventTypeForInstall(slug: skill.slug, version: version, targetRoot: result.skillDirectory.deletingLastPathComponent())
            await recordLedgerEvent(
                LedgerEventInput(
                    eventType: eventType,
                    skillName: skill.displayName,
                    skillSlug: skill.slug,
                    version: version,
                    agent: agent,
                    status: .success,
                    note: "Installed via multi-target",
                    source: "remote",
                    verification: result.verification,
                    manifestSHA256: manifest.sha256,
                    targetPath: result.skillDirectory.path,
                    targets: Array(results.keys),
                    perTargetResults: results.reduce(into: [AgentKind: String]()) { dict, item in
                        dict[item.key] = "success"
                    },
                    signerKeyId: manifest.signerKeyId
                )
            )
        }
    }

    private func recordFailureEvents(
        for skill: RemoteSkill,
        version: String?,
        failures: [AgentKind: String],
        message: String? = nil
    ) async {
        if failures.isEmpty {
            await recordLedgerEvent(
                LedgerEventInput(
                    eventType: .install,
                    skillName: skill.displayName,
                    skillSlug: skill.slug,
                    version: version,
                    agent: nil,
                    status: .failure,
                    note: message,
                    source: "remote"
                )
            )
            return
        }
        for (agent, error) in failures {
            await recordLedgerEvent(
                LedgerEventInput(
                    eventType: .install,
                    skillName: skill.displayName,
                    skillSlug: skill.slug,
                    version: version,
                    agent: agent,
                    status: .failure,
                    note: error,
                    source: "remote",
                    targets: [agent],
                    perTargetResults: [agent: "failure"]
                )
            )
        }
    }

    private func recordLedgerEvent(_ input: LedgerEventInput) async {
        guard let ledger else { return }
        do {
            _ = try await ledger.record(input)
        } catch {
            // Ledger failures should not block installs.
        }
    }

    private func recordVerifyIfAvailable(skill: RemoteSkill) async {
        guard let manifest = previewStateBySlug[skill.slug]?.manifest else { return }
        await recordLedgerEvent(
            LedgerEventInput(
                eventType: .verify,
                skillName: skill.displayName,
                skillSlug: skill.slug,
                version: skill.latestVersion,
                agent: nil,
                status: .success,
                note: "Verified via preview",
                source: "remote",
                verification: .strict,
                manifestSHA256: manifest.sha256,
                signerKeyId: manifest.signerKeyId
            )
        )
    }

    private func fetchManifestCached(slug: String, version: String?) async throws -> RemoteArtifactManifest? {
        if let cached = previewCache.loadManifest(slug: slug, version: version) {
            return cached.manifest
        }
        let manifest = try await client.fetchManifest(slug, version)
        if let manifest {
            previewCache.storeManifest(slug: slug, version: version, manifest: manifest, etag: nil)
        }
        return manifest
    }

    private func eventTypeForInstall(slug: String, version: String?, targetRoot: URL) -> LedgerEventType {
        let existing = existingVersion(slug: slug, root: targetRoot)
        guard let existing, let version, existing != version else { return .install }
        return .update
    }

    private func existingVersion(slug: String, root: URL) -> String? {
        let skillRoot = root.appendingPathComponent(slug, isDirectory: true)
        let skillFile = skillRoot.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else { return nil }
        guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let fm = FrontmatterParser.parseTopBlock(text)
        return fm["version"]
    }

    private func refreshKeysetIfConfigured() async {
        guard let rootKey = ProcessInfo.processInfo.environment["STOOLS_KEYSET_ROOT_KEY"],
              !rootKey.isEmpty else { return }
        do {
            guard let keyset = try await client.fetchKeyset() else { return }
            if keyset.isExpired() {
                errorMessage = "Remote keyset expired; using existing trust store."
                return
            }
            guard keyset.verifySignature(rootPublicKeyBase64: rootKey) else {
                errorMessage = "Remote keyset signature verification failed."
                return
            }
            keysetUpdater(keyset)
        } catch {
            errorMessage = "Failed to refresh keyset: \(error.localizedDescription)"
        }
    }
}

struct RemotePreviewState: Sendable {
    enum Status: String, Sendable { case idle, loading, available, unavailable, failed }
    var status: Status
    var preview: RemoteSkillPreview?
    var manifest: RemoteArtifactManifest?
    var error: String?

    static func loading() -> RemotePreviewState { .init(status: .loading, preview: nil, manifest: nil, error: nil) }
    static func available(preview: RemoteSkillPreview, manifest: RemoteArtifactManifest?) -> RemotePreviewState {
        .init(status: .available, preview: preview, manifest: manifest, error: nil)
    }
    static func unavailable(manifest: RemoteArtifactManifest?) -> RemotePreviewState {
        .init(status: .unavailable, preview: nil, manifest: manifest, error: nil)
    }
    static func failed(_ message: String) -> RemotePreviewState {
        .init(status: .failed, preview: nil, manifest: nil, error: message)
    }
}

enum RemoteProvenanceStatus: String, Sendable {
    case verified
    case unknown
    case failed
}

struct BulkOperationProgress: Sendable {
    enum Operation: String, Sendable {
        case verifyAll = "Verify All"
        case updateAllVerified = "Update All Verified"
    }

    var operation: Operation
    var total: Int
    var completed: Int
    var failures: [String: String]

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var hasFailures: Bool {
        !failures.isEmpty
    }

    var failureSummary: String {
        let count = failures.count
        if count == 0 { return "" }
        if count == 1 { return "1 failure" }
        return "\(count) failures"
    }
}
