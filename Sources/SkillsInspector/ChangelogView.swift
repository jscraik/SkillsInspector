import SwiftUI
import SkillsCore

struct ChangelogView: View {
    @ObservedObject var viewModel: IndexViewModel
    @State private var changelogPath: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/skills/Skills-Changelog.md")
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(spacing: 0) {
            // Main header
            HStack(spacing: DesignTokens.Spacing.xs) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    Text("Changelog")
                        .heading2()
                    Text("App Store release notes and version history")
                        .bodySmall()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        loadChangelog()
                    } label: {
                        Label("Open…", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Open existing changelog file")

                    Button {
                        saveChangelog()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(viewModel.generatedMarkdown.isEmpty)
                    .help("Save changelog to file")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(glassBarStyle(cornerRadius: 0))
            
            // Status bar
            if let path = viewModel.changelogPath {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                    Text("Saved at: \(path.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    Spacer()
                    
                    if let statusMessage {
                        HStack(spacing: DesignTokens.Spacing.hair) {
                            Image(systemName: statusMessage.contains("failed") ? "exclamationmark.triangle" : "checkmark.circle")
                                .font(.caption2)
                                .foregroundStyle(statusMessage.contains("failed") ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Status.success)
                            Text(statusMessage)
                                .font(.caption)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxxs)
                        .padding(.vertical, DesignTokens.Spacing.hair)
                        .background(
                            (statusMessage.contains("failed") ? DesignTokens.Colors.Status.error : DesignTokens.Colors.Status.success)
                                .opacity(0.1)
                        )
                        .cornerRadius(DesignTokens.Radius.sm)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
            }
        }
    }

    private var content: some View {
        Group {
            if viewModel.generatedMarkdown.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Changelog Generated",
                    message: "Generate an index first to create changelog content. The changelog will show version history and release notes for App Store submissions.",
                    action: nil,
                    actionLabel: ""
                )
                .padding(DesignTokens.Spacing.xl)
            } else {
                VStack(spacing: 0) {
                    // Changelog content with improved styling
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            // Changelog header
                            HStack {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                                    Text("App Store Changelog")
                                        .heading3()
                                    Text("Generated from skill index")
                                        .captionText()
                                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                }
                                Spacer()
                                
                                // Copy button
                                Button {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(changelogPreview, forType: .string)
                                    statusMessage = "Copied to clipboard"
                                    #endif
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy changelog to clipboard")
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(glassBarStyle(cornerRadius: DesignTokens.Radius.lg))
                            
                            // Markdown preview with enhanced styling
                            MarkdownPreviewView(content: changelogPreview)
                                .padding(DesignTokens.Spacing.xs)
                                .background(
                                    glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: DesignTokens.Colors.Accent.blue.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                                        .stroke(DesignTokens.Colors.Border.light, lineWidth: 0.5)
                                )
                        }
                        .padding(DesignTokens.Spacing.xs)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var changelogPreview: String {
        let lines = viewModel.generatedMarkdown.split(separator: "\n", omittingEmptySubsequences: false)
        if let start = lines.firstIndex(where: { $0 == "## Changelog" }) {
            return lines[start...].joined(separator: "\n")
        }
        return "## Changelog\n(No entries yet.)"
    }

    private func saveChangelog() {
        do {
            try changelogPreview.write(to: changelogPath, atomically: true, encoding: .utf8)
            statusMessage = "Saved to \(changelogPath.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func loadChangelog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.title = "Open Changelog"
        if panel.runModal() == .OK, let url = panel.url, let data = try? String(contentsOf: url, encoding: .utf8) {
            changelogPath = url
            viewModel.generatedMarkdown = data
            statusMessage = "Loaded \(url.lastPathComponent)"
        }
    }
}

#Preview {
    ChangelogView(viewModel: IndexViewModel())
}
