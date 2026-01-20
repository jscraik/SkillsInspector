import SwiftUI
import SkillsCore

// MARK: - Supporting Types
struct SkillVersionHistoryEntry: Identifiable, Codable {
    let id = UUID()
    let skillPath: String
    let skillName: String
    let oldVersion: String?
    let newVersion: String
    let timestamp: Date
    let changeNote: String?
    
    enum CodingKeys: String, CodingKey {
        case skillPath, skillName, oldVersion, newVersion, timestamp, changeNote
    }
}

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
    @Published var generateError: String?
    @Published var generateSuccessMessage: String?
    private var currentTask: Task<([SkillIndexEntry], String, String), Never>?
    @Published var changelogPath: URL?
    
    // Enhanced version management properties
    @Published var skillVersionBump: IndexBump = .none
    @Published var isUpdatingSkillVersions = false
    @Published var skillVersionHistory: [SkillVersionHistoryEntry] = []
    
    let selectionStorageKey = "IndexView.lastSelection"

    init() {
        if let stored = UserDefaults.standard.string(forKey: selectionStorageKey) {
            selectedPath = stored
        }
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
        // Check if we have valid roots to generate index from
        let hasValidRoots = !codexRoots.isEmpty || PathUtil.existsDir(claudeRoot)
        guard hasValidRoots else {
            generateError = "No valid skill roots configured. Please check your root directories in the sidebar."
            generateSuccessMessage = nil
            return
        }

        isGenerating = true
        generateError = nil
        generateSuccessMessage = nil
        currentTask?.cancel()

        currentTask = Task(priority: .userInitiated) {
            if Task.isCancelled { return ([SkillIndexEntry](), "", "") }
            let entries = SkillIndexer.generate(
                codexRoots: codexRoots,
                claudeRoot: claudeRoot,
                codexSkillManagerRoot: codexSkillManagerRoot,
                copilotRoot: copilotRoot,
                include: include,
                recursive: recursive,
                maxDepth: nil,
                excludes: excludes,
                excludeGlobs: excludeGlobs
            )

            let (version, markdown) = SkillIndexer.renderMarkdown(
                entries: entries,
                existingVersion: existingVersion.isEmpty ? nil : existingVersion,
                bump: bump,
                changelogNote: changelogNote.isEmpty ? nil : changelogNote
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

        // Set success message
        let entryCount = entries.count
        generateSuccessMessage = "Generated index for \(entryCount) skill\(entryCount == 1 ? "" : "s"). Version \(generatedVersion)."
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
    
    // MARK: - Enhanced Version Management
    
    /// Update version for a specific skill
    func updateSkillVersion(
        _ entry: SkillIndexEntry, 
        newVersion: String,
        codexRoots: [URL],
        claudeRoot: URL,
        codexSkillManagerRoot: URL?,
        copilotRoot: URL?,
        recursive: Bool,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        guard !newVersion.isEmpty else { return }
        
        let skillURL = URL(fileURLWithPath: entry.path)
        guard let content = try? String(contentsOf: skillURL, encoding: .utf8) else { return }
        
        // Parse and update frontmatter
        let updatedContent = updateVersionInFrontmatter(content: content, newVersion: newVersion)
        
        do {
            try updatedContent.write(to: skillURL, atomically: true, encoding: .utf8)
            
            // Record in history
            let historyEntry = SkillVersionHistoryEntry(
                skillPath: entry.path,
                skillName: entry.name,
                oldVersion: entry.version,
                newVersion: newVersion,
                timestamp: Date(),
                changeNote: nil
            )
            skillVersionHistory.append(historyEntry)
            
            // Regenerate index to reflect changes
            await generate(
                codexRoots: codexRoots,
                claudeRoot: claudeRoot,
                codexSkillManagerRoot: codexSkillManagerRoot,
                copilotRoot: copilotRoot,
                recursive: recursive,
                excludes: excludes,
                excludeGlobs: excludeGlobs
            )
        } catch {
            // Handle error silently for now
        }
    }
    
    /// Bulk update all skill versions
    func bumpAllSkillVersions(
        codexRoots: [URL],
        claudeRoot: URL,
        codexSkillManagerRoot: URL?,
        copilotRoot: URL?,
        recursive: Bool,
        excludes: [String],
        excludeGlobs: [String]
    ) async {
        guard skillVersionBump != .none else { return }
        
        isUpdatingSkillVersions = true
        defer { isUpdatingSkillVersions = false }
        
        for entry in entries {
            let currentVersion = entry.version ?? "0.1.0"
            let newVersion = bumpSemanticVersion(currentVersion, bump: skillVersionBump)
            await updateSkillVersion(
                entry,
                newVersion: newVersion,
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
    
    /// Get changelog file path for display
    func getChangelogDisplayPath() -> String {
        guard let path = changelogPath else {
            return resolveChangelogPath()?.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: "~"
            ) ?? "Not determined"
        }
        return path.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
    
    // MARK: - Private Helpers
    
    private func updateVersionInFrontmatter(content: String, newVersion: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var updatedLines: [String] = []
        var inFrontmatter = false
        var foundVersion = false
        
        for line in lines {
            if line == "---" {
                if !inFrontmatter {
                    inFrontmatter = true
                    updatedLines.append(line)
                } else {
                    // End of frontmatter
                    if !foundVersion {
                        updatedLines.append("version: \(newVersion)")
                    }
                    updatedLines.append(line)
                    inFrontmatter = false
                }
            } else if inFrontmatter && line.hasPrefix("version:") {
                updatedLines.append("version: \(newVersion)")
                foundVersion = true
            } else {
                updatedLines.append(line)
            }
        }
        
        // If no frontmatter exists, add it
        if !foundVersion {
            let frontmatter = [
                "---",
                "version: \(newVersion)",
                "---",
                ""
            ]
            return frontmatter.joined(separator: "\n") + content
        }
        
        return updatedLines.joined(separator: "\n")
    }
    
    private func bumpSemanticVersion(_ version: String, bump: IndexBump) -> String {
        let comps = version.split(separator: ".").compactMap { Int($0) }
        var major = comps.count > 0 ? comps[0] : 0
        var minor = comps.count > 1 ? comps[1] : 0
        var patch = comps.count > 2 ? comps[2] : 0
        
        switch bump {
        case .major:
            major += 1; minor = 0; patch = 0
        case .minor:
            minor += 1; patch = 0
        case .patch:
            patch += 1
        case .none:
            break
        }
        
        return "\(major).\(minor).\(patch)"
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
    @AppStorage("useSharedSkillsRoot") private var useSharedSkillsRoot = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .frame(minWidth: 600)
        // Previous implementation had these auto-generate triggers:
        // .task(id: viewModel.include) { await autoGenerateIfReady() }
        // .task(id: viewModel.bump) { await autoGenerateIfReady() }
        // .task(id: recursive) { await autoGenerateIfReady() }
        // .task(id: viewModel.existingVersion) { try? await Task.sleep(nanoseconds: 800_000_000); await autoGenerateIfReady() }
        // .task(id: viewModel.changelogNote) { try? await Task.sleep(nanoseconds: 1_200_000_000); await autoGenerateIfReady() }
        // .onReceive(NotificationCenter.default.publisher(for: .runScan)) { _ in Task { await viewModel.generate(...) } }
        // These caused immediate index generation on view appearance or settings changes, blocking UI responsiveness.
        // Index generation control is now explicit: users must click "Generate" button to trigger index creation.
        .onReceive(NotificationCenter.default.publisher(for: .cancelScan)) { _ in
            viewModel.cancel()
        }
        .onChange(of: viewModel.generateError) { _, error in
            if let error = error {
                toastMessage = ToastMessage(style: .error, message: error)
            }
        }
        .onChange(of: viewModel.generateSuccessMessage) { _, message in
            if let message = message {
                toastMessage = ToastMessage(style: .success, message: message)
            }
        }
        .toast($toastMessage)
    }
    
    // Helper to compute effective roots based on shared mode
    private func effectiveRoots() -> (codexRoots: [URL], claudeRoot: URL, codexSkillManagerRoot: URL?, copilotRoot: URL?) {
        guard useSharedSkillsRoot else {
            return (codexRoots, claudeRoot, codexSkillManagerRoot, copilotRoot)
        }
        
        // Single source of truth mode: use only first Codex root for all agents
        let masterRoot = codexRoots.first ?? claudeRoot
        return ([masterRoot], masterRoot, nil, nil)
    }
}

// MARK: - Subviews
private extension IndexView {
    @ViewBuilder
    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Primary Action Group
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        let roots = effectiveRoots()
                        Task { await viewModel.generate(codexRoots: roots.codexRoots, claudeRoot: roots.claudeRoot, codexSkillManagerRoot: roots.codexSkillManagerRoot, copilotRoot: roots.copilotRoot, recursive: recursive, excludes: excludes, excludeGlobs: excludeGlobs) }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "doc.badge.gearshape.fill")
                            }
                            Text(viewModel.isGenerating ? "Indexing…" : "Generate")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isGenerating)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help("Generate or refresh the skills index (⌘R)")
                }

                Divider()
                    .frame(height: 28)

                // Filtering Configuration
                HStack(spacing: DesignTokens.Spacing.xs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source Scope")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        Picker("", selection: $viewModel.include) {
                            Label("All", systemImage: "square.grid.2x2").tag(IndexInclude.all)
                            Label("Codex", systemImage: "cpu").tag(IndexInclude.codex)
                            Label("Claude", systemImage: "brain").tag(IndexInclude.claude)
                            Label("CSM", systemImage: "briefcase").tag(IndexInclude.codexSkillManager)
                            Label("Copilot", systemImage: "terminal").tag(IndexInclude.copilot)
                        }
                        .pickerStyle(.segmented)
                        .scaleEffect(0.9)
                        .frame(width: 300)
                    }
                    
                    Button {
                        recursive.toggle()
                    } label: {
                        Image(systemName: recursive ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.down.right.and.arrow.up.left.circle")
                            .font(.title3)
                            .foregroundStyle(recursive ? DesignTokens.Colors.Accent.green : DesignTokens.Colors.Icon.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Recursive search: \(recursive ? "On" : "Off")")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Index Version Bump")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            .textCase(.uppercase)
                        
                        Picker("", selection: $viewModel.bump) {
                            Text("No Bump").tag(IndexBump.none)
                            Text("Patch").tag(IndexBump.patch)
                            Text("Minor").tag(IndexBump.minor)
                            Text("Major").tag(IndexBump.major)
                        }
                        .pickerStyle(.segmented)
                        .scaleEffect(0.9)
                        .frame(width: 240)
                        .help("Bumps the version of the generated skills index, not individual skills")
                    }
                }

                Spacer()

                // Final Status & Meta
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if !viewModel.generatedVersion.isEmpty {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("TARGET VERSION")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            Text("v\(viewModel.generatedVersion)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Colors.Accent.blue.opacity(0.2), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("COUNT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        Text("\(viewModel.entries.count)")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                }
            }
            
            Divider()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(cleanToolbarStyle(cornerRadius: 0))
    }
    
    @ViewBuilder
    private var content: some View {
        HStack(spacing: 0) {
            // Skills list (fixed width)
            Group {
                if viewModel.isGenerating {
                    // Loading state with consistent skeleton count
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.xxs) {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonIndexRow()
                            }
                        }
                        .padding(DesignTokens.Spacing.xs)
                    }
                } else if viewModel.entries.isEmpty {
                    // Empty state using ContentUnavailableView pattern
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Ready to Index",
                        message: "Generate a consolidated skills index from your Codex and Claude roots.",
                        action: {
                            let roots = effectiveRoots()
                            Task { await viewModel.generate(codexRoots: roots.codexRoots, claudeRoot: roots.claudeRoot, codexSkillManagerRoot: roots.codexSkillManagerRoot, copilotRoot: roots.copilotRoot, recursive: recursive, excludes: excludes, excludeGlobs: excludeGlobs) }
                        },
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
        .frame(minWidth: 500)
    }
    
    private var skillsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Settings section - Using Form pattern for better structure
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        Text("Index Header Configuration")
                            .heading3()
                        Spacer()
                    }
                    .padding(.bottom, DesignTokens.Spacing.hair)
                    
                    Form {
                        Section {
                            HStack {
                                Text("Current Index Version")
                                    .help("Current version of the skills index (not individual skills)")
                                Spacer()
                                TextField("0.1.0", text: $viewModel.existingVersion)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                                HStack {
                                    Text("Changelog Note")
                                        .help("This note goes to a separate changelog file, not individual skills")
                                    Spacer()
                                }
                                TextField("Describe index changes...", text: $viewModel.changelogNote, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                            }
                            
                            // Changelog file path display
                            if !viewModel.changelogNote.isEmpty {
                                HStack(spacing: DesignTokens.Spacing.hair) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                                    Text("Will write to: \(viewModel.getChangelogDisplayPath())")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
                    .cornerRadius(DesignTokens.Radius.md)
                    .frame(height: viewModel.changelogNote.isEmpty ? 120 : 160)
                }
                .padding(.bottom, DesignTokens.Spacing.xs)
                
                // Bulk Skill Version Management Section - Using Form pattern
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundStyle(DesignTokens.Colors.Accent.orange)
                        Text("Bulk Skill Version Management")
                            .heading3()
                        Spacer()
                    }
                    .padding(.bottom, DesignTokens.Spacing.hair)
                    
                    Form {
                        Section {
                            HStack {
                                Text("Skill Version Bump")
                                    .help("Bumps the version in each individual SKILL.md file")
                                Spacer()
                                Picker("Bump Type", selection: $viewModel.skillVersionBump) {
                                    Text("None").tag(IndexBump.none)
                                    Text("Patch").tag(IndexBump.patch)
                                    Text("Minor").tag(IndexBump.minor)
                                    Text("Major").tag(IndexBump.major)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if !viewModel.entries.isEmpty {
                                        Text("Will update \(viewModel.entries.count) skill files")
                                            .font(.caption2)
                                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    Task { 
                                        await viewModel.bumpAllSkillVersions(
                                            codexRoots: codexRoots,
                                            claudeRoot: claudeRoot,
                                            codexSkillManagerRoot: codexSkillManagerRoot,
                                            copilotRoot: copilotRoot,
                                            recursive: recursive,
                                            excludes: excludes,
                                            excludeGlobs: excludeGlobs
                                        )
                                    }
                                } label: {
                                    HStack(spacing: DesignTokens.Spacing.hair) {
                                        if viewModel.isUpdatingSkillVersions {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.up.circle.fill")
                                        }
                                        Text(viewModel.isUpdatingSkillVersions ? "Updating..." : "Bump All")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .disabled(viewModel.skillVersionBump == .none || viewModel.isUpdatingSkillVersions)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .help("Update version in all SKILL.md frontmatter blocks")
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
                    .cornerRadius(DesignTokens.Radius.md)
                    .frame(height: 100)
                }
                .padding(.bottom, DesignTokens.Spacing.xs)
                
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
                    .buttonStyle(.clean)
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
                    .buttonStyle(.cleanProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(cleanToolbarStyle(cornerRadius: 12))

                MarkdownPreviewView(content: preview)
                    .id(viewModel.selectedPath ?? "generated-preview")
                    .background(DesignTokens.Colors.Background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    .padding(DesignTokens.Spacing.xs)
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
}
}

// MARK: - Actions
private extension IndexView {
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