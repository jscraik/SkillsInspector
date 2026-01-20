import CryptoKit
import Foundation
import Security

public struct ChangelogSigner {
    private let keyStoreURL: URL
    private let useKeychain: Bool
    private let keychainService = "com.stools.changelog-signing-key"
    private let keychainAccount = "default"

    public init(keyStoreURL: URL? = nil) {
        if let keyStoreURL {
            self.keyStoreURL = keyStoreURL
            self.useKeychain = false
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let supportDir = (base ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("SkillsInspector", isDirectory: true)
            self.keyStoreURL = supportDir.appendingPathComponent("changelog-signing-key.json")
            self.useKeychain = true
        }
    }

    public func sign(markdown: String) throws -> SignedChangelog {
        let key = try loadOrCreateKey()
        let data = Data(markdown.utf8)
        let signature = try key.privateKey.signature(for: data).base64EncodedString()
        let publicKey = key.privateKey.publicKey.rawRepresentation.base64EncodedString()
        let keyId = Self.keyId(for: key.privateKey.publicKey.rawRepresentation)
        let signedAt = ISO8601DateFormatter().string(from: Date())

        let metadata = SignatureMetadata(
            keyId: keyId,
            publicKeyBase64: publicKey,
            signature: signature,
            signatureAlgorithm: "ed25519",
            signedAt: signedAt
        )
        return SignedChangelog(markdown: markdown, metadata: metadata)
    }

    private func loadOrCreateKey() throws -> SigningKey {
        if let key = try? loadKey() { return key }
        let newKey = SigningKey(privateKey: Curve25519.Signing.PrivateKey())
        try saveKey(newKey)
        return newKey
    }

    private func loadKey() throws -> SigningKey {
        if useKeychain, let key = try loadKeyFromKeychain() {
            return key
        }
        let data = try Data(contentsOf: keyStoreURL)
        let payload = try JSONDecoder().decode(KeyPayload.self, from: data)
        guard let keyData = Data(base64Encoded: payload.privateKeyBase64) else {
            throw ChangelogSigningError.invalidKey
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        return SigningKey(privateKey: privateKey)
    }

    private func saveKey(_ key: SigningKey) throws {
        if useKeychain {
            try saveKeyToKeychain(key)
            return
        }
        try FileManager.default.createDirectory(at: keyStoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let payload = KeyPayload(privateKeyBase64: key.privateKey.rawRepresentation.base64EncodedString())
        let data = try JSONEncoder().encode(payload)
        try data.write(to: keyStoreURL, options: [.atomic])
    }

    private func loadKeyFromKeychain() throws -> SigningKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw ChangelogSigningError.keychainReadFailed(status)
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        return SigningKey(privateKey: privateKey)
    }

    private func saveKeyToKeychain(_ key: SigningKey) throws {
        let keyData = key.privateKey.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status: OSStatus
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var createQuery = query
            createQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(createQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw ChangelogSigningError.keychainWriteFailed(status)
        }
    }

    private static func keyId(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
    }

    public struct SignedChangelog: Sendable {
        public let markdown: String
        public let metadata: SignatureMetadata

        public func renderSignedMarkdown() -> String {
            var lines: [String] = []
            lines.append(markdown.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
            lines.append("<!-- SIGNED-CHANGELOG")
            lines.append("key_id: \(metadata.keyId)")
            lines.append("public_key_base64: \(metadata.publicKeyBase64)")
            lines.append("signature: \(metadata.signature)")
            lines.append("signature_algorithm: \(metadata.signatureAlgorithm)")
            lines.append("signed_at: \(metadata.signedAt)")
            lines.append("-->")
            return lines.joined(separator: "\n")
        }
    }

    public struct SignatureMetadata: Codable, Sendable {
        public let keyId: String
        public let publicKeyBase64: String
        public let signature: String
        public let signatureAlgorithm: String
        public let signedAt: String
    }

    public struct SigningKey: Sendable {
        public let privateKey: Curve25519.Signing.PrivateKey
    }

    private struct KeyPayload: Codable {
        let privateKeyBase64: String
    }

    private enum ChangelogSigningError: Error {
        case invalidKey
        case keychainReadFailed(OSStatus)
        case keychainWriteFailed(OSStatus)
    }
}
