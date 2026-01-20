import Foundation
import CryptoKit
import UniformTypeIdentifiers

/// Errors during remote skill installation.
public enum RemoteInstallError: LocalizedError {
    case archiveUnreadable
    case unzipFailed(Int32)
    case missingSkill
    case multipleSkillsFound
    case validationFailed(String)
    case destinationExists(URL)
    case ioFailure(String)
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .archiveUnreadable: return "Downloaded archive is unreadable."
        case .unzipFailed(let code): return "Failed to unzip archive (exit \(code))."
        case .missingSkill: return "No SKILL.md found in archive."
        case .multipleSkillsFound: return "Multiple skill roots detected; expected one."
        case .validationFailed(let reason): return "Validation failed: \(reason)"
        case .destinationExists(let url): return "Destination already exists: \(url.path)"
        case .ioFailure(let reason): return "I/O failure: \(reason)"
        case .verificationFailed(let reason): return "Verification failed: \(reason)"
        }
    }
}

/// Installs a downloaded remote skill archive into a target root with validation and rollback.
public struct RemoteSkillInstaller: Sendable {
    public init() {}

    /// Verify a downloaded archive against a manifest and trust store without installing it.
    public func verify(
        archiveURL: URL,
        manifest: RemoteArtifactManifest?,
        policy: RemoteVerificationPolicy = .default,
        trustStore: RemoteTrustStore = .ephemeral,
        skillSlug: String? = nil
    ) throws -> RemoteVerificationOutcome {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw RemoteInstallError.archiveUnreadable
        }
        let outcome = try evaluateVerification(archiveURL: archiveURL, manifest: manifest, policy: policy, trustStore: trustStore, skillSlug: skillSlug)
        if policy.mode == .strict, !outcome.issues.isEmpty {
            throw RemoteInstallError.verificationFailed(outcome.issues.joined(separator: "; "))
        }
        return outcome
    }

    /// Install a downloaded archive (.zip) into the given target.
    /// - Parameters:
    ///   - archiveURL: local URL to the downloaded archive (zip)
    ///   - target: installation root
    ///   - overwrite: whether to replace existing skill dir
    ///   - manifest: optional manifest containing checksums/signature
    ///   - policy: verification strictness and limits
    ///   - trustStore: trusted public keys for signature validation
    /// - Returns: install result with destination and counts
    public func install(
        archiveURL: URL,
        target: SkillInstallTarget,
        overwrite: Bool = false,
        agent: AgentKind? = nil,
        manifest: RemoteArtifactManifest? = nil,
        policy: RemoteVerificationPolicy = .default,
        trustStore: RemoteTrustStore = .ephemeral,
        skillSlug: String? = nil,
        securityConfig: SecurityConfig = .default,
        acipScanner: ACIPScanner = ACIPScanner(),
        quarantineStore: QuarantineStore = QuarantineStore(),
        preserveBackup: Bool = false
    ) async throws -> RemoteSkillInstallResult {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw RemoteInstallError.archiveUnreadable
        }

        try verifyArchive(archiveURL: archiveURL, manifest: manifest, policy: policy, trustStore: trustStore, skillSlug: skillSlug)

        // 1) Extract to a temp directory
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("skill-install-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try unzip(archiveURL: archiveURL, destination: tempRoot)

        // 2) Locate skill root (expect exactly one directory containing SKILL.md)
        let skillRoot = try findSkillRoot(in: tempRoot)

        // 2a) Enforce extraction limits and block symlinks/absolute paths
        try enforceExtractedLimits(at: skillRoot, limits: policy.limits)

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
            case .copilot: return .copilot
            case .custom: return agent ?? .codex
            }
        }()
        if let doc = SkillLoader.load(agent: inferredAgent, rootURL: target.root, skillFileURL: skillFile) {
            let findings = SkillValidator.validate(doc: doc, policy: nil)
            if let blocking = findings.first(where: { $0.severity == .error }) {
                throw RemoteInstallError.validationFailed(blocking.message)
            }
        }

        // 3b) Security scan (ACIP) before install
        try await enforceSecurityScan(
            at: skillRoot,
            skillSlug: skillSlug ?? skillRoot.lastPathComponent,
            archiveURL: archiveURL,
            securityConfig: securityConfig,
            acipScanner: acipScanner,
            quarantineStore: quarantineStore
        )

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
        if !preserveBackup {
            try? backupURL.map { try FileManager.default.removeItem(at: $0) }
            backupURL = nil
        }
        try? FileManager.default.removeItem(at: tempRoot)

        // 5) Compute bytes count and checksums
        let totalBytes = (try? Self.directoryByteSize(at: destination)) ?? 0
        let checksum = try? Self.sha256Hex(of: archiveURL)
        let contentChecksum = try? Self.contentSHA256(at: destination)
        return RemoteSkillInstallResult(
            verification: policy.mode,
            skillDirectory: destination,
            filesCopied: Self.fileCount(at: destination),
            totalBytes: totalBytes,
            archiveSHA256: checksum,
            contentSHA256: contentChecksum,
            backupURL: backupURL
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
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        let dirs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        let candidates = dirs.filter { dir in
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("SKILL.md").path)
        }
        if candidates.count != 1 {
            if candidates.isEmpty { throw RemoteInstallError.missingSkill }
            throw RemoteInstallError.multipleSkillsFound
        }
        return candidates[0]
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

    public static func sha256Hex(of fileURL: URL) throws -> String {
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

    // MARK: - Verification

    private func verifyArchive(
        archiveURL: URL,
        manifest: RemoteArtifactManifest?,
        policy: RemoteVerificationPolicy,
        trustStore: RemoteTrustStore,
        skillSlug: String?
    ) throws {
        try enforceMIMEType(archiveURL: archiveURL, limits: policy.limits)
        let outcome = try evaluateVerification(archiveURL: archiveURL, manifest: manifest, policy: policy, trustStore: trustStore, skillSlug: skillSlug)
        if policy.mode == .strict, !outcome.issues.isEmpty {
            throw RemoteInstallError.verificationFailed(outcome.issues.joined(separator: "; "))
        }
    }

    private func evaluateVerification(
        archiveURL: URL,
        manifest: RemoteArtifactManifest?,
        policy: RemoteVerificationPolicy,
        trustStore: RemoteTrustStore,
        skillSlug: String?
    ) throws -> RemoteVerificationOutcome {
        let attrs = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        if let size = attrs[.size] as? NSNumber, size.int64Value > policy.limits.maxArchiveBytes {
            throw RemoteInstallError.verificationFailed("Archive exceeds size limit")
        }

        var issues: [String] = []
        var checksumValidated = false
        var signatureValidated = false
        var trustedSigner = false

        guard let manifest else {
            issues.append("Manifest missing")
            return RemoteVerificationOutcome(
                mode: policy.mode,
                checksumValidated: false,
                signatureValidated: false,
                trustedSigner: false,
                issues: issues
            )
        }

        if let expectedSize = manifest.size, let actualSize = attrs[.size] as? NSNumber, expectedSize != actualSize.int64Value {
            throw RemoteInstallError.verificationFailed("Archive size mismatch")
        }

        let digest = try Self.sha256Hex(of: archiveURL)
        if digest.lowercased() != manifest.sha256.lowercased() {
            throw RemoteInstallError.verificationFailed("Checksum mismatch")
        }
        checksumValidated = true

        if let signature = manifest.signature, let keyId = manifest.signerKeyId {
            let ok = (try? trustStore.verifySignature(hexDigest: digest, signatureBase64: signature, keyId: keyId, scopeSlug: skillSlug)) ?? false
            signatureValidated = ok
            if !ok {
                issues.append("Signature invalid for key \(keyId)")
            }
        } else {
            issues.append("Signature missing")
        }

        if let allowed = manifest.trustedSigners, let keyId = manifest.signerKeyId {
            if !allowed.contains(keyId) {
                throw RemoteInstallError.verificationFailed("Signer not in trustedSigners")
            }
        }
        if let revoked = manifest.revokedKeys, let keyId = manifest.signerKeyId, revoked.contains(keyId) {
            throw RemoteInstallError.verificationFailed("Signer is revoked")
        }

        if let keyId = manifest.signerKeyId {
            trustedSigner = trustStore.trustedKey(for: keyId, scopeSlug: skillSlug) != nil
            if !trustedSigner {
                issues.append("Signer not trusted locally")
            }
        }

        return RemoteVerificationOutcome(
            mode: policy.mode,
            checksumValidated: checksumValidated,
            signatureValidated: signatureValidated,
            trustedSigner: trustedSigner,
            issues: issues
        )
    }

    private func enforceExtractedLimits(at root: URL, limits: RemoteVerificationLimits) throws {
        let stats = try Self.directoryStats(at: root)
        if stats.totalBytes > limits.maxExtractedBytes {
            throw RemoteInstallError.verificationFailed("Extracted content exceeds size limit")
        }
        if stats.fileCount > limits.maxFileCount {
            throw RemoteInstallError.verificationFailed("Extracted content exceeds file-count limit")
        }
        if !stats.symlinks.isEmpty {
            throw RemoteInstallError.verificationFailed("Symlinks are not allowed: \(stats.symlinks.prefix(3))")
        }
    }

    private static func directoryStats(at root: URL) throws -> (fileCount: Int, totalBytes: Int64, symlinks: [String]) {
        var count = 0
        var bytes: Int64 = 0
        var symlinks: [String] = []
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey], options: [], errorHandler: nil)
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey])
            if values.isDirectory == true { continue }
            count += 1
            if let size = values.fileAllocatedSize { bytes += Int64(size) }
            if values.isSymbolicLink == true {
                symlinks.append(url.lastPathComponent)
            }
        }
        return (count, bytes, symlinks)
    }

    private func enforceMIMEType(archiveURL: URL, limits: RemoteVerificationLimits) throws {
        let ext = archiveURL.pathExtension.lowercased()
        guard !limits.allowedMIMETypes.isEmpty else { return }
        if let type = UTType(filenameExtension: ext),
           let mime = type.preferredMIMEType,
           limits.allowedMIMETypes.contains(mime) {
            return
        }
        throw RemoteInstallError.verificationFailed("Archive MIME type is not allowed")
    }

    private func enforceSecurityScan(
        at skillRoot: URL,
        skillSlug: String,
        archiveURL: URL,
        securityConfig: SecurityConfig,
        acipScanner: ACIPScanner,
        quarantineStore: QuarantineStore
    ) async throws {
        await acipScanner.updateConfig(securityConfig)
        let results = await acipScanner.scanSkill(at: skillRoot, source: .remote)
        for (filePath, result) in results {
            switch result.action {
            case .block(let reason, let match):
                throw RemoteInstallError.validationFailed("ACIP blocked: \(reason) (\(match)) in \(filePath)")
            case .quarantine(let reason, let match, let safeExcerpt):
                _ = await quarantineStore.quarantine(
                    skillName: skillRoot.lastPathComponent,
                    skillSlug: skillSlug,
                    reasons: ["\(reason): \(match)"],
                    safeExcerpt: safeExcerpt,
                    sourceURL: archiveURL
                )
                throw RemoteInstallError.validationFailed("ACIP quarantined: \(reason) (\(match)) in \(filePath)")
            case .allow:
                continue
            }
        }
    }
}
