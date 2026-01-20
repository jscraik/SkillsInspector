import SwiftUI
import SkillsCore

/// Visual progress indicator showing workflow stage pipeline
public struct WorkflowProgressIndicator: View {
    let currentStage: Stage
    let compact: Bool

    public init(currentStage: Stage, compact: Bool = false) {
        self.currentStage = currentStage
        self.compact = compact
    }

    public var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    private var fullView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                if index > 0 {
                    connector(isCompleted: stageIsBefore(stage, currentStage))
                }

                stageNode(stage, isCompleted: stageIsBefore(stage, currentStage), isCurrent: stage == currentStage)
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var compactView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                if index > 0 {
                    Rectangle()
                        .fill(stageIsBefore(stage, currentStage) ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Border.light)
                        .frame(width: 4, height: 2)
                }

                Circle()
                    .fill(colorFor(stage: stage, isCompleted: stageIsBefore(stage, currentStage), isCurrent: stage == currentStage))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func stageNode(_ stage: Stage, isCompleted: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(isCompleted || isCurrent ? colorFor(stage: stage, isCompleted: isCompleted, isCurrent: isCurrent) : DesignTokens.Colors.Background.tertiary)
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: stage.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isCurrent ? .white : DesignTokens.Colors.Icon.secondary)
                }
            }

            if !compact {
                Text(stage.displayName)
                    .font(.system(size: DesignTokens.Typography.Caption.size))
                    .foregroundStyle(isCurrent ? DesignTokens.Colors.Text.primary : DesignTokens.Colors.Text.secondary)
            }
        }
    }

    private func connector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Border.light)
            .frame(width: 24, height: 2)
    }

    private func stageIsBefore(_ stage: Stage, _ reference: Stage) -> Bool {
        guard let stageIndex = stages.firstIndex(of: stage),
              let refIndex = stages.firstIndex(of: reference) else {
            return false
        }
        return stageIndex < refIndex
    }

    private func colorFor(stage: Stage, isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted {
            return DesignTokens.Colors.Accent.green
        } else if isCurrent {
            return DesignTokens.Colors.Accent.blue
        } else {
            return DesignTokens.Colors.Background.tertiary
        }
    }

    private var stages: [Stage] {
        [.draft, .validating, .reviewed, .approved, .published]
    }
}

// MARK: - Preview

#Preview("Full Progress") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        WorkflowProgressIndicator(currentStage: .draft)
        WorkflowProgressIndicator(currentStage: .validating)
        WorkflowProgressIndicator(currentStage: .reviewed)
        WorkflowProgressIndicator(currentStage: .approved)
        WorkflowProgressIndicator(currentStage: .published)
    }
    .padding()
    .frame(width: 500)
}

#Preview("Compact") {
    VStack(spacing: DesignTokens.Spacing.md) {
        WorkflowProgressIndicator(currentStage: .draft, compact: true)
        WorkflowProgressIndicator(currentStage: .validating, compact: true)
        WorkflowProgressIndicator(currentStage: .reviewed, compact: true)
        WorkflowProgressIndicator(currentStage: .approved, compact: true)
        WorkflowProgressIndicator(currentStage: .published, compact: true)
    }
    .padding()
    .frame(width: 300)
}
