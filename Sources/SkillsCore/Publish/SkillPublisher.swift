import Foundation
import CryptoKit

public struct SkillPublisher: Sendable {
    public struct PublishOutput: Sendable {
        public let artifactURL: URL
        public let artifactSHA256: String
        public let attestationURL: URL
        public let attestation: PublishAttestation
    }

    public struct ToolConfig: Sendable {
        public let toolPath: URL
        public let toolName: String
        public let expectedSHA256: String?
        public let expectedSHA512: String?
        public let arguments: [String]

        public init(
            toolPath: URL,
            toolName: String,
            expectedSHA256: String? = nil,
            expectedSHA512: String? = nil,
            arguments: [String] = []
        ) {
            self.toolPath = toolPath
            self.toolName = toolName
            self.expectedSHA256 = expectedSHA256
            self.expectedSHA512 = expectedSHA512
            self.arguments = arguments
        }
    }

    public struct SigningKey: Sendable {
        public let privateKey: Curve25519.Signing.PrivateKey

        public init(privateKey: Curve25519.Signing.PrivateKey) {
            self.privateKey = privateKey
        }

        public static func fromBase64(_ base64: String) throws -> SigningKey {
            guard let data = Data(base64Encoded: base64) else {
                throw PublishError.invalidSigningKey
            }
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
            return SigningKey(privateKey: key)
        }
    }

    public enum PublishError: LocalizedError {
        case invalidTool
        case toolHashMismatch
        case invalidSigningKey
        case missingSigningKey
        case zipFailed(Int32)
        case toolInvocationFailed(Int32)
        case ioFailure(String)

        public var errorDescription: String? {
            switch self {
            case .invalidTool:
                return "Publish tool not found or unreadable."
            case .toolHashMismatch:
                return "Publish tool hash mismatch."
            case .invalidSigningKey:
                return "Signing key is invalid."
            case .missingSigningKey:
                return "Signing key required for attestation."
            case .zipFailed(let code):
                return "Failed to build zip artifact (exit \(code))."
            case .toolInvocationFailed(let code):
                return "Publish tool failed (exit \(code))."
            case .ioFailure(let reason):
                return "I/O failure: \(reason)"
            }
        }
    }

    public init() {}

    public func buildAndPublish(
        skillDirectory: URL,
        outputURL: URL,
        attestationURL: URL,
        tool: ToolConfig,
        signingKey: SigningKey
    ) throws -> PublishOutput {
        try validateTool(tool)
        try buildDeterministicZip(skillDirectory: skillDirectory, outputURL: outputURL)
        let artifactSHA256 = try sha256Hex(of: outputURL)
        let attestation = try signAttestation(
            skillDirectory: skillDirectory,
            artifactSHA256: artifactSHA256,
            tool: tool,
            signingKey: signingKey
        )
        try writeAttestation(attestation, to: attestationURL)
        try runTool(tool, artifactURL: outputURL, attestationURL: attestationURL)

        return PublishOutput(
            artifactURL: outputURL,
            artifactSHA256: artifactSHA256,
            attestationURL: attestationURL,
            attestation: attestation
        )
    }

    public func buildOnly(
        skillDirectory: URL,
        outputURL: URL,
        attestationURL: URL,
        tool: ToolConfig,
        signingKey: SigningKey
    ) throws -> PublishOutput {
        try validateTool(tool)
        try buildDeterministicZip(skillDirectory: skillDirectory, outputURL: outputURL)
        let artifactSHA256 = try sha256Hex(of: outputURL)
        let attestation = try signAttestation(
            skillDirectory: skillDirectory,
            artifactSHA256: artifactSHA256,
            tool: tool,
            signingKey: signingKey
        )
        try writeAttestation(attestation, to: attestationURL)

        return PublishOutput(
            artifactURL: outputURL,
            artifactSHA256: artifactSHA256,
            attestationURL: attestationURL,
            attestation: attestation
        )
    }

    private func validateTool(_ tool: ToolConfig) throws {
        guard FileManager.default.isReadableFile(atPath: tool.toolPath.path) else {
            throw PublishError.invalidTool
        }
        let toolSHA256 = try sha256Hex(of: tool.toolPath)
        if let expected = tool.expectedSHA256, expected.lowercased() != toolSHA256.lowercased() {
            throw PublishError.toolHashMismatch
        }
        if let expected512 = tool.expectedSHA512, try expected512.lowercased() != sha512Hex(of: tool.toolPath).lowercased() {
            throw PublishError.toolHashMismatch
        }
    }

