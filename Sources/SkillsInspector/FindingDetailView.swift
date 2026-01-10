import SwiftUI
import SkillsCore

struct FindingDetailView: View {
    let finding: Finding
    @State private var showingBaselineSuccess = false
    @State private var baselineMessage = ""
    @State private var showingFixResult = false
    @State private var fixResultMessage = ""
    @State private var fixSucceeded = false
    @State private var showPreview = false
    @State private var markdownContent: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: finding.severity.icon)
                            .foregroundStyle(finding.severity.color)
                            .font(.title2)
                        Text(finding.severity.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(finding.severity.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(finding.severity.color.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(finding.ruleID)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Divider()
                    
                    // Message
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Message")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(finding.message)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding(16)
                .background(DesignTokens.Colors.Background.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                
                // Details Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Details")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    detailRow(icon: finding.agent.icon, label: "Agent", value: finding.agent.rawValue.capitalized, color: finding.agent.color)
                    detailRow(icon: "doc", label: "File", value: finding.fileURL.lastPathComponent)
                    detailRow(icon: "folder", label: "Path", value: finding.fileURL.deletingLastPathComponent().path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    if let line = finding.line {
                        detailRow(icon: "number", label: "Line", value: "\(line)")
                    }
                }
                .padding(16)
                .background(DesignTokens.Colors.Background.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                
                // Markdown Preview Card (only for .md files)
                if finding.fileURL.pathExtension.lowercased() == "md" {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.purple)
                            Text("Markdown Preview")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $showPreview)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        
                        if showPreview {
                            Divider()
                            
                            if let content = markdownContent {
                                MarkdownPreviewView(content: content)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 400)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(8)
                            } else {
                                ProgressView("Loading...")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                            }
                        }
                    }
                    .padding(16)
                    .background(DesignTokens.Colors.Background.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .onAppear {
                        loadMarkdownContent()
                    }
                }
                
                // Suggested Fix Card (if available)
                if let fix = finding.suggestedFix {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.green)
                            Text("Suggested Fix")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        Text(fix.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        if fix.automated {
                            Button {
                                applyFix(fix)
                            } label: {
                                Label("Apply Fix Automatically", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            Label("Manual fix required - open in editor", systemImage: "hand.point.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(DesignTokens.Colors.Background.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                
                // Actions Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                        Text("Actions")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        Menu {
                            ForEach(EditorIntegration.installedEditors, id: \.self) { editor in
                                Button {
                                    FindingActions.openInEditor(finding.fileURL, line: finding.line, editor: editor)
                                } label: {
                                    Label(editor.rawValue, systemImage: editor.icon)
                                }
                            }
                        } label: {
                            Label("Open in Editor", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        } primaryAction: {
                            FindingActions.openInEditor(finding.fileURL, line: finding.line)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        HStack(spacing: 8) {
                            Button {
                                FindingActions.showInFinder(finding.fileURL)
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                addToBaseline()
                            } label: {
                                Label("Add to Baseline", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(16)
                .background(DesignTokens.Colors.Background.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .padding(20)
        }
        .alert("Baseline Updated", isPresented: $showingBaselineSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(baselineMessage)
        }
        .alert(fixSucceeded ? "Fix Applied" : "Fix Failed", isPresented: $showingFixResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(fixResultMessage)
        }
    }

    private func detailRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .font(.callout)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.callout, design: label == "File" || label == "Path" ? .monospaced : .default))
                    .textSelection(.enabled)
            }
        }
    }
    
    private func addToBaseline() {
        let baselineURL: URL
        if let repoRoot = findRepoRoot(from: finding.fileURL) {
            baselineURL = repoRoot.appendingPathComponent(".skillsctl/baseline.json")
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            baselineURL = home.appendingPathComponent(".skillsctl/baseline.json")
        }
        
        do {
            try FindingActions.addToBaseline(finding, baselineURL: baselineURL)
            baselineMessage = "Added to baseline:\n\(baselineURL.path)"
            showingBaselineSuccess = true
        } catch {
            baselineMessage = "Failed to add to baseline:\n\(error.localizedDescription)"
            showingBaselineSuccess = true
        }
    }
    
    private func findRepoRoot(from url: URL) -> URL? {
        var current = url.deletingLastPathComponent()
        while current.path != "/" {
            let gitPath = current.appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: gitPath) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
    
    private func applyFix(_ fix: SuggestedFix) {
        let result = FixEngine.applyFix(fix)
        switch result {
        case .success:
            fixSucceeded = true
            fixResultMessage = "Fix applied successfully! Re-scan to verify."
        case .failed(let error):
            fixSucceeded = false
            fixResultMessage = "Failed to apply fix:\n\(error)"
        case .notApplicable:
            fixSucceeded = false
            fixResultMessage = "Fix is not applicable to current file state."
        }
        showingFixResult = true
    }
    
    private func loadMarkdownContent() {
        Task {
            do {
                let content = try String(contentsOf: finding.fileURL, encoding: .utf8)
                await MainActor.run {
                    markdownContent = content
                }
            } catch {
                await MainActor.run {
                    markdownContent = "**Error loading file:** \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Cards
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: finding.severity.icon)
                    .foregroundStyle(finding.severity.color)
                    .font(.title2)
                Text(finding.severity.rawValue.uppercased())
                    .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.weight))
                    .fontWeight(.bold)
                    .foregroundStyle(finding.severity.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(finding.severity.color.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text(finding.ruleID)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.medium)
        }
        .cardStyle(tint: finding.severity.color)
    }
    
    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Message")
                .font(.system(size: DesignTokens.Typography.Caption.size, weight: DesignTokens.Typography.Caption.weight))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(finding.message)
                .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.weight))
                .textSelection(.enabled)
        }
        .cardStyle()
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Details")
                    .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            }
            detailRow(icon: finding.agent.icon, label: "Agent", value: finding.agent.rawValue.capitalized, color: finding.agent.color)
            detailRow(icon: "doc", label: "File", value: finding.fileURL.lastPathComponent)
            detailRow(icon: "folder", label: "Path", value: finding.fileURL.deletingLastPathComponent().path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
            if let line = finding.line {
                detailRow(icon: "number", label: "Line", value: "\(line)")
            }
        }
        .cardStyle()
    }
    
    private var markdownCard: some View {
        Group {
            if finding.fileURL.pathExtension.lowercased() == "md" {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(DesignTokens.Colors.Accent.purple)
                        Text("Markdown Preview")
                            .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
                        Spacer()
                        Toggle("", isOn: $showPreview)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    
                    if showPreview {
                        if let content = markdownContent {
                            MarkdownPreviewView(content: content)
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                                .background(DesignTokens.Colors.Background.secondary)
                                .cornerRadius(DesignTokens.Radius.md)
                        } else {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                    }
                }
                .onAppear { loadMarkdownContent() }
                .cardStyle()
            }
        }
    }
    
    private var suggestedFixCard: some View {
        Group {
            if let fix = finding.suggestedFix {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(.green)
                        Text("Suggested Fix")
                            .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
                    }
                    
                    Text(fix.description)
                        .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.weight))
                        .foregroundStyle(.secondary)
                    
                    if fix.automated {
                        Button {
                            applyFix(fix)
                        } label: {
                            Label("Apply Fix Automatically", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Label("Manual fix required - open in editor", systemImage: "hand.point.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle(tint: DesignTokens.Colors.Accent.blue)
            }
        }
    }
    
    private var actionsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                Text("Actions")
                    .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            }
            
            VStack(spacing: 8) {
                Menu {
                    ForEach(EditorIntegration.installedEditors, id: \.self) { editor in
                        Button {
                            FindingActions.openInEditor(finding.fileURL, line: finding.line, editor: editor)
                        } label: {
                            Label(editor.rawValue, systemImage: editor.icon)
                        }
                    }
                } label: {
                    Label("Open in Editor", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                } primaryAction: {
                    FindingActions.openInEditor(finding.fileURL, line: finding.line)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                HStack(spacing: 8) {
                    Button {
                        FindingActions.showInFinder(finding.fileURL)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        addToBaseline()
                    } label: {
                        Label("Add to Baseline", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardStyle(tint: DesignTokens.Colors.Accent.orange)
    }
}
