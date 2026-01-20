import SwiftUI
import SkillsCore

/// View for reviewing and managing quarantined skills
public struct QuarantineReviewView: View {
    @State private var quarantineStore = QuarantineStore()
    @State private var quarantinedItems: [QuarantineStore.QuarantineItem] = []
    @State private var selectedItem: QuarantineStore.QuarantineItem?
    @State private var isLoading = false
    @State private var showDetail = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPanel
        }
        .task {
            await loadQuarantinedItems()
        }
        .navigationTitle("Quarantine")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if quarantinedItems.isEmpty {
                emptyState
            } else {
                List(quarantinedItems, selection: $selectedItem) { item in
                    QuarantineRow(item: item)
                        .tag(item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 320)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadQuarantinedItems() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .help("Refresh")
            }
        }
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let item = selectedItem {
                QuarantineDetailView(
                    item: item,
                    onApprove: {
                        Task {
                            await approveItem(item)
                        }
                    },
                    onReject: {
                        Task {
                            await rejectItem(item)
                        }
                    }
                )
            } else {
                emptyDetailState
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)

            Text("No Quarantined Skills")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            Text("Skills with security issues will appear here for review.")
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDetailState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)

            Text("Select a Skill")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            Text("Choose a quarantined skill from the list to review details and take action.")
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadQuarantinedItems() async {
        isLoading = true
        defer { isLoading = false }
        quarantinedItems = await quarantineStore.list()
    }

    private func approveItem(_ item: QuarantineStore.QuarantineItem) async {
        let _ = await quarantineStore.approve(id: item.id)
        await loadQuarantinedItems()
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
    }

    private func rejectItem(_ item: QuarantineStore.QuarantineItem) async {
        let _ = await quarantineStore.reject(id: item.id)
        await loadQuarantinedItems()
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
    }
}

// MARK: - QuarantineRow

private struct QuarantineRow: View {
    let item: QuarantineStore.QuarantineItem

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            severityIcon

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                Text(item.skillName)
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                Text(item.skillSlug)
                    .font(.system(size: DesignTokens.Typography.Caption.size))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }

            Spacer()

            statusBadge
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }

    private var severityIcon: some View {
        let (iconName, color): (String, Color) = {
            let highestSeverity = item.reasons.count
            if highestSeverity >= 3 {
                return ("exclamationmark.triangle.fill", DesignTokens.Colors.Accent.red)
            } else if highestSeverity >= 2 {
                return ("exclamationmark.triangle.fill", DesignTokens.Colors.Accent.orange)
            } else {
                return ("exclamationmark.shield.fill", DesignTokens.Colors.Accent.yellow)
            }
        }()

        return Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 20)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch item.status {
            case .pending:
                return ("Review", DesignTokens.Colors.Accent.orange)
            case .approved:
                return ("Approved", DesignTokens.Colors.Accent.green)
            case .rejected:
                return ("Rejected", DesignTokens.Colors.Accent.red)
            }
        }()

        return Text(text)
            .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.emphasis))
            .foregroundStyle(color)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.micro)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - QuarantineDetailView

private struct QuarantineDetailView: View {
    let item: QuarantineStore.QuarantineItem
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                header

                Divider()

                // Security Issues
                securityIssues

                Divider()

                // Context Snippet
                contextSnippet

                Divider()

                // Metadata
                metadata

                Spacer()

                // Actions
                actions
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle(item.skillName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignTokens.Colors.Accent.orange)

                Text("Quarantined Skill")
                    .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            }

            Text(item.skillSlug)
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
    }

    private var securityIssues: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Security Issues")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                ForEach(Array(item.reasons.enumerated()), id: \.offset) { _, reason in
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.Colors.Accent.orange)
                            .frame(width: 16)

                        Text(reason)
                            .font(.system(size: DesignTokens.Typography.Body.size))
                            .foregroundStyle(DesignTokens.Colors.Text.primary)
                    }
                }
            }
        }
    }

    private var contextSnippet: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Context Snippet")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            Text(item.safeExcerpt)
                .font(.system(size: DesignTokens.Typography.BodySmall.size))
                .monospaced()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .padding(DesignTokens.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.Background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Metadata")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                metadataRow("Source URL", item.sourceURL.absoluteString)
                metadataRow("Quarantined", formatDate(item.quarantinedAt))
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
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

    private var actions: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Button {
                onReject()
            } label: {
                Text("Reject")
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                    .foregroundStyle(DesignTokens.Colors.Text.inverted)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Accent.red)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }
            .buttonStyle(.plain)

            Button {
                onApprove()
            } label: {
                Text("Approve")
                    .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                    .foregroundStyle(DesignTokens.Colors.Text.inverted)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Accent.green)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    QuarantineReviewView()
}
