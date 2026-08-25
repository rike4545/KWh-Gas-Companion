//  DynamicSuperchargingExplainerILView.swift
//  My KWh Companion
//
//  Tesla Supercharging: Dynamic Pricing vs Time-of-Day (Illinois)
//  Swift 6 • iOS 17+
//
//  Illinois twist:
//  - Strong general consumer-fraud statute + price-gouging regs
//  - Separate Illinois Antitrust Act
//  - ICC regulates utilities and certifies EV charger installers, but does not tightly
//    set retail Supercharging prices like a classic tariff
//

import SwiftUI

@MainActor
struct DynamicSuperchargingExplainerILView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                DSILGlassCard(title: "Why dynamic Supercharging is risky in Illinois") {
                    Text("Illinois has robust consumer-fraud and antitrust statutes, plus price-gouging rules for emergencies. But like most states, it has not yet built a regulatory framework specifically for algorithmic EV-charging prices. Tesla’s dynamic Supercharging model can slip between these regimes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DSILBulletList(items: [
                        "Drivers experience volatility and opacity at the charger.",
                        "AG and ICC see only fragments unless they proactively collect data.",
                        "Competitors face a platform with deeper data and tighter integration."
                    ])
                }

                DSILGlassCard(title: "From ToD to dynamic: what changes") {
                    DSILTwoColumnRow(
                        leftTitle: "Time-of-day pricing",
                        leftPoints: [
                            "Simple peak/off-peak windows, published in advance.",
                            "Everyone in that window pays the same price.",
                            "Easier to benchmark against gas or other DC fast providers.",
                            "Works relatively well with Illinois’ utility-centric regulatory mindset."
                        ],
                        rightTitle: "Dynamic Supercharging",
                        rightPoints: [
                            "Real-time or near-real-time price shifts by location, time, and demand.",
                            "Potentially different prices for different drivers in similar circumstances.",
                            "Much harder for the Illinois AG or courts to spot patterns without deep data access.",
                            "Lets Tesla exercise platform power without obvious headline abuses."
                        ]
                    )
                }

                DSILLawSnapshotCard()
                DSILRiskMeterCard()
                DSILKhanCard()
                DSILHarmsToCompetitionCard()
                DSILProtectionsCard()
                DSILDisclaimerCard()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DSILTheme.background(for: scheme).ignoresSafeArea())
        .navigationTitle("Dynamic Supercharging – IL")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynamic Supercharging in Illinois")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(DSILTheme.accentGradient)

            Text("How Tesla’s dynamic Supercharging pricing interacts with Illinois consumer-fraud, price-gouging, and antitrust law.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DSILTagRow(tags: [
                "Illinois",
                "Tesla Supercharging",
                "Dynamic pricing",
                "Consumer fraud",
                "Antitrust"
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Law Snapshot Card (Illinois)

fileprivate struct DSILLawSnapshotCard: View {
    var body: some View {
        DSILGlassCard(title: "Illinois legal context for dynamic Supercharging") {
            VStack(alignment: .leading, spacing: 10) {
                DSILBulletHeader(label: "Consumer Fraud & Deceptive Practices (815 ILCS 505)") {
                    Text("Illinois’ Consumer Fraud and Deceptive Business Practices Act is broad: it covers unfair or deceptive acts in trade or commerce, including misleading price practices.")
                        .font(.subheadline)
                    DSILBulletList(items: [
                        "Price-gouging regulations for petroleum products and emergencies are implemented under this Act.",
                        "AG guidance treats “unconscionably high” prices for essentials during emergencies as unlawful.",
                        "But outside emergencies, the statute is still mostly aimed at deception and unfairness, not at **all** price discrimination."
                    ])
                }

                Divider().opacity(0.4)

                DSILBulletHeader(label: "Price-gouging rules") {
                    DSILBulletList(items: [
                        "Illinois has price-gouging regulations built on the Consumer Fraud Act and emergency-management powers.",
                        "They can reach excessive price hikes for commodities and services during declared disasters.",
                        "Whether Supercharging is treated as a covered “essential” in any particular emergency is fact-specific – and not yet deeply litigated."
                    ])
                }

                Divider().opacity(0.4)

                DSILBulletHeader(label: "Illinois Antitrust Act (740 ILCS 10)") {
                    DSILBulletList(items: [
                        "Prohibits unreasonable restraints of trade and monopolization.",
                        "Courts are instructed to look to federal antitrust case law as a guide, so the same consumer-welfare debates apply.",
                        "A pattern of dynamic pricing that forecloses rival DC fast networks could, in principle, be challenged as exclusionary conduct."
                    ])
                }

                Divider().opacity(0.4)

                DSILBulletHeader(label: "EV charging & the ICC") {
                    DSILBulletList(items: [
                        "The Illinois Commerce Commission regulates utilities and certifies EV-charger installers, but does not comprehensively set retail prices for private networks like Tesla’s.",
                        "That means Supercharger prices are **not** treated like standard utility rates subject to full rate-case review.",
                        "Instead, they sit in the intersection of consumer-fraud, antitrust, and light-touch infrastructure regulation."
                    ])
                }
            }
        }
    }
}

// MARK: - Risk Meter Card (Illinois)

fileprivate struct DSILRiskMeterCard: View {
    private let level: DSILRiskLevel = .elevated

    private let items: [DSILRiskItem] = [
        .init(label: "Complex legal patchwork", score: 4,
              explanation: "Multiple overlapping regimes (consumer fraud, price-gouging, antitrust, ICC) but no dedicated EV pricing rulebook."),
        .init(label: "Data asymmetry", score: 4,
              explanation: "Tesla sees session-level behavior across the fleet; regulators and rivals see only fragments."),
        .init(label: "Emergency vulnerability", score: 3,
              explanation: "During emergencies, price caps help on paper, but practical enforcement for EV charging is untested."),
        .init(label: "Platform leverage over rivals", score: 4,
              explanation: "Dynamic pricing plus routing control can steer volume away from emerging networks on key corridors."),
        .init(label: "Transparency for drivers", score: 4,
              explanation: "Drivers often can’t predict whether next week’s Supercharging will blow their budget, weakening household planning and lease economics.")
    ]

    var body: some View {
        DSILGlassCard(title: "Risk score: Illinois driver exposure") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(level.tint.gradient)
                        .frame(width: 12, height: 12)
                    Text(level.label)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Subjective, educational only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(items) { item in
                    DSILRiskRow(item: item)
                }
            }
        }
    }
}

