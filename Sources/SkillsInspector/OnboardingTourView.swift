import SwiftUI

// MARK: - Onboarding Tour View

/// Guided onboarding tour for first-time users showcasing key features.
/// Tour flow: Welcome → Validate → Remote → Changelog → Trust → Completion
struct OnboardingTourView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isSampleMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Colors.Background.primary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator

                Spacer()

                // Current step content
                stepContent
                    .frame(maxHeight: 400)

                Spacer()

                // Navigation buttons
                navigationButtons
                    .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .onAppear {
            // Start with subtle entrance animation
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.5)) {
                    // Animation handled by state change
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(stepColor(for: step))
                    .frame(width: 8, height: 8)
                    .accessibilityElement(children: .ignore)
            }
        }
        .padding(.top, DesignTokens.Spacing.md)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentStep.index + 1) of \(OnboardingStep.allCases.count)")
    }

    private func stepColor(for step: OnboardingStep) -> Color {
        let stepIndex = OnboardingStep.allCases.firstIndex(of: step) ?? 0
        let currentIndex = currentStep.index

        if stepIndex <= currentIndex {
            return DesignTokens.Colors.Accent.blue
        } else {
            return DesignTokens.Colors.Border.light
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .validate:
            validateStep
        case .remote:
            remoteStep
        case .changelog:
            changelogStep
        case .trust:
            trustStep
        case .completion:
            completionStep
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "app.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignTokens.Colors.Accent.blue)
                .symbolEffect(.bounce, value: currentStep)

            Text("Welcome to SkillsInspector")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.primary)

            Text("Your trustworthy skills inspector")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                featureRow(
                    icon: "checkmark.shield.fill",
                    title: "Verify Skills",
                    description: "Cryptographic verification ensures skills haven't been tampered with"
                )

                featureRow(
                    icon: "doc.text.fill",
                    title: "Track Changes",
                    description: "Complete changelog of all skill installations and updates"
                )

                featureRow(
                    icon: "lock.fill",
                    title: "Trust Store",
                    description: "Manage trusted signers and control what runs on your system"
                )
            }
            .padding()
            .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
            .cornerRadius(DesignTokens.Radius.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to SkillsInspector. Your trustworthy skills inspector with verify skills, track changes, and trust store features.")
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.Accent.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bodySmall()
                    .foregroundStyle(DesignTokens.Colors.Text.primary)

                Text(description)
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }
        }
    }

    // MARK: - Validate Step

    private var validateStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.Accent.purple)

            Text("Validate Skills")
                .heading2()

            Text("Scan your skill directories to find issues, validate structure, and ensure quality standards are met.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)

            // Sample validation results
            if isSampleMode {
                sampleValidationResults
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Validate Skills. Scan your skill directories to find issues and ensure quality.")
    }

    private var sampleValidationResults: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.Status.success)
                Text("MySkill.swift")
                    .bodySmall()
                Spacer()
                Text("No issues")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Status.success)
            }
            .padding()
            .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
            .cornerRadius(DesignTokens.Radius.sm)

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.Colors.Status.warning)
                Text("OldSkill.swift")
                    .bodySmall()
                Spacer()
                Text("3 findings")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Status.warning)
            }
            .padding()
            .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
            .cornerRadius(DesignTokens.Radius.sm)
        }
        .padding()
    }

    // MARK: - Remote Step

    private var remoteStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.Accent.green)

            Text("Remote Skills")
                .heading2()

            Text("Browse and install verified skills from the marketplace. Each skill is cryptographically signed for your security.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)

            // Sample skill card
            if isSampleMode {
                sampleSkillCard
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Remote Skills. Browse and install verified skills from the marketplace.")
    }

    private var sampleSkillCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(DesignTokens.Colors.Status.success)
                Text("Verified")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.Status.success)
            }

            Text("AI Code Assistant")
                .bodySmall()

            Text("Advanced AI-powered code completion and suggestions")
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
        }
        .padding()
        .frame(maxWidth: 280)
        .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Colors.Accent.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Changelog Step

    private var changelogStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.Accent.orange)

            Text("Skill Changelog")
                .heading2()

            Text("Track every installation, update, and removal with a signed changelog. Perfect for auditing and incident response.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)

            // Sample changelog entry
            if isSampleMode {
                sampleChangelogEntry
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Skill Changelog. Track every installation, update, and removal.")
    }

    private var sampleChangelogEntry: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack {
                Text("2026-01-14")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                Spacer()
                Text("INSTALL")
                    .captionText()
                    .foregroundStyle(DesignTokens.Colors.Status.success)
            }

            Text("AI Code Assistant v2.3.0")
                .bodySmall()

            Text("Installed from clawdhub.com")
                .captionText()
                .foregroundStyle(DesignTokens.Colors.Text.tertiary)
        }
        .padding()
        .frame(maxWidth: 320)
        .background(DesignTokens.Colors.Background.tertiary.opacity(0.5))
        .cornerRadius(DesignTokens.Radius.md)
    }

    // MARK: - Trust Step

    private var trustStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.Accent.blue)

            Text("Trust Store")
                .heading2()

            Text("Manage trusted signers and control which skills can run on your system. Revoke trust at any time.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)

            // Sample trust store
            if isSampleMode {
                sampleTrustStore
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trust Store. Manage trusted signers and control which skills can run.")
    }

    private var sampleTrustStore: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(DesignTokens.Colors.Status.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("clawdhub-official")
                        .bodySmall()
                        .font(.system(size: 10, design: .monospaced))
                    Text("Trusted Signer")
                        .captionText()
                        .foregroundStyle(DesignTokens.Colors.Text.tertiary)
                }
                Spacer()
                Text("TRUSTED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.Status.success)
            }
            .padding()
            .background(DesignTokens.Colors.Background.secondary.opacity(0.5))
            .cornerRadius(DesignTokens.Radius.sm)
        }
        .padding()
    }

    // MARK: - Completion Step

    private var completionStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignTokens.Colors.Status.success)
                .symbolEffect(.bounce, value: currentStep)

            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.Text.primary)

            Text("SkillsInspector is ready to help you manage and verify your skills with confidence.")
                .bodyText()
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Button("Get Started") {
                    completeTour()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Explore Sample Data") {
                    isSampleMode = true
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("You're all set! SkillsInspector is ready to help you manage and verify your skills.")
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Skip button
            if currentStep != .completion {
                Button("Skip Tour") {
                    completeTour()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DesignTokens.Colors.Text.secondary)
            }

            Spacer()

            // Sample mode toggle (for feature highlight steps)
            if [.validate, .remote, .changelog, .trust].contains(currentStep) {
                Button {
                    withAnimation {
                        isSampleMode.toggle()
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxxs) {
                        Image(systemName: isSampleMode ? "eye.fill" : "eye")
                        Text(isSampleMode ? "Sample Mode On" : "Sample Mode")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Next/Complete button
            Button(action: nextStep) {
                HStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text(nextButtonTitle)
                    if currentStep != .completion {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentStep == .completion && !isSampleMode)
        }
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome: return "Start Tour"
        case .completion: return isSampleMode ? "Get Started" : "Complete"
        default: return "Next"
        }
    }

    // MARK: - Actions

    private func nextStep() {
        if currentStep == .completion && isSampleMode {
            completeTour()
            return
        }

        guard currentStep != .completion else {
            completeTour()
            return
        }

        withAnimation(reduceMotion ? .easeOut : .spring(response: 0.3, dampingFraction: 0.8)) {
            if let nextStep = OnboardingStep.allCases.firstIndex(of: currentStep).flatMap({ index in
                OnboardingStep.allCases.indices.contains(index + 1) ? OnboardingStep.allCases[index + 1] : nil
            }) {
                currentStep = nextStep
            }
        }

        // Enable sample mode after first step
        if currentStep != .welcome {
            isSampleMode = true
        }
    }

    private func completeTour() {
        // Mark tour as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingTour")
        onComplete()
    }
}

// MARK: - Onboarding Step Enum

enum OnboardingStep: CaseIterable {
    case welcome
    case validate
    case remote
    case changelog
    case trust
    case completion

    var index: Int {
        OnboardingStep.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingTourView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingTourView {
            print("Tour completed")
        }
    }
}
#endif
