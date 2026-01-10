import SwiftUI
import SkillsCore
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: InspectorViewModel
    
    private var stats: ValidationStats {
        ValidationStats(findings: viewModel.findings)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Validation Statistics")
                        .font(.system(size: DesignTokens.Typography.Heading2.size, weight: DesignTokens.Typography.Heading2.weight))
                    if viewModel.isScanning {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                
                // Summary cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(title: "Total Files", value: "\(viewModel.filesScanned)", icon: "doc.fill", color: .blue)
                    statCard(title: "Findings", value: "\(viewModel.findings.count)", icon: "exclamationmark.triangle.fill", color: .orange)
                    statCard(title: "Errors", value: "\(stats.errorCount)", icon: "xmark.circle.fill", color: .red)
                    statCard(title: "Warnings", value: "\(stats.warningCount)", icon: "exclamationmark.triangle.fill", color: .yellow)
                }
                
                // Charts
                if !viewModel.findings.isEmpty {
                    VStack(spacing: 20) {
                        sectionCard(title: "Findings by Severity", icon: "exclamationmark.triangle.fill", tint: .orange) {
                            severityChart
                        }
                        sectionCard(title: "Findings by Agent", icon: "person.2", tint: .purple) {
                            agentChart
                        }
                        sectionCard(title: "Top 10 Most Common Rules", icon: "list.number", tint: .blue) {
                            topRulesChart
                        }
                        sectionCard(title: "Fix Availability", icon: "wand.and.stars", tint: .green) {
                            fixAvailabilityChart
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(color.opacity(0.25))
                .frame(width: 5)
                .padding(.vertical, 6)
        }
        .cardStyle(tint: color)
    }
    
    private func sectionCard<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: DesignTokens.Typography.Heading3.size, weight: DesignTokens.Typography.Heading3.weight))
            }
            content()
        }
        .cardStyle(tint: tint)
    }
    
    private var severityChart: some View {
        Chart {
            ForEach(stats.severityBreakdown, id: \.severity) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Severity", item.severity.rawValue.capitalized)
                )
                .foregroundStyle(item.severity.color)
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 120)
        .chartXAxis(.hidden)
    }
    
    private var agentChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(stats.agentBreakdown, id: \.agent) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.agent.color)
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
            
            HStack(spacing: 16) {
                ForEach(stats.agentBreakdown, id: \.agent) { item in
                    Label {
                        Text("\(item.agent.rawValue.capitalized): \(item.count)")
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(item.agent.color)
                            .frame(width: 8, height: 8)
                    }
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
                .foregroundStyle(.blue.gradient)
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
                .foregroundStyle(.green)
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
                .foregroundStyle(.blue)
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
                .foregroundStyle(.gray)
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
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Auto-fixable: \(autoFixable)", systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label("Manual fix: \(manualFix)", systemImage: "wrench")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Label("No fix available: \(noFix)", systemImage: "xmark")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No findings to display")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Run a validation scan to see statistics")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
