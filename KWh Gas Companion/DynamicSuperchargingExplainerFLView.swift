//  DynamicSuperchargingExplainerFLView.swift
//  My KWh Companion
//
//  Tesla Supercharging: Dynamic Pricing vs Time-of-Day (Florida)
//  Swift 6 • iOS 17+
//
//  Florida twist:
//  - EV charging by non-utilities is *explicitly* not a regulated retail electricity rate
//  - Pricing mostly lives under FDUTPA, price-gouging, and antitrust – not PSC tariffs
//

import SwiftUI

@MainActor
struct DynamicSuperchargingExplainerFLView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                DSFLGlassCard(title: "Dynamic Supercharging in a deregulated lane") {
                    Text("Florida deliberately keeps non-utility EV charging providers like Tesla outside traditional utility rate regulation. That makes it fertile ground for aggressive, algorithmic pricing – and leaves drivers leaning on general consumer-protection and antitrust law instead of rate cases.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DSFLBulletList(items: [
                        "You see a price in the app, but not the full logic behind it.",
                        "Non-utility fast charging is treated more like **retail services** than **regulated electricity**.",
                        "That design choice shapes how anti-consumer dynamic pricing can get before the law bites."
                    ])
                }

                DSFLGlassCard(title: "ToD vs dynamic: why the shift matters") {
                    DSFLTwoColumnRow(
                        leftTitle: "Time-of-day (ToD)",
                        leftPoints: [
                            "Simple peak/off-peak windows, fairly predictable.",
                            "Encourages load-shifting without targeting individual drivers.",
                            "Easier to compare against other networks or gas.",
                            "Looks a bit like a mini-utility tariff, even if private."
                        ],
                        rightTitle: "Dynamic Supercharging",
                        rightPoints: [
                            "Price can react to congestion, events, demand spikes.",
                            "Can be tuned to **when drivers are captive** (low SOC, no alternatives).",
                            "Creates room for data-driven price discrimination and dark patterns.",
                            "Harder for FDUTPA to police unless the patterns are blatant."
                        ]
                    )
                }

                DSFLLawSnapshotCard()
                DSFLRiskMeterCard()
                DSFLKhanCard()
                DSFLHarmsToCompetitionCard()
                DSFLProtectionsCard()
                DSFLDisclaimerCard()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DSFLTheme.background(for: scheme).ignoresSafeArea())
        .navigationTitle("Dynamic Supercharging – FL")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynamic Supercharging in Florida")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(DSFLTheme.accentGradient)
            Text("Tesla Supercharging prices in a state that treats non-utility EV charging as a market service, not a regulated rate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DSFLTagRow(tags: [
                "Florida",
                "Tesla Supercharging",
                "Dynamic pricing",
                "FDUTPA",
                "Antitrust"
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Law Snapshot Card (Florida)

fileprivate struct DSFLLawSnapshotCard: View {
    var body: some View {
        DSFLGlassCard(title: "Florida’s legal backdrop for dynamic Supercharging") {
            VStack(alignment: .leading, spacing: 10) {
                DSFLBulletHeader(label: "EV charging not treated as utility retail rates") {
                    Text("Florida Statute 366.94 says that non-utility EV charging is **not** the “retail sale of electricity,” and that non-utility charging rates, terms, and conditions are **not regulated** as public-utility rates.")
                        .font(.subheadline)
                    DSFLBulletList(items: [
                        "Tesla can set Supercharger prices without PSC tariff approval.",
                        "The PSC focuses more on infrastructure deployment rules and metering, not per-kWh margins.",
                        "This makes dynamic pricing a feature, not a bug, of Florida’s policy choice."
                    ])
                }

                Divider().opacity(0.4)

                DSFLBulletHeader(label: "FDUTPA: unfair & deceptive acts") {
                    Text("The Florida Deceptive and Unfair Trade Practices Act (FDUTPA) targets **deception and unfairness**, not normal profit-seeking per se.")
                        .font(.subheadline)
                    DSFLBulletList(items: [
                        "It can reach hidden fees, bait-and-switch, or materially misleading disclosures.",
                        "It is less tested against **complex algorithmic price discrimination**.",
                        "So a dynamic Supercharger algorithm could feel predatory in practice but still sit in a legal gray area if disclosed in boilerplate terms."
                    ])
                }

                Divider().opacity(0.4)

                DSFLBulletHeader(label: "Price-gouging: emergency-only tool") {
                    DSFLBulletList(items: [
                        "Under §501.160, “unconscionable” price hikes during declared emergencies can be illegal.",
                        "Historically aimed at gas, lodging, generators, essentials – but EV charging could be swept in for evacuation routes.",
                        "Outside emergency windows, it does **not** constrain day-to-day dynamic pricing."
                    ])
                }

                Divider().opacity(0.4)

                DSFLBulletHeader(label: "Florida Antitrust Act of 1980") {
                    DSFLBulletList(items: [
                        "Prohibits monopolization, attempts to monopolize, and certain restraints of trade.",
                        "State and federal enforcers could challenge a pattern where Tesla uses dynamic pricing to **exclude rivals** or control the DC fast market.",
                        "But as with most antitrust law, the focus is on **long-run structure and exclusion**, not every price spike that feels unfair."
                    ])
                }
            }
        }
    }
}

// MARK: - Risk Meter Card (Florida)

fileprivate struct DSFLRiskMeterCard: View {
    private let level: DSFLRiskLevel = .high

    private let items: [DSFLRiskItem] = [
        .init(label: "Regulatory vacuum", score: 5,
              explanation: "Non-utility charging prices largely escape rate regulation, so dynamic pricing has wide latitude."),
        .init(label: "Tourist & evacuation exposure", score: 5,
              explanation: "Out-of-state drivers and evac routes create moments of extreme dependence on Superchargers."),
        .init(label: "Behavioral & surge pricing", score: 4,
              explanation: "Dynamic pricing can track demand spikes (storms, events) in ways that are hard to verify as cost-based."),
        .init(label: "Market-power leverage", score: 4,
              explanation: "Tesla’s network lead plus app routing can be weaponized to keep volume away from would-be rivals."),
        .init(label: "Legal lag", score: 4,
              explanation: "FDUTPA and antitrust tools exist, but are slow, reactive, and not tuned for real-time algorithms.")
    ]

    var body: some View {
        DSFLGlassCard(title: "Risk score: Florida driver exposure") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(level.tint.gradient)
                        .frame(width: 12, height: 12)
                    Text(level.label)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Subjective, educational diagnostic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(items) { item in
                    DSFLRiskRow(item: item)
                }
            }
        }
    }
}

