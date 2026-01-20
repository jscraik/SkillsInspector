import SwiftUI
import SkillsCore

/// Security settings UI for configuring ACIP scanner and quarantine settings
public struct SecuritySettingsView: View {
    @State private var securityConfig = SecurityConfig()
    @State private var quarantineStore = QuarantineStore()
    @State private var quarantinedCount = 0
    @State private var isLoading = false
    @State private var isHydrating = false
    @State private var allowlistDraft = ""
    @State private var blocklistDraft = ""
    @State private var isAllowlistSheetPresented = false
    @State private var isBlocklistSheetPresented = false

    private let settingsStore = SecuritySettingsStore()

    public init() {}

    public var body: some View {
        Form {
            // Preset Section
            Section {
                Picker("Security Level", selection: $securityPreset) {
                    Text("Default").tag(Preset.default)
                    Text("Permissive").tag(Preset.permissive)
                    Text("Strict").tag(Preset.strict)
                    Text("Custom").tag(Preset.custom)
                }
                .pickerStyle(.segmented)
                .onChange(of: securityPreset) { _, newValue in
                    applyPreset(newValue)
                }

                Text(presetDescription)
                    .font(.system(size: DesignTokens.Typography.BodySmall.size))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            } header: {
                Text("Security Preset")
            } footer: {
                Text("Presets configure the ACIP scanner sensitivity and allowed patterns.")
            }

            // Scan Configuration
            Section {
                Toggle("Scan Code Blocks", isOn: $securityConfig.scanCodeBlocks)
                Toggle("Scan References", isOn: $securityConfig.scanReferences)

                HStack {
                    Text("Max File Size")
                    Spacer()
                    Text("\(formatFileSize(securityConfig.maxFileSize))")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                Stepper("Max File Size: \(formatFileSize(securityConfig.maxFileSize))",
                        value: $securityConfig.maxFileSize,
                        in: 1024...10*1024*1024,
                        step: 1024*1024)
                .font(.system(size: DesignTokens.Typography.Body.size))
            } header: {
                Text("Scan Configuration")
            } footer: {
                Text("Configure which content types to scan and file size limits.")
            }

            // Pattern Configuration
            Section {
                List {
                    ForEach(ACIPScanner.InjectionPattern.builtInPatterns, id: \.id) { pattern in
                        HStack {
                            Toggle(isOn: bindingForPattern(pattern.id)) {
                                HStack {
                                    severityIcon(pattern.severity)
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                                        Text(pattern.name)
                                            .font(.system(size: DesignTokens.Typography.Body.size, weight: DesignTokens.Typography.Body.emphasis))
                                        Text(pattern.description)
                                            .font(.system(size: DesignTokens.Typography.BodySmall.size))
                                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Detection Patterns")
            } footer: {
                Text("Select which ACIP v1.3 injection patterns to enable during scanning.")
            }

            // Allowlist Configuration
            Section {
                if securityConfig.allowlist.isEmpty {
                    Text("No allowlist patterns configured")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                } else {
                    ForEach(Array(securityConfig.allowlist.enumerated()), id: \.offset) { _, pattern in
                        patternRow(pattern) {
                            removeAllowlistPattern(pattern)
                        }
                    }
                }

                Button("Add Allowlist Pattern") {
                    allowlistDraft = ""
                    isAllowlistSheetPresented = true
                }
            } header: {
                Text("Allowlist")
            } footer: {
                Text("Patterns that bypass security checks. Use with caution.")
            }

            // Blocklist Configuration
            Section {
                if securityConfig.blocklist.isEmpty {
                    Text("No blocklist patterns configured")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                } else {
                    ForEach(Array(securityConfig.blocklist.enumerated()), id: \.offset) { _, pattern in
                        patternRow(pattern) {
                            removeBlocklistPattern(pattern)
                        }
                    }
                }

                Button("Add Blocklist Pattern") {
                    blocklistDraft = ""
                    isBlocklistSheetPresented = true
                }
            } header: {
                Text("Blocklist")
            } footer: {
                Text("Patterns that immediately block content.")
            }

            // Quarantine Stats
            Section {
                HStack {
                    Text("Quarantined Skills")
                    Spacer()
                    Text("\(quarantinedCount)")
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }

                NavigationLink {
                    QuarantineReviewView()
                } label: {
                    Label("Review Quarantine", systemImage: "shield.checkered")
                }
            } header: {
                Text("Quarantine")
            } footer: {
                Text("Review and manage skills that have been quarantined due to security issues.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Security Settings")
        .task {
            await loadSettings()
        }
        .onChange(of: securityConfig) { _, newValue in
            guard !isHydrating else { return }
            let resolvedPreset = preset(for: newValue)
            if securityPreset != resolvedPreset {
                securityPreset = resolvedPreset
            }
            Task {
                await settingsStore.save(newValue)
            }
        }
        .sheet(isPresented: $isAllowlistSheetPresented) {
            patternSheet(
                title: "Add Allowlist Pattern",
                description: "Allowlist patterns bypass security checks. Enter a unique pattern to enable Save.",
                placeholder: "e.g. \\btrusted\\b",
                draft: $allowlistDraft,
                canSave: canAddAllowlistPattern,
                onCancel: { isAllowlistSheetPresented = false },
                onSave: addAllowlistPattern
            )
        }
        .sheet(isPresented: $isBlocklistSheetPresented) {
            patternSheet(
                title: "Add Blocklist Pattern",
                description: "Blocklist patterns immediately block content. Enter a unique pattern to enable Save.",
                placeholder: "e.g. eval\\(",
                draft: $blocklistDraft,
                canSave: canAddBlocklistPattern,
                onCancel: { isBlocklistSheetPresented = false },
                onSave: addBlocklistPattern
            )
        }
    }

    // MARK: - Computed Properties

    private enum Preset: String {
        case `default`
        case permissive
        case strict
        case custom
    }

    @State private var securityPreset: Preset = .default

    private var presetDescription: String {
        switch securityPreset {
        case .default:
            return "Balanced security with standard ACIP v1.3 patterns enabled."
        case .permissive:
            return "Reduced security checks, allows more content through."
        case .strict:
            return "Strict scanning with maximum coverage."
        case .custom:
            return "Custom configuration based on your overrides."
        }
    }

    private var trimmedAllowlistDraft: String {
        allowlistDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBlocklistDraft: String {
        blocklistDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddAllowlistPattern: Bool {
        !trimmedAllowlistDraft.isEmpty && !securityConfig.allowlist.contains(trimmedAllowlistDraft)
    }

    private var canAddBlocklistPattern: Bool {
        !trimmedBlocklistDraft.isEmpty && !securityConfig.blocklist.contains(trimmedBlocklistDraft)
    }

    // MARK: - Helper Methods

    private func bindingForPattern(_ patternId: String) -> Binding<Bool> {
        Binding(
            get: {
                self.securityConfig.enabledPatterns.contains(patternId) || self.securityConfig.enabledPatterns.isEmpty
            },
            set: { newValue in
                if newValue {
                    if !self.securityConfig.enabledPatterns.contains(patternId) {
                        self.securityConfig.enabledPatterns.append(patternId)
                    }
                } else {
                    self.securityConfig.enabledPatterns.removeAll { $0 == patternId }
                }
            }
        )
    }

    private func patternRow(_ pattern: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(pattern)
                .font(.system(size: DesignTokens.Typography.Body.size))
                .monospaced()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Remove pattern")
        }
    }

    private func patternSheet(
        title: String,
        description: String,
        placeholder: String,
        draft: Binding<String>,
        canSave: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))

            Text(description)
                .font(.system(size: DesignTokens.Typography.Body.size))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            TextField(placeholder, text: draft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: DesignTokens.Typography.Body.size))

            Spacer()

            HStack {
                Button("Cancel") {
                    onCancel()
                }

                Spacer()

                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 420, height: 220)
    }

    private func severityIcon(_ severity: ACIPScanner.InjectionPattern.Severity) -> some View {
        let (iconName, color): (String, Color) = {
            switch severity {
            case .critical:
                return ("xmark.circle.fill", DesignTokens.Colors.Accent.red)
            case .high:
                return ("exclamationmark.triangle.fill", DesignTokens.Colors.Accent.orange)
            case .medium:
                return ("exclamationmark.triangle", DesignTokens.Colors.Accent.yellow)
            case .low:
                return ("info.circle.fill", DesignTokens.Colors.Accent.blue)
            }
        }()

        return Image(systemName: iconName)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .frame(width: 16)
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func applyPreset(_ preset: Preset) {
        switch preset {
        case .default:
            securityConfig = .default
        case .permissive:
            securityConfig = .permissive
        case .strict:
            securityConfig = .strict
        case .custom:
            break
        }
    }

    private func addAllowlistPattern() {
        let pattern = trimmedAllowlistDraft
        guard !pattern.isEmpty else { return }
        guard !securityConfig.allowlist.contains(pattern) else { return }
        securityConfig.allowlist.append(pattern)
        allowlistDraft = ""
        isAllowlistSheetPresented = false
    }

    private func addBlocklistPattern() {
        let pattern = trimmedBlocklistDraft
        guard !pattern.isEmpty else { return }
        guard !securityConfig.blocklist.contains(pattern) else { return }
        securityConfig.blocklist.append(pattern)
        blocklistDraft = ""
        isBlocklistSheetPresented = false
    }

    private func removeAllowlistPattern(_ pattern: String) {
        securityConfig.allowlist.removeAll { $0 == pattern }
    }

    private func removeBlocklistPattern(_ pattern: String) {
        securityConfig.blocklist.removeAll { $0 == pattern }
    }

    private func preset(for config: SecurityConfig) -> Preset {
        if config == .default { return .default }
        if config == .permissive { return .permissive }
        if config == .strict { return .strict }
        return .custom
    }

    private func loadSettings() async {
        isLoading = true
        isHydrating = true
        defer {
            isHydrating = false
            isLoading = false
        }

        let stored = await settingsStore.load()
        securityConfig = stored
        securityPreset = preset(for: stored)

        // Load quarantine count
        let items = await quarantineStore.list()
        quarantinedCount = items.filter { $0.status == .pending }.count
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
