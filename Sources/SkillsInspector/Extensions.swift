import SwiftUI
import SkillsCore
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Severity Color Extension

extension Severity {
    var color: Color {
        switch self {
        case .error: return DesignTokens.Colors.Status.error
        case .warning: return DesignTokens.Colors.Status.warning
        case .info: return DesignTokens.Colors.Icon.secondary
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
        case .codex: return DesignTokens.Colors.Accent.blue
        case .claude: return DesignTokens.Colors.Accent.purple
        case .codexSkillManager: return DesignTokens.Colors.Accent.green
        case .copilot: return DesignTokens.Colors.Accent.orange
        }
    }
    
    var icon: String {
        switch self {
        case .codex: return "cpu"
        case .claude: return "brain"
        case .codexSkillManager: return "folder"
        case .copilot: return "bolt"
        }
    }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .codexSkillManager: return "CodexSkillManager"
        case .copilot: return "Copilot"
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
    var compactMode: Bool = false

    @State private var iconScale: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: compactMode ? DesignTokens.Spacing.sm : DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: compactMode ? 40 : 48))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                .scaleEffect(iconScale)
                .onAppear {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                            iconScale = 1.0
                        }
                    } else {
                        iconScale = 1.0
                    }
                }

            Text(title)
                .font(.system(size: compactMode ? 16 : 18, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.Text.primary)

            Text(message)
                .bodySmallText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: compactMode ? 280 : 340)

            if let action {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.cleanProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(compactMode ? DesignTokens.Spacing.lg : DesignTokens.Spacing.xl)
        .background(cleanPanelStyle(cornerRadius: 18))
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
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Severity badges
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                severityBadge(count: errorCount, severity: .error)
                severityBadge(count: warningCount, severity: .warning)
                severityBadge(count: infoCount, severity: .info)
            }
            
            Divider()
                .frame(height: 16)
            
            // Cache stats
            if scannedFiles > 0 {
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                    Text("\(scannedFiles) files")
                    if cacheHits > 0 {
                        Text("(\(cacheHits) cached)")
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                }
                .captionText()
            }
            
            Spacer()
            
            // Timing info
            if let duration {
                Text(String(format: "%.2fs", duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }
            
            if let lastScan {
                Text(lastScan.formatted(date: .omitted, time: .shortened))
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
        .background(.bar)
    }
    
    private func severityBadge(count: Int, severity: Severity) -> some View {
        HStack(spacing: DesignTokens.Spacing.hair) {
            Image(systemName: severity.icon)
                .foregroundStyle(count > 0 ? AnyShapeStyle(severity.color) : AnyShapeStyle(DesignTokens.Colors.Icon.tertiary))
            Text("\(count)")
                .fontWeight(count > 0 ? .medium : .regular)
        }
        .captionText()
        .padding(.horizontal, DesignTokens.Spacing.xxxs)
        .padding(.vertical, DesignTokens.Spacing.hair)
        .background(count > 0 ? severity.color.opacity(0.15) : Color.clear)
        .cornerRadius(DesignTokens.Radius.sm)
    }
}

// MARK: - Shimmer Loading Effect

private struct ActivePaneKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isActivePane: Bool {
        get { self[ActivePaneKey.self] }
        set { self[ActivePaneKey.self] = newValue }
    }
}

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isActivePane) private var isActivePane
    @State private var phase: CGFloat = -200
    
    func body(content: Content) -> some View {
        if !isActive || !isActivePane || reduceMotion {
            content
        } else {
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
}

extension View {
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: active))
    }
}

// MARK: - Loading Skeleton Views

struct SkeletonFindingRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 120, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 60, height: 16)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 14)
            
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 80, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 30, height: 10)
            }
        }
        .padding(8)
        .shimmer()
    }
}

struct SkeletonSyncRow: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: "doc.fill")
                .foregroundStyle(DesignTokens.Colors.Background.secondary)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 180, height: 14)
                
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 120, height: 10)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .shimmer()
    }
}

