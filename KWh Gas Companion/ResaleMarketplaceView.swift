//
//  ResaleMarketplaceView.swift
//  KWh Gas Companion / My KWh Companion
//
//  Self-contained (no external types required).
//  - Baseline pricing links (Carvana + others)
//  - EV value drivers (filter chips + search + favorites)
//  - “What to include” proof points
//  - Brand notes (includes Rivian + GM EVs incl. Hummer EV) + easy pathway to add more
//
//  Swift 6 • iOS 17+
//

import SwiftUI

// MARK: - Models

private enum FactorCategory: String, CaseIterable, Identifiable, Hashable {
    case all
    case battery
    case charging
    case warranty
    case software
    case hardware
    case incentives
    case market

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .battery: return "Battery"
        case .charging: return "Charging"
        case .warranty: return "Warranty"
        case .software: return "Software"
        case .hardware: return "Hardware"
        case .incentives: return "Incentives"
        case .market: return "Market"
        }
    }

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .battery: return "battery.100"
        case .charging: return "bolt.car"
        case .warranty: return "checkmark.seal"
        case .software: return "cpu"
        case .hardware: return "wrench.and.screwdriver"
        case .incentives: return "percent"
        case .market: return "chart.line.uptrend.xyaxis"
        }
    }

    var sortOrder: Int {
        switch self {
        case .all: return 0
        case .battery: return 1
        case .charging: return 2
        case .warranty: return 3
        case .software: return 4
        case .hardware: return 5
        case .incentives: return 6
        case .market: return 7
        }
    }
}

private struct BaselineLink: Identifiable, Hashable {
    let id: String
    let title: String
    let urlString: String
    let icon: String

    static let defaults: [BaselineLink] = [
        .init(id: "carvana", title: "Carvana Value Tracker", urlString: "https://www.carvana.com/value-tracker", icon: "link.circle.fill"),
        .init(id: "kbb", title: "Kelley Blue Book (KBB)", urlString: "https://www.kbb.com/", icon: "tag.circle.fill"),
        .init(id: "edmunds", title: "Edmunds Appraisal", urlString: "https://www.edmunds.com/appraisal/", icon: "doc.text.magnifyingglass"),
        .init(id: "carsdotcom", title: "Cars.com Listings (compare comps)", urlString: "https://www.cars.com/", icon: "list.bullet.rectangle")
    ]
}

private struct Factor: Identifiable, Hashable {
    /// Stable ID so favorites survive app updates.
    let id: String
    let category: FactorCategory
    let icon: String
    let title: String
    let detail: String
    let keywords: [String]

