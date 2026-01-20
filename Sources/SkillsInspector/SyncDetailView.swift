import SwiftUI
import SkillsCore

struct SyncDetailView: View {
    let selection: SyncViewModel.SyncSelection
    let rootsByAgent: [AgentKind: URL]
    let diffDetail: MultiSyncReport.DiffDetail?

    @State private var contents: [AgentKind: String] = [:]
    @State private var errors: [AgentKind: String] = [:]
    @State private var modified: [AgentKind: Date] = [:]
    @State private var docs: [AgentKind: SkillDoc] = [:]
    @State private var loadState: LoadState = .idle
    @State private var activeLoadID = UUID()
    @State private var diffMode: DiffMode = .unified
    @State private var showLineNumbers = true
    
    @State private var leftAgent: AgentKind?
    @State private var rightAgent: AgentKind?

    enum DiffMode: String, CaseIterable {
        case unified = "Unified"
        case sideBySide = "Side by Side"
    }

    enum LoadState {
        case idle
        case loading
        case loaded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                header

                if loadState == .loading {
                    loadingState
                } else if loadState == .loaded && contents.isEmpty && errors.isEmpty {
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

}

// MARK: - Subviews
private extension SyncDetailView {

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Title and Metadata Panel
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: headerIcon)
                                .foregroundStyle(headerTint)
                            Text(headerTitle)
                                .font(.system(size: 10, weight: .black))
                                .textCase(.uppercase)
                                .foregroundStyle(headerTint)
                        }
                        
                        Text(skillName)
                            .heading2()
                        
                        Text(headerDescription)
                            .bodySmall()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                    
                    Spacer()
                    
                    if let detail = diffDetail {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(sortedAgents(from: detail.hashes.keys), id: \.self) { agent in
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(agent.displayName.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                    if let hash = detail.hashes[agent], !hash.isEmpty {
                                        Text(hash.prefix(8))
                                            .font(.system(.caption2, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundStyle(agent.color)
                                    }
                                }
                                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                                .padding(.vertical, DesignTokens.Spacing.micro)
                                .background(agent.color.opacity(0.1))
                                .cornerRadius(DesignTokens.Radius.sm)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
            .cornerRadius(DesignTokens.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
            )
        }
    }

    private var loadingState: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            ProgressView()
                .tint(DesignTokens.Colors.Accent.blue)
            Text("Analyzing content differences…")
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(cleanPanelStyle())
    }

    private func diffSection(_ inputs: DiffInputs) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            // Diff Action Toolbar
            HStack(spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "arrow.left.and.right.text.vertical")
                        .foregroundStyle(DesignTokens.Colors.Accent.orange)
                    Text("Compare \(inputs.leftAgent.displayName) & \(inputs.rightAgent.displayName)")
                        .heading3()
                }
                
                Spacer()
                
