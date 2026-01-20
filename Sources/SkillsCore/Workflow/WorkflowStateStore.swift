import Foundation

/// Persistent store for workflow states
public actor WorkflowStateStore {
    private var states: [String: WorkflowState] = [:]
    private let storageURL: URL

    private static func defaultStorageURL() -> URL {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupportURL.appendingPathComponent("SkillsInspector", isDirectory: true)

        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        return supportDir.appendingPathComponent("workflow-states.json")
    }

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        // Load deferred to first access
    }

    private func ensureLoaded() {
        if states.isEmpty {
            load()
        }
    }

    /// Create a new workflow state
    public func create(
        skillSlug: String,
        stage: Stage = .draft,
        createdBy: String = "system"
    ) -> WorkflowState {
        ensureLoaded()

        let state = WorkflowState(
            skillSlug: skillSlug,
            stage: stage,
            versionHistory: [
                WorkflowState.VersionEntry(
                    version: "1",
                    stage: stage,
                    changedBy: createdBy,
                    changelog: "Initial workflow state"
                )
            ]
        )

        states[skillSlug] = state
        save()
        return state
    }

    /// Get workflow state for a skill
    public func get(skillSlug: String) -> WorkflowState? {
        ensureLoaded()
        return states[skillSlug]
    }

    /// Update workflow state
    public func update(_ state: WorkflowState) {
        ensureLoaded()
        states[state.skillSlug] = state
        save()
    }

    /// Delete workflow state
    public func delete(skillSlug: String) {
        ensureLoaded()
        states.removeValue(forKey: skillSlug)
        save()
    }

    /// List all workflow states
    public func list() -> [WorkflowState] {
        ensureLoaded()
        return Array(states.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    /// List workflow states filtered by stage
    public func list(stage: Stage) -> [WorkflowState] {
        list().filter { $0.stage == stage }
    }

    /// List workflow states filtered by agent
    public func list(agent: AgentKind) -> [WorkflowState] {
        // Filter by skill slug pattern (simple heuristic)
        let agentPrefixes: [String]
        switch agent {
        case .codex:
            agentPrefixes = [".codex", "/codex"]
        case .claude:
            agentPrefixes = [".claude", "/claude"]
        case .copilot:
            agentPrefixes = [".copilot", "/copilot"]
        default:
            agentPrefixes = []
        }

        return list().filter { state in
            agentPrefixes.contains { state.skillSlug.lowercased().contains($0) }
        }
    }

    /// Clear all workflow states
    public func clear() {
        states.removeAll()
        save()
    }

    private func save() {
        let data = try? JSONEncoder().encode(states)
        try? data?.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: WorkflowState].self, from: data) else {
            return
        }
        states = decoded
    }
}
