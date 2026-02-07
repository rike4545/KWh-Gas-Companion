//
//  DynamicSuperchargingExplainerView.swift
//  My KWh Companion / My EV Companion
//
//  State-aware wrapper for Dynamic Supercharging explainers.
//  - NY is the default
//  - Selector lets you switch between NY, CA, NJ, FL, and IL
//
//  This file hosts the state selector + NY content.
//  Other states (CA, NJ, FL, IL) live in their own files:
//
//  - DynamicSuperchargingExplainerCAView.swift
//  - DynamicSuperchargingExplainerNJView.swift
//  - DynamicSuperchargingExplainerFLView.swift
//  - DynamicSuperchargingExplainerILView.swift
//

import SwiftUI

// MARK: - State Enum

fileprivate enum DynamicSuperchargingState: String, CaseIterable, Identifiable {
    case ny, ca, nj, fl, il

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ny: return "NY"
        case .ca: return "CA"
        case .nj: return "NJ"
        case .fl: return "FL"
        case .il: return "IL"
        }
    }

    var fullName: String {
        switch self {
        case .ny: return "New York"
        case .ca: return "California"
        case .nj: return "New Jersey"
        case .fl: return "Florida"
        case .il: return "Illinois"
        }
    }
}

// MARK: - Root: State-aware Explainer

@MainActor
struct DynamicSuperchargingExplainerView: View {
    @Environment(\.colorScheme) private var scheme

    @State private var selectedState: DynamicSuperchargingState = .ny

