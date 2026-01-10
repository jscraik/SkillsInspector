import SwiftUI
import SkillsCore

// MARK: - Severity Color Extension

extension Severity {
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - AgentKind Styling Extension

extension AgentKind {
    var color: Color {
        switch self {
        case .codex: return .blue
        case .claude: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .codex: return "cpu"
        case .claude: return "brain"
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Try Again"
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            if let action {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Status Bar View

struct StatusBarView: View {
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let lastScan: Date?
    let duration: TimeInterval?
    let cacheHits: Int
    let scannedFiles: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Severity badges
            HStack(spacing: 8) {
                severityBadge(count: errorCount, severity: .error)
                severityBadge(count: warningCount, severity: .warning)
                severityBadge(count: infoCount, severity: .info)
            }
            
            Divider()
                .frame(height: 16)
            
            // Cache stats
            if scannedFiles > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                    Text("\(scannedFiles) files")
                    if cacheHits > 0 {
                        Text("(\(cacheHits) cached)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            
            Spacer()
            
            // Timing info
            if let duration {
                Text(String(format: "%.2fs", duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            if let lastScan {
                Text(lastScan.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    private func severityBadge(count: Int, severity: Severity) -> some View {
        HStack(spacing: 4) {
            Image(systemName: severity.icon)
                .foregroundStyle(count > 0 ? AnyShapeStyle(severity.color) : AnyShapeStyle(.tertiary))
            Text("\(count)")
                .fontWeight(count > 0 ? .medium : .regular)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(count > 0 ? severity.color.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Keyboard Shortcut Helpers

extension KeyboardShortcut {
    static let scan = KeyboardShortcut("r", modifiers: .command)
    static let refresh = KeyboardShortcut("r", modifiers: [.command, .shift])
    static let filter = KeyboardShortcut("f", modifiers: .command)
    static let clearFilter = KeyboardShortcut(.escape, modifiers: [])
    static let openInEditor = KeyboardShortcut(.return, modifiers: .command)
    static let showInFinder = KeyboardShortcut("o", modifiers: [.command, .shift])
    static let baseline = KeyboardShortcut("b", modifiers: [.command, .shift])
}

// MARK: - Animated Transition Helpers

extension AnyTransition {
    static var fadeAndSlide: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        )
    }
}

// MARK: - Card Styling

extension View {
    /// Standard card styling used across list rows for visual parity.
    func cardStyle(selected: Bool = false, tint: Color = .accentColor) -> some View {
        self
            .padding(DesignTokens.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignTokens.Colors.Background.primary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? tint.opacity(0.55) : .clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(selected ? 0.14 : 0.06), radius: selected ? 8 : 4, y: selected ? 4 : 2)
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "checkmark.circle",
        title: "No Issues Found",
        message: "All skill files pass validation.",
        action: { print("Scan") },
        actionLabel: "Scan Again"
    )
}

#Preview("Status Bar") {
    StatusBarView(
        errorCount: 3,
        warningCount: 7,
        infoCount: 2,
        lastScan: Date(),
        duration: 1.234,
        cacheHits: 15,
        scannedFiles: 20
    )
}