    private func buildDeterministicZip(skillDirectory: URL, outputURL: URL) throws {
        let parent = skillDirectory.deletingLastPathComponent()
        let rootName = skillDirectory.lastPathComponent
        let fileList = try enumerateFiles(root: skillDirectory)
        let relative = fileList.map { rootName + "/" + $0 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = parent
        process.arguments = ["-X", "-q", "-@", outputURL.path]

        let input = Pipe()
        process.standardInput = input
        try process.run()
        let joined = relative.joined(separator: "\n") + "\n"
        if let data = joined.data(using: .utf8) {
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PublishError.zipFailed(process.terminationStatus)
        }
    }

    private func enumerateFiles(root: URL) throws -> [String] {
        let fm = FileManager.default
        let resolvedRoot = root.resolvingSymlinksInPath()
        let enumerator = fm.enumerator(at: resolvedRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil)
        var files: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            let resolvedURL = url.resolvingSymlinksInPath()
            if (try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }
            let rootPrefix = resolvedRoot.path + "/"
            guard resolvedURL.path.hasPrefix(rootPrefix) else { continue }
            let relative = resolvedURL.path.replacingOccurrences(of: rootPrefix, with: "")
            files.append(relative)
        }
        return files.sorted()
    }

    private func signAttestation(
        skillDirectory: URL,
        artifactSHA256: String,
        tool: ToolConfig,
        signingKey: SigningKey
    ) throws -> PublishAttestation {
        let skillName = skillDirectory.lastPathComponent
        let version = readSkillVersion(skillDirectory)
        let payload = PublishAttestationPayload(
            skillName: skillName,
            version: version,
            artifactSHA256: artifactSHA256,
            toolName: tool.toolName,
            toolHash: try sha256Hex(of: tool.toolPath),
            builtAt: ISO8601DateFormatter().string(from: Date())
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let signature = try signingKey.privateKey.signature(for: data).base64EncodedString()
        return PublishAttestation(
            skillName: payload.skillName,
            version: payload.version,
            artifactSHA256: payload.artifactSHA256,
            toolName: payload.toolName,
            toolHash: payload.toolHash,
            builtAt: payload.builtAt,
            signatureAlgorithm: "ed25519",
            signature: signature
        )
    }

    private func writeAttestation(_ attestation: PublishAttestation, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(attestation)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw PublishError.ioFailure(error.localizedDescription)
        }
    }

    private func runTool(_ tool: ToolConfig, artifactURL: URL, attestationURL: URL) throws {
        let process = Process()
        process.executableURL = tool.toolPath
        process.arguments = tool.arguments.map {
            $0.replacingOccurrences(of: "{artifact}", with: artifactURL.path)
                .replacingOccurrences(of: "{attestation}", with: attestationURL.path)
        }
        var env = ProcessInfo.processInfo.environment
        env["STOOLS_ARTIFACT_PATH"] = artifactURL.path
        env["STOOLS_ATTESTATION_PATH"] = attestationURL.path
        process.environment = env
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PublishError.toolInvocationFailed(process.terminationStatus)
        }
    }

    public func sha256Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    internal func sha512Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA512.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func readSkillVersion(_ skillDirectory: URL) -> String? {
        let skillFile = skillDirectory.appendingPathComponent("SKILL.md")
        guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let frontmatter = FrontmatterParser.parseTopBlock(text)
        return frontmatter["version"]
    }
}

/// Default pinned tool configuration for clawdhub@0.1.0
/// This is the officially supported version for reproducible publishing.
public struct PinnedTool: Sendable {
    /// The pinned version of clawdhub
    public static let version = "0.1.0"

    /// The SHA-512 integrity hash for clawdhub@0.1.0
    /// This is an SRI-style hash that ensures the exact tool binary is used.
    public static let integritySHA512 = "LZ0mRf61F5SjgprrMwgyLRqMOKxC5sQZYF1tZGgZCawiaVfb79A8cp0Fl32/JNRqiRI7TB0/EuPJPMJ4evmK0g=="

    /// The expected tool name
    public static let toolName = "clawdhub"

    /// Creates a ToolConfig with the pinned tool configuration
    /// - Parameter toolPath: Path to the clawdhub binary
    /// - Returns: A ToolConfig with the pinned version and integrity hash
    public static func toolConfig(toolPath: URL) -> SkillPublisher.ToolConfig {
        SkillPublisher.ToolConfig(
            toolPath: toolPath,
            toolName: toolName,
            expectedSHA256: nil,
            expectedSHA512: integritySHA512,
            arguments: ["publish", "--artifact", "{artifact}", "--attestation", "{attestation}"]
        )
    }
}
