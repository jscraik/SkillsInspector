import Foundation
import SkillsCore

@MainActor
final class TrustStoreViewModel: ObservableObject {
    @Published private(set) var keys: [RemoteTrustStore.TrustedKey] = []
    @Published private(set) var revokedKeyIds: Set<String> = []
    @Published var errorMessage: String?

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            self.storeURL = (base ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("SkillsInspector", isDirectory: true)
                .appendingPathComponent("trust.json")
        }
        load()
    }

    var trustStore: RemoteTrustStore {
        let allowed = keys.filter { !revokedKeyIds.contains($0.keyId) }
        return RemoteTrustStore(keys: allowed)
    }

    func isTrusted(keyId: String, slug: String?) -> Bool {
        guard let key = keys.first(where: { $0.keyId == keyId }) else { return false }
        if revokedKeyIds.contains(keyId) { return false }
        if let slug, let allowed = key.allowedSlugs, !allowed.contains(slug) {
            return false
        }
        return true
    }

    func addTrustedKey(keyId: String, publicKeyBase64: String, allowedSlugs: [String]? = nil) {
        guard !keyId.isEmpty, !publicKeyBase64.isEmpty else { return }
        if let index = keys.firstIndex(where: { $0.keyId == keyId }) {
            keys[index] = RemoteTrustStore.TrustedKey(keyId: keyId, publicKeyBase64: publicKeyBase64, allowedSlugs: allowedSlugs ?? keys[index].allowedSlugs)
        } else {
            keys.append(RemoteTrustStore.TrustedKey(keyId: keyId, publicKeyBase64: publicKeyBase64, allowedSlugs: allowedSlugs))
        }
        revokedKeyIds.remove(keyId)
        save()
    }

    func revokeKey(keyId: String) {
        revokedKeyIds.insert(keyId)
        save()
    }

    func clearError() {
        errorMessage = nil
    }

    func applyKeyset(_ keyset: RemoteKeyset) {
        var updatedKeys = keys
        for incoming in keyset.keys {
            if let index = updatedKeys.firstIndex(where: { $0.keyId == incoming.keyId }) {
                let allowed = updatedKeys[index].allowedSlugs ?? incoming.allowedSlugs
                updatedKeys[index] = RemoteTrustStore.TrustedKey(
                    keyId: incoming.keyId,
                    publicKeyBase64: incoming.publicKeyBase64,
                    allowedSlugs: allowed
                )
            } else {
                updatedKeys.append(incoming)
            }
        }
        keys = updatedKeys
        revokedKeyIds.formUnion(keyset.revokedKeyIds)
        save()
    }

    func refreshKeyset(client: RemoteSkillClient, rootKeyBase64: String) async {
        do {
            guard let keyset = try await client.fetchKeyset() else { return }
            if keyset.isExpired() {
                errorMessage = "Remote keyset expired; keeping existing trust store."
                return
            }
            guard keyset.verifySignature(rootPublicKeyBase64: rootKeyBase64) else {
                errorMessage = "Remote keyset signature verification failed."
                return
            }
            applyKeyset(keyset)
        } catch {
            errorMessage = "Failed to refresh keyset: \(error.localizedDescription)"
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storeURL)
            let payload = try JSONDecoder().decode(TrustStorePayload.self, from: data)
            keys = payload.keys
            revokedKeyIds = Set(payload.revokedKeyIds)
        } catch {
            // First-run is expected; only surface if file exists but fails to parse.
            if FileManager.default.fileExists(atPath: storeURL.path) {
                errorMessage = "Failed to load trust store: \(error.localizedDescription)"
            }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let payload = TrustStorePayload(keys: keys, revokedKeyIds: Array(revokedKeyIds))
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            errorMessage = "Failed to save trust store: \(error.localizedDescription)"
        }
    }
}

private struct TrustStorePayload: Codable {
    let keys: [RemoteTrustStore.TrustedKey]
    let revokedKeyIds: [String]
}
