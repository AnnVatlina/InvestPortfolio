//
//  OnboardingView.swift
//  InvestPortfolio
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("App_HasCompletedOnboarding") private var hasCompleted = false
    @EnvironmentObject private var container: DIContainer
    @Environment(\.locale) private var locale

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Hero
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.22, green: 0.56, blue: 0.92),
                                     Color(red: 0.12, green: 0.36, blue: 0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 104, height: 104)
                        .shadow(color: .blue.opacity(0.35), radius: 16, y: 6)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("app.name")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("onboarding.tagline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 56)

            Spacer()

            // MARK: Features
            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "banknote.fill",
                    gradient: [.green, .teal],
                    title: "deposits.title",
                    description: "onboarding.feature.deposits"
                )
                featureRow(
                    icon: "repeat.circle.fill",
                    gradient: [.orange, Color(red: 1, green: 0.6, blue: 0.2)],
                    title: "subscriptions.title",
                    description: "onboarding.feature.subscriptions"
                )
                featureRow(
                    icon: "chart.bar.fill",
                    gradient: [.purple, .indigo],
                    title: "analytics.title",
                    description: "onboarding.feature.analytics"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // MARK: Error
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            // MARK: Buttons
            VStack(spacing: 12) {
                Button {
                    Task { await loadSampleAndContinue() }
                } label: {
                    Text("onboarding.tryDemo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)

                Button("onboarding.startFresh") {
                    hasCompleted = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("onboarding.loading")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    // MARK: - Feature row

    private func featureRow(
        icon: String,
        gradient: [Color],
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadSampleAndContinue() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SampleDataService.load(into: container)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }
        hasCompleted = true
    }
}
