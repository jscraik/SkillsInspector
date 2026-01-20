import CryptoKit
import Foundation

/// Signed keyset payload for trusted signer distribution.
public struct RemoteKeyset: Codable, Sendable {
    public let keys: [RemoteTrustStore.TrustedKey]
    public let revokedKeyIds: [String]
    public let expiresAt: Date?
    public let signature: String?
    public let signatureAlgorithm: String?
    public let signedAt: Date?
    public let keysetVersion: Int?

    enum CodingKeys: String, CodingKey {
        case keys
        case revokedKeyIds
        case expiresAt
        case signature
        case signatureAlgorithm
        case signedAt
        case keysetVersion
    }

    public init(
        keys: [RemoteTrustStore.TrustedKey],
        revokedKeyIds: [String],
        expiresAt: Date? = nil,
        signature: String? = nil,
        signatureAlgorithm: String? = nil,
        signedAt: Date? = nil,
        keysetVersion: Int? = nil
    ) {
        self.keys = keys
        self.revokedKeyIds = revokedKeyIds
        self.expiresAt = expiresAt
        self.signature = signature
        self.signatureAlgorithm = signatureAlgorithm
        self.signedAt = signedAt
        self.keysetVersion = keysetVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = try container.decode([RemoteTrustStore.TrustedKey].self, forKey: .keys)
        revokedKeyIds = try container.decodeIfPresent([String].self, forKey: .revokedKeyIds) ?? []
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        signatureAlgorithm = try container.decodeIfPresent(String.self, forKey: .signatureAlgorithm)
        signedAt = try container.decodeIfPresent(Date.self, forKey: .signedAt)
        keysetVersion = try container.decodeIfPresent(Int.self, forKey: .keysetVersion)
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return date >= expiresAt
    }

    public func verifySignature(rootPublicKeyBase64: String) -> Bool {
        guard let signature, let signatureData = Data(base64Encoded: signature) else { return false }
        guard let keyData = Data(base64Encoded: rootPublicKeyBase64) else { return false }
        guard let payloadData = signaturePayloadData() else { return false }
        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else { return false }
        return publicKey.isValidSignature(signatureData, for: payloadData)
    }

    private func signaturePayloadData() -> Data? {
        let payload = SignedPayload(
            keys: keys,
            revokedKeyIds: revokedKeyIds,
            expiresAt: expiresAt,
            signedAt: signedAt,
            keysetVersion: keysetVersion
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    private struct SignedPayload: Codable {
        let keys: [RemoteTrustStore.TrustedKey]
        let revokedKeyIds: [String]
        let expiresAt: Date?
        let signedAt: Date?
        let keysetVersion: Int?
    }
}
