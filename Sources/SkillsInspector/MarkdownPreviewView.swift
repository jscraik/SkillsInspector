import MarkdownUI
import SwiftUI

/// SwiftUI-native Markdown renderer with a guarded fallback for very large documents.
struct MarkdownPreviewView: View {
    let content: String

    @State private var parsed: MarkdownContent?
    @State private var isLarge = false
    private let largeThreshold = 50_000 // characters; beyond this use plain text to avoid known perf issues.

    var body: some View { contentView.task(id: content) { await prepare() } }

    @ViewBuilder
    private var contentView: some View {
        if isLarge {
            fallbackView(title: "Large document", detail: "Showing plain text to keep scrolling responsive.")
        } else if let parsed {
            ScrollView([.vertical, .horizontal]) {
                Markdown(parsed)
                    .markdownTheme(Self.theme)
                    .frame(minWidth: 1200, maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(DesignTokens.Colors.Background.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
        } else {
            ProgressView("Rendering…")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
        }
    }

    private func fallbackView(title: String, detail: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(DesignTokens.Colors.Background.primary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    private func prepare() async {
        let stripped = stripFrontmatter(content)
        await MainActor.run {
            // Reset cached state whenever the bound content changes (task is keyed by `content`)
            // so the preview always reflects the newly selected skill.
            self.parsed = nil
            self.isLarge = false
        }
        if stripped.count > largeThreshold {
            isLarge = true
            return
        }
        let parsedContent = MarkdownContent(stripped)
        await MainActor.run {
            self.parsed = parsedContent
        }
    }

    private func stripFrontmatter(_ markdown: String) -> String {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return markdown }
        // Find closing --- and drop frontmatter block.
        if let endIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            let body = lines[(endIndex + 1)...]
            return body.joined(separator: "\n")
        }
        return markdown
    }

    private static let theme: Theme = {
        Theme.docC
    }()
}
