//
//  EVMaterialsShiftView.swift
//  My KWh Companion — Shift
//
//  Educational Shift file: raw materials, composites, and lifecycle impacts
//  for EVs, written for non-engineers but grounded enough for power users.
//
//  ✅ Theme-aware (uses AppThemeSpec via Environment, but does NOT require AppAppearance)
//  ✅ Tesla-Glass optional background haze (reads "uiStyle" AppStorage, safe if absent)
//  ✅ Search within the Shift
//  ✅ Tap-anywhere expand/collapse with no double-toggle bugs
//  ✅ Optional coin easter egg (uses EasterEggCoinButton + hingedpic/unhingedpic assets)
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Foundation

// MARK: - Local UIStyle (kept file-scoped to avoid collisions)

fileprivate enum ShiftUIStyle: String {
    case classic
    case teslaGlass
}

// MARK: - Public View

@MainActor
public struct EVMaterialsShiftView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"
    private var uiStyle: ShiftUIStyle { ShiftUIStyle(rawValue: uiStyleRaw) ?? .classic }

    @State private var expanded: Set<UUID> = []
    @State private var searchText: String = ""

    // Static “last updated” text so it doesn’t drift every launch
    private let lastUpdated: String = "October 2025"

    public init() {}

    public var body: some View {
        let theme = themeBox.base

        ZStack {
            background(theme: theme)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(theme: theme)
                    controls(theme: theme)

                    if displayTopics.isEmpty {
                        emptyResultsCard(theme: theme)
                    } else {
                        ForEach(displayTopics) { topic in
                            ShiftSectionCard(
                                topic: topic,
                                isExpanded: expanded.contains(topic.id),
                                toggle: { toggle(topic.id) },
                                theme: theme
                            )
                        }
                    }

                    sources(theme: theme)
                    disclaimer(theme: theme)
                    footer(theme: theme)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("EV Materials & Environment")
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.enabled)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search materials, chemistries, recycling…"
        )
        .toolbar {
            // Optional easter egg coin (hingedpic / unhingedpic in Assets)
            ToolbarItem(placement: .topBarTrailing) {
                EasterEggCoinButton(
                    hingedAssetName: "hingedpic",
                    unhingedAssetName: "unhingedpic",
                    size: 32
                )
                .accessibilityLabel("Easter egg coin")
            }
        }
        .tint(theme.accent)
    }

    // MARK: - Derived

    private var displayTopics: [ShiftTopic] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return ShiftData.topics }

        return ShiftData.topics.filter { t in
            if t.title.lowercased().contains(q) { return true }
            if (t.subtitle ?? "").lowercased().contains(q) { return true }
            if t.bullets.contains(where: { $0.lowercased().contains(q) }) { return true }
            if t.details.contains(where: { $0.lowercased().contains(q) }) { return true }
            return false
        }
    }

    // MARK: - Background

    private func background(theme: any AppThemeSpec) -> some View {
        Rectangle()
            .fill(theme.screenBackground)
            .overlay {
                // Subtle accent haze (only when Tesla Glass is enabled)
                if uiStyle == .teslaGlass {
                    RadialGradient(
                        colors: [
                            theme.accent.opacity(scheme == .dark ? 0.55 : 0.20),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: scheme == .dark ? 640 : 560
                    )
                    .blur(radius: scheme == .dark ? 46 : 34)

                    RadialGradient(
                        colors: [
                            Color.purple.opacity(scheme == .dark ? 0.26 : 0.10),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: scheme == .dark ? 620 : 520
                    )
                    .blur(radius: scheme == .dark ? 48 : 36)
                }
            }
            .ignoresSafeArea()
    }

    // MARK: - Header

    private func header(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(scheme == .dark ? 0.18 : 0.14))
                    Circle()
                        .strokeBorder(theme.accent.opacity(scheme == .dark ? 0.35 : 0.25), lineWidth: 1)

                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Raw Materials & Composites in EVs")
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)

                    Text("What goes into an EV, where it comes from, and how it shapes impacts across mining, manufacturing, use, and end-of-life.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Content last refreshed: \(lastUpdated)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }

                Spacer(minLength: 8)
            }

            Divider().opacity(0.25)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                Text("Fast facts first — tap a card to expand for deeper technical context and lifecycle nuance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .shiftGlassCard(theme: theme)
    }

    // MARK: - Controls

    private func controls(theme: any AppThemeSpec) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    expanded = Set(ShiftData.topics.map(\.id))
                }
            } label: {
                Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    expanded.removeAll()
                }
            } label: {
                Label("Collapse All", systemImage: "chevron.up.chevron.down")
            }
            .buttonStyle(.bordered)

            Spacer()

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("\(displayTopics.count) result\(displayTopics.count == 1 ? "" : "s")")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote.weight(.semibold))
    }

    private func emptyResultsCard(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No matches", systemImage: "magnifyingglass")
                .font(.headline)
            Text("Try a broader term like “lithium”, “recycling”, “LFP”, “nickel”, or “SiC”.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .shiftGlassCard(theme: theme)
    }

    // MARK: - Sources & Notes

    private func sources(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Further Reading")
                .font(.title3.weight(.bold))
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("• US EPA – life-cycle greenhouse gas guidance for EVs and ICEVs.")
                Text("• Argonne National Laboratory – GREET model for well-to-wheels and materials impacts.")
                Text("• International Energy Agency – Global EV Outlook (annual).")
                Text("• Responsible Minerals Initiative & similar frameworks for supply-chain due diligence.")
                Text("• Global Battery Alliance – early work on ‘battery passports’ and transparency.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .shiftGlassCard(theme: theme)
    }

    private func disclaimer(theme: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes & Scope")
                .font(.headline)

            Text("""
Numbers vary by chemistry, supplier, model year, plant efficiency, and local grid mix. This Shift article summarizes common ranges and themes to help you reason about trade-offs — it doesn’t replace a specific vehicle’s Environmental Product Declaration or a full ISO-compliant lifecycle assessment.
""")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .shiftGlassCard(theme: theme)
    }

    private func footer(theme: any AppThemeSpec) -> some View {
        Text("Tip: Favorite this Shift in your Tools list if you reference it often.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    // MARK: - Expand / Collapse

    private func toggle(_ id: UUID) {
        withAnimation(.snappy(duration: 0.25)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }
}

// MARK: - Card View

fileprivate struct ShiftSectionCard: View {
    let topic: ShiftTopic
    let isExpanded: Bool
    let toggle: () -> Void
    let theme: any AppThemeSpec

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                fastFacts
                if isExpanded { detailsBlock }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .shiftGlassCard(theme: theme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(topic.title)
        .accessibilityHint(isExpanded ? "Collapses section." : "Expands section for more detail.")
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let icon = topic.icon {
                        Image(systemName: icon)
                            .imageScale(.medium)
                            .foregroundStyle(theme.accent)
                    }
                    Text(topic.title)
                        .font(.headline)
                }

                if let s = topic.subtitle, !s.isEmpty {
                    Text(s)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Text(isExpanded ? "Collapse" : "Expand")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(theme.separator.opacity(0.6), lineWidth: 1)
                )
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var fastFacts: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(topic.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.callout)
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var detailsBlock: some View {
        Divider().opacity(0.22)

        VStack(alignment: .leading, spacing: 10) {
            ForEach(topic.details, id: \.self) { detail in
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Model / Data (file-scoped to avoid collisions)

fileprivate struct ShiftTopic: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String?
    let bullets: [String]
    let details: [String]

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        bullets: [String],
        details: [String]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.bullets = bullets
        self.details = details
    }
}

fileprivate enum ShiftData {
    static let topics: [ShiftTopic] = [
        ShiftTopic(
            title: "Battery Materials",
            subtitle: "Lithium, nickel, cobalt, manganese, graphite, phosphate, copper, aluminum",
            icon: "battery.100.bolt",
            bullets: [
                "Cathode chemistries (NMC/NCA/LFP) and graphite-based anodes dominate current EV packs.",
                "Copper and aluminum appear in tabs, foils, busbars, and pack wiring.",
                "Chemistry choice shifts impacts: LFP cuts cobalt/nickel dependence; NMC/NCA maximize energy density.",
                "Recycling can recover lithium, nickel, cobalt, copper, and aluminum; recovery rates depend on process design."
            ],
            details: [
                "Mining & processing: Lithium from brines and hard-rock ores can be water-intensive; nickel and cobalt often involve sulfuric leaching, tailings dams, and air-emissions control. Responsible sourcing programs aim to reduce both environmental and human-rights risks.",
                "Cathode trends: LFP growth reduces cobalt and nickel demand and simplifies supply chains, while high-nickel NMC/NCA remains attractive for long-range and performance vehicles. High-manganese and LNMO-type chemistries seek to further reduce critical materials.",
                "Anodes: Natural and synthetic graphite are still standard; silicon blends improve energy density but bring swelling and durability challenges that must be managed with coatings and pack-level controls.",
                "Manufacturing: Solvent choice and recovery (e.g., NMP vs water-based) plus dry-electrode lines strongly influence emissions and worker exposure. Source of electricity and factory efficiency are major levers.",
                "End-of-life: Mechanical pre-processing plus hydrometallurgical or pyrometallurgical steps can recover metals. Battery passports and better pack traceability help close loops, improve yields, and support extended producer responsibility."
            ]
        ),
        ShiftTopic(
            title: "Motors & Magnets",
            subtitle: "Steel laminations, copper windings, rare earth magnets",
            icon: "bolt.circle",
            bullets: [
                "Permanent-magnet motors use neodymium-iron-boron magnets; some designs trim dysprosium content.",
                "Induction or reluctance motors avoid rare earths entirely but can be larger or less efficient in some duty cycles.",
                "Electrical steel quality and copper fill factor directly affect efficiency and mass."
            ],
            details: [
                "Rare earths: Mining and separation may produce radioactive tailings and acid waste if not managed carefully. Diversifying supply, improving scrap recycling, and using less dysprosium all reduce risk.",
                "Design trade-offs: Automakers may mix motor types across trims or axles to balance efficiency, performance, cost, and material criticality.",
                "Recycling: Magnet-to-magnet recycling and alloy recovery are scaling. Design for disassembly improves end-of-life yields."
            ]
        ),
        ShiftTopic(
            title: "Body, Frame & Safety Structures",
            subtitle: "High-strength steels, aluminum, magnesium, composites",
            icon: "car.2",
            bullets: [
                "Multi-material bodies reduce mass and improve crash performance (castings, tailored blanks, adhesives).",
                "Aluminum content is often higher in EVs vs comparable ICE vehicles to offset battery mass.",
                "Composites are used selectively where stiffness-to-weight is critical."
            ],
            details: [
                "Steel vs aluminum: Primary aluminum has higher embodied energy than conventional steel, but recycled content significantly lowers aluminum’s footprint.",
                "Composites: Great stiffness and corrosion resistance, but recycling routes are less mature than metals. Thermoplastics and reversible resins improve repair/recyclability.",
                "Paint shops are energy-intensive; low-VOC chemistries and heat-recovery reduce emissions."
            ]
        ),
        ShiftTopic(
            title: "Electronics & Power Systems",
            subtitle: "Inverters, onboard chargers, DC-DC converters, control modules",
            icon: "cpu",
            bullets: [
                "High-voltage harnesses, inverters, and chargers are copper- and semiconductor-intensive.",
                "Silicon-carbide (SiC) inverters improve efficiency at high voltage; GaN is emerging in auxiliary power.",
                "Thermal management uses coolants and, in some designs, phase-change materials."
            ],
            details: [
                "Chip fabs have non-trivial energy and water footprints; cleaner grids and yield improvements reduce per-chip impacts.",
                "Copper vs aluminum conductors: Aluminum can reduce mass but complicates terminations and corrosion control.",
                "Design for repair and module replacement reduces electronic waste."
            ]
        ),
        ShiftTopic(
            title: "Tires, Interiors & Polymers",
            subtitle: "Synthetic rubber, plastics, foams, textiles, bio-based options",
            icon: "leaf",
            bullets: [
                "Tires use blends of synthetic and natural rubber plus fillers; torque and mass can affect wear if not tuned.",
                "Cabin materials trend toward recycled fibers and lower-VOC adhesives.",
                "Plastics reduce mass, but recyclability depends on resin choice and part design."
            ],
            details: [
                "Tire abrasion particles contribute to air/water pollution; compound design and torque management influence wear rates.",
                "Recycled PET and bio-based foams can cut impacts while improving longevity.",
                "Material labeling and design for disassembly improve recycling outcomes."
            ]
        ),
        ShiftTopic(
            title: "Charging Infrastructure Materials",
            subtitle: "Cables, cabinets, foundations, grid connections",
            icon: "bolt.badge.a",
            bullets: [
                "Fast-charging sites require substantial copper/aluminum conductors and power-electronics cabinets.",
                "Civil works (concrete pads, trenching) carry their own material and carbon footprints.",
                "Smart siting and load management reduce material per delivered kWh."
            ],
            details: [
                "Shared-use hubs (public + fleet + workplace) improve utilization, amortizing site impacts over more delivered energy.",
                "Modular cabinets support refurbishment and reuse rather than full scrappage."
            ]
        ),
        ShiftTopic(
            title: "Lifecycle Impacts vs ICE",
            subtitle: "Embodied emissions, use-phase, maintenance, end-of-life",
            icon: "chart.bar.doc.horizontal",
            bullets: [
                "EVs often have higher manufacturing emissions (battery) but lower use-phase emissions, especially on cleaner grids.",
                "Break-even mileage depends on pack size, vehicle class, driving profile, and grid CO₂ intensity.",
                "Lower routine maintenance reduces consumables over the vehicle’s life."
            ],
            details: [
                "For ICE vehicles, tailpipe emissions dominate; for EVs, electricity mix and manufacturing are the big levers.",
                "Heavier vehicles and coal-heavy grids push break-even later; smaller packs and cleaner grids pull it earlier.",
                "Regenerative braking reduces some wear, but tires still matter."
            ]
        ),
        ShiftTopic(
            title: "Circularity & Design for Disassembly",
            subtitle: "Second-life, repairability, reuse, material passports",
            icon: "arrow.triangle.2.circlepath",
            bullets: [
                "Battery second-life can defer recycling until economics and technology mature.",
                "Design for service access improves recovery yields and reduces total-loss outcomes.",
                "Digital product passports support safe logistics and end-of-life routing."
            ],
            details: [
                "Hydrometallurgy can recover high percentages of nickel, cobalt, lithium, and copper; many systems combine methods.",
                "Structural packs can boost efficiency, but must preserve realistic repair procedures to avoid unnecessary scrappage.",
                "Traceability helps recyclers pick safe processes and supports verifiable reporting."
            ]
        ),
        ShiftTopic(
            title: "Emerging Chemistries & Substitutions",
            subtitle: "Sodium-ion, LMFP/M3P, high-Mn, solid-state variants",
            icon: "sparkles",
            bullets: [
                "Sodium-ion reduces lithium dependence for cost-sensitive segments and stationary storage.",
                "Manganese-rich chemistries reduce nickel/cobalt use while improving voltage vs standard LFP.",
                "Solid-state concepts promise different safety/energy-density trade-offs, but manufacturing is still maturing."
            ],
            details: [
                "Fit-for-purpose matters: city cars and fleets can accept lower energy density, making LFP-family and sodium-ion attractive.",
                "Pack architecture and thermal behavior evolve with new electrolytes and separators.",
                "Industrialization details (format, binders, drying) determine real-world footprint and cost."
            ]
        ),
        ShiftTopic(
            title: "Community & Environmental Safeguards",
            subtitle: "Water, biodiversity, tailings, human rights",
            icon: "person.2.badge.gearshape",
            bullets: [
                "Water stewardship, tailings management, and dust control are central in lithium, nickel, and copper projects.",
                "Meaningful community consultation and strong labor standards reduce social risk.",
                "Biodiversity restoration plans help manage land-use impacts."
            ],
            details: [
                "Public reporting on water balances, emissions, and remediation improves trust and helps downstream sourcing decisions.",
                "Urban mining (recycling), efficiency gains, and right-sizing vehicles reduce pressure for new extraction.",
                "Procurement scorecards and third-party audits increasingly influence supplier behavior."
            ]
        )
    ]
}

// MARK: - Local styling (collision-safe)

fileprivate extension View {
    func shiftGlassCard(theme: any AppThemeSpec) -> some View {
        self
            .background(
                theme.cardBackground.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.separator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EVMaterialsShiftView()
            .preferredColorScheme(.dark)
    }
    .appTheme(DefaultAppTheme())
}
