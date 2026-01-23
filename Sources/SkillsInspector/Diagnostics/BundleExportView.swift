import SwiftUI
import SkillsCore

/// View for generating diagnostic bundles with configurable options.
///
/// Provides UI controls for:
/// - Triggering bundle generation
/// - Including/excluding logs
/// - Setting log history range (1-168 hours)
struct BundleExportView: View {
    // MARK: - Published Properties

    @Binding var isPresented: Bool
    @State private var isGenerating = false
    @State private var includeLogs = false
    @State private var logHours = 24
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // MARK: - Dependencies

    let findings: [Finding]
    let scanConfig: DiagnosticBundle.ScanConfiguration

    // MARK: - Constants

    private let minLogHours = 1
    private let maxLogHours = 168  // 1 week

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 400)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Diagnostic Bundle", systemImage: "archivebox")
                .heading3()
            Spacer()
            Button("Close") { isPresented = false }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGenerating)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(.bar)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    infoCard
                    optionsCard
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(DesignTokens.Colors.Background.secondary)

            Divider()

            footer
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Label("About Diagnostic Bundles", systemImage: "info.circle")
                .heading3()

            VStack(alignment: .leading, spacing: 4) {
                infoRow(
                    icon: "doc.text",
                    text: "Contains system info, scan results, and configuration"
                )
                infoRow(
                    icon: "eye.slash",
                    text: "Personal information is redacted for privacy"
                )
                infoRow(
                    icon: "checkmark.shield",
                    text: "Safe to share with support for troubleshooting"
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .cardStyle(tint: DesignTokens.Colors.Accent.blue)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            Image(systemName: icon)
                .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                .frame(width: 16)
            Text(text)
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Label("Export Options", systemImage: "slider.horizontal.3")
                .heading3()

            // Include logs toggle
            Toggle(isOn: $includeLogs) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Include logs")
                        .font(.callout)
                    Text("Add recent log entries to help diagnose issues")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(isGenerating)

            if includeLogs {
                // Log hours stepper
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log history")
                            .font(.callout)
                        Text("Hours of log history to include")
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }

                    Spacer()

                    Stepper("\(logHours) hours", value: $logHours, in: minLogHours...maxLogHours)
                        .controlSize(.small)
                        .disabled(isGenerating)

                    if logHours == maxLogHours {
                        Text("(max 1 week)")
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                }
                .padding(.top, DesignTokens.Spacing.xxxs)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .cardStyle(tint: DesignTokens.Colors.Accent.purple)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Status message
            if let success = successMessage {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                    Text(success)
                        .captionText()
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else if isGenerating {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating bundle...")
                        .captionText()
                }
                .transition(.opacity)
            }

            Spacer()

            // Export button
            Button {
                Task {
                    await generateBundle()
                }
            } label: {
                if isGenerating {
                    Label("Generating...", systemImage: "arrow.clockwise")
                } else {
                    Label("Generate Bundle", systemImage: "archivebox")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isGenerating)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.primary)
    }

    // MARK: - Actions

    private func generateBundle() async {
        isGenerating = true
        errorMessage = nil
        successMessage = nil

        do {
            // Collect bundle
            let collector = try DiagnosticBundleCollector()
            let bundle = try await collector.collect(
                findings: findings,
                config: scanConfig,
                includeLogs: includeLogs,
                logHours: logHours
            )

            // Export to default location (Desktop)
            let exporter = DiagnosticBundleExporter()
            let outputURL = exporter.defaultOutputURL()
            exportURL = try exporter.export(bundle: bundle, to: outputURL)

            // Show success
            successMessage = "Saved to \(exportURL?.lastPathComponent ?? "Desktop")"

            // Auto-dismiss after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !Task.isCancelled {
                isPresented = false
            }

        } catch {
            errorMessage = "Failed to generate bundle: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}

// MARK: - Preview

#Preview("Bundle Export View") {
    BundleExportView(
        isPresented: .constant(true),
        findings: [
            Finding(
                ruleID: "test-rule",
                severity: .error,
                agent: .codex,
                fileURL: URL(fileURLWithPath: "/Users/test/skills/SKILL.md"),
                message: "Test error message",
                line: 10,
                column: 5
            )
        ],
        scanConfig: DiagnosticBundle.ScanConfiguration(
            codexRoots: ["~/.codex/skills"],
            claudeRoot: "~/.claude/skills",
            codexSkillManagerRoot: nil,
            copilotRoot: nil,
            recursive: true,
            maxDepth: nil,
            excludes: [".git", "node_modules"]
        )
    )
}
