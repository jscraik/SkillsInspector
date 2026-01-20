import SwiftUI
import SkillsCore

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(DesignTokens.Colors.Icon.accent)
                Text("Keyboard Shortcuts")
                    .heading2()
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(.bar)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Scanning section
                    shortcutSection(title: "Scanning", icon: "magnifyingglass", color: DesignTokens.Colors.Accent.blue) {
                        shortcutRow(key: "⌘R", description: "Run scan")
                        shortcutRow(key: "⌘.", description: "Cancel scan")
                        shortcutRow(key: "⇧⌘W", description: "Toggle watch mode")
                    }
                    
                    // Navigation section
                    shortcutSection(title: "Navigation", icon: "arrow.up.arrow.down", color: DesignTokens.Colors.Accent.purple) {
                        shortcutRow(key: "↑↓", description: "Navigate findings")
                        shortcutRow(key: "⌘F", description: "Focus search")
                        shortcutRow(key: "⎋", description: "Clear filters")
                    }
                    
                    // Actions section
                    shortcutSection(title: "Actions", icon: "bolt.fill", color: DesignTokens.Colors.Accent.orange) {
                        shortcutRow(key: "⌘↩", description: "Open in editor")
                        shortcutRow(key: "⇧⌘O", description: "Show in Finder")
                        shortcutRow(key: "⇧⌘B", description: "Add to baseline")
                    }
                    
                    // Window section
                    shortcutSection(title: "Window", icon: "macwindow", color: DesignTokens.Colors.Accent.green) {
                        shortcutRow(key: "⌘,", description: "Open Settings")
                        shortcutRow(key: "⌘?", description: "Show this help")
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(DesignTokens.Colors.Background.secondary)
        }
        .frame(width: 520, height: 500)
    }
    
    @ViewBuilder
    private func shortcutSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .heading3()
            }
            .padding(.bottom, DesignTokens.Spacing.hair)
            
            VStack(spacing: DesignTokens.Spacing.hair) {
                content()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .cardStyle(tint: color)
    }
    
    private func shortcutRow(key: String, description: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .padding(.vertical, DesignTokens.Spacing.hair)
                .background(DesignTokens.Colors.Background.tertiary)
                .cornerRadius(DesignTokens.Radius.sm)
                .frame(minWidth: 60, alignment: .center)
            
            Text(description)
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
            
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.hair)
    }
}

struct KeyboardShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardShortcutsView()
    }
}
