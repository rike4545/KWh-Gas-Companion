//  DynamicSuperchargingExplainerNJView.swift
//  My KWh Companion
//
//  Tesla Supercharging: Dynamic Pricing vs Time-of-Day (New Jersey)
//  Swift 6 • iOS 17+
//
//  - Focused on Tesla Supercharging (not home rates)
//  - Highlights NJ consumer-protection, price-gouging & antitrust context
//  - Frames dynamic pricing as structurally anti-consumer & competition-risky
//  - Uses Lina Khan’s critique of the “consumer welfare” (short-term price) test
//

import SwiftUI

@MainActor
struct DynamicSuperchargingExplainerNJView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                header

                DSNJGlassCard(title: "Why this tile exists") {
                    Text("Tesla’s move from simple time-of-day (ToD) pricing to opaque, algorithmic Supercharging prices can be especially risky in states like New Jersey, where EV charging is treated as a market service rather than a regulated utility rate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DSNJBulletList(items: [
                        "Help you spot when “dynamic” really means “price discrimination with no guardrails.”",
                        "Show where New Jersey’s laws do and don’t protect you today.",
                        "Frame how this fits into bigger debates about platform power and antitrust."
                    ])
                }

                DSNJGlassCard(title: "Dynamic Supercharging vs ToD") {
                    DSNJTwoColumnRow(
                        leftTitle: "Old model: Time-of-day",
                        leftPoints: [
                            "Published peak/off-peak windows.",
                            "Everyone at that time pays the same $/kWh.",
                            "Easier to budget & compare vs competitors.",
                            "Feels more like a utility tariff, even if set by Tesla."
                        ],
                        rightTitle: "New model: Dynamic pricing",
                        rightPoints: [
                            "Price can shift by time, congestion, site, and demand.",
                            "Drivers may see different prices at the same time.",
                            "Harder to tell if increases are cost-based or pure margin.",
                            "Creates scope for behavioral & exploitative pricing."
                        ]
                    )
                }

                DSNJLawSnapshotCard()

                DSNJRiskMeterCard()

                DSNJKhanCard()

                DSNJHarmsToCompetitionCard()

                DSNJProtectionsCard()

                DSNJDisclaimerCard()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DSNJTheme.background(for: scheme).ignoresSafeArea())
        .navigationTitle("Dynamic Supercharging – NJ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynamic Supercharging vs Time-of-Day Pricing")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(DSNJTheme.accentGradient)

            Text("Focused on Tesla Supercharging in New Jersey – not your home or utility bills.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DSNJTagRow(tags: [
                "Tesla Supercharging",
                "Dynamic pricing",
                "New Jersey law",
                "Consumer protection"
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Law Snapshot Card

fileprivate struct DSNJLawSnapshotCard: View {
    var body: some View {
        DSNJGlassCard(title: "How New Jersey sees EV charging & pricing") {
            VStack(alignment: .leading, spacing: 10) {
                Text("This is a blunt summary, not legal advice. But it shows why dynamic Supercharging sits in a gray zone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DSNJBulletHeader(label: "EV charging is not a \"public utility\" rate") {
                    Text("New Jersey law and BPU policy treat most EV charging networks as **competitive services, not public utilities**. That means:")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    DSNJBulletList(items: [
                        "BPU does not set retail $/kWh for Tesla’s Superchargers.",
                        "Prices are largely governed by contract terms, disclosures, and general consumer-protection rules.",
                        "Programs like Charge Up NJ push deployment, but don’t tightly regulate what Tesla can charge per session."
                    ])
                }

                Divider().opacity(0.4)

                DSNJBulletHeader(label: "Consumer-protection backstop") {
                    Text("The **New Jersey Consumer Fraud Act (CFA)** bans “unconscionable or abusive” commercial practices and deceptive pricing or marketing.")
                        .font(.subheadline)
                    DSNJBulletList(items: [
                        "It can reach dark-pattern pricing or materially misleading disclosures.",
                        "But it is built to punish **fraud and deception**, not fine-grained algorithmic price discrimination.",
                        "So a price can be **sharp and unfair in practice** yet still survive if Tesla disclosed its right to vary prices."
                    ])
                }

                Divider().opacity(0.4)

                DSNJBulletHeader(label: "Price-gouging – but only in emergencies") {
                    DSNJBulletList(items: [
                        "During a declared state of emergency, NJ caps “excessive price increases” (often benchmarked ~10%+ above pre-emergency levels).",
                        "That tool is meant for gas, food, generators, etc. It **could** apply to Supercharging if the facts line up, but only in narrow windows.",
                        "Outside emergencies, there is **no specific cap** on rapid, non-transparent Supercharger price jumps."
                    ])
                }

                Divider().opacity(0.4)

                DSNJBulletHeader(label: "Antitrust: New Jersey Antitrust Act") {
                    DSNJBulletList(items: [
                        "Mirrors federal Sherman/Clayton logic: bans contracts, combinations, or conspiracies that restrain trade, and monopolization/abuse.",
                        "In theory, could reach **exploitative or exclusionary pricing** if Tesla used Supercharging to entrench dominance.",
                        "In practice, cases are slow, data-heavy, and usually brought for systemic patterns – not individual price spikes."
                    ])
                }
            }
        }
    }
}

// MARK: - Risk Meter Card

fileprivate struct DSNJRiskMeterCard: View {
    private let level: DSNJRiskLevel = .high

    private let items: [DSNJRiskItem] = [
        .init(label: "Price opacity", score: 5,
              explanation: "Drivers get little ex-ante visibility into how/why prices jump between sessions or sites."),
        .init(label: "Lock-in & switching costs", score: 5,
              explanation: "NJ Tesla owners are heavily steered to Superchargers; rival DC fast networks are sparse in key corridors."),
        .init(label: "Behavioral targeting", score: 4,
              explanation: "Dynamic prices can be tuned to desperation – low SOC, tight schedules – rather than cost."),
        .init(label: "Lease & financing spillovers", score: 4,
              explanation: "Leases and loan calculators often assume predictable charging costs; volatility flows through to lessees."),
        .init(label: "Competition impact", score: 4,
              explanation: "If rivals can’t match Tesla’s data or footprint, they may be squeezed out before they scale.")
    ]

    var body: some View {
        DSNJGlassCard(title: "Risk score: How exposed are NJ drivers?") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(level.tint.gradient)
                        .frame(width: 12, height: 12)
                    Text(level.label)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Subjective diagnostic – for education only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(items) { item in
                    DSNJRiskRow(item: item)
                }
            }
        }
    }
}

