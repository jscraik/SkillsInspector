import SwiftUI
import SkillsCore

/// A reusable row view for displaying a finding in a list.
struct FindingRowView: View {
    let finding: Finding
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Severity indicator
            Image(systemName: finding.severity.icon)
                .foregroundStyle(finding.severity.color)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                // Header: rule ID, agent, and fix badge
                HStack(spacing: 6) {
                    Text(finding.ruleID)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Label(finding.agent.rawValue, systemImage: finding.agent.icon)
                        .font(.caption2)
                        .foregroundStyle(finding.agent.color)
                    
                    // Fix available badge
                    if let fix = finding.suggestedFix {
                        Label(fix.automated ? "Auto-fix" : "Fix", systemImage: fix.automated ? "wand.and.stars" : "wrench")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
                
                // Message
                Text(finding.message)
                    .font(.callout)
                    .lineLimit(2)
                
                // File path
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.caption2)
                    Text(finding.fileURL.lastPathComponent)
                        .fontWeight(.medium)
                    if let line = finding.line {
                        Text(":\(line)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.severity.rawValue): \(finding.message)")
        .accessibilityHint("In \(finding.fileURL.lastPathComponent)")
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