                // Agent Selector Pair
                HStack(spacing: 0) {
                    Menu {
                        Picker("Left Agent", selection: $leftAgent) {
                            ForEach(comparisonAgents, id: \.self) { agent in
                                Label(agent.displayName, systemImage: agent.icon).tag(Optional(agent))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: inputs.leftAgent.icon)
                                .foregroundStyle(inputs.leftAgent.color)
                            Text(inputs.leftAgent.displayName)
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(inputs.leftAgent.color.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        .padding(.horizontal, 6)
                    
                    Menu {
                        Picker("Right Agent", selection: $rightAgent) {
                            ForEach(comparisonAgents, id: \.self) { agent in
                                Label(agent.displayName, systemImage: agent.icon).tag(Optional(agent))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: inputs.rightAgent.icon)
                                .foregroundStyle(inputs.rightAgent.color)
                            Text(inputs.rightAgent.displayName)
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(inputs.rightAgent.color.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
                .cornerRadius(DesignTokens.Radius.md)
                
                Divider().frame(height: 20)
                
                // Copy Actions Group
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Button {
                        Task { await copyContent(from: inputs.leftAgent, to: inputs.rightAgent) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.doc.on.doc")
                            Text("\(inputs.leftAgent.displayName) → \(inputs.rightAgent.displayName)")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .buttonStyle(.clean)
                    .help("Copy content from \(inputs.leftAgent.displayName) to \(inputs.rightAgent.displayName)")
                    
                    Button {
                        Task { await copyContent(from: inputs.rightAgent, to: inputs.leftAgent) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.doc.on.doc")
                            Text("\(inputs.rightAgent.displayName) → \(inputs.leftAgent.displayName)")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .buttonStyle(.clean)
                    .help("Copy content from \(inputs.rightAgent.displayName) to \(inputs.leftAgent.displayName)")
                    
                    Button {
                        Task { await copyAndBump(from: inputs.leftAgent, to: inputs.rightAgent) }
                    } label: {
                        Label("Bump & Align", systemImage: "bolt.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.cleanProminent)
                    .tint(DesignTokens.Colors.Accent.green)
                }
                .controlSize(.small)
                
                Divider().frame(height: 20)
                
                Picker("", selection: $diffMode) {
                    ForEach(DiffMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .scaleEffect(0.9)
            }
            .padding(.bottom, DesignTokens.Spacing.hair)

            if diffMode == .unified {
                unifiedDiffView(inputs)
                    .transition(.opacity)
            } else {
                sideBySideDiffView(inputs)
                    .transition(.opacity)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
        .cornerRadius(DesignTokens.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
        )
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
        HStack(alignment: .top, spacing: 0) {
            diffColumn(title: inputs.leftAgent.displayName, content: inputs.leftContent)
            Divider()
            diffColumn(title: inputs.rightAgent.displayName, content: inputs.rightContent)
        }
        .frame(minHeight: 220, maxHeight: 400)
        .background(DesignTokens.Colors.Background.primary)
        .cornerRadius(DesignTokens.Radius.sm)
    }

    private func diffColumn(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.Background.secondary)

            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 8) {
                            if showLineNumbers {
                                Text("\(index + 1)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                    .frame(width: 32, alignment: .trailing)
                            }
                            Text(String(line))
                                .font(.system(.caption, design: .monospaced))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 1)
                    }
                }
                .padding(8)
            }
        }
    }

    private var agentGrid: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("Raw content preview")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.xxxs)

            ForEach(sortedAgents(from: rootsByAgent.keys).filter { contents[$0] != nil || errors[$0] != nil || $0 == missingAgent }, id: \.self) { agent in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Circle()
                            .fill(agent.color.opacity(0.15))
                            .frame(width: 24, height: 24)
                            .overlay(Image(systemName: agent.icon).foregroundStyle(agent.color).font(.caption2))
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(agent.displayName)
                                .font(.system(.body, weight: .bold))
                            Text(pathDescription(for: agent))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        if let date = modified[agent] {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 9))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.micro)

                    if let text = contents[agent] {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("\(text.split(separator: "\n").count) lines")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(DesignTokens.Colors.Status.success)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xxxs)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))

                            if let doc = docs[agent] {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    AssetCountBadge(label: "Refs", count: doc.referencesCount, icon: "link")
                                    AssetCountBadge(label: "Assets", count: doc.assetsCount, icon: "photo")
                                    AssetCountBadge(label: "Scripts", count: doc.scriptsCount, icon: "terminal")
                                    Spacer()
                                }
                                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                                .padding(.vertical, 4)
                                .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
                            }

                            ScrollView {
                                Text(text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(DesignTokens.Spacing.xxxs)
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                            .frame(minHeight: 120, maxHeight: 240)
                        }
                        .background(DesignTokens.Colors.Background.primary)
                        .cornerRadius(DesignTokens.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
                        )
                    } else {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(DesignTokens.Colors.Status.error)
                            Text(errorMessage(for: agent))
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(DesignTokens.Colors.Status.error)
                        }
                        .padding(DesignTokens.Spacing.xs)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(DesignTokens.Colors.Status.error.opacity(0.05))
                        .cornerRadius(DesignTokens.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Colors.Status.error.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(DesignTokens.Spacing.xxs)
                .background(DesignTokens.Colors.Background.secondary.opacity(0.2))
                .cornerRadius(DesignTokens.Radius.md)
            }
        }
    }

}

// MARK: - State
private extension SyncDetailView {

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
        
        let agents = comparisonAgents
        guard agents.count >= 2 else { return nil }
        
        // Resolve effective agents for diffing
        let left = leftAgent ?? agents.first!
        var right = rightAgent ?? agents.dropFirst().first!
        
        // Ensure they are different and exist
        if !agents.contains(left) {
            // Left is gone, reset to first available
        }
        
        if left == right {
            // Force right to something else if possible
            right = agents.first(where: { $0 != left }) ?? left
        }
        
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

}

// MARK: - Actions
private extension SyncDetailView {

