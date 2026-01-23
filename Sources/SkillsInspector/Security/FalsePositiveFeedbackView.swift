import SwiftUI
import SkillsCore

/// Context menu button and actions for marking security findings as false positives
public struct FalsePositiveFeedbackView: View {
    let finding: Finding
    let onIgnore: () -> Void
    let onUnignore: () -> Void
    var isIgnored: Bool = false

    public init(
        finding: Finding,
        isIgnored: Bool = false,
        onIgnore: @escaping () -> Void,
        onUnignore: @escaping () -> Void
    ) {
        self.finding = finding
        self.isIgnored = isIgnored
        self.onIgnore = onIgnore
        self.onUnignore = onUnignore
    }

    public var body: some View {
        Menu {
            if isIgnored {
                Button(action: onUnignore) {
                    Label("Restore Finding", systemImage: "arrow.uturn.backward")
                }

                Divider()

                Text("This finding is marked as a false positive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onIgnore) {
                    Label("Mark as False Positive", systemImage: "xmark.circle")
                }

                Divider()

                Text("Hide this finding in future scans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: isIgnored ? "eye.slash.fill" : "ellipsis")
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .help(isIgnored ? "Finding is ignored (false positive)" : "Show options")
    }
}

/// Preview provider for FalsePositiveFeedbackView
#Preview("False Positive Feedback (Not Ignored)") {
    FalsePositiveFeedbackView(
        finding: Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/path/to/skill.swift"),
            message: "Hardcoded API key detected",
            line: 42
        ),
        isIgnored: false,
        onIgnore: {},
        onUnignore: {}
    )
    .padding()
}

#Preview("False Positive Feedback (Ignored)") {
    FalsePositiveFeedbackView(
        finding: Finding(
            ruleID: "security.hardcoded_secret",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/path/to/skill.swift"),
            message: "Hardcoded API key detected",
            line: 42
        ),
        isIgnored: true,
        onIgnore: {},
        onUnignore: {}
    )
    .padding()
}

/// Extension to add context menu to FindingRowView
extension View {
    /// Adds false positive feedback menu to a view representing a finding
    /// - Parameters:
    ///   - finding: The security finding
    ///   - scanner: The security scanner to manage ignored state
    ///   - isIgnored: Whether the finding is currently ignored
    /// - Returns: A view with a context menu for false positive feedback
    @ViewBuilder
    func falsePositiveContextMenu(
        for finding: Finding,
        scanner: SecurityScanner,
        isIgnored: Bool
    ) -> some View {
        self.contextMenu {
            FalsePositiveFeedbackView(
                finding: finding,
                isIgnored: isIgnored,
                onIgnore: {
                    Task {
                        await scanner.ignoreFinding(finding)
                    }
                },
                onUnignore: {
                    Task {
                        await scanner.unignoreFinding(finding)
                    }
                }
            )
        }
    }
}
