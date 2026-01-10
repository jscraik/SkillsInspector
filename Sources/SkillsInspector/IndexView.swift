import SwiftUI
import SkillsCore

@MainActor
final class IndexViewModel: ObservableObject {
    @Published var entries: [SkillIndexEntry] = []
    @Published var isGenerating = false
    @Published var include: IndexInclude = .both
    @Published var recursive = false
    @Published var bump: IndexBump = .none
    @Published var changelogNote = ""
    @Published var generatedMarkdown = ""
    @Published var generatedVersion = ""
    @Published var existingVersion = ""
    @Published var expandedSkills: Set<String> = []
    
    func generate(codexRoots: [URL], claudeRoot: URL) async {
        isGenerating = true
        
        let codexRoot = codexRoots.first
        let claude = claudeRoot
        let includeFilter = include
        let recursiveFlag = recursive
        let bumpType = bump
        let changelog = changelogNote
        let existingVer = existingVersion.isEmpty ? nil : existingVersion
        
        let result = await Task(priority: .userInitiated) {
            if Task.isCancelled { return ([SkillIndexEntry](), "", "") }
            let entries = SkillIndexer.generate(
                codexRoot: codexRoot,
                claudeRoot: claude,
                include: includeFilter,
                recursive: recursiveFlag,
                maxDepth: nil,
                excludes: [".git", ".system", "__pycache__", ".DS_Store"],
                excludeGlobs: []
            )
            
            let (version, markdown) = SkillIndexer.renderMarkdown(
                entries: entries,
                existingVersion: existingVer,
                bump: bumpType,
                changelogNote: changelog.isEmpty ? nil : changelog
            )
            
            return (entries, version, markdown)
        }.value
        if Task.isCancelled {
            isGenerating = false
            return
        }
        
        entries = result.0
        generatedVersion = result.1
        generatedMarkdown = result.2
        isGenerating = false
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
}

struct IndexView: View {
    @ObservedObject var viewModel: IndexViewModel
    let codexRoots: [URL]
    let claudeRoot: URL
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
    }
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.generate(codexRoots: codexRoots, claudeRoot: claudeRoot) }
            } label: {
                Label(viewModel.isGenerating ? "Generating…" : "Generate", systemImage: "doc.badge.gearshape")
            }
            .disabled(viewModel.isGenerating)
            .buttonStyle(.borderedProminent)
            
            Divider()
                .frame(height: 20)
            
            Picker("Include", selection: $viewModel.include) {
                Text("Both").tag(IndexInclude.both)
                Text("Codex").tag(IndexInclude.codex)
                Text("Claude").tag(IndexInclude.claude)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Toggle("Recursive", isOn: $viewModel.recursive)
                .toggleStyle(.switch)
                .controlSize(.small)
            
            Divider()
                .frame(height: 20)
            
            Picker("Bump", selection: $viewModel.bump) {
                Text("None").tag(IndexBump.none)
                Text("Patch").tag(IndexBump.patch)
                Text("Minor").tag(IndexBump.minor)
                Text("Major").tag(IndexBump.major)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Spacer()
            
            if !viewModel.generatedVersion.isEmpty {
                Text("v\(viewModel.generatedVersion)")
                    .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.weight, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tertiary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text("\(viewModel.entries.count) skills")
                .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.weight))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: .regular))
    }
    
    private var content: some View {
        HStack(spacing: 0) {
            // Skills list (fixed width)
            Group {
                if viewModel.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating index...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.entries.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Ready to Index",
                        message: "Generate a consolidated skills index from your Codex and Claude roots.",
                        action: { Task { await viewModel.generate(codexRoots: codexRoots, claudeRoot: claudeRoot) } },
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
    }
    
    private var skillsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Settings section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Existing Version:")
                                .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: DesignTokens.Typography.BodySmall.weight))
                                .foregroundStyle(.secondary)
                            TextField("0.1.0", text: $viewModel.existingVersion)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Changelog Note:")
                                .font(.system(size: DesignTokens.Typography.BodySmall.size, weight: DesignTokens.Typography.BodySmall.weight))
                                .foregroundStyle(.secondary)
                            TextField("Added new skills", text: $viewModel.changelogNote)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(16)
                    .cardStyle()
                }
                
                // Codex skills section
                if !viewModel.entries.filter({ $0.agent == .codex }).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.blue)
                            Text("Codex Skills")
                                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
                            Text("(\(viewModel.entries.filter { $0.agent == .codex }.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        ForEach(viewModel.entries.filter { $0.agent == .codex }, id: \.path) { entry in
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
                                }
                            )
                        }
                    }
                }
                
                // Claude skills section
                if !viewModel.entries.filter({ $0.agent == .claude }).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundStyle(.purple)
                            Text("Claude Skills")
                                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
                            Text("(\(viewModel.entries.filter { $0.agent == .claude }.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        ForEach(viewModel.entries.filter { $0.agent == .claude }, id: \.path) { entry in
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
                                }
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var markdownPreview: some View {
        VStack(spacing: 0) {
            if viewModel.generatedMarkdown.isEmpty {
                emptyPreviewState
            } else {
                // Header with actions
                HStack {
                    Text("Markdown Preview")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.copyMarkdown()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        viewModel.saveMarkdown()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
                
                // Markdown content
                MarkdownPreviewView(content: viewModel.generatedMarkdown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Markdown Generated")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Generate an index to see the markdown preview")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
