import SwiftUI
import SkillsCore

/// Container for heavy dependencies with lazy initialization
/// All heavy operations are deferred until first access
@MainActor
class AppDependencies: ObservableObject {
    // Lightweight - creates immediately
    let features: FeatureFlags = FeatureFlags.fromEnvironment()

    // Lazy - created on first access
    private var _ledger: SkillLedger?
    var ledger: SkillLedger? {
        if _ledger == nil {
            _ledger = try? SkillLedger()
        }
        return _ledger
    }

    // Lazy - created on first access
    private var _telemetry: TelemetryClient?
    var telemetry: TelemetryClient {
        if let telemetry = _telemetry {
            return telemetry
        }
        let telemetryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SkillsInspector", isDirectory: true)
            .appendingPathComponent("telemetry.jsonl")
        let client = features.telemetryOptIn
            ? TelemetryClient.file(url: telemetryURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("telemetry.jsonl"))
            : .noop
        _telemetry = client
        return client
    }

    // Lazy - created on first access
    private var _trustStoreVM: TrustStoreViewModel?
    var trustStoreVM: TrustStoreViewModel {
        if let vm = _trustStoreVM {
            return vm
        }
        let vm = TrustStoreViewModel()
        _trustStoreVM = vm
        return vm
    }

    // Lazy ViewModels - created only when accessed
    private var _remoteVM: RemoteViewModel?
    func makeRemoteViewModel() -> RemoteViewModel {
        if let vm = _remoteVM {
            return vm
        }
        let vm = RemoteViewModel(
            client: RemoteSkillClient.live(),
            ledger: ledger,
            telemetry: telemetry,
            features: features,
            trustStoreProvider: { [weak self] in self?.trustStoreVM.trustStore ?? RemoteTrustStore() }
        )
        _remoteVM = vm
        return vm
    }

    private var _changelogVM: ChangelogViewModel?
    func makeChangelogViewModel() -> ChangelogViewModel {
        if let vm = _changelogVM {
            return vm
        }
        let vm = ChangelogViewModel(ledger: ledger)
        _changelogVM = vm
        return vm
    }
}
