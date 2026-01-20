import SwiftUI
import SkillsCore

struct SkillIndexRowView: View {
    let entry: SkillIndexEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture {
                    onSelect()
                }
                .onTapGesture(count: 2) {
                    onSelect()
                    onToggle()
                }
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
                        entry.agent.color.opacity(0.12),
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Header: Skill name and agent icon
            HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
                // Agent icon with enhanced styling
                ZStack {
                    Circle()
                        .fill(entry.agent.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(entry.agent.color.opacity(0.3), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: entry.agent.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(entry.agent.color)
                }
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                    // Skill name with better typography
                    Text(entry.name)
                        .font(.system(.title3, design: .default, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    
                    // Description with improved styling
                    if !entry.description.isEmpty {
                        Text(entry.description)
                            .font(.callout)
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    
                    // File location with enhanced styling
                    HStack(spacing: DesignTokens.Spacing.hair) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                        Text(URL(fileURLWithPath: entry.path).lastPathComponent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.6))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
                
                Spacer()
                
                // Expand/collapse indicator
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isExpanded ? entry.agent.color : DesignTokens.Colors.Icon.tertiary)
                        .rotationEffect(.degrees(isHovered && !isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse details" : "Expand details")
            }
            
            // Metadata badges with improved organization
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                // Version badge (if available)
                if let version = entry.version {
                    metadataBadge(
                        text: "v\(version)",
                        icon: "number.circle",
                        color: DesignTokens.Colors.Accent.blue
                    )
                }
                
                if entry.referencesCount > 0 {
                    metadataBadge(
                        count: entry.referencesCount,
                        label: "ref",
                        icon: "book.closed",
                        color: DesignTokens.Colors.Accent.purple
                    )
                }
                if entry.assetsCount > 0 {
                    metadataBadge(
                        count: entry.assetsCount,
                        label: "asset",
                        icon: "tray.full",
                        color: DesignTokens.Colors.Accent.blue
                    )
                }
                if entry.scriptsCount > 0 {
                    metadataBadge(
                        count: entry.scriptsCount,
                        label: "script",
                        icon: "terminal",
                        color: DesignTokens.Colors.Accent.orange
                    )
                }
                Spacer()
            }
            
            // Expanded details section
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.hair)
                    
                    // Full path display
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                        Text("Full Path")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .textCase(.uppercase)
                        
                        Text(entry.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            .textSelection(.enabled)
                            .padding(.horizontal, DesignTokens.Spacing.xxxs)
                            .padding(.vertical, DesignTokens.Spacing.xxxs)
                            .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
                            .cornerRadius(DesignTokens.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 0.5)
                            )
                    }
                    
                    // Version information
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                            Text("Skill Version")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                .textCase(.uppercase)
                            
                            Text(entry.version ?? "Not specified")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(entry.version != nil ? DesignTokens.Colors.Accent.blue : DesignTokens.Colors.Text.tertiary)
                                .fontWeight(entry.version != nil ? .semibold : .regular)
                        }
                        
                        if let modified = entry.modified {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                                Text("Last Modified")
                                    .font(.system(.caption2, weight: .semibold))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    .textCase(.uppercase)
                                
                                Text(DateFormatter.shortDateTime.string(from: modified))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Action buttons with improved styling
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Button {
                            NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("Reveal", systemImage: "folder")
                                .font(.caption)
                                .fontWeight(.medium)
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
                                .fontWeight(.medium)
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
                            Label("Copy Path", systemImage: "doc.on.doc")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignTokens.Spacing.xs)
    }
    
    private func metadataBadge(count: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.hair) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
            Text(count == 1 ? label : "\(label)s")
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignTokens.Spacing.xxxs)
        .padding(.vertical, DesignTokens.Spacing.hair)
        .background(color.opacity(0.12))
        .cornerRadius(DesignTokens.Radius.sm)
    }
    
    private func metadataBadge(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.hair) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignTokens.Spacing.xxxs)
        .padding(.vertical, DesignTokens.Spacing.hair)
        .background(color.opacity(0.12))
        .cornerRadius(DesignTokens.Radius.sm)
    }
}
