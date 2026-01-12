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
    @State private var toastMessage: ToastMessage? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Header Card
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: finding.severity.icon)
                            .foregroundStyle(finding.severity.color)
                            .font(.title2)
                        Text(finding.severity.rawValue.uppercased())
                            .captionText(emphasis: true)
                            .foregroundStyle(finding.severity.color)
                            .padding(.horizontal, DesignTokens.Spacing.xxxs)
                            .padding(.vertical, DesignTokens.Spacing.hair)
                            .background(finding.severity.color.opacity(0.15))
                            .cornerRadius(DesignTokens.Radius.sm)
                    }
                    
                    Text(finding.ruleID)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Divider()
                    
                    // Message
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair + DesignTokens.Spacing.micro) {
                        Text("Message")
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .textCase(.uppercase)
                        Text(finding.message)
                            .bodyText()
                            .textSelection(.enabled)
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: finding.severity.color.opacity(0.08)))
                
                // Details Card
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        Text("Details")
                            .heading3()
                    }
                    
                    Divider()
                    
                    detailRow(icon: finding.agent.icon, label: "Agent", value: finding.agent.rawValue.capitalized, color: finding.agent.color)
                    detailRow(icon: "doc", label: "File", value: finding.fileURL.lastPathComponent)
                    detailRow(icon: "folder", label: "Path", value: finding.fileURL.deletingLastPathComponent().path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    if let line = finding.line {
                        detailRow(icon: "number", label: "Line", value: "\(line)")
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: DesignTokens.Colors.Accent.blue.opacity(0.06)))
                
                // Markdown Preview Card (only for .md files)
                if finding.fileURL.pathExtension.lowercased() == "md" {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(DesignTokens.Colors.Accent.purple)
                            Text("Markdown Preview")
                                .heading3()
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
                                    .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.md, tint: DesignTokens.Colors.Accent.purple.opacity(0.06)))
                            } else {
                                ProgressView("Loading...")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.xs)
                    .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: DesignTokens.Colors.Accent.purple.opacity(0.05)))
                    .onAppear {
                        loadMarkdownContent()
                    }
                }
                
                // Suggested Fix Card (if available)
                if let fix = finding.suggestedFix {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(DesignTokens.Colors.Accent.green)
                            Text("Suggested Fix")
                                .heading3()
                        }
                        
                        Divider()
                        
                        Text(fix.description)
                            .bodyText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        
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
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    }
                    .padding(DesignTokens.Spacing.xs)
                    .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: DesignTokens.Colors.Accent.blue.opacity(0.06)))
                }
                
                // Actions Card
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(DesignTokens.Colors.Accent.orange)
                        Text("Actions")
                            .heading3()
                    }
                    
                    Divider()
                    
                    VStack(spacing: DesignTokens.Spacing.xxxs) {
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
                .padding(DesignTokens.Spacing.xs)
                .background(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: DesignTokens.Colors.Accent.orange.opacity(0.06)))
            }
            .padding(DesignTokens.Spacing.xs)
        }
        .toast($toastMessage)
    }

    private func detailRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.xxxs) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .font(.callout)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                Text(label)
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
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
            toastMessage = ToastMessage(style: .success, message: "Added to baseline")
        } catch {
            toastMessage = ToastMessage(style: .error, message: "Failed to add to baseline")
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
            toastMessage = ToastMessage(style: .success, message: "Fix applied successfully! Re-scan to verify.")
        case .failed(let error):
            toastMessage = ToastMessage(style: .error, message: "Failed to apply fix: \(error)")
        case .notApplicable:
            toastMessage = ToastMessage(style: .warning, message: "Fix is not applicable to current file state.")
        }
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: finding.severity.icon)
                    .foregroundStyle(finding.severity.color)
                    .font(.title2)
                Text(finding.severity.rawValue.uppercased())
                    .captionText(emphasis: true)
                    .foregroundStyle(finding.severity.color)
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(finding.severity.color.opacity(0.15))
                    .cornerRadius(DesignTokens.Radius.sm)
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
                .buttonStyle(.customGlass)
                .controlSize(.large)
                
                HStack(spacing: 8) {
                    Button {
                        FindingActions.showInFinder(finding.fileURL)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.customGlass)
                    
                    Button {
                        addToBaseline()
                    } label: {
                        Label("Add to Baseline", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.customGlassProminent)
                }
            }
        }
        .cardStyle(tint: DesignTokens.Colors.Accent.orange)
    }
}
