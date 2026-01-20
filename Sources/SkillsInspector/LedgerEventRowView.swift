import SwiftUI
import SkillsCore

struct LedgerEventRowView: View {
    let event: LedgerEvent
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            // Timeline track
            VStack(spacing: 0) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 8, height: 8)
                    .padding(4)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(iconColor.opacity(0.3), lineWidth: 1)
                    )
                
                if !isLast {
                    Rectangle()
                        .fill(DesignTokens.Colors.Border.light.opacity(0.5))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(event.skillName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.primary)
                            
                            if let version = event.version {
                                Text("v\(version)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(DesignTokens.Colors.Background.tertiary)
                                    .cornerRadius(4)
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            label(for: event.eventType)
                            
                            if let agent = event.agent {
                                Text(agent.displayLabel)
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
                
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private func label(for type: LedgerEventType) -> some View {
        Text(type.rawValue.uppercased())
            .font(.system(size: 8, weight: .black))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
            .cornerRadius(3)
            .foregroundStyle(DesignTokens.Colors.Text.tertiary)
    }

    private var iconColor: Color {
        switch event.status {
        case .success: return DesignTokens.Colors.Status.success
        case .failure: return DesignTokens.Colors.Status.error
        case .skipped: return DesignTokens.Colors.Status.warning
        }
    }
}


struct LedgerEventRowView_Previews: PreviewProvider {
    static var previews: some View {
        LedgerEventRowView(
            event: LedgerEvent(
                id: 1,
                timestamp: Date(),
                eventType: .install,
                skillName: "Prompt Booster",
                skillSlug: "prompt-booster",
                version: "1.2.0",
                agent: .codex,
                status: .success,
                note: "Verified install",
                source: nil,
                verification: .strict,
                manifestSHA256: "abc",
                targetPath: "/tmp/skills/prompt-booster",
                targets: nil,
                perTargetResults: nil,
                signerKeyId: nil
            ),
            isLast: false
        )
    }
}
