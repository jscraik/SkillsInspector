import SwiftUI

struct IndexPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Index mode (coming soon)")
                .font(.title3)
                .bold()
            Text("Generate a consolidated Skills.md from Codex/Claude roots with optional SemVer bump and changelog.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
