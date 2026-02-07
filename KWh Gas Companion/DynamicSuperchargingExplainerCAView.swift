//
//  DynamicSuperchargingExplainerCAView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 11/17/25.
//


//
//  DynamicSuperchargingExplainerCAView.swift
//  My KWh Companion / My EV Companion
//
//  Swift 6 • iOS 17+
//
//  Explainer: Tesla Dynamic Supercharging vs Time-of-Day (TOU) pricing,
//  focused on California consumer risk, CPUC rules, and platform power.
//
//  NOTE: All helpers are namespaced with `DSCA` to avoid collisions.
//

import SwiftUI

@MainActor
struct DynamicSuperchargingExplainerCAView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryCard
                driverRiskCard
                caLawSnapshotCard
                linaKhanCard
                structuralHarmsCard
                protectionsCard
                disclaimerCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DSCATheme.background(for: scheme).ignoresSafeArea())
        .navigationTitle("Dynamic Supercharging (CA)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sections

private extension DynamicSuperchargingExplainerCAView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DSCATheme.accentGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.car.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dynamic Supercharging vs TOU")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DSCATheme.primaryText(for: scheme))

                    Text("How Tesla’s live pricing plays with California law, CPUC rules, and platform power.")
                        .font(.callout)
                        .foregroundStyle(DSCATheme.secondaryText(for: scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                DSCAInfoChip(icon: "waveform.path.ecg.rectangle", label: "High volatility")
                DSCAInfoChip(icon: "cpu", label: "Algorithms & power")
                DSCAInfoChip(icon: "building.columns", label: "California law")
            }
        }
    }

    var summaryCard: some View {
        DSCAGlassCard(title: "What Tesla Changed") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tesla is shifting away from simple Time-of-Day (TOU) Supercharger pricing toward **live, demand-based pricing**. Instead of fixed “off-peak vs peak” windows, the price you pay depends on how busy the site is when you plug in.")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.primaryText(for: scheme))

                DSCABulletList(
                    title: "Key traits of dynamic Supercharging:",
                    items: [
                        "Price is higher when a site is busy and lower when it’s empty.",
                        "The session price is shown before you start and then locked in.",
                        "Tesla says the *average* price over time stays about the same.",
                        "In California, Tesla is a major DC fast-charging provider, so this shift can touch a big share of highway fast charging."
                    ]
                )

                Divider().overlay(DSCATheme.cardDivider)

                Text("On paper, that can sound harmless: if the *average* doesn’t move, classic “consumer welfare” analysis may shrug. The real story is **who pays the highs, who gets the lows, and who controls the knobs.**")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.secondaryText(for: scheme))
            }
        }
    }

    var driverRiskCard: some View {
        DSCAGlassCard(title: "Why It Feels Anti-Consumer") {
            VStack(alignment: .leading, spacing: 10) {
                DSCABulletList(
                    title: "For everyday drivers, dynamic Supercharging can be worse than TOU because it:",
                    items: [
                        "Makes budgeting harder: you don’t know the price for your next road-trip stop until you’re nearly there.",
                        "Penalizes people who can’t flex their schedule: commuters, night-shift workers, families on tight itineraries.",
                        "Leverages “captive moments”: when a Supercharger is effectively the only fast charger on your route, dynamic pricing acts like a **toll on having an EV**.",
                        "Concentrates volatility: the people who most need reliability can get hit with the worst spikes, even if the long-run average price looks flat."
                    ]
                )

                DSCARiskMeterRow(
                    title: "Consumer risk snapshot",
                    items: [
                        DSCARiskItem(label: "Volatility", level: .high),
                        DSCARiskItem(label: "Budget stability", level: .low),
                        DSCARiskItem(label: "Choice at charger", level: .low)
                    ]
                )
            }
        }
    }

    var caLawSnapshotCard: some View {
        DSCAGlassCard(title: "California Law Snapshot (High-Level)") {
            VStack(alignment: .leading, spacing: 12) {
                Text("In California, the Public Utilities Commission has held that providers of EV charging services are generally **not regulated as public utilities**. They’re treated as end-use customers buying power from utilities, then reselling charging as a service. That means Tesla’s **Supercharger prices to drivers** are set competitively, not as CPUC-approved tariffs—but they’re still constrained by broad consumer-protection and competition laws.")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.primaryText(for: scheme))

                DSCATagRow(tags: [
                    "UCL – Bus. & Prof. Code §17200",
                    "CLRA – Civ. Code §1750+",
                    "Price gouging – Penal Code §396",
                    "Cartwright Act & AB 325"
                ])

                DSCABulletList(
                    title: "What actually touches Tesla’s dynamic pricing:",
                    items: [
                        "California’s Unfair Competition Law (UCL) broadly forbids “unlawful, unfair, or fraudulent” business acts and misleading advertising. It’s used to attack dark patterns, hidden fees, and misleading pricing structures—not just classic anticompetitive conduct.",
                        "The Consumers Legal Remedies Act (CLRA) gives drivers a private right of action when a company uses certain deceptive practices in selling goods or services—for example, misrepresenting charges or burying key fees and conditions.",
                        "The state’s price-gouging statute (Penal Code §396) generally caps price increases on many essential goods and services at 10% during and shortly after declared emergencies, unless higher prices are justified by increased costs. If EV fast charging is treated as essential during evacuations or disasters, aggressive surge-like pricing can be scrutinized under this law.",
                        "California’s Cartwright Act is the state antitrust statute. New amendments like AB 325 explicitly target **common pricing algorithms**, limiting the use of shared pricing engines and coercive algorithmic pricing, because those can act as a vehicle for cartel-like coordination."
                    ]
                )
            }
        }
    }

    var linaKhanCard: some View {
        DSCAGlassCard(title: "Lina Khan & the Consumer-Welfare Blind Spot") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Modern U.S. antitrust has leaned on the **consumer welfare standard**—basically asking whether prices to consumers go up in the short term. If prices stay low or “about the same,” enforcement often assumes competition is working.")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.primaryText(for: scheme))

                Text("Lina Khan’s work argues this test **doesn’t fit platform businesses**. Tesla is not just selling energy; it builds the car, runs the operating system and navigation, and controls a major fast-charging network. Looking only at today’s average Supercharger price misses deeper structural harms:")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.primaryText(for: scheme))

                DSCABulletList(
                    title: "Khan’s critique, applied to Tesla:",
                    items: [
                        "Short-term prices can look fine even as a platform quietly **locks in users and sidelines rivals**.",
                        "Gatekeepers can use data and control over the interface (like in-car navigation) to **steer demand** toward their own chargers, regardless of whether they’re the cheapest option.",
                        "Dynamic, algorithmic pricing becomes a lever of **platform power**: it can target captive users with higher prices and strategically undercut rival chargers where competition exists.",
                        "A focus on “average prices” ignores **who** pays the highs, **who** gets the lows, and **how** that pattern shapes the future market structure."
                    ]
                )
            }
        }
    }

    var structuralHarmsCard: some View {
        DSCAGlassCard(title: "Structural Harms Beyond the Price Tag") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Even if Tesla keeps the average Supercharger price roughly flat, a platform-power lens reveals harms that a price-only test glosses over.")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.primaryText(for: scheme))

                DSCABulletList(
                    title: "How dynamic Supercharging can distort the market:",
                    items: [
                        "Steering & self-preferencing: Tesla’s navigation can highlight Superchargers (with live prices and congestion) while giving weaker visibility into rival fast chargers, nudging you into its own network even when others are cheaper.",
                        "Targeted extraction: high “busy-site” prices fall on drivers who can’t defer charging. Flexible drivers chase discounts; trapped drivers pay more.",
                        "Raising rivals’ costs: in corridors with strong competition, Tesla can price sharply; in Supercharger-only gaps, it can quietly harvest scarcity rents. That pattern can chill investment by competing networks.",
                        "Using public support, then privatizing the upside: where public programs help finance EV infrastructure, aggressive dynamic pricing lets the operator keep more upside while undermining the policy goal of broadly affordable EV fueling."
                    ]
                )

                DSCARiskMeterRow(
                    title: "Competition risk snapshot",
                    items: [
                        DSCARiskItem(label: "Lock-in & steering", level: .high),
                        DSCARiskItem(label: "Rival entry climate", level: .low),
                        DSCARiskItem(label: "Transparency", level: .medium)
                    ]
                )
            }
        }
    }

    var protectionsCard: some View {
        DSCAGlassCard(title: "What Protection Exists Today (CA)") {
            VStack(alignment: .leading, spacing: 10) {
                DSCABulletList(
                    title: "In California, the main guardrails are:",
                    items: [
                        "If the price shown in the Tesla app before you start charging doesn’t match what you’re billed—or if important surcharges are hidden in the UI—drivers can potentially challenge that under the UCL and CLRA as unfair or deceptive.",
                        "During declared states of emergency, Penal Code §396 generally limits price increases on many essential goods and services to 10% above pre-emergency levels (unless higher prices are justified by increased costs). If EV charging is treated as essential to evacuation or disaster response, sharp dynamic surges could be examined as illegal price gouging.",
                        "The Cartwright Act, reinforced by new AB 325 provisions, gives enforcers tools to attack **algorithmic collusion**—for example, where networks rely on a shared pricing algorithm or pressure each other to adopt algorithmic prices.",
                        "Federal antitrust law overlays all of this: regulators can look at whether a dominant charging network uses dynamic pricing plus platform control in ways that exclude rivals or cement its gatekeeper position, even if “average” prices look reasonable."
                    ]
                )

                Text("None of these rules bans dynamic pricing outright. Instead, they make it riskier to rely on opaque algorithms, misleading UI, or surge-like pricing in moments when drivers have little or no real alternative.")
                    .font(.callout)
                    .foregroundStyle(DSCATheme.secondaryText(for: scheme))
            }
        }
    }

    var disclaimerCard: some View {
        DSCAGlassCard(title: "Context, Not Legal Advice") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This screen is an educational overview of how Tesla’s dynamic Supercharging interacts with California law and platform-power debates.")
                    .font(.footnote)
                    .foregroundStyle(DSCATheme.secondaryText(for: scheme))

                Text("It is **not legal advice**, does not create an attorney-client relationship, and may omit details relevant to your situation. If you are considering legal action or need advice about a lease, contract, or charging dispute, consult a qualified attorney.")
                    .font(.footnote)
                    .foregroundStyle(DSCATheme.secondaryText(for: scheme))
            }
        }
    }
}

