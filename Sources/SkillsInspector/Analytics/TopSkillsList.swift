import SwiftUI
import SkillsCore

/// A list view displaying the most scanned skills
public struct TopSkillsList: View {
    let rankings: [SkillUsageRanking]
    let limit: Int

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    public init(rankings: [SkillUsageRanking], limit: Int = 10) {
        self.rankings = Array(rankings.prefix(limit))
        self.limit = limit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Header
            header

            // List content
            if rankings.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(
            glassPanelStyle(cornerRadius: DesignTokens.Radius.lg)
        )
    }
}

// MARK: - Subviews
private extension TopSkillsList {

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "list.star")
                        .foregroundStyle(DesignTokens.Colors.Accent.purple)
                        .font(.title3)
                    Text("Top Skills")
                        .heading3()
                }

                // Summary metrics
                HStack(spacing: DesignTokens.Spacing.md) {
                    metricItem(label: "Skills", value: "\(rankings.count)")
                    if let topSkill = rankings.first {
                        metricItem(label: "Top", value: "\(topSkill.scanCount) scans")
                    }
                }
            }

            Spacer()
        }
    }

    private var list: some View {
        VStack(spacing: DesignTokens.Spacing.xxxs) {
            ForEach(Array(rankings.enumerated()), id: \.element.skillName) { index, ranking in
                skillRow(index: index, ranking: ranking)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Status.info)

            Text("No Skills Found")
                .heading3()

            Text("No scan activity has been recorded in the selected time range.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private func skillRow(index: Int, ranking: SkillUsageRanking) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Rank badge
            rankBadge(index: index)

            // Skill info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                Text(ranking.skillName)
                    .bodyText(emphasis: true)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    if let agent = ranking.agent {
                        Image(systemName: agent.icon)
                            .font(.caption2)
                            .foregroundStyle(agent.color)

                        Text(agent.displayName)
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }

                    Text("•")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)

                    Text(relativeFormatter.localizedString(for: ranking.lastScanned, relativeTo: Date()))
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
            }

            Spacer()

            // Scan count
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Text("\(ranking.scanCount)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.Accent.purple)

                Text("scans")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }
        }
        .padding(DesignTokens.Spacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Colors.Background.secondary.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(index + 1): \(ranking.skillName), scanned \(ranking.scanCount) times")
    }

    private func rankBadge(index: Int) -> some View {
        let rank = index + 1
        let isTopThree = rank <= 3

        return ZStack {
            Circle()
                .fill(isTopThree ? DesignTokens.Colors.Accent.purple.opacity(0.15) : DesignTokens.Colors.Background.secondary)
                .frame(width: 32, height: 32)

            Text("\(rank)")
                .font(.system(.caption, design: .rounded, weight: isTopThree ? .bold : .medium))
                .foregroundStyle(isTopThree ? DesignTokens.Colors.Accent.purple : DesignTokens.Colors.Text.secondary)
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
            Text(label)
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
        }
    }
}

// MARK: - Sample Data
extension TopSkillsList {
    /// Sample top skills list for preview/testing
    public static let sampleRankings: [SkillUsageRanking] = {
        let calendar = Calendar.current
        let now = Date()

        return [
            SkillUsageRanking(
                skillName: "code-review",
                agent: .claude,
                scanCount: 47,
                lastScanned: calendar.date(byAdding: .hour, value: -2, to: now)!
            ),
            SkillUsageRanking(
                skillName: "refactor-helper",
                agent: .codex,
                scanCount: 35,
                lastScanned: calendar.date(byAdding: .hour, value: -5, to: now)!
            ),
            SkillUsageRanking(
                skillName: "test-generator",
                agent: .claude,
                scanCount: 28,
                lastScanned: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            SkillUsageRanking(
                skillName: "documentation-writer",
                agent: .codexSkillManager,
                scanCount: 21,
                lastScanned: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            SkillUsageRanking(
                skillName: "bug-finder",
                agent: .copilot,
                scanCount: 18,
                lastScanned: calendar.date(byAdding: .day, value: -2, to: now)!
            ),
            SkillUsageRanking(
                skillName: "code-explainer",
                agent: .claude,
                scanCount: 15,
                lastScanned: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            SkillUsageRanking(
                skillName: "api-designer",
                agent: .codex,
                scanCount: 12,
                lastScanned: calendar.date(byAdding: .day, value: -4, to: now)!
            ),
            SkillUsageRanking(
                skillName: "performance-optimizer",
                agent: .claude,
                scanCount: 9,
                lastScanned: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            ),
            SkillUsageRanking(
                skillName: "security-scanner",
                agent: .codexSkillManager,
                scanCount: 7,
                lastScanned: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            ),
            SkillUsageRanking(
                skillName: "migration-helper",
                agent: .codex,
                scanCount: 5,
                lastScanned: calendar.date(byAdding: .weekOfYear, value: -2, to: now)!
            )
        ]
    }()

    /// Empty rankings for preview
    public static let emptyRankings: [SkillUsageRanking] = []

    /// Single skill for preview
    public static let singleRanking: [SkillUsageRanking] = [
        SkillUsageRanking(
            skillName: "code-review",
            agent: .claude,
            scanCount: 47,
            lastScanned: Date()
        )
    ]
}

// MARK: - Preview
#Preview("With Data") {
    TopSkillsList(rankings: TopSkillsList.sampleRankings, limit: 10)
        .frame(width: 500, height: 500)
        .padding()
}

#Preview("Empty Data") {
    TopSkillsList(rankings: TopSkillsList.emptyRankings)
        .frame(width: 500, height: 400)
        .padding()
}

#Preview("Single Item") {
    TopSkillsList(rankings: TopSkillsList.singleRanking)
        .frame(width: 500, height: 200)
        .padding()
}

#Preview("Top 5") {
    TopSkillsList(rankings: TopSkillsList.sampleRankings, limit: 5)
        .frame(width: 500, height: 350)
        .padding()
}