// MARK: - Khan / Consumer Welfare Card (Illinois)

fileprivate struct DSILKhanCard: View {
    var body: some View {
        DSILGlassCard(title: "Lina Khan, consumer welfare, and Illinois antitrust") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Illinois antitrust law explicitly tells courts to look to federal antitrust doctrine, which has long leaned on the **consumer-welfare standard** – focusing on prices and output. Khan’s critique is that this lens is “unequipped to capture the architecture of market power” in platform markets.")
                    .font(.subheadline)

                DSILBulletList(items: [
                    "If Tesla keeps average Illinois Supercharger prices stable or modest, traditional “consumer-welfare” analysis may shrug.",
                    "But dynamic pricing, combined with dense integration (navigation, billing, fleet data), can **lock in drivers and marginalize rivals** without obvious price spikes.",
                    "Illinois courts applying federal-style consumer-welfare tests may therefore **under-enforce** against subtle platform abuses in the EV-charging stack."
                ])

                Text("A structural or “New Brandeis” approach would instead ask: how does dynamic Supercharging reshape market structure, bargaining power, and long-run options for Illinois drivers and would-be competitors?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Harms to Competition Card (Illinois)

fileprivate struct DSILHarmsToCompetitionCard: View {
    var body: some View {
        DSILGlassCard(title: "Potential harms to competition in Illinois") {
            DSILBulletList(items: [
                "Dynamic pricing can be used to **undercut competitors locally** where they try to enter, while over-recovering elsewhere – hard to catch with average price metrics.",
                "Where state-park or public-corridor charging is free or subsidized, Tesla can position Superchargers as the **default fast option** for longer trips, amplifying its platform power.",
                "Rivals that rely on transparent tariffs may appear more expensive in the short run, even if they are more stable and predictable long-term.",
                "Illinois’ reliance on federal-style consumer-welfare analysis risks under-weighting harms to sellers (independent charging networks) and labor while over-weighting short-term price snapshots.",
                "Once a few integrated platforms control most DC fast charging, future experiments in exploitative dynamic pricing will be far harder to discipline via entry."
            ])
        }
    }
}

// MARK: - Protections Card (Illinois)

fileprivate struct DSILProtectionsCard: View {
    var body: some View {
        DSILGlassCard(title: "Realistic protections for Illinois drivers") {
            DSILBulletList(items: [
                "✅ **Consumer Fraud Act** can target materially deceptive or unfair pricing practices, especially if Tesla’s disclosures are misleading.",
                "✅ **Price-gouging regulations** can address “unconscionably high” emergency pricing, including EV charging if treated as an essential service in that context.",
                "✅ **Illinois Antitrust Act + federal antitrust** can go after exclusionary dynamic-pricing strategies that help maintain or acquire monopoly power.",
                "⚠️ **No bespoke EV-pricing regime**: Supercharging lives in general law, not a dedicated EV tariff system.",
                "⚠️ **Evidence problem**: proving how an opaque algorithm behaves across thousands of sessions is expensive and technically complex, which itself chills enforcement."
            ])
        }
    }
}

// MARK: - Disclaimer Card (Illinois)

fileprivate struct DSILDisclaimerCard: View {
    var body: some View {
        DSILGlassCard(title: "Important disclaimer") {
            Text("This view is a critical, educational take on Tesla’s dynamic Supercharging in Illinois. It does not provide legal advice, does not opine on whether any specific price or practice is unlawful, and should not be relied on for litigation or regulatory decisions. Use it as a lens for understanding structural risk, not as a substitute for counsel.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Pieces (Illinois)

fileprivate enum DSILTheme {
    static let accent = Color(red: 0.80, green: 0.45, blue: 0.98)

    static func background(for scheme: ColorScheme) -> LinearGradient {
        let top = scheme == .dark
            ? Color(red: 0.03, green: 0.03, blue: 0.07)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
        let bottom = scheme == .dark
            ? Color(red: 0.05, green: 0.08, blue: 0.16)
            : Color(red: 0.90, green: 0.93, blue: 0.98)
        return LinearGradient(colors: [top, bottom],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.7)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

fileprivate struct DSILGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    scheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.1), radius: 7, x: 0, y: 3)
    }
}

fileprivate struct DSILTagRow: View {
    let tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                        )
                }
            }
        }
    }
}

