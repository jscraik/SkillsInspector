import SwiftUI
import SkillsCore

struct RemoteView: View {
    @ObservedObject var viewModel: RemoteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Remote Skills")
                    .heading2()
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.loadLatest() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.customGlass)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
            .background(glassBarStyle())

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(DesignTokens.Colors.Status.error)
            }
            if viewModel.skills.isEmpty && !viewModel.isLoading {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text("No remote skills yet.")
                        .heading3()
                    Text("Check your network or try Refresh. For screenshots, set SKILLS_MOCK_REMOTE=1 to load sample data.")
                        .bodySmall()
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
                .padding(DesignTokens.Spacing.xs)
                .background(glassPanelStyle(cornerRadius: 14))
            }

            List(viewModel.skills, id: \.id) { skill in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.hair + DesignTokens.Spacing.micro) {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                            Text(skill.displayName)
                                .heading3()
                            Text(skill.slug)
                                .font(.caption.monospaced())
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        Spacer()
                        if let version = skill.latestVersion {
                            Text("v\(version)")
                                .captionText(emphasis: true)
                                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                                .padding(.vertical, DesignTokens.Spacing.hair)
                                .background(DesignTokens.Colors.Background.secondary)
                                .clipShape(Capsule())
                        }
                        if viewModel.isUpdateAvailable(for: skill) {
                            Text("Update")
                                .captionText(emphasis: true)
                                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                                .padding(.vertical, DesignTokens.Spacing.hair)
                                .background(DesignTokens.Colors.Status.warning.opacity(0.2))
                                .foregroundStyle(DesignTokens.Colors.Status.warning)
                                .clipShape(Capsule())
                        }
                    }
                    if let summary = skill.summary {
                        Text(summary)
                            .bodySmall()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                    if let owner = viewModel.ownerBySlug[skill.slug] ?? nil {
                        HStack(spacing: DesignTokens.Spacing.hair + DesignTokens.Spacing.micro) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(DesignTokens.Colors.Icon.secondary)
                            Text(owner.displayName ?? owner.handle ?? "Unknown")
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                    } else {
                        Button("Load owner") {
                            Task { await viewModel.fetchOwner(for: skill.slug) }
                        }
                        .buttonStyle(.link)
                    }
                    if let change = viewModel.changelogBySlug[skill.slug], let text = change {
                        Text("Changelog: \(text)")
                            .captionText()
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    } else {
                        Button("Load changelog") {
                            Task { await viewModel.fetchChangelog(for: skill.slug) }
                        }
                        .buttonStyle(.link)
                    }
                    HStack {
                        Button {
                            Task { await viewModel.install(slug: skill.slug, version: skill.latestVersion) }
                        } label: {
                            if viewModel.installingSlug == skill.slug {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Install to Codex", systemImage: "square.and.arrow.down")
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.installingSlug != nil)
                        if let installed = viewModel.installedVersions[skill.slug] {
                            Text("Installed v\(installed)")
                                .captionText()
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.hair + DesignTokens.Spacing.micro)
                .listRowSeparator(.hidden)
                .listRowBackground(glassPanelStyle(cornerRadius: 12, tint: Color.primary.opacity(0.06)))
            }
            .listStyle(.plain)
        }
        .padding(DesignTokens.Spacing.md)
        .task {
            if viewModel.skills.isEmpty && !viewModel.isLoading {
                await viewModel.loadLatest()
            }
        }
    }
}
