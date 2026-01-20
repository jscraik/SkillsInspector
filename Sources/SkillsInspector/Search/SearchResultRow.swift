import SwiftUI
import SkillsCore

/// Row component displaying a single search result with BM25 score and highlighted snippet
public struct SearchResultRow: View {
    let result: SkillSearchEngine.SearchResult
    var onSelect: () -> Void = {}

    public init(result: SkillSearchEngine.SearchResult, onSelect: @escaping () -> Void = {}) {
        self.result = result
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    // Skill name and agent
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(result.skillName)
                            .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                            .foregroundStyle(DesignTokens.Colors.Text.primary)
                            .lineLimit(1)

                        agentBadge
                    }

                    // Slug
                    Text(result.skillSlug)
                        .font(.system(size: DesignTokens.Typography.Caption.size))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .lineLimit(1)

                    // Highlighted snippet
                    highlightedSnippet
                }

                Spacer()

                // BM25 score
                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    Text("\(rankDisplay)")
                        .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.emphasis))
                        .foregroundStyle(rankColor)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.secondary.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
        )
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Subviews

    private var agentBadge: some View {
        let (iconName, color) = agentIconAndColor

        return HStack(spacing: DesignTokens.Spacing.micro) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(color)

            Text(result.agent.rawValue.capitalized)
                .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.emphasis))
                .foregroundStyle(color)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.micro)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var highlightedSnippet: some View {
        let snippet = result.snippet
            .replacingOccurrences(of: "<mark>", with: "||")
            .replacingOccurrences(of: "</mark>", with: "||")

        let parts = snippet.split(separator: "||", maxSplits: 2, omittingEmptySubsequences: false)

        return Text(buildAttributedString(from: parts, isHighlight: false))
            .font(.system(size: DesignTokens.Typography.BodySmall.size))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }

    private var contextMenuItems: some View {
        Group {
            Button("Open in Finder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: result.filePath))
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.filePath, forType: .string)
            }

            Divider()
        }
    }

    // MARK: - Computed Properties

    private var agentIconAndColor: (String, Color) {
        switch result.agent {
        case .codex:
            return ("cube.fill", DesignTokens.Colors.Accent.blue)
        case .claude:
            return ("sparkles", DesignTokens.Colors.Accent.purple)
        case .copilot:
            return ("brain", DesignTokens.Colors.Accent.green)
        default:
            return ("square.fill", DesignTokens.Colors.Accent.gray)
        }
    }

    private var rankDisplay: String {
        String(format: "%.2f", result.rank)
    }

    private var rankColor: Color {
        // Lower BM25 score is better, so invert for display
        if result.rank < 1.0 {
            return DesignTokens.Colors.Accent.green
        } else if result.rank < 5.0 {
            return DesignTokens.Colors.Accent.yellow
        } else {
            return DesignTokens.Colors.Accent.orange
        }
    }

    // MARK: - Helper Methods

    private func buildAttributedString(from parts: [Substring], isHighlight: Bool) -> AttributedString {
        guard !parts.isEmpty else {
            return AttributedString("")
        }

        var result = AttributedString(String(parts[0]))

        if parts.count > 1 {
            var highlighted = AttributedString(String(parts[1]))
            highlighted.font = .system(size: DesignTokens.Typography.BodySmall.size, weight: .bold)
            highlighted.backgroundColor = DesignTokens.Colors.Accent.yellow.opacity(0.3)
            result.append(highlighted)
        }

        if parts.count > 2 {
            result.append(AttributedString(String(parts[2])))
        }

        return result
    }
}

// MARK: - Preview

#Preview("Search Results") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        SearchResultRow(result: sampleResult()) {
            print("Selected: sample-result")
        }

        SearchResultRow(result: sampleResult(rank: 0.5)) {
            print("Selected: high-rank")
        }

        SearchResultRow(result: sampleResult(rank: 8.0)) {
            print("Selected: low-rank")
        }
    }
    .padding()
    .background(DesignTokens.Colors.Background.primary)
}

private func sampleResult(rank: Double = 2.5) -> SkillSearchEngine.SearchResult {
    SkillSearchEngine.SearchResult(
        id: "test-skill",
        skillName: "Test Skill",
        skillSlug: "test-skill",
        agent: .claude,
        snippet: "This is a <mark>sample</mark> snippet showing search term highlighting.",
        rank: rank,
        filePath: "/tmp/test"
    )
}
