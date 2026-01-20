import MarkdownUI
import SwiftUI

/// SwiftUI-native Markdown renderer with a guarded fallback for very large documents.
struct MarkdownPreviewView: View {
    let content: String
    let minContentWidth: CGFloat

    @State private var parsed: MarkdownContent?
    @State private var isLarge = false
    @State private var isPreparing = false
    @State private var lastProcessedFingerprint: Int?
    @State private var lastProcessedLength = 0
    private let largeThreshold = 50_000 // characters; beyond this use plain text to avoid known perf issues.

    init(content: String, minContentWidth: CGFloat = 0) {
        self.content = content
        self.minContentWidth = minContentWidth
    }

    var body: some View { contentView.task(id: content) { await prepare() } }

    @ViewBuilder
    private var contentView: some View {
        if isLarge {
            fallbackView(title: "Large document", detail: "Showing plain text to keep scrolling responsive.")
        } else if let parsed {
            ScrollView([.vertical, .horizontal]) {
                Markdown(parsed)
                    .markdownTheme(Self.theme)
                    .frame(minWidth: minContentWidth, maxWidth: .infinity, alignment: .leading)
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
        let fingerprint = stripped.hashValue
        let length = stripped.count
        let shouldSkip = await MainActor.run {
            if let lastProcessedFingerprint, lastProcessedFingerprint == fingerprint, lastProcessedLength == length {
                return true
            }
            isPreparing = true
            return false
        }
        if shouldSkip { return }

        if length > largeThreshold {
            await MainActor.run {
                isLarge = true
                parsed = nil
                lastProcessedFingerprint = fingerprint
                lastProcessedLength = length
                isPreparing = false
            }
            return
        }

        let parsedContent = MarkdownContent(stripped)
        if Task.isCancelled {
            await MainActor.run { isPreparing = false }
            return
        }
        await MainActor.run {
            isLarge = false
            parsed = parsedContent
            lastProcessedFingerprint = fingerprint
            lastProcessedLength = length
            isPreparing = false
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
