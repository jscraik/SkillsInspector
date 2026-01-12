import Foundation
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

    private let client: RemoteSkillClient
    private let installer: RemoteSkillInstaller
    private let targetResolver: () -> SkillInstallTarget

    init(
        client: RemoteSkillClient,
        installer: RemoteSkillInstaller = RemoteSkillInstaller(),
        targetResolver: @escaping () -> SkillInstallTarget = { .codex(PathUtil.urlFromPath("~/.codex/skills")) }
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
        self.targetResolver = targetResolver
    }

    func loadLatest(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await client.fetchLatest(limit)
            skills = result
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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

    func install(slug: String, version: String? = nil) async {
        installingSlug = slug
        defer { installingSlug = nil }
        do {
            let archive = try await client.download(slug, version)
            let result = try await installer.install(archiveURL: archive, target: targetResolver(), overwrite: true)
            installResult = result
            await refreshInstalledVersions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isUpdateAvailable(for skill: RemoteSkill) -> Bool {
        guard let latest = skill.latestVersion else { return false }
        guard let installed = installedVersions[skill.slug] else { return false }
        return installed != latest
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
}
