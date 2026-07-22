//
//  ImportHubOnboardingSheet.swift
//  My KWh Companion
//
//  Full-screen welcome sheet shown the FIRST TIME the user opens
//  ChargingImportHubView. Persisted via @AppStorage so it never
//  shows again after dismissal.
//
//  Swift 6 / iOS 17+
//

import SwiftUI

// MARK: - Persistence key

private let kOnboardingSeenKey = "importHub.onboardingSeen.v1"

// MARK: - OnboardingSheet

struct ImportHubOnboardingSheet: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var appearance: AppAppearance

    var onDismiss: () -> Void

    @State private var cardVisible: [Bool] = [false, false, false, false]
    @State private var buttonVisible = false
    @State private var heroVisible = false

    private let cards: [OnboardingCard] = [
        OnboardingCard(
            icon: "bolt.car.fill",
            color: .blue,
            title: "Official Tesla CSV",
            body: "Import billing history straight from the Tesla app — each Supercharging session maps to a ledger entry with date, kWh, and cost."
        ),
        OnboardingCard(
            icon: "road.lanes",
            color: .purple,
            title: "TeslaFi Raw Telemetry",
            body: "Import raw TeslaFi polling logs to derive trip segments, route history, and detailed analytics."
        ),
        OnboardingCard(
            icon: "arrow.triangle.2.circlepath",
            color: .green,
            title: "Safe to Re-import",
            body: "Duplicate detection helps prevent double entries if you import the same file more than once."
        ),
        OnboardingCard(
            icon: "hand.raised.fill",
            color: .orange,
            title: "Stays on Your Device",
            body: "All imported data lives locally. Nothing is uploaded to a server or shared with third parties."
        ),
    ]

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                heroSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(Array(cards.enumerated()), id: \.0) { idx, card in
                            OnboardingCardView(card: card)
                                .opacity(cardVisible[idx] ? 1 : 0)
                                .offset(y: cardVisible[idx] ? 0 : 22)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }

                ctaButton
                    .opacity(buttonVisible ? 1 : 0)
                    .offset(y: buttonVisible ? 0 : 16)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .task { await runEntrance() }
    }

    // MARK: Background

    private var backgroundLayer: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(
                colors: [
                    appearance.accentColor.opacity(scheme == .dark ? 0.22 : 0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Layered bolt icon with glow ring
            ZStack {
                Circle()
                    .fill(appearance.accentColor.opacity(scheme == .dark ? 0.12 : 0.08))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(appearance.accentColor.opacity(scheme == .dark ? 0.20 : 0.14))
                    .frame(width: 82, height: 82)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(appearance.accentColor)
            }
            .padding(.top, 44)

            VStack(spacing: 8) {
                Text("Charging Imports")
                    .font(.largeTitle.weight(.bold))

                Text("Two pipelines, one home screen.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Here's everything you need to know.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    // MARK: CTA

    private var ctaButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                onDismiss()
            }
        } label: {
            HStack(spacing: 8) {
                Text("Get Started")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(appearance.accentColor)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: Entrance animation

    private func runEntrance() async {
        try? await Task.sleep(nanoseconds: 80_000_000)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            heroVisible = true
        }
        for i in cards.indices {
            try? await Task.sleep(nanoseconds: UInt64(110_000_000 * (i + 1)))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cardVisible[i] = true
            }
        }
        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            buttonVisible = true
        }
    }
}

// MARK: - Card model & view

private struct OnboardingCard: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let body: String
}

private struct OnboardingCardView: View {
    let card: OnboardingCard
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(card.color.opacity(scheme == .dark ? 0.20 : 0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: card.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(card.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.headline)
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07))
                )
        )
    }
}

// MARK: - View modifier for auto-presenting on first launch

struct ImportHubOnboardingModifier: ViewModifier {
    @AppStorage(kOnboardingSeenKey) private var seen = false
    @State private var showSheet = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !seen { showSheet = true }
            }
            .sheet(isPresented: $showSheet) {
                ImportHubOnboardingSheet {
                    seen = true
                    showSheet = false
                }
                .interactiveDismissDisabled(true)
            }
    }
}

extension View {
    /// Attach to `ChargingImportHubView` — shows the welcome sheet once, ever.
    func importHubOnboarding() -> some View {
        modifier(ImportHubOnboardingModifier())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ImportHubOnboardingSheet { }
        .environmentObject(AppAppearance())
}
#endif