// MARK: - Theme

fileprivate enum DSCATheme {
    static let darkBackgroundTop    = Color(red: 7/255,  green: 11/255, blue: 18/255)
    static let darkBackgroundBottom = Color(red: 2/255,  green: 6/255,  blue: 10/255)

    static let cardTop              = Color.white.opacity(0.08)
    static let cardBottom           = Color.white.opacity(0.02)
    static let cardBorder           = Color.white.opacity(0.10)

    static let accentStart          = Color(red: 240/255, green: 86/255,  blue: 60/255)
    static let accentEnd            = Color(red: 255/255, green: 149/255, blue: 94/255)

    static let divider              = Color.white.opacity(0.18)

    static func background(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [darkBackgroundTop, darkBackgroundBottom]
                : [Color.black.opacity(0.04), Color.white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 15/255, green: 17/255, blue: 23/255)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.72)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardBackground: LinearGradient {
        LinearGradient(
            colors: [cardTop, cardBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardStroke: Color { cardBorder }
    static var cardDivider: Color { divider }
}

// MARK: - Reusable Components (namespaced)

fileprivate struct DSCAGlassCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DSCATheme.primaryText(for: scheme))

            content
        }
        .padding(16)
        .background(
            DSCATheme.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(DSCATheme.cardStroke, lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 14)
    }
}