// MARK: - Khan / Consumer Welfare Card

fileprivate struct DSNJKhanCard: View {
    var body: some View {
        DSNJGlassCard(title: "Why “consumer welfare = low prices” misses the point") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Traditional antitrust has focused on **short-term prices**: if prices fall or stay low, courts assume competition is working. Lina Khan and other “New Brandeis” scholars argue that this **consumer-welfare test** is a bad fit for platform markets.")
                    .font(.subheadline)

                DSNJBulletList(items: [
                    "Platforms like Tesla can keep prices “not obviously outrageous” while still **tightening control** over drivers and rivals.",
                    "The real power comes from **data, network effects, vertical integration, and lock-in**, not just today’s per-kWh rate.",
                    "Dynamic pricing can **mask discrimination and exclusion** – especially when the algorithm is a black box."
                ])

                Text("In that lens, dynamic Supercharging can be anti-consumer and anti-competitive **even if average prices look fine**, because the metric should be: “Does this deepen dependency and close off alternatives?” not just “Is today’s price higher than last year’s?”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Harms to Competition Card

fileprivate struct DSNJHarmsToCompetitionCard: View {
    var body: some View {
        DSNJGlassCard(title: "Potential harms to competition (New Jersey flavor)") {
            VStack(alignment: .leading, spacing: 10) {
                DSNJBulletList(items: [
                    "Dynamic Supercharging lets Tesla **experiment with granular price discrimination** (time, site, driver behavior, congestion).",
                    "Rivals lack Tesla’s **fleet data, routing control, and in-car defaults**, making it hard to match targeted offers.",
                    "If Tesla cross-subsidizes some routes (e.g., temporarily cheap prices where it faces DC fast competition) and overcharges elsewhere, that can **starve competitors of volume** without triggering classic predatory-pricing tests.",
                    "As NJ pushes more EV adoption, early dominance in high-traffic corridors could become **self-reinforcing infrastructure power** – similar to app-store or e-commerce platforms.",
                    "Gaps in rate regulation mean most of this behavior is policed, if at all, by **after-the-fact litigation** rather than ex-ante rules."
                ])

                Text("These are exactly the kinds of structural harms the consumer-welfare test struggles to see, because they unfold through **architecture, defaults, and data**, not obvious per-kWh overcharges.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Protections Card

fileprivate struct DSNJProtectionsCard: View {
    var body: some View {
        DSNJGlassCard(title: "So what protections exist today in NJ?") {
            DSNJBulletList(items: [
                "✅ **Transparency & deception** – If Tesla’s app or marketing materially misleads drivers about how/when prices change, the CFA gives the AG and private plaintiffs tools.",
                "✅ **Emergency price-gouging** – During declared disasters, large spikes could be attacked as “excessive price increases,” though statutes were written with gas and essentials in mind.",
                "✅ **Antitrust (state + federal)** – If Tesla used dynamic pricing to exclude rivals (for example, targeted below-cost pricing where a competitor tries to enter), NJ and federal enforcers could pursue monopolization or unfair-competition theories.",
                "⚠️ **But**: none of these regimes give you **forward-looking, utility-style rate oversight** of Supercharging prices.",
                "⚠️ **Algorithmic opacity** means drivers, AGs, and regulators may struggle to **prove** that specific price paths were abusive, even if they feel that way on the ground."
            ])
        }
    }
}

// MARK: - Disclaimer Card

fileprivate struct DSNJDisclaimerCard: View {
    var body: some View {
        DSNJGlassCard(title: "Important disclaimer") {
            Text("This screen is educational and opinionated. It is not legal advice, does not take into account your specific facts, and does not claim that Tesla is violating New Jersey law. It’s designed to help you ask sharper questions about dynamic Supercharging and how it interacts with market power and consumer protection.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Pieces (NJ)

fileprivate enum DSNJTheme {
    static let accent = Color(red: 0.95, green: 0.40, blue: 0.22)

    static func background(for scheme: ColorScheme) -> LinearGradient {
        let top = scheme == .dark
            ? Color(red: 0.03, green: 0.03, blue: 0.06)
            : Color(red: 0.95, green: 0.96, blue: 0.99)
        let bottom = scheme == .dark
            ? Color(red: 0.05, green: 0.08, blue: 0.13)
            : Color(red: 0.90, green: 0.93, blue: 0.97)
        return LinearGradient(colors: [top, bottom],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [
            accent,
            accent.opacity(0.7)
        ], startPoint: .leading, endPoint: .trailing)
    }
}

fileprivate struct DSNJGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

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
        .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }
}

fileprivate struct DSNJTagRow: View {
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
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                }
            }
        }
    }
}

fileprivate struct DSNJBulletList: View {
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

fileprivate struct DSNJBulletHeader<Content: View>: View {
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

fileprivate struct DSNJTwoColumnRow: View {
    let leftTitle: String
    let leftPoints: [String]
    let rightTitle: String
    let rightPoints: [String]

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                column(title: leftTitle, points: leftPoints)
                column(title: rightTitle, points: rightPoints)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func column(title: String, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
            DSNJBulletList(items: points)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Risk Helpers

fileprivate struct DSNJRiskItem: Identifiable {
    let id = UUID()
    let label: String
    let score: Int   // 1–5
    let explanation: String
}

fileprivate enum DSNJRiskLevel {
    case moderate, elevated, high

    var label: String {
        switch self {
        case .moderate: return "Overall risk: Moderate"
        case .elevated: return "Overall risk: Elevated"
        case .high:     return "Overall risk: High"
        }
    }

    var tint: Color {
        switch self {
        case .moderate: return Color.yellow
        case .elevated: return Color.orange
        case .high:     return Color.red
        }
    }
}

fileprivate struct DSNJRiskRow: View {
    let item: DSNJRiskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index < item.score ? DSNJTheme.accent : Color.secondary.opacity(0.3))
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
        DynamicSuperchargingExplainerNJView()
    }
    .preferredColorScheme(.dark)
}
#endif
