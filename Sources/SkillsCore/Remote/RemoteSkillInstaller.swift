import Foundation
import CryptoKit

/// Errors during remote skill installation.
public enum RemoteInstallError: LocalizedError {
    case archiveUnreadable
    case unzipFailed(Int32)
    case missingSkill
    case multipleSkillsFound
    case validationFailed(String)
    case destinationExists(URL)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .archiveUnreadable: return "Downloaded archive is unreadable."
        case .unzipFailed(let code): return "Failed to unzip archive (exit \(code))."
        case .missingSkill: return "No SKILL.md found in archive."
        case .multipleSkillsFound: return "Multiple skill roots detected; expected one."
        case .validationFailed(let reason): return "Validation failed: \(reason)"
        case .destinationExists(let url): return "Destination already exists: \(url.path)"
        case .ioFailure(let reason): return "I/O failure: \(reason)"
        }
    }
}

/// Installs a downloaded remote skill archive into a target root with validation and rollback.
public struct RemoteSkillInstaller: Sendable {
    public init() {}

    /// Install a downloaded archive (.zip) into the given target.
    /// - Parameters:
    ///   - archiveURL: local URL to the downloaded archive (zip)
    ///   - target: installation root
    ///   - overwrite: whether to replace existing skill dir
    /// - Returns: install result with destination and counts
    public func install(
        archiveURL: URL,
        target: SkillInstallTarget,
        overwrite: Bool = false,
        agent: AgentKind? = nil
    ) async throws -> RemoteSkillInstallResult {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw RemoteInstallError.archiveUnreadable
        }

        // 1) Extract to a temp directory
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("skill-install-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try unzip(archiveURL: archiveURL, destination: tempRoot)

        // 2) Locate skill root (expect exactly one directory containing SKILL.md)
        let skillRoot = try findSkillRoot(in: tempRoot)

        // 3) Validate SKILL.md presence and readability
        let skillFile = skillRoot.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFile.path) else {
            throw RemoteInstallError.missingSkill
        }
        _ = try String(contentsOf: skillFile, encoding: .utf8) // readability check

        // Validate with existing rules (agent inferred from target unless supplied)
        let inferredAgent: AgentKind = {
            switch target {
            case .codex: return .codex
            case .claude: return .claude
            case .custom: return agent ?? .codex
            }
        }()
        if let doc = SkillLoader.load(agent: inferredAgent, rootURL: target.root, skillFileURL: skillFile) {
            let findings = SkillValidator.validate(doc: doc, policy: nil)
            if let blocking = findings.first(where: { $0.severity == .error }) {
                throw RemoteInstallError.validationFailed(blocking.message)
            }
        }

        // 4) Prepare destination (atomic move with rollback)
        let destination = target.root.appendingPathComponent(skillRoot.lastPathComponent, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) && !overwrite {
            throw RemoteInstallError.destinationExists(destination)
        }

        // Stage path for atomic replace
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: staging.path) {
            try FileManager.default.removeItem(at: staging)
        }
        try FileManager.default.moveItem(at: skillRoot, to: staging)

        // Ensure parent exists
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Replace atomically, backing up existing dir if overwrite
        var backupURL: URL?
        if FileManager.default.fileExists(atPath: destination.path) {
            backupURL = destination.deletingLastPathComponent().appendingPathComponent(".backup-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.moveItem(at: destination, to: backupURL!)
        }

        do {
            try FileManager.default.moveItem(at: staging, to: destination)
        } catch {
            // rollback
            if let backupURL {
                try? FileManager.default.moveItem(at: backupURL, to: destination)
            }
            throw RemoteInstallError.ioFailure(error.localizedDescription)
        }

        // Cleanup staging/backup
        try? backupURL.map { try FileManager.default.removeItem(at: $0) }
        try? FileManager.default.removeItem(at: tempRoot)

        // 5) Compute bytes count and checksums
        let totalBytes = (try? Self.directoryByteSize(at: destination)) ?? 0
        let checksum = try? Self.sha256Hex(of: archiveURL)
        let contentChecksum = try? Self.contentSHA256(at: destination)
        return RemoteSkillInstallResult(
            skillDirectory: destination,
            filesCopied: Self.fileCount(at: destination),
            totalBytes: totalBytes,
            archiveSHA256: checksum,
            contentSHA256: contentChecksum
        )
    }

    // MARK: - Helpers

    private func unzip(archiveURL: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qo", archiveURL.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RemoteInstallError.unzipFailed(process.terminationStatus)
        }
    }

    private func findSkillRoot(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        let dirs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        if dirs.count != 1 {
            throw dirs.isEmpty ? RemoteInstallError.missingSkill : RemoteInstallError.multipleSkillsFound
        }
        return dirs[0]
    }

    private static func directoryByteSize(at url: URL) throws -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey], options: [], errorHandler: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            if values.isDirectory == true { continue }
            if let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                total += Int64(size)
            }
        }
        return total
    }

    private static func fileCount(at url: URL) -> Int {
        let fm = FileManager.default
        let enumerator = fm.enumerator(atPath: url.path)
        var count = 0
        while enumerator?.nextObject() != nil { count += 1 }
        return count
    }

    private static func sha256Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Deterministic hash of extracted contents (paths + bytes) for verification.
    private static func contentSHA256(at root: URL) throws -> String {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil)
        var paths: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }
            paths.append(url)
        }
        paths.sort { $0.path < $1.path }
        var hasher = SHA256()
        for url in paths {
            let relative = url.path.replacingOccurrences(of: root.path, with: "")
            hasher.update(data: Data(relative.utf8))
            hasher.update(data: try Data(contentsOf: url))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