    var body: some View {
        ZStack {
            // Unified background
            DSCTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                statePicker

                Divider()
                    .overlay(Color.white.opacity(scheme == .dark ? 0.18 : 0.12))
                    .padding(.bottom, 4)

                // The selected state's detailed explainer
                stateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        // Let the inner views control the exact navigation title
        // (NY/CA/NJ/FL/IL cards already set their own titles)
    }

    // MARK: - Header & Picker

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DSCTheme.accentGradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Dynamic Supercharging")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DSCTheme.primaryText(for: scheme))

                Text("Compare Tesla’s dynamic vs time-of-day pricing across states.")
                    .font(.caption)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("State focus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
                Spacer()
                Text(selectedState.fullName)
                    .font(.caption)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }

            Picker("State", selection: $selectedState) {
                ForEach(DynamicSuperchargingState.allCases) { state in
                    Text(state.label)
                        .tag(state)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - State Content Switcher

    @ViewBuilder
    private var stateContent: some View {
        switch selectedState {
        case .ny:
            DynamicSuperchargingNYDetailView()
        case .ca:
            // Uses your existing California file
            DynamicSuperchargingExplainerCAView()
        case .nj:
            // Uses your existing New Jersey file
            DynamicSuperchargingExplainerNJView()
        case .fl:
            // Uses your existing Florida file
            DynamicSuperchargingExplainerFLView()
        case .il:
            // Uses your existing Illinois file
            DynamicSuperchargingExplainerILView()
        }
    }
}

// MARK: - NEW YORK DETAIL (embedded here)

// This is the NY-specific explainer (previously your standalone DynamicSuperchargingExplainerView)
// Namespaced with DSC* so it doesn’t collide with other screens.

@MainActor
fileprivate struct DynamicSuperchargingNYDetailView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryCard
                driverRiskCard
                nyLawSnapshotCard
                linaKhanCard
                structuralHarmsCard
                protectionsCard
                disclaimerCard
            }
            .padding(.vertical, 16)
        }
        .background(Color.clear) // outer view already supplies gradient
        .navigationTitle("Dynamic Supercharging (NY)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New York: Dynamic Supercharging vs Time-of-Day Pricing")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSCTheme.primaryText(for: scheme))

            Text("Focused on Tesla Supercharging, not home utility rates. NY is the baseline for how dynamic pricing interacts with state consumer-protection and competition law.")
                .font(.callout)
                .foregroundStyle(DSCTheme.secondaryText(for: scheme))

            DSCTagRow(tags: [
                "Tesla Supercharging",
                "Dynamic pricing",
                "NY GBL §349 / §396-r",
                "Donnelly Act",
                "Platform power"
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        DSCGlassCard(title: "What changed when Tesla went dynamic?") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tesla is moving away from simple time-of-day Supercharger pricing toward **live, demand-based pricing**. Instead of clear off-peak vs peak windows, the price you pay depends on how busy the site is and when you plug in.")
                    .font(.callout)
                    .foregroundStyle(DSCTheme.primaryText(for: scheme))

                DSCBulletList(
                    title: "In practice, that means:",
                    items: [
                        "You may pay more at the same site than another driver did an hour earlier.",
                        "Budgeting road-trip charging becomes harder; the “going rate” is a moving target.",
                        "Tesla frames it as revenue-neutral: the *average* price stays about the same.",
                        "Because Tesla dominates DC fast charging for Teslas in NY, this change hits a large share of fast-charging events."
                    ]
                )

                Divider().overlay(DSCTheme.cardDivider)

                Text("The catch: classic “consumer welfare = price level” analysis looks only at averages. It ignores **who** pays the high prices, **when**, and **how much leverage** Tesla has at that moment.")
                    .font(.callout)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }
        }
    }

    private var driverRiskCard: some View {
        DSCGlassCard(title: "Why NY drivers may see this as anti-consumer") {
            VStack(alignment: .leading, spacing: 10) {
                DSCBulletList(
                    title: "Compared to simple time-of-day pricing, dynamic Supercharging:",
                    items: [
                        "Undermines predictability – it’s harder to plan your monthly EV budget or road-trip costs.",
                        "Penalizes people who **can’t flex time**: workers with fixed shifts, families on tight itineraries, renters who can’t charge at home.",
                        "Lets Tesla charge the most when you’re **most captive** (low state of charge, no realistic alternative nearby).",
                        "Shifts volatility onto drivers even if the long-run average price stays flat on a spreadsheet."
                    ]
                )

                DSCRiskMeterRow(
                    title: "Consumer risk snapshot (NY)",
                    items: [
                        DSCRiskItem(label: "Volatility", level: .high),
                        DSCRiskItem(label: "Budget stability", level: .low),
                        DSCRiskItem(label: "Choice at charger", level: .low)
                    ]
                )
            }
        }
    }

    private var nyLawSnapshotCard: some View {
        DSCGlassCard(title: "Where New York law actually bites (high-level)") {
            VStack(alignment: .leading, spacing: 10) {
                Text("New York doesn’t treat Tesla’s Supercharger price as a traditional utility tariff. Tesla buys electricity on regulated tariffs, but **your** price at the charger is governed mainly by general consumer-protection and competition rules.")
                    .font(.callout)
                    .foregroundStyle(DSCTheme.primaryText(for: scheme))

                DSCTagRow(tags: [
                    "GBL §349 – Deceptive practices",
                    "Algorithmic Pricing Disclosure Act",
                    "GBL §396-r – Price gouging",
                    "GBL §340 – Donnelly Act"
                ])

                DSCBulletList(
                    title: "Key levers under NY law:",
                    items: [
                        "GBL §349 bans **deceptive or misleading** acts. If the app UI or messaging hides how prices surge, or the number shown doesn’t match what you’re charged, that can be attacked as deceptive.",
                        "NY’s Algorithmic Pricing Disclosure rules require disclosure when an algorithm sets prices using your **personal data**, and they restrict using protected-class data in pricing.",
                        "GBL §396-r (price-gouging) lets the AG challenge “unconscionably excessive” prices for essential goods/services during abnormal market disruptions—think evacuation-route surges.",
                        "The Donnelly Act (NY antitrust) mirrors federal antitrust. It can reach **exclusionary conduct** if Tesla uses dynamic pricing + platform control to entrench fast-charging dominance."
                    ]
                )
            }
        }
    }

    private var linaKhanCard: some View {
        DSCGlassCard(title: "Lina Khan vs the “consumer welfare = price” lens") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Modern U.S. antitrust has leaned on the **consumer welfare standard**, often reduced to: “Are prices to consumers going up?” If not, regulators and courts tend to assume competition is fine.")
                    .font(.callout)
                    .foregroundStyle(DSCTheme.primaryText(for: scheme))

                Text("Lina Khan argues this test is **not fit for platform businesses** like Tesla, which is simultaneously:")
                    .font(.callout)
                    .foregroundStyle(DSCTheme.primaryText(for: scheme))

                DSCBulletList(
                    title: "Tesla’s platform stack in NY:",
                    items: [
                        "Designs the car and controls the in-car OS and navigation defaults.",
                        "Owns and operates the Supercharger network most Tesla drivers rely on.",
                        "Can push updates that change routing, pricing UI, and default choices overnight.",
                        "Holds rich behavioral data on when, where, and how drivers need to charge."
                    ]
                )

                Text("If you only ask “Did the **average price** go up?”, you miss whether Tesla is using dynamic pricing and UI control to deepen lock-in and **tilt the market structure** in its favor.")
                    .font(.footnote)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }
        }
    }

    private var structuralHarmsCard: some View {
        DSCGlassCard(title: "Structural harms beyond the immediate price per kWh") {
            VStack(alignment: .leading, spacing: 10) {
                DSCBulletList(
                    title: "In New York, dynamic Supercharging can:",
                    items: [
                        "Let Tesla **steer demand**: the in-car map highlights Superchargers (with live congestion/prices) and may give weaker visibility to rival fast-charging options.",
                        "Enable **targeted extraction**: drivers who can’t defer charging (low battery, winter conditions, late night) pay the highest prices, while flexible drivers chase discounts.",
                        "Help **raise rivals’ costs**: in corridors where competitors appear, Tesla can be aggressive on price; in “Supercharger-only” gaps, it can quietly harvest scarcity rents.",
                        "Leverage public support: where public funds help build out chargers, dynamic pricing lets Tesla privatize more upside while undermining the policy goal of affordable, predictable EV fueling."
                    ]
                )

                DSCRiskMeterRow(
                    title: "Competition risk snapshot (NY)",
                    items: [
                        DSCRiskItem(label: "Lock-in & steering", level: .high),
                        DSCRiskItem(label: "Rival entry climate", level: .low),
                        DSCRiskItem(label: "Transparency", level: .medium)
                    ]
                )
            }
        }
    }

    private var protectionsCard: some View {
        DSCGlassCard(title: "What protects NY drivers today (and what doesn’t)") {
            VStack(alignment: .leading, spacing: 10) {
                DSCBulletList(
                    title: "Real guardrails:",
                    items: [
                        "You must see a price before charging, and it must match billing. Big gaps or hidden add-ons can be attacked under GBL §349.",
                        "If Tesla ever personalizes Supercharger prices using your **personal data**, NY’s algorithmic pricing rules mandate clear disclosure and restrict certain data uses.",
                        "In declared emergencies, sharp surges at key sites can be scrutinized as **price gouging**, especially on evacuation routes or in fuel-scarcity zones.",
                        "Antitrust (Donnelly Act + federal law) can go after patterns where dynamic pricing plus platform control are used to **foreclose rivals** or cement gatekeeper status."
                    ]
                )

                Text("But none of this functions like a NYPSC rate case. There is **no ex-ante price-of-service review** for Supercharging. Most tools are reactive and data-intensive, which makes subtle abuses harder to reach.")
                    .font(.footnote)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }
        }
    }

    private var disclaimerCard: some View {
        DSCGlassCard(title: "Context, not legal advice") {
            VStack(alignment: .leading, spacing: 6) {
                Text("This New York view is an educational critique of Tesla’s dynamic Supercharging model, not legal advice. It doesn’t determine whether any specific session or policy is unlawful and doesn’t create an attorney-client relationship.")
                    .font(.footnote)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))

                Text("If you’re considering legal action or need advice about a lease, contract, or charging dispute, talk to a qualified attorney who can review the specific facts.")
                    .font(.footnote)
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }
        }
    }
}