    static let allEVValueDrivers: [Factor] = [
        // Battery
        .init(
            id: "battery_soh",
            category: .battery,
            icon: "battery.100",
            title: "Battery State of Health (SOH)",
            detail: "Capacity retention vs new (e.g., 88–95%). Buyers pay more for higher usable kWh and slower degradation.",
            keywords: ["soh", "health", "degradation", "capacity", "usable"]
        ),
        .init(
            id: "battery_chemistry_pack",
            category: .battery,
            icon: "cube.transparent",
            title: "Battery chemistry & pack variant",
            detail: "LFP vs NCA/NCM, usable pack size, and charging curve characteristics affect range perception and cycle life.",
            keywords: ["lfp", "nca", "ncm", "pack", "curve"]
        ),
        .init(
            id: "thermal_heat_pump",
            category: .battery,
            icon: "thermometer.snowflake",
            title: "Thermal system & heat pump",
            detail: "Heat pump presence and healthy thermal management improve cold-weather efficiency and buyer confidence.",
            keywords: ["heat pump", "thermal", "winter", "range"]
        ),

        // Charging
        .init(
            id: "dcfc_history",
            category: .charging,
            icon: "bolt.circle",
            title: "DC fast-charging history",
            detail: "High DCFC ratio and frequent high-SOC fast charging can raise buyer concerns. More home/AC charging can support value.",
            keywords: ["dcfc", "fast", "supercharger", "ccs", "nacs"]
        ),
        .init(
            id: "charging_network_access",
            category: .charging,
            icon: "bolt.badge.a.fill",
            title: "Charging network access",
            detail: "Native NACS port or reliable adapter support (and access to fast networks) improves usability—and resale appeal.",
            keywords: ["nacs", "ccs", "adapter", "network"]
        ),
        .init(
            id: "included_accessories",
            category: .charging,
            icon: "cable.connector",
            title: "Included charging gear",
            detail: "Mobile connector, Level-2 EVSE, NACS/CCS adapters, and complete cables reduce buyer friction.",
            keywords: ["evse", "mobile connector", "adapter", "cable"]
        ),

        // Warranty
        .init(
            id: "warranty_remaining",
            category: .warranty,
            icon: "checkmark.seal",
            title: "Warranty status",
            detail: "Remaining battery/drive-unit warranty years/miles (and any extended coverage) is a major pricing lever—document it clearly.",
            keywords: ["warranty", "battery warranty", "drive unit"]
        ),
        .init(
            id: "service_history_diagnostics",
            category: .warranty,
            icon: "doc.text.magnifyingglass",
            title: "Service & diagnostics history",
            detail: "Closed recalls, documented HV repairs, and recent inspections increase trust and reduce negotiation friction.",
            keywords: ["service", "recall", "diagnostics", "hv"]
        ),

        // Software
        .init(
            id: "packages_hw_generation",
            category: .software,
            icon: "cpu.fill",
            title: "Hardware & software packages",
            detail: "Driver-assist packages, hardware generation, infotainment version, and transfer policies influence demand.",
            keywords: ["driver assist", "infotainment", "packages", "hw", "features"]
        ),
        .init(
            id: "ota_support",
            category: .software,
            icon: "antenna.radiowaves.left.and.right",
            title: "OTA support & feature cadence",
            detail: "Active OTA updates and a clean software story add confidence. Show your current firmware/version screen.",
            keywords: ["ota", "firmware", "updates", "version"]
        ),

        // Hardware
        .init(
            id: "refresh_trim_options",
            category: .hardware,
            icon: "car.side",
            title: "Refresh & trim specifics",
            detail: "Mid-cycle refreshes and desirable trims/colors can materially shift market price, even at similar mileage.",
            keywords: ["refresh", "trim", "color", "options"]
        ),
        .init(
            id: "commercial_usage_signals",
            category: .hardware,
            icon: "building.2.fill",
            title: "Fleet / rideshare usage signals",
            detail: "Commercial patterns (high utilization, heavy DCFC) can weigh on perceived longevity even at similar mileage.",
            keywords: ["fleet", "rideshare", "commercial"]
        ),

        // Incentives
        .init(
            id: "policy_incentives",
            category: .incentives,
            icon: "percent",
            title: "Incentive eligibility & policy shifts",
            detail: "Used-EV credits and local rebates can change demand quickly. Know what your buyer might qualify for.",
            keywords: ["tax credit", "rebate", "incentive", "used ev"]
        ),

        // Market
        .init(
            id: "macro_market",
            category: .market,
            icon: "chart.line.uptrend.xyaxis",
            title: "Macro market factors",
            detail: "New-car price cuts, rates, fuel prices, and inventory levels can swing used EV pricing faster than ICE segments.",
            keywords: ["rates", "inventory", "price cuts", "market"]
        )
    ]
}

private struct ProofPoint: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String

    static let defaults: [ProofPoint] = [
        .init(id: "pp_soh", icon: "battery.100.bolt", title: "Battery health / SOH screenshot (service or diagnostics)"),
        .init(id: "pp_charge_mix", icon: "bolt.car", title: "AC vs DC charging mix (or fast-charge count)"),
        .init(id: "pp_records", icon: "wrench.adjustable", title: "Service records + closed recalls"),
        .init(id: "pp_warranty", icon: "doc.richtext", title: "Warranty statement with remaining years/miles"),
        .init(id: "pp_firmware", icon: "wifi", title: "Current firmware/version screen (OTA up to date)"),
        .init(id: "pp_accessories", icon: "cable.connector", title: "Included charging gear + adapters (NACS/CCS)"),
        .init(id: "pp_title", icon: "doc.text", title: "Clean title + lien release (if applicable)")
    ]
}

private enum EVBrandKey: String, CaseIterable, Hashable {
    case tesla
    case rivian
    case gm
    case other

    var displayName: String {
        switch self {
        case .tesla: return "Tesla"
        case .rivian: return "Rivian"
        case .gm: return "GM (Hummer / Lyriq / Blazer / Silverado)"
        case .other: return "Other EV brands"
        }
    }

    var icon: String {
        switch self {
        case .tesla: return "bolt.fill"
        case .rivian: return "mountain.2.fill"
        case .gm: return "shield.lefthalf.filled"
        case .other: return "square.grid.2x2"
        }
    }

