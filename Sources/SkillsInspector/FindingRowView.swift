import SwiftUI
import SkillsCore

/// A reusable row view for displaying a finding in a list.
struct FindingRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let finding: Finding
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Severity + Rule ID + Agent
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: 4) {
                    Image(systemName: finding.severity.icon)
                        .font(.system(size: 9, weight: .black))
                    Text(finding.ruleID)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(finding.severity.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(finding.severity.color.opacity(isHovered ? 0.18 : 0.12))
                .cornerRadius(DesignTokens.Radius.sm)
                
                Spacer()
                
                HStack(spacing: DesignTokens.Spacing.micro) {
                    Image(systemName: finding.agent.icon)
                    Text(finding.agent.displayName)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(finding.agent.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(finding.agent.color.opacity(0.1))
                .cornerRadius(DesignTokens.Radius.sm)
            }
            
            // Message
            Text(finding.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.Text.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
            
            // Footer: File Path and Line
            HStack(spacing: DesignTokens.Spacing.micro) {
                Image(systemName: "doc.text")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                
                Text(finding.fileURL.lastPathComponent)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                
                if let line = finding.line {
                    Text("L\(line)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                        .cornerRadius(2)
                }
                
                if finding.suggestedFix != nil {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "wand.and.stars")
                        Text("FIX")
                            .font(.system(size: 8, weight: .black))
                    }
                    .foregroundStyle(DesignTokens.Colors.Accent.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(DesignTokens.Colors.Accent.green.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
                if isHovered {
                    DesignTokens.Colors.Background.tertiary.opacity(0.4)
                }
            }
        )
        .cornerRadius(DesignTokens.Radius.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.severity.rawValue): \(finding.message)")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct FindingRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
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
            .previewDisplayName("Finding Row - Error")
            
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
            .previewDisplayName("Finding Row - Warning")
        }
    }
}
