import SwiftUI
import SkillsCore

/// Dashboard for viewing and managing skill workflows
public struct WorkflowDashboardView: View {
    @State private var workflowStore = WorkflowStateStore()
    @State private var workflows: [WorkflowState] = []
    @State private var selectedStage: Stage?
    @State private var selectedWorkflow: WorkflowState?
    @State private var isLoading = true
    @State private var searchText = ""

    private let stages: [Stage?] = [nil, .draft, .validating, .reviewed, .approved, .published, .archived]

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPanel
        }
        .task {
            await loadWorkflows()
        }
        .navigationTitle("Workflow Dashboard")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Stage picker
            stagePicker

            Divider()

            // Search bar
            searchBar

            Divider()

            // Workflow list
            if isLoading {
                loadingView
            } else if filteredWorkflows.isEmpty {
                emptyState
            } else {
                workflowList
            }
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 400)
    }

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(stages, id: \.self) { stage in
                    let count = countForStage(stage)
                    StageButton(
                        stage: stage,
                        isSelected: selectedStage == stage,
                        count: count
                    ) {
                        selectedStage = stage
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
    }

    private func countForStage(_ stage: Stage?) -> Int {
        if let stage = stage {
            return workflows.filter { $0.stage == stage }.count
        } else {
            return workflows.count
        }
    }

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Colors.Icon.secondary)

            TextField("Search skills...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: DesignTokens.Typography.Body.size))
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .padding(DesignTokens.Spacing.sm)
    }

    private var workflowList: some View {
        List(filteredWorkflows, id: \.id, selection: $selectedWorkflow) { workflow in
            WorkflowRow(state: workflow) {
                selectedWorkflow = workflow
            }
            .tag(workflow.id)
            .contentShape(Rectangle())
        }
        .listStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading workflows...")
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)

            Text("No Workflows")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            Text(selectedStage == nil ? "No workflows found" : "No workflows in \(selectedStage!.displayName) stage")
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let workflow = selectedWorkflow {
                WorkflowDetailView(
                    state: workflow,
                    onApprove: { reviewer, notes in
                        await handleApprove(reviewer: reviewer, notes: notes)
                    },
                    onTransition: { stage, notes in
                        await handleTransition(to: stage, notes: notes)
                    }
                )
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignTokens.Colors.Icon.tertiary)

                    Text("Select a Workflow")
                        .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

                    Text("Choose a workflow to view details and perform actions.")
                        .font(.system(size: DesignTokens.Typography.Body.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredWorkflows: [WorkflowState] {
        var result = workflows

        // Filter by stage
        if let stage = selectedStage {
            result = result.filter { $0.stage == stage }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { workflow in
                workflow.skillSlug.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Actions

    private func loadWorkflows() async {
        isLoading = true
        workflows = await workflowStore.list()
        isLoading = false
    }

    private func handleApprove(reviewer: String, notes: String) async {
        guard let workflow = selectedWorkflow,
              let path = skillPath(for: workflow.skillSlug) else {
            return
        }

        do {
            let coordinator = SkillLifecycleCoordinator()
            let updated = try await coordinator.approve(
                at: path,
                reviewer: reviewer,
                notes: notes
            )
            await updateWorkflow(updated)
        } catch {
            // Handle error
            print("Error approving workflow: \(error)")
        }
    }

    private func handleTransition(to stage: Stage, notes: String) async {
        guard var workflow = selectedWorkflow else { return }

        workflow.transitionTo(stage, by: NSFullUserName(), notes: notes)
        await workflowStore.update(workflow)
        await updateWorkflow(workflow)
    }

    private func updateWorkflow(_ state: WorkflowState) async {
        await workflowStore.update(state)
        await loadWorkflows()
        selectedWorkflow = state
    }

    private func skillPath(for slug: String) -> URL? {
        // Try to find the skill in standard locations
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent(".codex/skills").appendingPathComponent(slug),
            home.appendingPathComponent(".claude/skills").appendingPathComponent(slug),
            home.appendingPathComponent(".copilot/skills").appendingPathComponent(slug)
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        return nil
    }
}

// MARK: - StageButton

private struct StageButton: View {
    let stage: Stage?
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let stage = stage {
                    Image(systemName: stage.icon)
                        .font(.system(size: 12))
                }

                Text(stage?.displayName ?? "All")
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: isSelected ? DesignTokens.Typography.Body.emphasis : DesignTokens.Typography.Body.weight))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: DesignTokens.Typography.Caption.size))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Background.tertiary)
                        .foregroundStyle(isSelected ? .white : DesignTokens.Colors.Text.secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(isSelected ? DesignTokens.Colors.Accent.blue.opacity(0.15) : DesignTokens.Colors.Background.secondary)
            .foregroundStyle(isSelected ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Text.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    WorkflowDashboardView()
        .frame(width: 1000, height: 700)
}