struct SkeletonIndexRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.xxs) {
            // Agent icon placeholder
            Circle()
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                // Skill name placeholder
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 200, height: 16)
                
                // Path placeholder
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 150, height: 12)
                
                // Version badge placeholder
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.Background.secondary)
                    .frame(width: 60, height: 10)
            }
            
            Spacer()
            
            // Expand button placeholder
            Circle()
                .fill(DesignTokens.Colors.Background.secondary)
                .frame(width: 20, height: 20)
        }
        .padding(DesignTokens.Spacing.xxs)
        .redacted(reason: .placeholder)
        .shimmer()
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
    /// Clean card styling for professional appearance
    func cardStyle(selected: Bool = false, tint: Color = .accentColor) -> some View {
        self
            .padding(DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .fill(DesignTokens.Colors.Background.primary)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .stroke(selected ? tint : DesignTokens.Colors.Border.light, lineWidth: selected ? 2 : 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .shadow(color: selected ? tint.opacity(0.1) : .clear, radius: selected ? 8 : 0, y: 0)
    }

    /// Clean panel background without excessive glass effects
    func cleanPanelStyle(cornerRadius: CGFloat = DesignTokens.Radius.lg) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DesignTokens.Colors.Background.secondary)
            .shadow(color: .black.opacity(0.03), radius: 1, y: 0.5)
            .allowsHitTesting(false)
    }

    /// Subtle toolbar background
    func cleanToolbarStyle(cornerRadius: CGFloat = DesignTokens.Radius.md) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DesignTokens.Colors.Background.tertiary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Toast Notification System

enum ToastStyle {
    case success
    case warning
    case error
    case info
    
    var color: Color {
        switch self {
        case .success: return DesignTokens.Colors.Status.success
        case .warning: return DesignTokens.Colors.Status.warning
        case .error: return DesignTokens.Colors.Status.error
        case .info: return DesignTokens.Colors.Status.info
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let style: ToastStyle
    let message: String
    let duration: TimeInterval
    
    init(style: ToastStyle, message: String, duration: TimeInterval = 3.0) {
        self.style = style
        self.message = message
        self.duration = duration
    }
}

struct ToastView: View {
    let toast: ToastMessage
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: toast.style.icon)
                .foregroundStyle(toast.style.color)
            
            Text(toast.message)
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Colors.Background.primary)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(toast.style.color.opacity(0.3), lineWidth: 1)
        )
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                withAnimation(reduceMotion ? .easeOut : .spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowing = false
                }
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    @State private var workItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(toast: toast, isShowing: Binding(
                        get: { self.toast != nil },
                        set: { if !$0 { self.toast = nil } }
                    ))
                    .padding(.top, DesignTokens.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast != nil)
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Button Styles

struct CleanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(DesignTokens.Colors.Background.tertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.Border.light, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CleanProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(Color.accentColor)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Typography Extensions

extension View {
    func heading1() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading1.size, weight: DesignTokens.Typography.Heading1.weight))
            .tracking(DesignTokens.Typography.Heading1.tracking)
            .lineSpacing(DesignTokens.Typography.Heading1.line - DesignTokens.Typography.Heading1.size)
    }
    
    func heading2() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))
            .tracking(DesignTokens.Typography.Heading2.tracking)
            .lineSpacing(DesignTokens.Typography.Heading2.line - DesignTokens.Typography.Heading2.size)
    }
    
    func heading3() -> some View {
        self.font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            .tracking(DesignTokens.Typography.Heading3.tracking)
            .lineSpacing(DesignTokens.Typography.Heading3.line - DesignTokens.Typography.Heading3.size)
    }
    
    func bodyText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.Body.size, weight: emphasis ? DesignTokens.Typography.Body.emphasis : DesignTokens.Typography.Body.weight))
            .tracking(DesignTokens.Typography.Body.tracking)
            .lineSpacing(DesignTokens.Typography.Body.line - DesignTokens.Typography.Body.size)
    }
    
    func bodySmall(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.BodySmall.size, weight: emphasis ? DesignTokens.Typography.BodySmall.emphasis : DesignTokens.Typography.BodySmall.weight))
            .tracking(DesignTokens.Typography.BodySmall.tracking)
            .lineSpacing(DesignTokens.Typography.BodySmall.line - DesignTokens.Typography.BodySmall.size)
    }

    func bodySmallText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.BodySmall.size, weight: emphasis ? DesignTokens.Typography.BodySmall.emphasis : DesignTokens.Typography.BodySmall.weight))
            .tracking(DesignTokens.Typography.BodySmall.tracking)
            .lineSpacing(DesignTokens.Typography.BodySmall.line - DesignTokens.Typography.BodySmall.size)
    }

    func captionText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.Caption.size, weight: emphasis ? DesignTokens.Typography.Caption.emphasis : DesignTokens.Typography.Caption.weight))
            .tracking(DesignTokens.Typography.Caption.tracking)
            .lineSpacing(DesignTokens.Typography.Caption.line - DesignTokens.Typography.Caption.size)
    }

    func subcaptionText(emphasis: Bool = false) -> some View {
        self.font(.system(size: DesignTokens.Typography.Subcaption.size, weight: emphasis ? DesignTokens.Typography.Subcaption.emphasis : DesignTokens.Typography.Subcaption.weight))
            .tracking(DesignTokens.Typography.Subcaption.tracking)
            .lineSpacing(DesignTokens.Typography.Subcaption.line - DesignTokens.Typography.Subcaption.size)
    }

    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Custom Shapes