    private func loadContents() async {
        let loadID = UUID()
        let name = skillName
        let rootsSnapshot = rootsByAgent
        await MainActor.run {
            activeLoadID = loadID
            loadState = .loading
            contents = [:]
            errors = [:]
            modified = [:]
            docs = [:]
        }

        let (loadedContents, loadedErrors, loadedModified, loadedDocs) = await Task(priority: .userInitiated) { () -> ([AgentKind: String], [AgentKind: String], [AgentKind: Date], [AgentKind: SkillDoc]) in
            var contents: [AgentKind: String] = [:]
            var errors: [AgentKind: String] = [:]
            var modified: [AgentKind: Date] = [:]
            var docs: [AgentKind: SkillDoc] = [:]
            for (agent, root) in rootsSnapshot {
                if Task.isCancelled { break }
                let url = root.appendingPathComponent(name).appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: url.path) else {
                    errors[agent] = "Missing SKILL.md"
                    continue
                }
                
                if let doc = SkillLoader.load(agent: agent, rootURL: root, skillFileURL: url) {
                    docs[agent] = doc
                    contents[agent] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let m = attrs[.modificationDate] as? Date {
                        modified[agent] = m
                    }
                } else {
                    errors[agent] = "Failed to load skill metadata"
                }
            }
            return (contents, errors, modified, docs)
        }.value

        await MainActor.run {
            guard activeLoadID == loadID, !Task.isCancelled else { return }
            contents = loadedContents
            errors = loadedErrors
            modified = loadedModified
            docs = loadedDocs
            loadState = .loaded
            
            // Auto-initialize diff agents if unset
            let available = sortedAgents(from: loadedContents.keys)
            if available.count >= 2 {
                if leftAgent == nil || !available.contains(leftAgent!) {
                    leftAgent = available.first
                }
                if rightAgent == nil || !available.contains(rightAgent!) || rightAgent == leftAgent {
                    rightAgent = available.first(where: { $0 != leftAgent }) ?? available.dropFirst().first
                }
            }
        }
    }

    private func copyContent(from: AgentKind, to: AgentKind) async {
        guard let text = contents[from], !text.isEmpty, let srcRoot = rootsByAgent[from], let destRoot = rootsByAgent[to] else { return }
        let srcDir = srcRoot.appendingPathComponent(skillName)
        let destDir = destRoot.appendingPathComponent(skillName)
        let destFile = destDir.appendingPathComponent("SKILL.md")
        let fm = FileManager.default
        
        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            
            // 1. Sync SKILL.md with backup
            // Normalize text to Unix line endings and trim trailing whitespace to ensure hash consistency
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            
            try normalized.write(to: destFile, atomically: true, encoding: .utf8)
            
            // 2. Sync specialized subdirectories if they exist in source
            let specialDirs = ["references", "assets", "scripts"]
            for dirName in specialDirs {
                let srcSubDir = srcDir.appendingPathComponent(dirName)
                let destSubDir = destDir.appendingPathComponent(dirName)
                
                if fm.fileExists(atPath: srcSubDir.path) {
                    if fm.fileExists(atPath: destSubDir.path) {
                        try? fm.removeItem(at: destSubDir)
                    }
                    try fm.copyItem(at: srcSubDir, to: destSubDir)
                }
            }
            
            await loadContents()
            
            // Notify parent to re-scan so the hashes and orange status indicators update
            NotificationCenter.default.post(name: .runScan, object: nil)
        } catch {
            // Error handling could be improved with a toast or status message
        }
    }

    private func copyAndBump(from: AgentKind, to: AgentKind) async {
        await copyContent(from: from, to: to)
        await regenerateIndexAndChangelog(note: "Synced \(skillName) from \(from.displayName) to \(to.displayName)")
    }

    private func regenerateIndexAndChangelog(note: String) async {
        let roots = rootsByAgent.mapValues { [$0] }
        let entries = SkillIndexer.generate(
            roots: roots,
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

}

// MARK: - Helpers
private extension SyncDetailView {
    private func sortedAgents(from agents: some Collection<AgentKind>) -> [AgentKind] {
        agents.sorted { $0.displayName < $1.displayName }
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

private struct AssetCountBadge: View {
    let label: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(count) \(label)")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(count > 0 ? DesignTokens.Colors.Text.secondary : DesignTokens.Colors.Text.tertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(count > 0 ? DesignTokens.Colors.Accent.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

private struct DiffInputs {
    let leftAgent: AgentKind
    let rightAgent: AgentKind
    let leftContent: String
    let rightContent: String
    let diffText: String
}

struct SyncDetailView_Previews: PreviewProvider {
    static var previews: some View {
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
}
