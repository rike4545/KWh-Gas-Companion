//  CarbonImpactDashboardView.swift — iOS26 Aesthetic Variant (v5)
//  My EV Companion
//
//  Target: iOS 17+
//
//  Refinements vs v4:
//  - Stable chart identity (no UUID-per-render) -> smoother animations/updates
//  - “Year to Date” becomes “Last N months” based on data window
//  - Safer empty-state handling
//  - Slightly more efficient month formatting + helper structure
//  - CardStyle uses background(in:) + clip for cleaner edges

import SwiftUI
import Charts

@MainActor
public struct CarbonImpactDashboardView: View {

    // MARK: - Inputs (immutable view configuration)
    /// Monthly energy used in kWh for the last N months. Newest last.
    public let monthlyKWh: [Double]
    /// Average grid intensity in gCO₂e/kWh (defaults to ~386 g/kWh, US avg c.2023)
    public let gridIntensity_gPerKWh: Double

    // MARK: - User-tunable assumptions
    @State private var iceMpg: Double
    @State private var evMilesPerKWh: Double

    // MARK: - UI State
    @State private var mode: DisplayMode = .both

    public init(
        monthlyKWh: [Double]? = nil,
        gridIntensity_gPerKWh: Double = 386.0,
        iceMpg: Double = 28.0,
        evMilesPerKWh: Double = 3.2
    ) {
        self.monthlyKWh = monthlyKWh ?? Self.sampleKWh
        self.gridIntensity_gPerKWh = gridIntensity_gPerKWh
        _iceMpg = State(initialValue: iceMpg)
        _evMilesPerKWh = State(initialValue: evMilesPerKWh)
    }

