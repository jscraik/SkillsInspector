import SwiftUI
import SkillsCore

/// A reusable row view for displaying a finding in a list.
struct FindingRowView: View {
    let finding: Finding
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            // Header row with severity, rule ID, and agent
            HStack(alignment: .center, spacing: DesignTokens.Spacing.xxxs) {
                // Severity indicator with enhanced styling
                Image(systemName: finding.severity.icon)
                    .foregroundStyle(finding.severity.color)
                    .font(.callout)
                    .frame(width: 20, height: 20)
                    .background(finding.severity.color.opacity(0.15))
                    .clipShape(Circle())
                
                // Rule ID with monospace font
                Text(finding.ruleID)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Colors.Text.primary)
                    .padding(.horizontal, DesignTokens.Spacing.hair)
                    .padding(.vertical, DesignTokens.Spacing.micro)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.6))
                    .cornerRadius(DesignTokens.Radius.sm - 2)
                
                Spacer()
                
                // Agent badge with improved styling
                HStack(spacing: DesignTokens.Spacing.hair) {
                    Image(systemName: finding.agent.icon)
                        .font(.caption2)
                    Text(finding.agent.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(finding.agent.color)
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .padding(.vertical, DesignTokens.Spacing.hair)
                .background(finding.agent.color.opacity(0.12))
                .cornerRadius(DesignTokens.Radius.sm)
                
                // Fix available badge
                if let fix = finding.suggestedFix {
                    HStack(spacing: DesignTokens.Spacing.hair) {
                        Image(systemName: fix.automated ? "wand.and.stars" : "wrench")
                            .font(.caption2)
                        Text(fix.automated ? "Auto" : "Fix")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignTokens.Colors.Accent.blue)
                    .padding(.horizontal, DesignTokens.Spacing.xxxs)
                    .padding(.vertical, DesignTokens.Spacing.hair)
                    .background(DesignTokens.Colors.Accent.blue.opacity(0.12))
                    .cornerRadius(DesignTokens.Radius.sm)
                }
            }
            
            // Message with better typography
            Text(finding.message)
                .font(.callout)
                .fontWeight(.regular)
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // File location with enhanced styling
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                
                Text(finding.fileURL.lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                
                if let line = finding.line {
                    Text(":")
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    Text("\(line)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // File path truncated
                let pathComponents = finding.fileURL.pathComponents
                if pathComponents.count > 2 {
                    Text("…/\(pathComponents.suffix(2).joined(separator: "/"))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xxs)
        .padding(.vertical, DesignTokens.Spacing.xxxs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(finding.severity.color.opacity(isHovered ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(finding.severity.color.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
        )
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.severity.rawValue): \(finding.message)")
        .accessibilityHint("In \(finding.fileURL.lastPathComponent)\(finding.line.map { ", line \($0)" } ?? "")")
    }
}

#Preview("Finding Row - Error") {
    List {
        FindingRowView(finding: Finding(
            ruleID: "frontmatter.missing",
            severity: .error,
            agent: .codex,
            fileURL: URL(fileURLWithPath: "/Users/test/.codex/skills/my-skill/SKILL.md"),
            message: "Missing or invalid YAML frontmatter (must start with --- on line 1)",
            line: 1,
            column: 1
        ))
    }
    .frame(width: 400, height: 100)
}

#Preview("Finding Row - Warning") {
    List {
        FindingRowView(finding: Finding(
            ruleID: "claude.length.warning",
            severity: .warning,
            agent: .claude,
            fileURL: URL(fileURLWithPath: "/Users/test/.claude/skills/long-skill/SKILL.md"),
            message: "Claude: SKILL.md is 623 lines; guidance suggests staying under ~500"
        ))
    }
    .frame(width: 400, height: 100)
}
