import XCTest
import SwiftUI
import CryptoKit
#if os(macOS)
import AppKit
import CoreGraphics
#endif
@testable import SkillsInspector
@testable import SkillsCore

@MainActor
final class UISnapshotsTests: XCTestCase {
    func testStatsViewSnapshotHash() throws {
        let view = StatsSnapshotHarness(findings: Self.sampleFindings)
        let hash = Self.renderHash(for: view, size: CGSize(width: 800, height: 1200))
        XCTAssertEqual(hash, "b27f1ba4f311a852189bc4ce58c68726b2c810c00168a67e064b6defe17b6926")
    }

    func testMarkdownPreviewSnapshotHash() throws {
        let content = """
        # Title

        - Item 1
        - Item 2

        > Quote block
        """
        let view = MarkdownPreviewView(content: content)
        let hash = Self.renderHash(for: view, size: CGSize(width: 640, height: 800))
        XCTAssertEqual(hash, "985ac614ba98e992c3c23c6e0132c874192e4011128f2886b47ffae46aaa0563")
    }

    func testStatsChartsSnapshotHash() throws {
        let allowChartsSnapshot = ProcessInfo.processInfo.environment["ALLOW_CHARTS_SNAPSHOT"] == "1"
        try XCTSkipIf(!allowChartsSnapshot, "Charts snapshot is unstable in headless test rendering. Set ALLOW_CHARTS_SNAPSHOT=1 for manual verification.")
        try requireDisplayForCharts()
        let vm = InspectorViewModel()
        vm.findings = Self.sampleFindings
        vm.filesScanned = 3
        vm.cacheHits = 1
        vm.isScanning = false
        let view = StatsView(
            viewModel: vm,
            mode: .constant(.stats),
            severityFilter: .constant(nil),
            agentFilter: .constant(nil)
        )
            .environment(\.colorScheme, .light)
        let hash = Self.renderHash(for: view, size: CGSize(width: 800, height: 1200))
        let expected = ProcessInfo.processInfo.environment["STATS_CHARTS_HASH"] ?? "ba8b39a918d019089050a4da1fb5916dc04a6d48dfad0eccf861137d6f1aba02"
        XCTAssertEqual(hash, expected)
    }

    // MARK: - Helpers
    private static func renderHash<V: View>(for view: V, size: CGSize) -> String {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = .init(width: size.width, height: size.height)
        guard let image = renderer.nsImage else { return "nil" }
        guard let data = image.tiffRepresentation else { return "nil" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func requireDisplayForCharts() throws {
        #if os(macOS)
        let sessionInfo = CGSessionCopyCurrentDictionary() as? [String: Any]
        let onConsole = sessionInfo?[kCGSessionOnConsoleKey as String] as? Bool ?? false
        let hasScreen = !NSScreen.screens.isEmpty
        try XCTSkipIf(!onConsole || !hasScreen, "Charts snapshot requires an active console session with a display.")
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        try XCTSkipIf(!NSApp.isActive, "Charts snapshot requires an active app session.")
        #endif
    }

    private static var sampleFindings: [Finding] {
        [
            Finding(ruleID: "STAT-1", severity: .error, agent: .codex, fileURL: URL(fileURLWithPath: "/tmp/a.md"), message: "Something went wrong", line: 1, column: nil, suggestedFix: nil),
            Finding(ruleID: "STAT-2", severity: .warning, agent: .claude, fileURL: URL(fileURLWithPath: "/tmp/b.md"), message: "Warning message", line: 2, column: nil, suggestedFix: nil),
            Finding(ruleID: "STAT-3", severity: .info, agent: .codex, fileURL: URL(fileURLWithPath: "/tmp/c.md"), message: "Informational note", line: 3, column: nil, suggestedFix: nil)
        ]
    }
}

// MARK: - Snapshot Harnesses (test-only)

private struct StatsSnapshotHarness: View {
    let findings: [Finding]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Validation Statistics")
                .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Findings", value: "\(findings.count)", color: DesignTokens.Colors.Accent.orange)
                statCard(title: "Errors", value: "\(findings.filter { $0.severity == .error }.count)", color: DesignTokens.Colors.Accent.red)
                statCard(title: "Warnings", value: "\(findings.filter { $0.severity == .warning }.count)", color: DesignTokens.Colors.Accent.orange)
                statCard(title: "Info", value: "\(findings.filter { $0.severity == .info }.count)", color: DesignTokens.Colors.Accent.blue)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary)
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: DesignTokens.Typography.Caption.size))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
        }
        .padding(DesignTokens.Spacing.xxs)
        .cardStyle(tint: color)
    }
}
