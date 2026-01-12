import SwiftUI
import SkillsCore
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: InspectorViewModel
    @Binding var mode: AppMode
    @Binding var severityFilter: Severity?
    @Binding var agentFilter: AgentKind?
    @AccessibilityFocusState private var chartFocused: Bool
    
    private var stats: ValidationStats {
        ValidationStats(findings: viewModel.findings)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Header with improved styling
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair) {
                            Text("Statistics")
                                .heading2()
                            Text("Analysis overview and insights")
                                .bodySmall()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        Spacer()
                        if severityFilter != nil || agentFilter != nil {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    severityFilter = nil
                                    agentFilter = nil
                                }
                            } label: {
                                Label("Clear Filters", systemImage: "xmark.circle.fill")
                                    .captionText()
                                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .accessibilityLabel("Clear all filters")
                        }
                    }
                    
                    // Progress indicator
                    if viewModel.isScanning {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(DesignTokens.Colors.Accent.blue)
                    }
                    
                    // Active filters display
                    if let sev = severityFilter {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: sev.icon)
                                .foregroundStyle(sev.color)
                                .font(.caption)
                            Text("Filtering by \(sev.rawValue) severity")
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxxs)
                        .padding(.vertical, DesignTokens.Spacing.hair)
                        .background(sev.color.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    if let agent = agentFilter {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: agent.icon)
                                .foregroundStyle(agent.color)
                                .font(.caption)
                            Text("Filtering by \(agent.displayName)")
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xxxs)
                        .padding(.vertical, DesignTokens.Spacing.hair)
                        .background(agent.color.opacity(0.1))
                        .cornerRadius(DesignTokens.Radius.sm)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(glassBarStyle(cornerRadius: DesignTokens.Radius.lg))
                
                // Summary cards with improved layout
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DesignTokens.Spacing.xs),
                    GridItem(.flexible(), spacing: DesignTokens.Spacing.xs)
                ], spacing: DesignTokens.Spacing.xs) {
                    statCard(title: "Files Scanned", value: "\(viewModel.filesScanned)", icon: "doc.fill", color: DesignTokens.Colors.Accent.blue)
                    statCard(title: "Total Findings", value: "\(viewModel.findings.count)", icon: "exclamationmark.triangle.fill", color: DesignTokens.Colors.Accent.orange)
                    statCard(title: "Errors", value: "\(stats.errorCount)", icon: "xmark.circle.fill", color: DesignTokens.Colors.Status.error)
                    statCard(title: "Warnings", value: "\(stats.warningCount)", icon: "exclamationmark.triangle.fill", color: DesignTokens.Colors.Status.warning)
                }
                
                // Charts section with improved organization
                if !viewModel.findings.isEmpty {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        sectionCard(title: "Findings by Severity", icon: "exclamationmark.triangle.fill", tint: DesignTokens.Colors.Accent.orange) {
                            severityChart
                        }
                        sectionCard(title: "Findings by Agent", icon: "person.2", tint: DesignTokens.Colors.Accent.purple) {
                            agentChart
                        }
                        sectionCard(title: "Most Common Issues", icon: "list.number", tint: DesignTokens.Colors.Accent.blue) {
                            topRulesChart
                        }
                        sectionCard(title: "Fix Availability", icon: "wand.and.stars", tint: DesignTokens.Colors.Accent.green) {
                            fixAvailabilityChart
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(DesignTokens.Spacing.xs)
        }
        .background(DesignTokens.Colors.Background.primary)
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.callout)
                Text(title)
                    .captionText(emphasis: true)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: color.opacity(0.06)))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 20)
                .cornerRadius(2, corners: .topLeft)
                .offset(x: 0, y: DesignTokens.Spacing.xs)
        }
    }
    
    private func sectionCard<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.title3)
                Text(title)
                    .heading3()
                Spacer()
            }
            .padding(.bottom, DesignTokens.Spacing.hair)
            
            content()
        }
        .padding(DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(glassPanelStyle(cornerRadius: DesignTokens.Radius.lg, tint: tint.opacity(0.04)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var severityChart: some View {
        Chart {
            ForEach(stats.severityBreakdown, id: \.severity) { item in
                let isSelected = severityFilter == item.severity
                let isFiltered = severityFilter != nil && !isSelected
                let opacity: Double = isFiltered ? 0.4 : 1.0
                
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Severity", item.severity.rawValue.capitalized)
                )
                .foregroundStyle(item.severity.color.opacity(opacity))
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 120)
        .chartXAxis(.hidden)
        .onTapGesture { location in
            // Find which bar was tapped
            if let tappedSeverity = severityAt(location: location) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if severityFilter == tappedSeverity {
                        severityFilter = nil
                    } else {
                        severityFilter = tappedSeverity
                        agentFilter = nil
                        mode = .validate
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Severity breakdown chart. Tap a bar to filter by that severity.")
    }
    
    private func severityAt(location: CGPoint) -> Severity? {
        // Simple heuristic: divide height into sections based on severity count
        let breakdowns = stats.severityBreakdown
        guard !breakdowns.isEmpty else { return nil }
        
        // Calculate which section was tapped (top to bottom matches chart order)
        let sectionHeight: CGFloat = 120.0 / CGFloat(breakdowns.count)
        let index = Int(location.y / sectionHeight)
        guard index >= 0 && index < breakdowns.count else { return nil }
        return breakdowns[index].severity
    }
    
    private var agentChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(stats.agentBreakdown, id: \.agent) { item in
                    let isSelected = agentFilter == item.agent
                    let isFiltered = agentFilter != nil && !isSelected
                    let opacity: Double = isFiltered ? 0.4 : 1.0
                    
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.agent.color.opacity(opacity))
                    .annotation(position: .overlay) {
                        VStack(spacing: 2) {
                            Image(systemName: item.agent.icon)
                                .font(.caption2)
                            Text("\(item.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 200)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Agent breakdown chart. Tap a legend item below to filter by that agent.")
            
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(stats.agentBreakdown, id: \.agent) { item in
                    let isSelected = agentFilter == item.agent
                    let isFiltered = agentFilter != nil && !isSelected
                    let opacity: Double = isFiltered ? 0.4 : 1.0
                    
                    Label {
                        Text("\(item.agent.rawValue.capitalized): \(item.count)")
                            .captionText()
                    } icon: {
                        Circle()
                            .fill(item.agent.color.opacity(opacity))
                            .frame(width: 8, height: 8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if agentFilter == item.agent {
                                agentFilter = nil
                            } else {
                                agentFilter = item.agent
                                severityFilter = nil
                                mode = .validate
                            }
                        }
                    }
                    .accessibilityAddTraits(agentFilter == item.agent ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel("\(item.agent.rawValue.capitalized): \(item.count) findings")
                    .accessibilityHint("Tap to filter by \(item.agent.rawValue)")
                }
            }
        }
    }
    
    private var topRulesChart: some View {
        Chart {
            ForEach(stats.topRules.prefix(10), id: \.ruleID) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Rule", item.ruleID)
                )
                .foregroundStyle(DesignTokens.Colors.Accent.blue.gradient)
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: CGFloat(min(stats.topRules.count, 10) * 30))
        .chartXAxis(.hidden)
    }
    
    private var fixAvailabilityChart: some View {
        let autoFixable = stats.autoFixableCount
        let manualFix = stats.manualFixableCount
        let noFix = stats.noFixCount
        
        return VStack(alignment: .leading, spacing: 12) {
            Chart {
                SectorMark(
                    angle: .value("Count", autoFixable),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(DesignTokens.Colors.Accent.green)
                .annotation(position: .overlay) {
                    VStack(spacing: 2) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                        Text("\(autoFixable)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                }
                
                SectorMark(
                    angle: .value("Count", manualFix),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(DesignTokens.Colors.Accent.blue)
                .annotation(position: .overlay) {
                    VStack(spacing: 2) {
                        Image(systemName: "wrench")
                            .font(.caption2)
                        Text("\(manualFix)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                }
                
                SectorMark(
                    angle: .value("Count", noFix),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(DesignTokens.Colors.Accent.gray)
                .annotation(position: .overlay) {
                    VStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                        Text("\(noFix)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Label("Auto-fixable: \(autoFixable)", systemImage: "wand.and.stars")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Accent.green)
                Label("Manual fix: \(manualFix)", systemImage: "wrench")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                Label("No fix available: \(noFix)", systemImage: "xmark")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Accent.gray)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "chart.bar")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                .padding(.bottom, DesignTokens.Spacing.xxxs)
            
            Text("No Statistics Available")
                .heading2()
                .foregroundStyle(DesignTokens.Colors.Text.primary)
            
            Text("Run a validation scan to generate insights and statistics about your skill files")
                .bodySmall()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(glassPanelStyle(cornerRadius: DesignTokens.Radius.xl, tint: DesignTokens.Colors.Accent.blue.opacity(0.03)))
        )
    }
}

// MARK: - Stats Model

struct ValidationStats {
    let findings: [Finding]
    
    var errorCount: Int {
        findings.filter { $0.severity == .error }.count
    }
    
    var warningCount: Int {
        findings.filter { $0.severity == .warning }.count
    }
    
    var infoCount: Int {
        findings.filter { $0.severity == .info }.count
    }
    
    var severityBreakdown: [(severity: Severity, count: Int)] {
        let grouped = Dictionary(grouping: findings) { $0.severity }
        return Severity.allCases.compactMap { severity in
            guard let items = grouped[severity], !items.isEmpty else { return nil }
            return (severity, items.count)
        }
    }
    
    var agentBreakdown: [(agent: AgentKind, count: Int)] {
        let grouped = Dictionary(grouping: findings) { $0.agent }
        return AgentKind.allCases.compactMap { agent in
            guard let items = grouped[agent], !items.isEmpty else { return nil }
            return (agent, items.count)
        }
    }
    
    var topRules: [(ruleID: String, count: Int)] {
        let grouped = Dictionary(grouping: findings) { $0.ruleID }
        return grouped.map { (ruleID: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    var autoFixableCount: Int {
        findings.filter { $0.suggestedFix?.automated == true }.count
    }
    
    var manualFixableCount: Int {
        findings.filter { $0.suggestedFix?.automated == false }.count
    }
    
    var noFixCount: Int {
        findings.filter { $0.suggestedFix == nil }.count
    }
}

extension Severity: CaseIterable {
    public static let allCases: [Severity] = [.error, .warning, .info]
}
