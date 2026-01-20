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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                headerCard
                messageCard
                detailsCard
                
                if finding.fileURL.pathExtension.lowercased() == "md" {
                    markdownCard
                }
                
                if finding.suggestedFix != nil {
                    suggestedFixCard
                }
                
                actionsCard
            }
            .padding(DesignTokens.Spacing.sm)
        }
        .task(id: finding.fileURL) {
            await loadMarkdownContent()
        }
        .toast($toastMessage)
    }

    // MARK: - Cards
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: finding.severity.icon)
                    .foregroundStyle(finding.severity.color)
                    .font(.title2)
                Text(finding.severity.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(finding.severity.color)
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, 2)
                    .background(finding.severity.color.opacity(0.15))
                    .cornerRadius(DesignTokens.Radius.sm)
                
                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: finding.agent.icon)
                    Text(finding.agent.displayName.uppercased())
                }
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(finding.agent.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(finding.agent.color.opacity(0.1))
                .cornerRadius(DesignTokens.Radius.sm)
            }
            
            Text(finding.ruleID)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(finding.severity.color.opacity(0.2), lineWidth: 1)
        )
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Finding Message")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .textCase(.uppercase)
            
            Text(finding.message)
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
        .cornerRadius(DesignTokens.Radius.md)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                Text("Metadata Details")
                    .heading3()
            }
            
            VStack(spacing: 1) {
                detailRow(icon: "doc.text", label: "File", value: finding.fileURL.lastPathComponent)
                detailRow(icon: "folder", label: "Path", value: finding.fileURL.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                if let line = finding.line {
                    detailRow(icon: "text.alignleft", label: "Line", value: "\(line)")
                }
            }
            .padding(4)
            .background(DesignTokens.Colors.Background.tertiary.opacity(0.3))
            .cornerRadius(DesignTokens.Radius.sm)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
        .cornerRadius(DesignTokens.Radius.md)
    }

    private var markdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(DesignTokens.Colors.Accent.purple)
                Text("Markdown Preview")
                    .heading3()
                Spacer()
                Toggle("", isOn: $showPreview)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            
            if showPreview {
                if let content = markdownContent {
                    MarkdownPreviewView(content: content)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 200, maxHeight: 400)
                        .background(DesignTokens.Colors.Background.primary)
                        .cornerRadius(DesignTokens.Radius.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Accent.purple.opacity(0.05))
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Colors.Accent.purple.opacity(0.1), lineWidth: 1)
        )
    }

    private var suggestedFixCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fix = finding.suggestedFix {
                HStack {
                    Label("Suggested Fix", systemImage: "wand.and.stars")
                        .heading3()
                        .foregroundStyle(DesignTokens.Colors.Accent.green)
                    
                    Spacer()
                    
                    if fix.automated {
                        Text("Automated")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.Accent.green.opacity(0.2))
                            .foregroundStyle(DesignTokens.Colors.Accent.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(fix.description)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                
                if !fix.changes.isEmpty {
                    FixDiffView(changes: fix.changes)
                        .frame(maxHeight: 300)
                        .cornerRadius(DesignTokens.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
                        )
                }

                if fix.automated {
                    Button {
                        applyFix(fix)
                    } label: {
                        Label("Apply Correction", systemImage: "magicmouse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.cleanProminent)
                    .tint(DesignTokens.Colors.Accent.green)
                    .controlSize(.large)
                } else {
                    HStack {
                        Image(systemName: "hand.point.up.fill")
                        Text("Manual intervention required")
                    }
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Accent.green.opacity(0.03))
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Colors.Accent.green.opacity(0.15), lineWidth: 1)
        )
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Quick Actions", systemImage: "bolt.fill")
                    .heading3()
                    .foregroundStyle(DesignTokens.Colors.Accent.orange)
                Spacer()
            }
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    FindingActions.openInEditor(finding.fileURL, line: finding.line)
                } label: {
                    Label("Open Editor", systemImage: "pencil.and.outline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.clean)
                
                Button {
                    addToBaseline()
                } label: {
                    Label("Add to Baseline", systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.clean)
                
                Button {
                    FindingActions.showInFinder(finding.fileURL)
                } label: {
                    Label("Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.clean)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Accent.orange.opacity(0.05))
        .cornerRadius(DesignTokens.Radius.md)
    }

    // MARK: - Helpers
    private func detailRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 10))
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .frame(width: 40, alignment: .leading)
            
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.vertical, 4)
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
            toastMessage = ToastMessage(style: .success, message: "Added finding to baseline")
        } catch {
            toastMessage = ToastMessage(style: .error, message: "Failed to update baseline")
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
            toastMessage = ToastMessage(style: .success, message: "Fix applied! Re-scan to verify.")
        case .failed(let error):
            toastMessage = ToastMessage(style: .error, message: "Fix failed: \(error)")
        case .notApplicable:
            toastMessage = ToastMessage(style: .warning, message: "File state changed, fix no longer applicable.")
        }
    }
    
    private func loadMarkdownContent() async {
        guard finding.fileURL.pathExtension.lowercased() == "md" else {
            await MainActor.run {
                markdownContent = nil
            }
            return
        }
        do {
            let content = try String(contentsOf: finding.fileURL, encoding: .utf8)
            await MainActor.run {
                markdownContent = content
            }
        } catch {
            await MainActor.run {
                markdownContent = "*Error loading source file.*"
            }
        }
    }
}

// MARK: - FixDiffView
struct FixDiffView: View {
    let changes: [FileChange]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(changes, id: \.self) { change in
                VStack(alignment: .leading, spacing: 0) {
                    let oldLines = change.originalText.components(separatedBy: .newlines)
                    let newLines = change.replacementText.components(separatedBy: .newlines)
                    
                    ForEach(oldLines.indices, id: \.self) { i in
                        diffLine(text: oldLines[i], type: .deleted, line: change.startLine + i)
                    }
                    
                    ForEach(newLines.indices, id: \.self) { i in
                        diffLine(text: newLines[i], type: .added, line: change.startLine + i)
                    }
                }
                if change != changes.last {
                    Divider()
                }
            }
        }
        .padding(6)
        .background(DesignTokens.Colors.Background.primary)
    }
    
    private enum LineType {
        case added, deleted
        var prefix: String { self == .added ? "+" : "-" }
        var color: Color { self == .added ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Status.error }
        var background: Color { color.opacity(0.12) }
    }
    
    private func diffLine(text: String, type: LineType, line: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(line)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                .frame(width: 24, alignment: .trailing)
            
            Text(type.prefix)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(type.color)
            
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
        .background(type.background)
    }
}
