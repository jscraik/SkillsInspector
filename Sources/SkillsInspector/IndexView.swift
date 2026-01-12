import SwiftUI
import SkillsCore

@MainActor
final class IndexViewModel: ObservableObject {
    @Published var entries: [SkillIndexEntry] = []
    @Published var isGenerating = false
    @Published var include: IndexInclude = .all
    @Published var bump: IndexBump = .none
    @Published var changelogNote = ""
    @Published var generatedMarkdown = ""
    @Published var generatedVersion = ""
    @Published var existingVersion = ""
    @Published var expandedSkills: Set<String> = []
    @Published var selectedPath: String?
    private var currentTask: Task<([SkillIndexEntry], String, String), Never>?
    @Published var changelogPath: URL?
    
    let selectionStorageKey = "IndexView.lastSelection"

    init() {
        if let stored = UserDefaults.standard.string(forKey: selectionStorageKey) {
            selectedPath = stored
        }
    }

    private var changelogURL: URL {
        let docs = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs", isDirectory: true)
        return docs.appendingPathComponent("skills-changelog.md")
    }
    
    func generate(
        codexRoots: [URL],
        claudeRoot: URL,
        codexSkillManagerRoot: URL?,
        copilotRoot: URL?,
        recursive: Bool,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        isGenerating = true
        currentTask?.cancel()
        
        let claude = claudeRoot
        let includeFilter = include
        let bumpType = bump
        let changelog = changelogNote
        let existingVer = existingVersion.isEmpty ? nil : existingVersion
        
        currentTask = Task(priority: .userInitiated) {
            if Task.isCancelled { return ([SkillIndexEntry](), "", "") }
            let entries = SkillIndexer.generate(
                codexRoots: codexRoots,
                claudeRoot: claude,
                codexSkillManagerRoot: codexSkillManagerRoot,
                copilotRoot: copilotRoot,
                include: includeFilter,
                recursive: recursive,
                maxDepth: nil,
                excludes: excludes,
                excludeGlobs: excludeGlobs
            )
            
            let (version, markdown) = SkillIndexer.renderMarkdown(
                entries: entries,
                existingVersion: existingVer,
                bump: bumpType,
                changelogNote: changelog.isEmpty ? nil : changelog
            )
            
            return (entries, version, markdown)
        }
        let result = await currentTask?.value ?? ([SkillIndexEntry](), "", "")
        if Task.isCancelled {
            isGenerating = false
            return
        }
        
        entries = result.0
        generatedVersion = result.1
        generatedMarkdown = result.2
        if let selectedPath, !entries.contains(where: { $0.path == selectedPath }) {
            self.selectedPath = nil
        }
        // If nothing is selected but we have a stored selection that still exists, restore it.
        if self.selectedPath == nil,
           let stored = UserDefaults.standard.string(forKey: selectionStorageKey),
           entries.contains(where: { $0.path == stored }) {
            self.selectedPath = stored
        }
        writeChangelogFile()
        isGenerating = false
        currentTask = nil
    }
    
    func copyMarkdown() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedMarkdown, forType: .string)
        #endif
    }
    
    func saveMarkdown() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Skills-\(generatedVersion).md"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.generatedMarkdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }

    func previewMarkdown() -> String {
        if let selectedPath {
            let url = URL(fileURLWithPath: selectedPath)
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return contents
            }
        }
        return generatedMarkdown
    }

    private func writeChangelogFile() {
        guard !generatedMarkdown.isEmpty else { return }
        let section = changelogSection(from: generatedMarkdown)
        guard let target = resolveChangelogPath() else { return }
        do {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try section.write(to: target, atomically: true, encoding: .utf8)
            changelogPath = target
        } catch {
            // Non-fatal; skip silently.
        }
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

    func cancel() {
        currentTask?.cancel()
        isGenerating = false
    }
}

