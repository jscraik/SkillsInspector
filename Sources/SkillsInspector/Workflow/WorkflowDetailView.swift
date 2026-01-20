import SwiftUI
import SkillsCore

/// Detail view for a workflow state showing full information
public struct WorkflowDetailView: View {
    @State private var state: WorkflowState
    let onApprove: ((String, String) async -> Void)?
    let onTransition: ((Stage, String) async -> Void)?

    public init(
        state: WorkflowState,
        onApprove: ((String, String) async -> Void)? = nil,
        onTransition: ((Stage, String) async -> Void)? = nil
    ) {
        self._state = State(initialValue: state)
        self.onApprove = onApprove
        self.onTransition = onTransition
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                headerSection

                Divider()

                // Progress
                progressSection

                Divider()

                // Validation results
                if !state.validationResults.isEmpty {
                    validationSection
                    Divider()
                }

                // Review info
                reviewSection

                Divider()

                // Version history
                historySection

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("Workflow Details")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: state.stage.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(stageColor)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(state.skillSlug)
                        .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))

                    Text(state.stage.displayName)
                        .font(.system(size: DesignTokens.Typography.Body.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                Spacer()

                validationBadge
            }

            Text("Created: \(formatDate(state.createdAt))")
                .font(.system(size: DesignTokens.Typography.BodySmall.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            Text("Updated: \(formatDate(state.updatedAt))")
                .font(.system(size: DesignTokens.Typography.BodySmall.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Workflow Progress")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            WorkflowProgressIndicator(currentStage: state.stage)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Validation Results")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            ForEach(state.validationResults) { result in
                ValidationResultRow(result: result)
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Review Information")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            if let reviewer = state.reviewer {
                detailRow("Reviewer", reviewer)
            }

            if !state.reviewNotes.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Notes")
                        .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)

                    Text(state.reviewNotes)
                        .font(.system(size: DesignTokens.Typography.Body.size))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)
                        .padding(DesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.Colors.Background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                }
            }

            // Actions
            if state.stage.canApprove {
                actionButtons
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Version History")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            ForEach(state.versionHistory.reversed()) { entry in
                VersionHistoryRow(entry: entry)
            }
        }
    }

    @ViewBuilder
    private var validationBadge: some View {
        if state.isValid {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("Valid")
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.Accent.green.opacity(0.15))
            .foregroundStyle(DesignTokens.Colors.Accent.green)
            .clipShape(Capsule())
        } else {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                Text("\(state.errorCount) Error\(state.errorCount == 1 ? "" : "s")")
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.Accent.red.opacity(0.15))
            .foregroundStyle(DesignTokens.Colors.Accent.red)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let onApprove = onApprove {
                Button("Approve") {
                    Task {
                        await onApprove(NSFullUserName(), "Approved via UI")
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let nextStage = state.stage.nextStage, let onTransition = onTransition {
                Button("Move to \(nextStage.displayName)") {
                    Task {
                        await onTransition(nextStage, "Advanced via UI")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var stageColor: Color {
        switch state.stage {
        case .draft: return DesignTokens.Colors.Accent.gray
        case .validating: return DesignTokens.Colors.Accent.orange
        case .reviewed: return DesignTokens.Colors.Accent.blue
        case .approved: return DesignTokens.Colors.Accent.green
        case .published: return DesignTokens.Colors.Accent.purple
        case .archived: return DesignTokens.Colors.Accent.gray
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.primary)

            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ValidationResultRow

private struct ValidationResultRow: View {
    let result: WorkflowValidationError

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: result.severity.isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(result.severity.isError ? DesignTokens.Colors.Accent.red : DesignTokens.Colors.Accent.orange)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(result.code)
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                Text(result.message)
                    .font(.system(size: DesignTokens.Typography.Body.size))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)

                if !result.file.isEmpty {
                    Text(result.file + (result.line.map { ":\($0)" } ?? ""))
                        .font(.system(size: DesignTokens.Typography.Caption.size))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}

// MARK: - VersionHistoryRow

private struct VersionHistoryRow: View {
    let entry: WorkflowState.VersionEntry

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: entry.stage.icon)
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Version \(entry.version)")
                        .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)

                    Text("•")
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)

                    Text(entry.stage.displayName)
                        .font(.system(size: DesignTokens.Typography.Body.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                if !entry.changelog.isEmpty {
                    Text(entry.changelog)
                        .font(.system(size: DesignTokens.Typography.BodySmall.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                Text("by \(entry.changedBy) • \(formatDate(entry.changedAt))")
                    .font(.system(size: DesignTokens.Typography.Caption.size))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }

            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkflowDetailView(
            state: {
                var state = WorkflowState(
                    skillSlug: "example-skill",
                    stage: .reviewed,
                    reviewNotes: "Looks good, ready for approval",
                    reviewer: "senior-dev"
                )
                state.addValidationResult(WorkflowValidationError(
                    code: "WARN001",
                    message: "Consider adding more documentation",
                    severity: .warning,
                    file: "SKILL.md",
                    line: 10
                ))
                return state
            }()
        )
    }
    .frame(width: 600, height: 800)
}
