import SwiftUI
import AppKit
import SkillsCore

enum RemoteSourceMode: String, CaseIterable {
    case remote = "Remote"
    case local = "Local"

    var displayName: String { rawValue }
}

struct RemoteView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @ObservedObject var trustStoreVM: TrustStoreViewModel
    @State private var selectedSkill: RemoteSkill?
    @State private var selectedLocalSlug: String?
    @State private var trustPrompt: TrustPrompt?
    @State private var sourceMode: RemoteSourceMode = .remote
    @State private var selectionTask: Task<Void, Never>?
    @State private var localPreviewTask: Task<Void, Never>?
    @State private var localPreviewMarkdown: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 340)
                .background(DesignTokens.Colors.Background.secondary.opacity(0.1))
                .layoutPriority(1)

            Divider()

            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
        }
        .frame(maxWidth: .infinity)
        .task {
            if sourceMode == .remote && viewModel.skills.isEmpty && !viewModel.isLoading {
                await viewModel.loadLatest()
            }
        }
        .onChange(of: sourceMode) { _, _ in
            // Clear selection when switching sources
            selectedSkill = nil
            selectedLocalSlug = nil
            localPreviewMarkdown = nil
            selectionTask?.cancel()
            localPreviewTask?.cancel()
            if sourceMode == .local {
                Task { await viewModel.refreshLocalSkills() }
            }
        }
        .onChange(of: selectedSkill?.id) { _, _ in
            selectionTask?.cancel()
            selectionTask = Task {
                guard let skill = selectedSkill else { return }
                await viewModel.fetchPreview(for: skill)
                await viewModel.fetchChangelog(for: skill.slug)
                await viewModel.fetchOwner(for: skill.slug)
            }
        }
        .onChange(of: selectedLocalSlug) { _, _ in
            localPreviewTask?.cancel()
            localPreviewTask = Task {
                guard let slug = selectedLocalSlug else {
                    await MainActor.run { localPreviewMarkdown = nil }
                    return
                }
                let markdown = viewModel.loadLocalSkillMarkdown(slug: slug)
                await MainActor.run { localPreviewMarkdown = markdown }
            }
        }
    }
}