// MARK: - Khan / Consumer Welfare Card (Florida)

fileprivate struct DSFLKhanCard: View {
    var body: some View {
        DSFLGlassCard(title: "Consumer welfare vs platform power in Florida") {
            VStack(alignment: .leading, spacing: 10) {
                Text("In Lina Khan’s critique, antitrust that focuses on **short-term prices** misses how platforms entrench power through data, integration, and control of critical infrastructure. Florida’s policy of market-driven EV charging pricing makes that tension very visible.")
                    .font(.subheadline)

                DSFLBulletList(items: [
                    "If Tesla keeps **headline prices** close to or below rivals, traditional “consumer-welfare” analysis may see no problem.",
                    "But the **architecture of dependence** – Supercharger coverage on evacuation routes, tourist corridors, and key interstates – gives Tesla leverage that isn’t captured by a one-day price snapshot.",
                    "Dynamic pricing lets Tesla **exercise that leverage** quietly, user by user, in ways that FDUTPA and classic antitrust doctrine struggle to detect."
                ])

                Text("Under a structural lens, the key question becomes: “Is Tesla designing pricing and routing in a way that locks in Florida drivers and forecloses rivals?” – not just “Were prices a few cents higher this weekend?”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Harms to Competition Card (Florida)

fileprivate struct DSFLHarmsToCompetitionCard: View {
    var body: some View {
        DSFLGlassCard(title: "How dynamic Supercharging can distort competition (FL)") {
            DSFLBulletList(items: [
                "Tesla can temporarily underprice on specific competitive corridors (where EA/EVgo appear) while over-recovering in areas where drivers are captive.",
                "Tourist and seasonal demand makes it easy to quietly **test higher prices** on non-repeat customers with little backlash.",
                "Rivals without integrated navigation and fleet data can’t match **fine-grained dynamic pricing**, leaving them either under-monetizing or losing volume.",
                "Over time, that can consolidate DC fast charging into a few vertically integrated platforms, making future abuses harder to unwind.",
                "Because Florida chose not to regulate non-utility EV charging rates, many of these structural harms will show up only as **after-the-fact consumer pain**, not as docketed rate cases."
            ])
        }
    }
}

// MARK: - Protections Card (Florida)

fileprivate struct DSFLProtectionsCard: View {
    var body: some View {
        DSFLGlassCard(title: "What realistically protects Florida drivers today?") {
            DSFLBulletList(items: [
                "✅ **FDUTPA actions** if Tesla’s app or marketing is materially misleading or hides key price terms.",
                "✅ **Emergency price-gouging** if Supercharging becomes an “essential commodity” during a declared emergency and prices spike unconscionably.",
                "✅ **Florida & federal antitrust** if dynamic pricing is part of a scheme to exclude rivals or maintain monopoly power.",
                "⚠️ **No utility-style rate review** of non-utility Supercharging prices; PSC focus is more on grid impacts and programs than retail $/kWh.",
                "⚠️ **High proof burden**: showing that specific dynamic-pricing patterns cross the line from “hard bargaining” into unlawful exploitation is fact-intensive and expensive."
            ])
        }
    }
}

// MARK: - Disclaimer Card (Florida)

fileprivate struct DSFLDisclaimerCard: View {
    var body: some View {
        DSFLGlassCard(title: "Not legal advice") {
            Text("This tile is an educational, critical lens on Tesla’s dynamic Supercharging in Florida. It does not give you individualized legal advice, does not claim that Tesla has violated Florida law, and should not be the basis for litigation decisions. It’s here so you can better understand the structural risks baked into this pricing model.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Pieces (Florida)

fileprivate enum DSFLTheme {
    static let accent = Color(red: 0.98, green: 0.65, blue: 0.20)

    static func background(for scheme: ColorScheme) -> LinearGradient {
        let top = scheme == .dark
            ? Color(red: 0.02, green: 0.04, blue: 0.10)
            : Color(red: 0.96, green: 0.97, blue: 0.99)
        let bottom = scheme == .dark
            ? Color(red: 0.04, green: 0.08, blue: 0.18)
            : Color(red: 0.90, green: 0.94, blue: 0.99)
        return LinearGradient(colors: [top, bottom],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.7)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

fileprivate struct DSFLGlassCard<Content: View>: View {
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

fileprivate struct DSFLTagRow: View {
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

fileprivate struct DSFLBulletList: View {
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

fileprivate struct DSFLBulletHeader<Content: View>: View {
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

fileprivate struct DSFLTwoColumnRow: View {
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
            DSFLBulletList(items: points)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Risk Helpers (Florida)

fileprivate struct DSFLRiskItem: Identifiable {
    let id = UUID()
    let label: String
    let score: Int
    let explanation: String
}

fileprivate enum DSFLRiskLevel {
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

fileprivate struct DSFLRiskRow: View {
    let item: DSFLRiskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index < item.score ? DSFLTheme.accent : Color.secondary.opacity(0.3))
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
        DynamicSuperchargingExplainerFLView()
    }
    .preferredColorScheme(.dark)
}
#endif