    var sortOrder: Int {
        switch self {
        case .tesla: return 1
        case .rivian: return 2
        case .gm: return 3
        case .other: return 99
        }
    }
}

private struct EVBrandNote: Identifiable, Hashable {
    let key: EVBrandKey
    var id: String { key.rawValue }

    let title: String
    let icon: String
    let commonModels: [String]
    let highlights: [String]
    let concerns: [String]
    let include: [String]

    static let defaults: [EVBrandNote] = [
        .init(
            key: .tesla,
            title: EVBrandKey.tesla.displayName,
            icon: EVBrandKey.tesla.icon,
            commonModels: ["Model 3", "Model Y", "Model S", "Model X"],
            highlights: [
                "Clear charging story: home vs fast-charge mix + adapters included",
                "Document driver-assist package ownership and any transfer policy details",
                "Show recent service / tires / alignment as proof of care"
            ],
            concerns: [
                "Package/transferability confusion can derail offers",
                "High DC fast-charge share without context can spook buyers"
            ],
            include: [
                "Firmware/version screen + packages/features screen (if applicable)",
                "Accessory list (mobile connector, adapters)",
                "Warranty remaining years/miles"
            ]
        ),
        .init(
            key: .rivian,
            title: EVBrandKey.rivian.displayName,
            icon: EVBrandKey.rivian.icon,
            commonModels: ["R1T", "R1S"],
            highlights: [
                "Show OTA status and charging mix (home vs DC fast)",
                "Be explicit about adventure use—good underbody photos help",
                "List included gear (racks, adapters, portable EVSE)"
            ],
            concerns: [
                "Off-road questions: underbody scrapes, suspension wear, alignment",
                "Missing accessories can reduce perceived completeness"
            ],
            include: [
                "OTA version screenshot + notable features",
                "Adapter inventory + EVSE details",
                "Service invoices/recall closure proof"
            ]
        ),
        .init(
            key: .gm,
            title: EVBrandKey.gm.displayName,
            icon: EVBrandKey.gm.icon,
            commonModels: ["GMC Hummer EV", "Cadillac Lyriq", "Chevy Blazer EV", "Chevy Silverado EV", "Equinox EV"],
            highlights: [
                "Clarify your charging standard and included adapters/cables",
                "Document software/infotainment updates and any dealer work",
                "Share real-world efficiency/range and typical fast-charge behavior"
            ],
            concerns: [
                "Some buyers worry about early software issues—show update history/receipts",
                "Charging expectations vary—set a clear, factual story"
            ],
            include: [
                "Recall closure proof + service invoices",
                "Charging/accessory list (portable EVSE, adapters)",
                "Warranty remaining years/miles"
            ]
        ),
        .init(
            key: .other,
            title: EVBrandKey.other.displayName,
            icon: EVBrandKey.other.icon,
            commonModels: ["Mach-E", "F-150 Lightning", "Ioniq 5/6", "EV6/EV9", "ID.4", "Leaf", "i4", "EQS/EQE", "e-tron", "Taycan", "Polestar 2", "Air"],
            highlights: [
                "Lead with battery health + warranty clarity + charging access story",
                "Document service/recalls and include charging accessories"
            ],
            concerns: [
                "Unclear charging standard/adapters creates friction—be explicit"
            ],
            include: [
                "Battery/health or range evidence",
                "Recall closure + service receipts",
                "Accessory list + adapters"
            ]
        )
    ]
    .sorted { $0.key.sortOrder < $1.key.sortOrder }
}

// MARK: - Small UI Pieces