struct IndexView: View {
    @ObservedObject var viewModel: IndexViewModel
    let codexRoots: [URL]
    let claudeRoot: URL
    let codexSkillManagerRoot: URL?
    let copilotRoot: URL?
    @Binding var recursive: Bool
    let excludes: [String]
    let excludeGlobs: [String]
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .frame(minWidth: 900)
        .task(id: viewModel.include) { await autoGenerateIfReady() }
        .task(id: viewModel.bump) { await autoGenerateIfReady() }
        .task(id: recursive) { await autoGenerateIfReady() }
        .onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in
            Task { await viewModel.generate(codexRoots: codexRoots, claudeRoot: claudeRoot, codexSkillManagerRoot: codexSkillManagerRoot, copilotRoot: copilotRoot, recursive: recursive, excludes: excludes, excludeGlobs: excludeGlobs) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
            viewModel.cancel()
        }
    }
    
    private var toolbar: some View {
        VStack(spacing: 0) {
            // Main toolbar
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Primary action
                Button {
                    Task { await viewModel.generate(codexRoots: codexRoots, claudeRoot: claudeRoot, codexSkillManagerRoot: codexSkillManagerRoot, copilotRoot: copilotRoot, recursive: recursive, excludes: excludes, excludeGlobs: excludeGlobs) }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.badge.gearshape")
                        }
                        Text(viewModel.isGenerating ? "Generating…" : "Generate")
                    }
                }
                .disabled(viewModel.isGenerating)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Divider()
                    .frame(height: 24)
                
                // Include filter
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    Text("Include")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .textCase(.uppercase)
                    Picker("Include", selection: $viewModel.include) {
                        Text("All").tag(IndexInclude.all)
                        Text("Codex").tag(IndexInclude.codex)
                        Text("Claude").tag(IndexInclude.claude)
                        Text("CSM").tag(IndexInclude.codexSkillManager)
                        Text("Copilot").tag(IndexInclude.copilot)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
                
                Divider()
                    .frame(height: 24)
                
                // Version bump
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    Text("Version Bump")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .textCase(.uppercase)
                    Picker("Bump", selection: $viewModel.bump) {
                        Text("None").tag(IndexBump.none)
                        Text("Patch").tag(IndexBump.patch)
                        Text("Minor").tag(IndexBump.minor)
                        Text("Major").tag(IndexBump.major)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Recursive toggle
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    Text("Options")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .textCase(.uppercase)
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Label("Recursive", systemImage: "arrow.down.right.and.arrow.up.left")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(recursive ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Icon.secondary)
                        Toggle("", isOn: $recursive)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if !viewModel.generatedVersion.isEmpty {
                        HStack(spacing: DesignTokens.Spacing.hair) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text("v\(viewModel.generatedVersion)")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        .padding(.horizontal, DesignTokens.Spacing.xxxs)
                        .padding(.vertical, DesignTokens.Spacing.hair)
                        .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                    }
                    
                    HStack(spacing: DesignTokens.Spacing.hair) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("\(viewModel.entries.count) skills")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.6))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(glassBarStyle(cornerRadius: 0))
        }
    }
    
    private var content: some View {
        HStack(spacing: 0) {
            // Skills list (fixed width)
            Group {
                if viewModel.isGenerating {
                    // Loading state with skeletons
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.xxs) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonIndexRow()
                            }
                        }
                        .padding(DesignTokens.Spacing.xs)
                    }
                } else if viewModel.entries.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Ready to Index",
                        message: "Generate a consolidated skills index from your Codex and Claude roots.",
                        action: { Task { await viewModel.generate(codexRoots: codexRoots, claudeRoot: claudeRoot, codexSkillManagerRoot: codexSkillManagerRoot, copilotRoot: copilotRoot, recursive: recursive, excludes: excludes, excludeGlobs: excludeGlobs) } },
                        actionLabel: "Generate Index"
                    )
                } else {
                    skillsList
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 440)
            
            Divider()
            
            // Markdown preview (flexible)
            markdownPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700)
    }
    
    private var skillsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Settings section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Settings")
                        .heading3()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    
                    VStack(spacing: DesignTokens.Spacing.xxs) {
                        HStack {
                            Text("Existing Version:")
                                .bodySmall()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            TextField("0.1.0", text: $viewModel.existingVersion)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair + DesignTokens.Spacing.micro) {
                            Text("Changelog Note:")
                                .bodySmall()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            TextField("Added new skills", text: $viewModel.changelogNote)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(DesignTokens.Spacing.xs)
                    .cardStyle()
                }
                
                ForEach(AgentKind.allCases, id: \.self) { agent in
                    let agentEntries = viewModel.entries.filter { $0.agent == agent }
                    if !agentEntries.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            HStack {
                                Image(systemName: agent.icon)
                                    .foregroundStyle(agent.color)
                                Text("\(agent.displayName) Skills")
                                    .heading3()
                                Text("(\(agentEntries.count))")
                                    .bodySmall()
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                            
                            ForEach(agentEntries, id: \.path) { entry in
                                SkillIndexRowView(
                                    entry: entry,
                                    isExpanded: viewModel.expandedSkills.contains(entry.path),
                                    onToggle: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if viewModel.expandedSkills.contains(entry.path) {
                                                viewModel.expandedSkills.remove(entry.path)
                                            } else {
                                                viewModel.expandedSkills.insert(entry.path)
                                            }
                                        }
                                    },
                                    onSelect: {
                                        viewModel.selectedPath = entry.path
                                        UserDefaults.standard.set(entry.path, forKey: viewModel.selectionStorageKey)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xs)
        }
    }
    
    private var markdownPreview: some View {
        let preview = viewModel.previewMarkdown()
        return VStack(spacing: 0) {
            if preview.isEmpty {
                emptyPreviewState
            } else {
                HStack {
                    Text("Markdown Preview")
                        .heading3()
                    Spacer()
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(preview, forType: .string)
                        #endif
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .captionText()
                    }
                    .buttonStyle(.customGlass)
                    .controlSize(.small)
                    
                    Button {
                        #if os(macOS)
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "Skills-\(viewModel.generatedVersion).md"
                        panel.allowedContentTypes = [.plainText]
                        panel.canCreateDirectories = true

                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                try? preview.write(to: url, atomically: true, encoding: .utf8)
                            }
                        }
                        #endif
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .captionText()
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(
                    Group {
                        if #available(iOS 26, macOS 15, *) {
                            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 12))
                        } else {
                            Color(.windowBackgroundColor)
                                .opacity(0.4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                )

                Group {
                    if #available(iOS 26, macOS 15, *) {
                        MarkdownPreviewView(content: preview)
                            .id(viewModel.selectedPath ?? "generated-preview")
                            .glassEffect(
                                .regular.tint(.primary.opacity(0.08)),
                                in: .rect(cornerRadius: 14)
                            )
                            .padding(DesignTokens.Spacing.xs)
                    } else {
                        MarkdownPreviewView(content: preview)
                            .id(viewModel.selectedPath ?? "generated-preview")
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .padding(DesignTokens.Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPath)
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
            Text("No Markdown Generated")
                .heading3()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
            Text("Generate an index to see the markdown preview")
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func autoGenerateIfReady() async {
        // Avoid re-entrancy while generating; respect user intent when a run is already in flight.
        guard viewModel.isGenerating == false else { return }
        await viewModel.generate(
            codexRoots: codexRoots,
            claudeRoot: claudeRoot,
            codexSkillManagerRoot: codexSkillManagerRoot,
            copilotRoot: copilotRoot,
            recursive: recursive,
            excludes: excludes,
            excludeGlobs: excludeGlobs
        )
    }
}
