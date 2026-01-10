import SwiftUI
import SkillsCore

struct SettingsView: View {
    @State private var selectedEditor: Editor = EditorIntegration.defaultEditor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    editorCard
                    detectedEditorsCard
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(DesignTokens.Colors.Background.secondary)
        }
        .frame(width: 520, height: 420)
        .onChange(of: selectedEditor) { _, newValue in
            EditorIntegration.defaultEditor = newValue
        }
    }
    
    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(.bar)
    }
    
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Label("Editor", systemImage: "pencil")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            Picker("Default Editor", selection: $selectedEditor) {
                ForEach(Editor.allCases, id: \.self) { editor in
                    HStack {
                        Image(systemName: editor.icon)
                        Text(editor.rawValue)
                        Spacer()
                        if !editor.isInstalled() {
                            Text("Not Installed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(editor)
                }
            }
            .pickerStyle(.menu)
            Text("Choose which editor to use when opening files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .cardStyle(tint: DesignTokens.Colors.Accent.blue)
    }
    
    private var detectedEditorsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Label("Detected Editors", systemImage: "checkmark.seal")
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(EditorIntegration.installedEditors, id: \.self) { editor in
                    HStack(spacing: 8) {
                        Image(systemName: editor.icon)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text(editor.rawValue)
                            .font(.callout)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                if EditorIntegration.installedEditors.count == 1 {
                    Text("Only Finder is available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .cardStyle(tint: DesignTokens.Colors.Accent.green)
    }
}