private struct CategoryChip: View {
    let category: FactorCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.displayName)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected
                    ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                    : AnyShapeStyle(.thinMaterial)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.20),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct FactorRow: View {
    let factor: Factor
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: factor.icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(factor.title)
                    .font(.subheadline.weight(.semibold))
                Text(factor.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.accentColor : .secondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - View

@MainActor
struct ResaleMarketplaceView: View {

    @State private var searchText: String = ""
    @State private var selectedCategory: FactorCategory = .all

    // Persist favorites as CSV of stable IDs
    @AppStorage("resaleFavoritedFactorIDsCSV") private var favoritedCSV: String = ""

    private var favoriteIDs: Set<String> {
        Set(
            favoritedCSV
                .split(separator: ",")
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private var filteredFactors: [Factor] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var list = Factor.allEVValueDrivers

        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }

        if !q.isEmpty {
            list = list.filter { f in
                f.title.lowercased().contains(q)
                || f.detail.lowercased().contains(q)
                || f.keywords.joined(separator: " ").lowercased().contains(q)
            }
        }

        return list.sorted { a, b in
            let af = favoriteIDs.contains(a.id)
            let bf = favoriteIDs.contains(b.id)
            if af != bf { return af && !bf }
            if a.category != b.category { return a.category.sortOrder < b.category.sortOrder }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var grouped: [(FactorCategory, [Factor])] {
        let cats = FactorCategory.allCases.filter { $0 != .all }
        return cats.compactMap { cat in
            let items = filteredFactors.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                baselineSection
                favoritesSection
                filterSection
                driversSection
                proofSection
                brandNotesSection
                disclaimerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Resale & Marketplace")
            .searchable(text: $searchText, prompt: "Search battery, warranty, charging…")
        }
    }

    // MARK: - Sections

    private var baselineSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Start with a third-party estimate, then adjust using EV-specific factors below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(BaselineLink.defaults) { link in
                    if let url = URL(string: link.urlString) {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: link.icon)
                                    .imageScale(.large)
                                    .foregroundStyle(Color.accentColor)

                                Text(link.title)
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Baseline estimate")
        }
    }

    private var favoritesSection: some View {
        Section {
            let fav = Factor.allEVValueDrivers.filter { favoriteIDs.contains($0.id) }
            if fav.isEmpty {
                Text("Tap the star on any factor to pin it here for quick copy/paste when listing or negotiating.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fav, id: \.id) { f in
                    FactorRow(
                        factor: f,
                        isFavorite: true,
                        onToggleFavorite: { toggleFavorite(f.id) }
                    )
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            Text("My talking points")
        }
    }

    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FactorCategory.allCases) { cat in
                        CategoryChip(category: cat, isSelected: selectedCategory == cat) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                selectedCategory = cat
                            }
                        }
                    }

                    if !searchText.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { searchText = "" }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                            }
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.20), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Filter")
        } footer: {
            Text("Favorites float to the top. Use categories to focus your listing and negotiation points.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var driversSection: some View {
        Section {
            if grouped.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                    Text("No matching factors")
                        .font(.headline)
                    Text("Try a different category or search term.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                ForEach(grouped, id: \.0) { (cat, items) in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color.accentColor)
                            Text(cat.displayName)
                                .font(.headline)
                            Spacer()
                            Text("\(items.count)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        ForEach(items, id: \.id) { f in
                            FactorRow(
                                factor: f,
                                isFavorite: favoriteIDs.contains(f.id),
                                onToggleFavorite: { toggleFavorite(f.id) }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        } header: {
            Text("EV value drivers")
        } footer: {
            Text("Works across Tesla, Rivian, and GM EVs (including Hummer EV), plus most other EV brands.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var proofSection: some View {
        Section {
            ForEach(ProofPoint.defaults) { p in
                Label(p.title, systemImage: p.icon)
                    .font(.subheadline)
            }
        } header: {
            Text("What to include in your listing")
        } footer: {
            Text("Evidence sells faster than vague claims. Screenshots + receipts reduce buyer uncertainty.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var brandNotesSection: some View {
        Section {
            ForEach(EVBrandNote.defaults) { note in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if !note.commonModels.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Common models")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(note.commonModels.joined(separator: " • "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !note.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Value-positive proof points")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(note.highlights, id: \.self) { t in
                                    Label(t, systemImage: "checkmark.seal")
                                        .font(.footnote)
                                }
                            }
                        }

                        if !note.concerns.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Buyer concerns to address")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(note.concerns, id: \.self) { t in
                                    Label(t, systemImage: "exclamationmark.triangle")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !note.include.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("What to include")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(note.include, id: \.self) { t in
                                    Label(t, systemImage: "doc.text")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: note.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        Text(note.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Brand notes")
        } footer: {
            Text("To add another brand later: add an `EVBrandKey` case + one `EVBrandNote` entry. The UI updates automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("Informational only — not financial advice. Market conditions, incentives, and transfer policies can change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func toggleFavorite(_ id: String) {
        var set = favoriteIDs
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        favoritedCSV = set.sorted().joined(separator: ",")
    }
}

#if DEBUG
#Preview {
    ResaleMarketplaceView()
}
#endif
