import SwiftUI
import SkillsCore

struct FindingDetailView: View {
    let finding: Finding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[\(finding.severity.rawValue.uppercased())] \(finding.ruleID)")
                .font(.headline)
                .foregroundStyle(color(for: finding.severity))
            Text(finding.message)
                .font(.body)
            detailRow(label: "Agent", value: finding.agent.rawValue)
            detailRow(label: "File", value: finding.fileURL.path)
            if let line = finding.line {
                detailRow(label: "Line", value: "\(line)")
            }
            Spacer()
        }
        .padding()
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    private func color(for severity: Severity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .secondary
        }
    }
}
