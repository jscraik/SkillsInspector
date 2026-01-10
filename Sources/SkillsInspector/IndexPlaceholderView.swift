import SwiftUI

struct IndexPlaceholderView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue.gradient)
            }
            
            VStack(spacing: 8) {
                Text("Index Mode")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Coming Soon")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            
            VStack(spacing: 16) {
                Text("Generate a consolidated Skills.md from Codex/Claude roots with optional SemVer bump and changelog.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 450)
                
                // Feature list
                VStack(alignment: .leading, spacing: 10) {
                    featureRow(icon: "doc.badge.plus", text: "Merge skills from multiple sources")
                    featureRow(icon: "number.circle", text: "Automatic SemVer versioning")
                    featureRow(icon: "list.bullet.clipboard", text: "Generate changelog")
                    featureRow(icon: "checkmark.seal", text: "Validate skill metadata")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.tertiary.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