    // MARK: - Body
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    controlsCard
                    totalsRow
                    emissionsChart
                    assumptionsCard
                    disclaimer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Carbon Impact")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share carbon impact")
                }
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        let lastKWh = monthlyKWh.last ?? 0

        let evCO2 = Self.kWhToCO2lbs(kWh: lastKWh, gPerKWh: gridIntensity_gPerKWh)
        let miles = lastKWh * evMilesPerKWh
        let iceGallons = miles / max(iceMpg, 1)
        let iceCO2 = iceGallons * 19.6 // lbs CO₂ per gallon gasoline (tailpipe only)
        let avoided = max(iceCO2 - evCO2, 0)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Last Month")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("You avoided \(avoided, format: .number.precision(.fractionLength(0))) lbs CO₂")
                .font(.title3)
                .bold()

            Text("EV: \(evCO2, format: .number.precision(.fractionLength(0))) vs ICE: \(iceCO2, format: .number.precision(.fractionLength(0))) lbs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mode Controls Card
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Display", selection: $mode) {
                ForEach(DisplayMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .cardStyle()
        .accessibilityLabel("Display mode")
    }

    // MARK: - Totals Row
    private var totalsRow: some View {
        let months = monthlyKWh.count
        let windowTitle = months >= 12 ? "Last 12 months" : "Last \(months) months"

        let totalKWh = monthlyKWh.reduce(0, +)
        let totalEVlbs = Self.kWhToCO2lbs(kWh: totalKWh, gPerKWh: gridIntensity_gPerKWh)

        let miles = totalKWh * evMilesPerKWh
        let gallons = miles / max(iceMpg, 1)
        let totalICElbs = gallons * 19.6
        let avoided = max(totalICElbs - totalEVlbs, 0)

        return HStack(spacing: 12) {
            MetricCard(title: windowTitle, value: avoided, unit: "lbs CO₂ avoided")
            MetricCard(title: "Miles on EV", value: miles, unit: "mi")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Chart
    private var emissionsChart: some View {
        let series: [MonthPoint] = monthlyKWh.enumerated().map { idx, k in
            let offsetFromEnd = (monthlyKWh.count - 1 - idx)
            return MonthPoint(
                id: idx, // stable id
                label: Self.monthLabel(offsetFromEnd: offsetFromEnd),
                evCO2: Self.kWhToCO2lbs(kWh: k, gPerKWh: gridIntensity_gPerKWh),
                iceCO2: Self.kWhToCO2lbsEquivalentICE(kWh: k, mpg: iceMpg, miPerKWh: evMilesPerKWh)
            )
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Emissions by Month")
                .font(.headline)

            if series.isEmpty {
                Text("No charging data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                Chart(series) { point in
                    if mode != .iceOnly {
                        BarMark(
                            x: .value("Month", point.label),
                            y: .value("EV lbs", point.evCO2)
                        )
                        .foregroundStyle(by: .value("Type", "EV"))
                        .accessibilityLabel("EV emissions \(point.label)")
                        .accessibilityValue("\(Int(point.evCO2)) pounds")
                    }

                    if mode != .evOnly {
                        LineMark(
                            x: .value("Month", point.label),
                            y: .value("ICE lbs", point.iceCO2)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(by: .value("Type", "ICE"))

                        PointMark(
                            x: .value("Month", point.label),
                            y: .value("ICE lbs", point.iceCO2)
                        )
                        .foregroundStyle(by: .value("Type", "ICE"))
                        .symbolSize(22)
                        .accessibilityHidden(true)
                    }
                }
                .frame(height: 240)
                .chartYAxisLabel("lbs CO₂")
                .chartLegend(position: .automatic, alignment: .leading)
                .chartForegroundStyleScale([
                    "EV": .primary,
                    "ICE": .secondary
                ])
                .accessibilityLabel("Emissions by month chart")
            }
        }
        .padding(16)
        .cardStyle(prominent: true)
    }

    // MARK: - Assumptions
    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assumptions").font(.headline)

            Stepper(value: $iceMpg, in: 12...60, step: 1) {
                LabeledContent("ICE Baseline", value: String(format: "%.0f mpg", iceMpg))
            }

            Stepper(value: $evMilesPerKWh, in: 2.0...6.0, step: 0.1) {
                LabeledContent("EV Efficiency", value: String(format: "%.1f mi/kWh", evMilesPerKWh))
            }

            Text("Grid intensity: \(gridIntensity_gPerKWh, format: .number) g CO₂/kWh")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Disclaimer
    private var disclaimer: some View {
        Text("Estimates use grid averages; ICE uses 19.6 lbs CO₂/gal tailpipe only. Upstream not included.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityHint("Informational only; not a lifecycle analysis.")
    }

    // MARK: - Helpers
    private func shareText() -> String {
        let k = monthlyKWh.last ?? 0
        let ev = Self.kWhToCO2lbs(kWh: k, gPerKWh: gridIntensity_gPerKWh)
        let ice = Self.kWhToCO2lbsEquivalentICE(kWh: k, mpg: iceMpg, miPerKWh: evMilesPerKWh)
        let avoided = max(ice - ev, 0)
        return "My EV avoided ~\(Int(avoided)) lbs CO₂ last month. #MyEVCompanion"
    }

    static func kWhToCO2lbs(kWh: Double, gPerKWh: Double) -> Double {
        (kWh * gPerKWh) / 453.592 // grams per pound
    }

    static func kWhToCO2lbsEquivalentICE(kWh: Double, mpg: Double, miPerKWh: Double) -> Double {
        let miles = kWh * miPerKWh
        let gallons = miles / max(mpg, 1)
        return gallons * 19.6
    }

    static func monthLabel(offsetFromEnd: Int) -> String {
        let now = Date()
        let d = Calendar.current.date(byAdding: .month, value: -offsetFromEnd, to: now) ?? now
        return Self.monthFormatter.string(from: d)
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    struct MonthPoint: Identifiable {
        let id: Int
        let label: String
        let evCO2: Double
        let iceCO2: Double
    }

    public static let sampleKWh: [Double] = [220, 245, 210, 260, 275, 240]
}

// MARK: - Display Mode
fileprivate enum DisplayMode: String, CaseIterable, Identifiable {
    case evOnly, iceOnly, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .evOnly: "EV"
        case .iceOnly: "ICE"
        case .both: "Both"
        }
    }
}

// MARK: - Shared Card Style (iOS26-ish)
fileprivate struct CardStyle: ViewModifier {
    var prominent: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        content
            .padding(.zero)
            .background(.thinMaterial, in: shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
            )
            .clipShape(shape)
            .shadow(
                color: Color.black.opacity(prominent ? 0.18 : 0.10),
                radius: prominent ? 18 : 12,
                x: 0,
                y: prominent ? 10 : 6
            )
            .shadow(
                color: Color.black.opacity(prominent ? 0.08 : 0.04),
                radius: prominent ? 4 : 2,
                x: 0,
                y: 0
            )
    }
}

private extension View {
    func cardStyle(prominent: Bool = false) -> some View {
        modifier(CardStyle(prominent: prominent))
    }
}

// MARK: - Metric Card
fileprivate struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(0)))
                .font(.title3)
                .bold()
            Text(unit).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview {
    CarbonImpactDashboardView()
}
