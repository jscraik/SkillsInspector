import SwiftUI
import SkillsCore

struct SyncDetailView: View {
    let selection: SyncViewModel.SyncSelection
    let rootsByAgent: [AgentKind: URL]
    let diffDetail: MultiSyncReport.DiffDetail?

    @State private var contents: [AgentKind: String] = [:]
    @State private var errors: [AgentKind: String] = [:]
    @State private var modified: [AgentKind: Date] = [:]
    @State private var isLoading = false
    @State private var diffMode: DiffMode = .unified
    @State private var showLineNumbers = true

    enum DiffMode: String, CaseIterable {
        case unified = "Unified"
        case sideBySide = "Side by Side"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                header

                if isLoading {
                    loadingState
                } else if contents.isEmpty && errors.isEmpty {
                    EmptyStateView(
                        icon: "sidebar.right",
                        title: "No Content",
                        message: "Could not load SKILL.md for \(skillName)."
                    )
                }

                if let diffInputs = diffInputs {
                    diffSection(diffInputs)
                }

                agentGrid
            }
            .padding(DesignTokens.Spacing.xs)
        }
        .task(id: selection) { await loadContents() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair + DesignTokens.Spacing.micro) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: headerIcon)
                    .foregroundStyle(headerTint)
                Text(headerTitle)
                    .captionText()
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.micro)
                    .background(headerTint.opacity(0.12))
                    .cornerRadius(DesignTokens.Radius.sm)
            }

            Text(skillName)
                .heading3()

            Text(headerDescription)
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            if let detail = diffDetail {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.xxs), count: 2), spacing: DesignTokens.Spacing.xxxs) {
                    ForEach(sortedAgents(from: detail.hashes.keys), id: \.self) { agent in
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Circle()
                                .fill(agent.color.opacity(0.2))
                                .frame(width: 22, height: 22)
                                .overlay(Image(systemName: agent.icon).foregroundStyle(agent.color).font(.caption2))
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                                Text(agent.displayName)
                                    .captionText()
                                if let hash = detail.hashes[agent], !hash.isEmpty {
                                    Text(hash.prefix(10))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                }
                                if let date = detail.modified[agent] ?? modified[agent] {
                                    Text(DateFormatter.shortDateTime.string(from: date))
                                        .captionText()
                                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.micro)
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            ProgressView()
            Text("Loading skill files…")
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
    }

    private func diffSection(_ inputs: DiffInputs) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack {
                Text("Diff between \(inputs.leftAgent.displayName) and \(inputs.rightAgent.displayName)")
                    .heading3()
                Spacer()
                Button {
                    Task { await copyContent(from: inputs.leftAgent, to: inputs.rightAgent) }
                } label: {
                    Label("\(inputs.leftAgent.displayName) → \(inputs.rightAgent.displayName)", systemImage: "arrow.right.doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(contents[inputs.leftAgent]?.isEmpty ?? true)

                Button {
                    Task { await copyContent(from: inputs.rightAgent, to: inputs.leftAgent) }
                } label: {
                    Label("\(inputs.rightAgent.displayName) → \(inputs.leftAgent.displayName)", systemImage: "arrow.left.doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(contents[inputs.rightAgent]?.isEmpty ?? true)

                Button {
                    Task { await copyAndBump(from: inputs.leftAgent, to: inputs.rightAgent) }
                } label: {
                    Label("Copy & bump", systemImage: "arrow.triangle.branch")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(contents[inputs.leftAgent]?.isEmpty ?? true)

                Picker("View", selection: $diffMode) {
                    ForEach(DiffMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Toggle(isOn: $showLineNumbers) {
                    Label("Line numbers", systemImage: "number")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(maxWidth: 160)
            }

            if diffMode == .unified {
                unifiedDiffView(inputs)
            } else {
                sideBySideDiffView(inputs)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .background(DesignTokens.Colors.Background.secondary)
        .cornerRadius(DesignTokens.Radius.md)
    }

    private func unifiedDiffView(_ inputs: DiffInputs) -> some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                let lines = inputs.diffText.split(separator: "\n", omittingEmptySubsequences: false)
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        if showLineNumbers {
                            Text("\(index + 1)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        let (color, background) = diffStyling(for: line)
                        Text(String(line))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color)
                            .padding(.horizontal, DesignTokens.Spacing.xxxs)
                            .padding(.vertical, DesignTokens.Spacing.micro)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(background)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xxxs)
        }
        .frame(minHeight: 220, maxHeight: 320)
        .background(DesignTokens.Colors.Background.primary)
        .cornerRadius(DesignTokens.Radius.sm)
    }

    private func sideBySideDiffView(_ inputs: DiffInputs) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.hair) {
            diffColumn(title: inputs.leftAgent.displayName, content: inputs.leftContent, alignment: .trailing)
            Divider()
            diffColumn(title: inputs.rightAgent.displayName, content: inputs.rightContent, alignment: .leading)
        }
        .frame(minHeight: 220, maxHeight: 320)
        .background(DesignTokens.Colors.Background.primary)
        .cornerRadius(DesignTokens.Radius.sm)
    }

    private func diffColumn(title: String, content: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .captionText()
                .padding(.vertical, DesignTokens.Spacing.micro)
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.Background.secondary)

            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: alignment, spacing: 0) {
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            if showLineNumbers {
                                Text("\(index + 1)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            Text(String(line))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DesignTokens.Spacing.micro)
                                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.xxxs)
            }
        }
    }

    private var agentGrid: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(sortedAgents(from: rootsByAgent.keys), id: \.self) { agent in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Circle()
                            .fill(agent.color.opacity(0.18))
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: agent.icon).foregroundStyle(agent.color).font(.caption))
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                            Text(agent.displayName)
                                .bodyText()
                            Text(pathDescription(for: agent))
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if let hash = diffDetail?.hashes[agent], !hash.isEmpty {
                            Text(hash.prefix(8))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.micro)

                    if let text = contents[agent] {
                        Text("\(text.split(separator: "\n").count) lines")
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        ScrollView {
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(DesignTokens.Spacing.xxxs)
                        }
                        .frame(minHeight: 140, maxHeight: 260)
                        .background(DesignTokens.Colors.Background.secondary)
                        .cornerRadius(DesignTokens.Radius.sm)
                    } else {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignTokens.Colors.Status.warning)
                            Text(errorMessage(for: agent))
                                .bodySmall()
                                .foregroundStyle(DesignTokens.Colors.Status.warning)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(DesignTokens.Spacing.xxxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.Colors.Background.secondary)
                        .cornerRadius(DesignTokens.Radius.sm)
                    }
                }
                .cardStyle(tint: agent.color)
            }
        }
    }

    private var headerIcon: String {
        switch selection {
        case .missing: return "exclamationmark.triangle.fill"
        case .different: return "doc.badge.gearshape"
        }
    }

    private var headerTint: Color {
        switch selection {
        case .missing(let agent, _): return agent.color
        case .different: return DesignTokens.Colors.Accent.orange
        }
    }

    private var headerTitle: String {
        switch selection {
        case .missing(let agent, _):
            return "Missing in \(agent.displayName)"
        case .different:
            return "Content differs across agents"
        }
    }

    private var headerDescription: String {
        switch selection {
        case .missing(let agent, _):
            return "Skill exists in at least one other agent but not in \(agent.displayName)."
        case .different:
            return "Hashes or content vary between agents. Review differences and align as needed."
        }
    }

    private var skillName: String { selection.name }

    private var isDifferent: Bool {
        if case .different = selection { return true }
        return false
    }

    private var missingAgent: AgentKind? {
        if case .missing(let agent, _) = selection { return agent }
        return nil
    }

    private var diffInputs: DiffInputs? {
        guard isDifferent else { return nil }
        let ordered = comparisonAgents
        guard let left = ordered.first, let right = ordered.dropFirst().first else { return nil }
        let leftContent = contents[left] ?? ""
        let rightContent = contents[right] ?? ""
        return DiffInputs(
            leftAgent: left,
            rightAgent: right,
            leftContent: leftContent,
            rightContent: rightContent,
            diffText: unifiedDiff(
                left: leftContent,
                right: rightContent,
                leftName: left.displayName,
                rightName: right.displayName
            )
        )
    }

    private var comparisonAgents: [AgentKind] {
        if let detail = diffDetail, !detail.hashes.isEmpty {
            return sortedAgents(from: detail.hashes.keys)
        }
        return sortedAgents(from: rootsByAgent.keys)
    }

    private func sortedAgents(from agents: some Collection<AgentKind>) -> [AgentKind] {
        agents.sorted { $0.displayName < $1.displayName }
    }

    private func loadContents() async {
        let name = skillName
        await MainActor.run {
            isLoading = true
            contents = [:]
            errors = [:]
            modified = [:]
        }

        let (loadedContents, loadedErrors, loadedModified) = await Task.detached(priority: .userInitiated) { () -> ([AgentKind: String], [AgentKind: String], [AgentKind: Date]) in
            var contents: [AgentKind: String] = [:]
            var errors: [AgentKind: String] = [:]
            var modified: [AgentKind: Date] = [:]
            for (agent, root) in rootsByAgent {
                let url = root.appendingPathComponent(name).appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: url.path) else {
                    errors[agent] = "Missing SKILL.md"
                    continue
                }
                do {
                    contents[agent] = try String(contentsOf: url, encoding: .utf8)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let m = attrs[.modificationDate] as? Date {
                        modified[agent] = m
                    }
                } catch {
                    errors[agent] = error.localizedDescription
                }
            }
            return (contents, errors, modified)
        }.value

        await MainActor.run {
            contents = loadedContents
            errors = loadedErrors
            modified = loadedModified
            isLoading = false
        }
    }

    private func errorMessage(for agent: AgentKind) -> String {
        if let specific = errors[agent] {
            return specific
        }
        if agent == missingAgent {
            return "\(skillName) is missing in \(agent.displayName)"
        }
        return "No content available"
    }

    private func pathDescription(for agent: AgentKind) -> String {
        guard let root = rootsByAgent[agent] else { return "Root not set" }
        return root.appendingPathComponent(skillName).path
    }

    private func diffStyling(for line: Substring) -> (Color, Color) {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return (DesignTokens.Colors.Text.secondary, .clear)
        }
        if line.hasPrefix("@@") {
            return (DesignTokens.Colors.Accent.blue, DesignTokens.Colors.Accent.blue.opacity(0.08))
        }
        if line.hasPrefix("+") {
            return (DesignTokens.Colors.Status.success, DesignTokens.Colors.Status.success.opacity(0.12))
        }
        if line.hasPrefix("-") {
            return (DesignTokens.Colors.Status.error, DesignTokens.Colors.Status.error.opacity(0.12))
        }
        return (DesignTokens.Colors.Text.primary, .clear)
    }

    private func copyContent(from: AgentKind, to: AgentKind) async {
        guard let text = contents[from], !text.isEmpty, let destRoot = rootsByAgent[to] else { return }
        let dest = destRoot.appendingPathComponent(skillName).appendingPathComponent("SKILL.md")
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) {
                let backup = dest.appendingPathExtension("bak")
                try? fm.removeItem(at: backup)
                try fm.copyItem(at: dest, to: backup)
            }
            try text.write(to: dest, atomically: true, encoding: .utf8)
            await loadContents()
        } catch {
            // Could surface a toast; keeping silent to avoid blocking UX.
        }
    }

    private func copyAndBump(from: AgentKind, to: AgentKind) async {
        await copyContent(from: from, to: to)
        await regenerateIndexAndChangelog(note: "Synced \(skillName) from \(from.displayName) to \(to.displayName)")
    }

    private func regenerateIndexAndChangelog(note: String) async {
        let codexRoots = rootsByAgent[.codex].map { [$0] } ?? []
        let claudeRoot = rootsByAgent[.claude]
        let csmRoot = rootsByAgent[.codexSkillManager]
        let copilotRoot = rootsByAgent[.copilot]
        let entries = SkillIndexer.generate(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: csmRoot,
            copilotRoot: copilotRoot,
            include: .all,
            recursive: true
        )
        let (version, markdown) = SkillIndexer.renderMarkdown(
            entries: entries,
            existingVersion: nil,
            bump: .patch,
            changelogNote: note
        )
        let changelog = changelogSection(from: markdown)
        if let target = resolveChangelogPath() {
            try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? changelog.write(to: target, atomically: true, encoding: .utf8)
        }
        _ = version // currently unused, retained for future display
    }

    private func changelogSection(from markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        if let start = lines.firstIndex(where: { $0 == "## Changelog" }) {
            return lines[start...].joined(separator: "\n")
        }
        return "## Changelog\n(No entries yet.)"
    }

    private func resolveChangelogPath() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent(".codex/public/skills-changelog.md"),
            home.appendingPathComponent(".claude/skills-changelog.md"),
            home.appendingPathComponent(".copilot/skills-changelog.md"),
            home.appendingPathComponent(".codexskillmanager/skills-changelog.md"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/skills-changelog.md")
        ]
        return candidates.first { url in
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) { return true }
            return (try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)) != nil
        }
    }

    private func unifiedDiff(left: String, right: String, leftName: String, rightName: String) -> String {
        let leftLines = left.split(separator: "\n", omittingEmptySubsequences: false)
        let rightLines = right.split(separator: "\n", omittingEmptySubsequences: false)

        var output: [String] = []
        output.append("--- \(leftName)")
        output.append("+++ \(rightName)")

        let maxCount = max(leftLines.count, rightLines.count)
        for index in 0..<maxCount {
            let l = index < leftLines.count ? String(leftLines[index]) : nil
            let r = index < rightLines.count ? String(rightLines[index]) : nil
            if l == r {
                output.append(" \(l ?? "")")
            } else {
                if let l { output.append("-\(l)") }
                if let r { output.append("+\(r)") }
            }
        }
        return output.joined(separator: "\n")
    }
}

private struct DiffInputs {
    let leftAgent: AgentKind
    let rightAgent: AgentKind
    let leftContent: String
    let rightContent: String
    let diffText: String
}

#Preview {
    let roots: [AgentKind: URL] = [
        .codex: URL(fileURLWithPath: "/tmp/codex"),
        .claude: URL(fileURLWithPath: "/tmp/claude"),
        .copilot: URL(fileURLWithPath: "/tmp/copilot")
    ]
    SyncDetailView(
        selection: .different(name: "demo"),
        rootsByAgent: roots,
        diffDetail: nil
    )
}