fileprivate struct DSCAInfoChip: View {
    let icon: String
    let label: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
        )
        .foregroundStyle(DSCATheme.primaryText(for: scheme).opacity(0.9))
    }
}

fileprivate struct DSCABulletList: View {
    let title: String
    let items: [String]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSCATheme.secondaryText(for: scheme))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(DSCATheme.accentGradient)
                            .frame(width: 10, alignment: .leading)

                        Text(item)
                            .font(.callout)
                            .foregroundStyle(DSCATheme.primaryText(for: scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

fileprivate struct DSCATagRow: View {
    let tags: [String]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(Color.white.opacity(scheme == .dark ? 0.06 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .foregroundStyle(DSCATheme.secondaryText(for: scheme))
                }
            }
        }
    }
}

// MARK: - Risk Meter

fileprivate enum DSCARiskLevel: String {
    case low, medium, high

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var fillFraction: CGFloat {
        switch self {
        case .low:    return 0.3
        case .medium: return 0.65
        case .high:   return 1.0
        }
    }
}

fileprivate struct DSCARiskItem: Identifiable {
    let id = UUID()
    let label: String
    let level: DSCARiskLevel
}

fileprivate struct DSCARiskMeterRow: View {
    let title: String
    let items: [DSCARiskItem]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSCATheme.secondaryText(for: scheme))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(DSCATheme.secondaryText(for: scheme))
                            .frame(width: 130, alignment: .leading)

                        GeometryReader { proxy in
                            let width = proxy.size.width * item.level.fillFraction
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(DSCATheme.accentGradient)
                                    .frame(width: max(width, 6))
                            }
                        }
                        .frame(height: 10)

                        Text(item.level.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DSCATheme.secondaryText(for: scheme))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DynamicSuperchargingExplainerCAView()
    }
}
