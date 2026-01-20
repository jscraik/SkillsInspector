import SwiftUI
import SkillsCore

/// Row component for displaying a workflow in the list
public struct WorkflowRow: View {
    let state: WorkflowState
    let onTap: () -> Void

    public init(state: WorkflowState, onTap: @escaping () -> Void) {
        self.state = state
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Stage icon
                stageIcon

                // Skill info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(state.skillSlug)
                        .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)

                    Text(stageInfo)
                        .font(.system(size: DesignTokens.Typography.BodySmall.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                Spacer()

                // Validation status and progress
                HStack(spacing: DesignTokens.Spacing.sm) {
                    validationSummary

                    WorkflowProgressIndicator(currentStage: state.stage, compact: true)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var stageIcon: some View {
        ZStack {
            Circle()
                .fill(stageColor.opacity(0.15))
                .frame(width: 36, height: 36)

            Image(systemName: state.stage.icon)
                .font(.system(size: 16))
                .foregroundStyle(stageColor)
        }
    }

    private var stageColor: Color {
        switch state.stage {
        case .draft:
            return DesignTokens.Colors.Accent.gray
        case .validating:
            return DesignTokens.Colors.Accent.orange
        case .reviewed:
            return DesignTokens.Colors.Accent.blue
        case .approved:
            return DesignTokens.Colors.Accent.green
        case .published:
            return DesignTokens.Colors.Accent.purple
        case .archived:
            return DesignTokens.Colors.Accent.gray
        }
    }

    private var stageInfo: String {
        if state.isValid {
            return state.stage.displayName
        } else {
            return "\(state.stage.displayName) • \(state.errorCount) error\(state.errorCount == 1 ? "" : "s")"
        }
    }

    @ViewBuilder
    private var validationSummary: some View {
        if !state.isValid {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                if state.errorCount > 0 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.Accent.red)

                    Text("\(state.errorCount)")
                        .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.emphasis))
                        .foregroundStyle(DesignTokens.Colors.Accent.red)
                }

                if state.warningCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.Accent.orange)

                    Text("\(state.warningCount)")
                        .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.emphasis))
                        .foregroundStyle(DesignTokens.Colors.Accent.orange)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Workflow States") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        WorkflowRow(state: WorkflowState(skillSlug: "test-skill", stage: .draft)) {}
        WorkflowRow(state: {
            var state = WorkflowState(skillSlug: "validating-skill", stage: .validating)
            state.addValidationResult(WorkflowValidationError(code: "TEST001", message: "Test error", severity: .error))
            state.addValidationResult(WorkflowValidationError(code: "TEST002", message: "Test warning", severity: .warning))
            return state
        }()) {}
        WorkflowRow(state: WorkflowState(skillSlug: "reviewed-skill", stage: .reviewed)) {}
        WorkflowRow(state: WorkflowState(skillSlug: "approved-skill", stage: .approved)) {}
        WorkflowRow(state: WorkflowState(skillSlug: "published-skill", stage: .published)) {}
    }
    .padding()
    .frame(width: 500)
}