// MARK: - NY Theme + Components (DSC*)

fileprivate enum DSCTheme {
    static let darkBackgroundTop    = Color(red: 7/255,  green: 11/255, blue: 18/255)
    static let darkBackgroundBottom = Color(red: 2/255,  green:  6/255, blue: 10/255)

    static let cardTop              = Color.white.opacity(0.10)
    static let cardBottom           = Color.white.opacity(0.02)
    static let cardBorder           = Color.white.opacity(0.14)
    static let divider              = Color.white.opacity(0.18)

    static let accentStart          = Color(red: 240/255, green:  86/255, blue:  60/255)
    static let accentEnd            = Color(red: 255/255, green: 149/255, blue:  94/255)

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
        scheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.70)
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

fileprivate struct DSCGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DSCTheme.primaryText(for: scheme))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DSCTheme.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(DSCTheme.cardStroke, lineWidth: 0.9)
                )
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 12)
    }
}

fileprivate struct DSCInfoChip: View {
    @Environment(\.colorScheme) private var scheme

    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(scheme == .dark ? 0.10 : 0.14))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .foregroundStyle(DSCTheme.secondaryText(for: scheme))
    }
}

fileprivate struct DSCBulletList: View {
    @Environment(\.colorScheme) private var scheme

    let title: String?
    let items: [String]

    init(title: String? = nil, items: [String]) {
        self.title = title
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSCTheme.secondaryText(for: scheme))
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(DSCTheme.accentGradient)
                        .frame(width: 10, alignment: .leading)

                    Text(item)
                        .font(.callout)
                        .foregroundStyle(DSCTheme.primaryText(for: scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

fileprivate struct DSCTagRow: View {
    @Environment(\.colorScheme) private var scheme

    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.12))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                        )
                        .foregroundStyle(DSCTheme.secondaryText(for: scheme))
                }
            }
        }
    }
}

// MARK: - Risk Meter (NY)

fileprivate enum DSCRiskLevel: String {
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
        case .low:    return 0.30
        case .medium: return 0.65
        case .high:   return 1.00
        }
    }
}

fileprivate struct DSCRiskItem: Identifiable {
    let id = UUID()
    let label: String
    let level: DSCRiskLevel
}

fileprivate struct DSCRiskMeterRow: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let items: [DSCRiskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSCTheme.secondaryText(for: scheme))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(DSCTheme.secondaryText(for: scheme))
                            .frame(width: 130, alignment: .leading)

                        GeometryReader { proxy in
                            let width = proxy.size.width * item.level.fillFraction
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(DSCTheme.accentGradient)
                                    .frame(width: max(width, 6))
                            }
                        }
                        .frame(height: 10)

                        Text(item.level.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DSCTheme.secondaryText(for: scheme))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        DynamicSuperchargingExplainerView()
    }
    .preferredColorScheme(.dark)
}
#endif