// MARK: - Subviews
private extension RemoteView {
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header / Toolbar
            HStack(spacing: DesignTokens.Spacing.xs) {
                Label("Marketplace", systemImage: "square.grid.3x3.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                Spacer()

                // Source toggle: Local / Remote
                Picker("", selection: $sourceMode) {
                    ForEach(RemoteSourceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                if sourceMode == .remote {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Button {
                            Task { await viewModel.loadLatest() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.clean)
                        .help("Refresh library")
                    }
                }

                if viewModel.isBulkActionsEnabled() {
                    Menu {
                        Button("Verify All") {
                            Task { await viewModel.verifyAll() }
                        }
                        Button("Update All Verified") {
                            Task { await viewModel.updateAllVerified() }
                        }
                        Divider()
                        Button("Export Changelog") {
                            Task { await viewModel.exportChangelog() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.clean)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.Background.primary.opacity(0.5))

            Divider()

            if let progress = viewModel.bulkOperationProgress {
                bulkOperationProgressView(progress)
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.octagon.fill")
                    Text(error)
                        .lineLimit(2)
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.Status.error)
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.Status.error.opacity(0.1))
            }

            if let exportedURL = viewModel.exportedChangelogURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Exported: \(exportedURL.lastPathComponent)")
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.Status.success)
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.Status.success.opacity(0.1))
            }

            if viewModel.isLoading && viewModel.skills.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonSkillRow()
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            } else if sourceMode == .remote && viewModel.skills.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Spacer()
                    Image(systemName: "cloud.rain.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                    Text("No remote skills found")
                        .font(.headline)
                    Text("Check your connection or enable Mock Remote in settings.")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else if sourceMode == .local && viewModel.installedVersions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Spacer()
                    Image(systemName: "folder.open.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                    Text("No local skills found")
                        .font(.headline)
                    Text("Install skills from the remote marketplace.")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else {
                Group {
                    if sourceMode == .remote {
                        List {
                            ForEach(viewModel.skills, id: \.id) { skill in
                                Button {
                                    selectedSkill = skill
                                } label: {
                                    skillRow(skill)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    } else {
                        List {
                            ForEach(Array(viewModel.installedVersions.keys.sorted()), id: \.self) { slug in
                                Button {
                                    selectedLocalSlug = slug
                                } label: {
                                    localSkillRow(slug: slug, version: viewModel.installedVersions[slug] ?? "unknown")
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func localSkillRow(slug: String, version: String) -> some View {
        let isSelected = selectedSkill?.slug == slug
        let displayName = slug.split(separator: "/").last?.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().capitalized ?? slug

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)

                    Text(slug)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.Status.success)
                    .font(.system(size: 14))
            }

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Text("v\(version)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(DesignTokens.Colors.Background.tertiary)
                    .cornerRadius(4)

                Text("LOCAL")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(DesignTokens.Colors.Accent.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.Accent.purple.opacity(0.1))
                    .cornerRadius(4)

                Spacer()
            }
        }
        .padding(10)
        .background(
            ZStack {
                if isSelected {
                    DesignTokens.Colors.Accent.blue.opacity(0.12)
                } else {
                    DesignTokens.Colors.Background.primary.opacity(0.4)
                }
            }
        )
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(isSelected ? DesignTokens.Colors.Accent.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var detailPanel: some View {
        ZStack {
            DesignTokens.Colors.Background.primary.ignoresSafeArea()

            if let skill = selectedSkill {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // Title and status
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Text(skill.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                                Spacer()

                                if viewModel.installedVersions[skill.slug] != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DesignTokens.Colors.Status.success)
                                            .font(.system(size: 12))
                                        Text("Installed")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(DesignTokens.Colors.Status.success)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignTokens.Colors.Status.success.opacity(0.1))
                                    .cornerRadius(DesignTokens.Radius.sm)
                                }
                            }

                            if let summary = skill.summary {
                                Text(summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                        }

                        Divider()

                        // Metadata
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            metadataRow(label: "Slug", value: skill.slug)
                            metadataRow(label: "Latest Version", value: skill.latestVersion)
                            if let installed = viewModel.installedVersions[skill.slug] {
                                metadataRow(label: "Installed Version", value: installed)
                            }
                            if let owner = viewModel.skillOwners[skill.slug] {
                                metadataRow(label: "Author", value: owner.displayName)
                                if let description = owner.description {
                                    Text(description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                        .padding(.leading, DesignTokens.Spacing.md)
                                }
                            }
                        }

                        Divider()

                        // Trust and Verification
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Trust & Verification")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)

                            HStack(spacing: DesignTokens.Spacing.xs) {
                                if trustStoreVM.trustStore.isTrusted(skill.slug) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .foregroundStyle(DesignTokens.Colors.Status.success)
                                        Text("Trusted")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignTokens.Colors.Status.success.opacity(0.1))
                                    .cornerRadius(DesignTokens.Radius.sm)
                                }

                                if viewModel.isVerified(skill.slug) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(DesignTokens.Colors.Accent.blue)
                                        Text("Verified")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
                                    .cornerRadius(DesignTokens.Radius.sm)
                                }

                                if viewModel.isUpdateAvailable(for: skill.slug) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundStyle(DesignTokens.Colors.Status.warning)
                                        Text("Update Available")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignTokens.Colors.Status.warning.opacity(0.1))
                                    .cornerRadius(DesignTokens.Radius.sm)
                                }
                            }
                        }

                        Divider()

                        // Actions
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Actions")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.Text.secondary)

                            HStack(spacing: DesignTokens.Spacing.xs) {
                                // Verify/Unverify
                                if viewModel.isVerified(skill.slug) {
                                    Button {
                                        Task { await viewModel.unverify(skill.slug) }
                                    } label: {
                                        Label("Unverify", systemImage: "xmark.seal")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlass)
                                } else {
                                    Button {
                                        Task { await viewModel.verify(skill.slug) }
                                    } label: {
                                        Label("Verify", systemImage: "checkmark.seal")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlassProminent)
                                }

                                // Trust/Untrust
                                if trustStoreVM.trustStore.isTrusted(skill.slug) {
                                    Button {
                                        trustStoreVM.trustStore.removeTrusted(skill.slug)
                                    } label: {
                                        Label("Untrust", systemImage: "xmark.shield")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlass)
                                } else {
                                    Button {
                                        trustStoreVM.trustStore.addTrusted(skill.slug)
                                    } label: {
                                        Label("Trust", systemImage: "checkmark.shield")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlass)
                                }

                                // Install
                                if viewModel.installedVersions[skill.slug] == nil {
                                    Button {
                                        Task { await viewModel.install(skill) }
                                    } label: {
                                        Label("Install", systemImage: "arrow.down.circle")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlassProminent)
                                } else if viewModel.isUpdateAvailable(for: skill.slug) {
                                    Button {
                                        Task { await viewModel.update(skill) }
                                    } label: {
                                        Label("Update", systemImage: "arrow.up.circle")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.customGlassProminent)
                                }
                            }
                        }

                        Divider()

                        // Changelog
                        if let changelog = viewModel.skillChangelogs[skill.slug], !changelog.isEmpty {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text("Changelog")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    ForEach(changelog.prefix(5), id: \.version) { entry in
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                                Text(entry.version)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                                                if let date = entry.date {
                                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                                                }
                                            }

                                            if !entry.changes.isEmpty {
                                                Text(entry.changes.joined(separator: "\n"))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            Divider()
                        }

                        // Preview
                        if let preview = viewModel.skillPreviews[skill.slug] {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text("Preview")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)

                                Text(preview)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                                    .padding(DesignTokens.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
                                    .cornerRadius(DesignTokens.Radius.sm)
                            }

                            Divider()
                        }

                        Spacer()
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 40))
                        .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                    Text("Select a skill to view details")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
            }
        }
    }

    private func skillRow(_ skill: RemoteSkill) -> some View {
        let isSelected = selectedSkill?.id == skill.id
        let isUpdateAvailable = viewModel.isUpdateAvailable(for: skill)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.Text.primary)

                    Text(skill.slug)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }

                Spacer()

                if isUpdateAvailable {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.warning)
                        .font(.system(size: 14))
                } else if viewModel.installedVersions[skill.slug] != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                        .font(.system(size: 14))
                }
            }

            if let summary = skill.summary {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                if viewModel.isVerified(skill.slug) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.Colors.Accent.blue)
                }

                if trustStoreVM.trustStore.isTrusted(skill.slug) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                }

                Spacer()

                Text(skill.latestVersion)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(
            Group {
                if isSelected {
                    DesignTokens.Colors.Accent.blue.opacity(0.1)
                } else {
                    DesignTokens.Colors.Background.secondary.opacity(0.3)
                }
            }
        )
        .cornerRadius(DesignTokens.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(isSelected ? DesignTokens.Colors.Accent.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func provenanceBadge(for skill: RemoteSkill) -> some View {
        let status = viewModel.provenanceStatus(for: skill.slug)
        let (icon, color): (String, Color) = {
            switch status {
            case .verified: return ("checkmark.seal.fill", DesignTokens.Colors.Status.success)
            case .failed: return ("exclamationmark.shield.fill", DesignTokens.Colors.Status.error)
            case .unknown: return ("questionmark.shield", DesignTokens.Colors.Icon.tertiary)
            }
        }()
        
        return HStack(spacing: 2) {
            Image(systemName: icon)
            Text(status.rawValue.uppercased())
        }
        .font(.system(size: 8, weight: .black))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }

    @ViewBuilder
    private var detailPanel: some View {
        if sourceMode == .local {
            localDetailPanel
        } else if let skill = selectedSkill {
            let previewState = viewModel.previewStateBySlug[skill.slug] ?? RemotePreviewState(status: .idle, preview: nil, manifest: nil, error: nil)
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Header Card
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                                Text(skill.displayName)
                                    .font(.system(.title2, weight: .black))
                                Text(skill.slug)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxxs) {
                                if let version = skill.latestVersion {
                                    Text("v\(version)")
                                        .font(.system(.title3, design: .monospaced))
                                        .fontWeight(.bold)
                                }
                                provenanceBadge(for: skill)
                            }
                        }
                        
                        if let owner = viewModel.ownerBySlug[skill.slug] ?? nil {
                            HStack(spacing: DesignTokens.Spacing.xxxs) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(DesignTokens.Colors.Accent.purple)
                                Text("by \(owner.displayName ?? owner.handle ?? "Unknown")")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                        }
                        
                        Divider()
                        
                        if let summary = skill.summary {
                            Text(summary)
                                .font(.system(.body, design: .serif))
                                .italic()
                                .foregroundStyle(DesignTokens.Colors.Text.primary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
                    .cornerRadius(DesignTokens.Radius.md)
                    
                    // Action Bar
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Button {
                            Task { await viewModel.install(skill: skill) }
                        } label: {
                            HStack {
                                if viewModel.installingSlug == skill.slug {
                                    ProgressView().scaleEffect(0.6).tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                }
                                Text(viewModel.installedVersions[skill.slug] != nil ? "Update and Verify" : "Download and verify")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.cleanProminent)
                        .tint(DesignTokens.Colors.Accent.blue)
                        .disabled(previewState.manifest == nil || viewModel.installingSlug != nil)
                        
                        if viewModel.isCrossIDEEnabled() {
                            Button {
                                Task { await viewModel.installToAllTargets(skill: skill) }
                            } label: {
                                Image(systemName: "square.grid.2x2.fill")
                                    .help("Install to all agent roots")
                            }
                            .buttonStyle(.clean)
                            .disabled(previewState.manifest == nil || viewModel.installingSlug != nil)
                        }
                        
                        Button {
                            Task { await viewModel.fetchPreview(for: skill) }
                        } label: {
                            Image(systemName: "checkmark.seal.fill")
                                .help("Re-verify provenance")
                        }
                        .buttonStyle(.clean)
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                    }
                    
                    // Security / Signer Card
                    signerCard(previewState: previewState)

                    // Per-Target Registration Status
                    if let outcome = viewModel.multiTargetOutcome {
                        perTargetStatusCard(outcome: outcome)
                    }
                    
                    // Content Preview Card
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Skill Preview", systemImage: "doc.richtext")
                                    .font(.system(size: 11, weight: .black))
                                    .textCase(.uppercase)
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)

                                if previewState.status == .available || previewState.preview != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(DesignTokens.Colors.Status.success)
                                        Text("Safe preview from server")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(DesignTokens.Colors.Status.success)
                                    }
                                }
                            }

                            Spacer()

                            if previewState.status == .loading {
                                ProgressView().scaleEffect(0.5)
                            }
                        }
                        
                        if let preview = previewState.preview, let markdown = preview.skillMarkdown {
                            MarkdownPreviewView(content: markdown)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 300)
                                .background(DesignTokens.Colors.Background.primary)
                                .cornerRadius(DesignTokens.Radius.sm)
                        } else if previewState.status == .loading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Fetching secure preview...")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.title)
                                    .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                                Text(previewState.status == .unavailable ? "Preview unavailable" : "Select Verify to load content")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(DesignTokens.Colors.Background.tertiary.opacity(0.2))
                            .cornerRadius(DesignTokens.Radius.sm)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
                    .cornerRadius(DesignTokens.Radius.md)
                    
                    // Changelog Section
                    if let change = viewModel.changelogBySlug[skill.slug] ?? nil {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Text("RECENT CHANGES")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            
                            Text(change)
                                .font(.system(.callout))
                                .padding(DesignTokens.Spacing.xs)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DesignTokens.Colors.Background.tertiary.opacity(0.3))
                                .cornerRadius(DesignTokens.Radius.sm)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(DesignTokens.Colors.Background.primary)
            .sheet(item: $trustPrompt) { prompt in
                TrustSignerSheet(prompt: prompt, trustStoreVM: trustStoreVM)
            }
        } else {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Select a skill to explore")
                    .font(.title2.weight(.bold))
                
                Text("Browse the remote marketplace for secure, verified skills from the community.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.Background.primary)
        }
    }

    @ViewBuilder
    private var localDetailPanel: some View {
        if let slug = selectedLocalSlug {
            let version = viewModel.installedVersions[slug] ?? "unknown"
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slug)
                                    .font(.title2.weight(.black))
                                Text("Local skill")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            }

                            Spacer()

                            Text("v\(version)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                        }

                        Divider()

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Button {
                                if let url = viewModel.localSkillURL(slug: slug) {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }
                            .buttonStyle(.clean)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.4))
                    .cornerRadius(DesignTokens.Radius.md)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Markdown Preview")
                            .heading3()

                        if let markdown = localPreviewMarkdown {
                            MarkdownPreviewView(content: markdown)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 240)
                                .background(DesignTokens.Colors.Background.primary)
                                .cornerRadius(DesignTokens.Radius.sm)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading local skill...")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(DesignTokens.Colors.Background.tertiary.opacity(0.2))
                            .cornerRadius(DesignTokens.Radius.sm)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
                    .cornerRadius(DesignTokens.Radius.md)
                }
                .padding(DesignTokens.Spacing.sm)
            }
            .background(DesignTokens.Colors.Background.primary)
        } else {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "folder")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.Colors.Icon.tertiary)
                Text("Select a local skill")
                    .font(.title2.weight(.bold))
                Text("Choose a skill from the list to review its local content.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.Background.primary)
        }
    }

    @ViewBuilder
    private func signerCard(previewState: RemotePreviewState) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("SECURITY & TRUST")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            
            if let signerKeyId = previewState.manifest?.signerKeyId {
                let trusted = trustStoreVM.isTrusted(keyId: signerKeyId, slug: selectedSkill?.slug)
                
                HStack(spacing: DesignTokens.Spacing.xs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signer Identification")
                            .font(.caption.weight(.bold))
                        Text(signerKeyId)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DesignTokens.Colors.Text.secondary)
                    }
                    
                    Spacer()
                    
                    if trusted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                            Text("TRUSTED")
                        }
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(DesignTokens.Colors.Status.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.Status.success.opacity(0.1))
                        .cornerRadius(6)
                        
                        Button("Revoke") {
                            trustStoreVM.revokeKey(keyId: signerKeyId)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    } else {
                        Button {
                            trustPrompt = TrustPrompt(keyId: signerKeyId, slug: selectedSkill?.slug)
                        } label: {
                            Label("Trust Signer", systemImage: "hand.raised.fill")
                        }
                        .buttonStyle(.cleanProminent)
                        .tint(DesignTokens.Colors.Accent.orange)
                        .controlSize(.small)
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.Background.tertiary.opacity(0.4))
                .cornerRadius(DesignTokens.Radius.sm)
            } else if previewState.status == .loading {
                Text("Verifying artifact integrity...")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                    .shimmer()
            } else {
                HStack {
                    Image(systemName: "questionmark.diamond.fill")
                        .foregroundStyle(DesignTokens.Colors.Status.warning)
                    Text("Unknown Signer: Artifact is not cryptographicly signed.")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.Text.secondary)
                }
                .padding(DesignTokens.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.Status.warning.opacity(0.05))
                .cornerRadius(DesignTokens.Radius.sm)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
        .cornerRadius(DesignTokens.Radius.md)
    }

    @ViewBuilder
    private func perTargetStatusCard(outcome: MultiTargetInstallOutcome) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("INSTALLATION STATUS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)

                Spacer()

                let successRate = Double(outcome.successes.count) / Double(outcome.successes.count + outcome.failures.count) * 100
                Text("\(Int(successRate))% success")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(successRate >= 90 ? DesignTokens.Colors.Status.success : DesignTokens.Colors.Status.warning)
            }

            // Display status for each IDE target
            ForEach([AgentKind.codex, .claude, .copilot], id: \.self) { agent in
                targetStatusRow(agent: agent, outcome: outcome)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.3))
        .cornerRadius(DesignTokens.Radius.md)
    }

    private func targetStatusRow(agent: AgentKind, outcome: MultiTargetInstallOutcome) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // IDE icon/label
            HStack(spacing: 6) {
                Image(systemName: iconForAgent(agent))
                    .font(.system(size: 12))
                    .foregroundStyle(colorForAgent(agent))
                Text(agent.displayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.Text.primary)
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            // Status indicator
            if outcome.successes[agent] != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Installed")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(DesignTokens.Colors.Status.success)
            } else if let error = outcome.failures[agent] {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Failed")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(DesignTokens.Colors.Status.error)
                .help(error)
            } else {
                Text("Not attempted")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(DesignTokens.Colors.Background.tertiary.opacity(0.3))
        .cornerRadius(DesignTokens.Radius.sm)
    }

    private func iconForAgent(_ agent: AgentKind) -> String {
        switch agent {
        case .codex: return "square.stack.3d.up.fill"
        case .claude: return "brain.head.profile"
        case .copilot: return "sparkles"
        case .codexSkillManager: return "gear"
        }
    }

    private func colorForAgent(_ agent: AgentKind) -> Color {
        switch agent {
        case .codex: return DesignTokens.Colors.Accent.blue
        case .claude: return DesignTokens.Colors.Accent.orange
        case .copilot: return DesignTokens.Colors.Accent.purple
        case .codexSkillManager: return DesignTokens.Colors.Icon.secondary
        }
    }

    private func bulkOperationProgressView(_ progress: BulkOperationProgress) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ProgressView(value: progress.progressFraction)
                .frame(width: 80)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(progress.operation.rawValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("\(progress.completed) of \(progress.total)")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }

            Spacer()

            if progress.hasFailures {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(progress.failureSummary)
                }
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.Status.warning)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
        .cornerRadius(DesignTokens.Radius.sm)
    }
}

            Spacer()
        }
    }

    private func bulkOperationProgressView(_ progress: BulkOperationProgress) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ProgressView()
                .scaleEffect(0.6)

            Text("\(progress.current)/\(progress.total)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.clean)
                
                Spacer()
                
                Button {
                    let trimmed = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    let allowed = trustAllSkills ? nil : prompt.slug.map { [$0] }
                    trustStoreVM.addTrustedKey(keyId: prompt.keyId, publicKeyBase64: trimmed, allowedSlugs: allowed)
                    dismiss()
                } label: {
                    Text("Authorize Trust")
                        .fontWeight(.bold)
                        .frame(width: 120)
                }
                .buttonStyle(.cleanProminent)
                .tint(DesignTokens.Colors.Accent.orange)
                .disabled(publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.Accent.blue.opacity(0.1))
        .cornerRadius(DesignTokens.Radius.sm)
    }
}