fileprivate struct DSILBulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.body)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

fileprivate struct DSILBulletHeader<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            content
        }
    }
}

fileprivate struct DSILTwoColumnRow: View {
    let leftTitle: String
    let leftPoints: [String]
    let rightTitle: String
    let rightPoints: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            column(title: leftTitle, points: leftPoints)
            column(title: rightTitle, points: rightPoints)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func column(title: String, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
            DSILBulletList(items: points)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Risk Helpers (Illinois)

fileprivate struct DSILRiskItem: Identifiable {
    let id = UUID()
    let label: String
    let score: Int
    let explanation: String
}

fileprivate enum DSILRiskLevel {
    case elevated, high

    var label: String {
        switch self {
        case .elevated: return "Overall risk: Elevated"
        case .high:     return "Overall risk: High"
        }
    }

    var tint: Color {
        switch self {
        case .elevated: return Color.orange
        case .high:     return Color.red
        }
    }
}

fileprivate struct DSILRiskRow: View {
    let item: DSILRiskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index < item.score ? DSILTheme.accent : Color.secondary.opacity(0.3))
                            .frame(width: 10, height: 4)
                    }
                }
            }
            Text(item.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        DynamicSuperchargingExplainerILView()
    }
    .preferredColorScheme(.dark)
}
#endif
