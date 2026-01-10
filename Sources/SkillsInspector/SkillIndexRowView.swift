import SwiftUI
import SkillsCore

struct SkillIndexRowView: View {
    let entry: SkillIndexEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onToggle()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isExpanded ? 0.15 : 0.08), radius: isExpanded ? 8 : 4, y: isExpanded ? 4 : 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isExpanded ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .scaleEffect((isHovered && !isExpanded && !reduceMotion) ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
    
    private var cardBackground: some View {
        Group {
            if isExpanded {
                LinearGradient(
                    colors: [
                        entry.agent == .codex ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1),
                        DesignTokens.Colors.Background.primary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                DesignTokens.Colors.Background.primary
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Skill name and agent icon
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(entry.agent == .codex ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: entry.agent == .codex ? "cpu" : "brain")
                            .font(.system(size: 18))
                            .foregroundStyle(entry.agent == .codex ? .blue : .purple)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.system(.title3, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    
                    if !entry.description.isEmpty {
                        Text(entry.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isHovered && !isExpanded ? 180 : 0))
            }
            
            // Bottom badges
            HStack(spacing: 8) {
                // Agent badge
                Label(entry.agent.rawValue.capitalized, systemImage: entry.agent == .codex ? "cpu" : "brain")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(entry.agent == .codex ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(entry.agent == .codex ? .blue : .purple)
                    .cornerRadius(6)
                
                // File location badge
                Label(URL(fileURLWithPath: entry.path).lastPathComponent, systemImage: "doc.text")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray).opacity(0.15))
                    .foregroundStyle(.secondary)
                    .cornerRadius(6)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Expanded actions
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Path display
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(entry.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.systemGray).opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("Reveal", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Menu {
                            ForEach(EditorIntegration.installedEditors, id: \.self) { editor in
                                Button {
                                    EditorIntegration.openFile(URL(fileURLWithPath: entry.path), line: nil, editor: editor)
                                } label: {
                                    Label(editor.rawValue, systemImage: editor.icon)
                                }
                            }
                        } label: {
                            Label("Open", systemImage: "pencil")
                                .font(.caption)
                        } primaryAction: {
                            EditorIntegration.openFile(URL(fileURLWithPath: entry.path), line: nil, editor: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(entry.path, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
    }
}
