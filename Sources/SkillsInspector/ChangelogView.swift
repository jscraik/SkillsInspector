import SwiftUI
import SkillsCore

struct ChangelogView: View {
    @ObservedObject var viewModel: ChangelogViewModel

    var body: some View {
        ZStack {
            DesignTokens.Colors.Background.secondary.opacity(0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                premiumHeader
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        if viewModel.generatedMarkdown.isEmpty {
                            emptyState
                        } else {
                            changelogPreviewCard
                        }
                        
                        ledgerTimelineSection
                    }
                    .padding(DesignTokens.Spacing.md)
                }
            }
        }
        .task {
            await viewModel.refreshEvents()
        }
    }

    private var premiumHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Release Management")
                        .font(.system(size: 14, weight: .black))
                    Text("Generate App Store assets from local history")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
                
                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        openChangelog()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.clean)
                    
                    Button {
                        Task { await viewModel.generateChangelog() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text("Generate")
                        }
                        .fontWeight(.bold)
                    }
                    .buttonStyle(.cleanProminent)
                    .tint(DesignTokens.Colors.Accent.blue)
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.Background.primary.opacity(0.8))
            
            if let path = viewModel.changelogPath {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10))
                    Text(path.lastPathComponent)
                        .font(.system(size: 10, design: .monospaced))
                    Spacer()
                    if let message = viewModel.statusMessage {
                        Text(message)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.Accent.green)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 4)
                .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }
            
            Divider()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                .symbolEffect(.bounce, options: .nonRepeating, value: viewModel.isLoading)
            
            VStack(spacing: 4) {
                Text("No Release Notes Generated")
                    .font(.headline)
                Text("Analyze your local skill ledger to automatically produce release notes for your next deployment.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            
            Button {
                Task { await viewModel.generateChangelog() }
            } label: {
                Text("Analyze Ledger History")
                    .fontWeight(.bold)
            }
            .buttonStyle(.cleanProminent)
            .tint(DesignTokens.Colors.Accent.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
        .cornerRadius(DesignTokens.Radius.lg)
    }

    private var changelogPreviewCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Label("PROPOSED RELEASE NOTES", systemImage: "text.quote")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                
                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Button {
                        viewModel.saveChangelog()
                    } label: {
                        Label("Save File", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.clean)
                    .foregroundStyle(DesignTokens.Colors.Status.success)
                    
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                    }
                    .buttonStyle(.clean)
                    .help("Copy to clipboard")
                }
            }
            
            MarkdownPreviewView(content: viewModel.generatedMarkdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.Background.primary)
                .cornerRadius(DesignTokens.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
                )
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
        .cornerRadius(DesignTokens.Radius.lg)
    }

    private var ledgerTimelineSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Label("LOCAL LEDGER TIMELINE", systemImage: "clock.arrow.2.circlepath")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                
                Spacer()
                
                Button {
                    Task { await viewModel.refreshEvents() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
            }
            
            if viewModel.events.isEmpty {
                Text("No activity recorded in the skill ledger.")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.events.enumerated()), id: \.offset) { index, event in
                        LedgerEventRowView(event: event, isLast: index == viewModel.events.count - 1)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
                .cornerRadius(DesignTokens.Radius.md)
            }
        }
    }

    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(viewModel.generatedMarkdown, forType: .string)
        viewModel.statusMessage = "Copied text to clipboard"
        #endif
    }

    private func openChangelog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.title = "Open Changelog"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadChangelog(from: url)
        }
    }
}

struct ChangelogView_Previews: PreviewProvider {
    static var previews: some View {
        ChangelogView(viewModel: ChangelogViewModel(ledger: nil))
    }
}