enum RectCorner {
    case topLeft, topRight, bottomLeft, bottomRight
    case allCorners
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Use switch instead of equality comparisons to avoid actor isolation issues
        let topLeft: Bool
        let topRight: Bool
        let bottomLeft: Bool
        let bottomRight: Bool
        
        switch corners {
        case .allCorners:
            topLeft = true
            topRight = true
            bottomLeft = true
            bottomRight = true
        case .topLeft:
            topLeft = true
            topRight = false
            bottomLeft = false
            bottomRight = false
        case .topRight:
            topLeft = false
            topRight = true
            bottomLeft = false
            bottomRight = false
        case .bottomLeft:
            topLeft = false
            topRight = false
            bottomLeft = true
            bottomRight = false
        case .bottomRight:
            topLeft = false
            topRight = false
            bottomLeft = false
            bottomRight = true
        }
        
        let tlRadius = topLeft ? radius : 0
        let trRadius = topRight ? radius : 0
        let blRadius = bottomLeft ? radius : 0
        let brRadius = bottomRight ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + tlRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - trRadius, y: rect.minY))
        if trRadius > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - trRadius, y: rect.minY + trRadius), 
                       radius: trRadius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - brRadius))
        if brRadius > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - brRadius, y: rect.maxY - brRadius), 
                       radius: brRadius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + blRadius, y: rect.maxY))
        if blRadius > 0 {
            path.addArc(center: CGPoint(x: rect.minX + blRadius, y: rect.maxY - blRadius), 
                       radius: blRadius, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tlRadius))
        if tlRadius > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tlRadius, y: rect.minY + tlRadius), 
                       radius: tlRadius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        }
        
        return path
    }
}

extension ButtonStyle where Self == CleanButtonStyle {
    static var clean: CleanButtonStyle { CleanButtonStyle() }
}

extension ButtonStyle where Self == CleanProminentButtonStyle {
    static var cleanProminent: CleanProminentButtonStyle { CleanProminentButtonStyle() }
}

// MARK: - Window Access (macOS Only)

#if os(macOS)
/// NSViewRepresentable that provides access to the hosting NSWindow for runtime configuration.
/// Calls the provided closure once with the host window, guarding against repeat invocations.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // Access the window after the view hierarchy is established
            if let window = view.window {
                context.coordinator.configure(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onWindow: onWindow)
    }
    
    class Coordinator {
        private var onWindow: (NSWindow) -> Void
        private var hasConfigured = false
        
        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
        }
        
        func configure(_ window: NSWindow) {
            // Guard: only configure once to prevent repeat invocations
            guard !hasConfigured else { return }
            hasConfigured = true
            onWindow(window)
        }
    }
}
#endif

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "No Issues Found",
            message: "All skill files pass validation.",
            action: { print("Scan") },
            actionLabel: "Scan Again"
        )
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
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
}
