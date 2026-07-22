//  RangeForecastView.swift
//  KWh Gas Companion
//
//  Retooled to avoid external dependencies and work out-of-the-box.
//  • Uses EntriesStore by default to infer a baseline Wh/mi when possible
//  • Otherwise lets the user set a baseline and other factors (speed, temp, HVAC)
//  • Estimates drivable range from usable battery capacity and SoC window
//  • Chart can visualize Range vs Temperature or Range vs Speed
//  • iOS 16+: uses Swift Charts

import SwiftUI
import Charts

struct RangeForecastView: View {
    // Optional: allow direct injection of a custom entry list
    private let injectedEntries: [ExpenseEntry]?
    init(entries: [ExpenseEntry]? = nil) { self.injectedEntries = entries }

    // Default source: your EntriesStore the app already injects
    @EnvironmentObject private var entriesStore: EntriesStore

    // --- Assumptions persisted across launches ---
    @AppStorage("rf_usable_kwh") private var usableCapacityKWh: Double = 75 // Adjust to your battery pack
    @AppStorage("rf_baseline_whpm") private var baselineWhPerMileUser: Double = 280 // If data not available
    @AppStorage("rf_ref_speed") private var referenceSpeedMph: Double = 65

    // Sensitivities (percent change per unit)
    @AppStorage("rf_temp_sens_pct_per_c") private var tempSensitivityPctPerC: Double = 0.5 // %/°C away from 20°C
    @AppStorage("rf_speed_sens_pct_per_mph") private var speedSensitivityPctPerMph: Double = 0.4 // %/mph away from ref

    // HVAC load (kW). Converted to Wh/mi by dividing by speed (mi/h) and * 1000
    @AppStorage("rf_hvac_kw") private var hvacLoadKW: Double = 1.5

    // SoC window
    @AppStorage("rf_soc_start") private var startSOC: Double = 90
    @AppStorage("rf_soc_reserve") private var reserveSOC: Double = 10

    // Controls (session)
    enum ChartMode: String, CaseIterable, Identifiable { case temp = "Temp", speed = "Speed"; var id: String { rawValue } }
    @State private var mode: ChartMode = .temp
    @State private var tempC: Double = 20
    @State private var speedMph: Double = 65

    private var useFahrenheit: Bool { Locale.current.usesFahrenheit }

    // MARK: - Data/Baseline
    private var entries: [ExpenseEntry] { injectedEntries ?? entriesStore.entries }
    private var energyEntries: [ExpenseEntry] { entries.filter { $0.isEnergy } }

    private var dataMilesSpan: Double? {
        let odos = entries.compactMap { $0.odometer }.sorted()
        guard let first = odos.first, let last = odos.last, last > first else { return nil }
        return last - first
    }

    private var totalKWhFromData: Double? {
        let totals: [Double] = energyEntries.compactMap { e in
            // Look for a kWh field if present on your model
            extractDouble(from: e, key: "energyKWh") ?? extractDouble(from: e, key: "kWh")
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(0, +)
    }

    /// If both kWh and miles span are available, compute baseline from your data
    private var baselineWhPerMileData: Double? {
        guard let miles = dataMilesSpan, miles > 0, let kwh = totalKWhFromData, kwh > 0 else { return nil }
        return (kwh * 1000.0) / miles
    }

    private var baselineWhPerMile: Double {
        baselineWhPerMileData ?? baselineWhPerMileUser
    }

    // MARK: - Prediction engine
    private func whPerMile(tempC: Double, speedMph: Double, hvacKW: Double) -> Double {
        // Temp factor: reference comfort 20°C; linear sensitivity per °C
        let tempDelta = abs(tempC - 20.0)
        let tempFactor = 1.0 + (tempSensitivityPctPerC / 100.0) * tempDelta

        // Speed factor: reference speed; linear sensitivity per mph
        let speedDelta = (speedMph - referenceSpeedMph)
        let speedFactor = 1.0 + (speedSensitivityPctPerMph / 100.0) * speedDelta

        // HVAC Wh/mi term = (kW → Wh/h) / (mi/h)
        let hvacWhPerMile = speedMph > 0 ? (hvacKW * 1000.0) / speedMph : 0

        return max(50, baselineWhPerMile * tempFactor * speedFactor + hvacWhPerMile) // guard against silly low values
    }

    private func rangeMiles(tempC: Double, speedMph: Double, hvacKW: Double) -> Double {
        let usableFrac = max(0, min(1, (startSOC - reserveSOC)/100.0))
        let whpm = whPerMile(tempC: tempC, speedMph: speedMph, hvacKW: hvacKW)
        return (usableCapacityKWh * 1000.0 * usableFrac) / whpm
    }

    // Chart data
    private var curveTemp: [CurvePoint] {
        let minC = -20.0, maxC = 40.0, step = 2.0
        return stride(from: minC, through: maxC, by: step).map { c in
            .init(x: c, y: rangeMiles(tempC: c, speedMph: speedMph, hvacKW: hvacLoadKW))
        }
    }
    private var curveSpeed: [CurvePoint] {
        let minS = 20.0, maxS = 85.0, step = 2.0
        return stride(from: minS, through: maxS, by: step).map { s in
            .init(x: s, y: rangeMiles(tempC: tempC, speedMph: s, hvacKW: hvacLoadKW))
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                summaryMetrics
                controls
                rangeChart
                if baselineWhPerMileData != nil { dataFootnote }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Range Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize temp slider to local comfort temp
            if useFahrenheit {
                // set 68°F as ~20°C equivalent for the control label
                tempC = 20
            }
        }
    }

    // MARK: - Sections
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Range Forecast").font(.title.bold())
            Text("Estimate range from temperature, speed, HVAC, and SoC window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryMetrics: some View {
        let est = rangeMiles(tempC: tempC, speedMph: speedMph, hvacKW: hvacLoadKW)
        let whpm = whPerMile(tempC: tempC, speedMph: speedMph, hvacKW: hvacLoadKW)
        let kwhAvail = usableCapacityKWh * max(0, min(1, (startSOC - reserveSOC)/100.0))

        return HStack(spacing: 12) {
            MetricPill(title: "Est. Range", value: String(format: "%.0f mi", est), icon: "point.topleft.down.curvedto.point.bottomright.up")
            MetricPill(title: "Use", value: String(format: "%.0f Wh/mi", whpm), icon: "bolt.fill")
            MetricPill(title: "Energy", value: String(format: "%.1f kWh", kwhAvail), icon: "battery.100")
        }
    }

    private var controls: some View {
        Card(title: "Inputs", subtitle: "Adjust assumptions and environment") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Chart").foregroundStyle(.secondary)
                    Picker("Chart", selection: $mode) {
                        ForEach(ChartMode.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .pickerStyle(.segmented)
                }
                Divider().gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text("Usable Capacity").foregroundStyle(.secondary)
                    Stepper(value: $usableCapacityKWh, in: 20...120, step: 1) {
                        Text(String(format: "%.0f kWh", usableCapacityKWh))
                    }
                }
                GridRow {
                    Text("Ref Speed").foregroundStyle(.secondary)
                    Stepper(value: $referenceSpeedMph, in: 20...85, step: 1) {
                        Text(String(format: "%.0f mph", referenceSpeedMph))
                    }
                }
                GridRow {
                    Text("Baseline Wh/mi").foregroundStyle(.secondary)
                    Stepper(value: $baselineWhPerMileUser, in: 150...500, step: 5) {
                        Text(String(format: "%.0f Wh/mi", baselineWhPerMileUser))
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text("Temp").foregroundStyle(.secondary)
                    Slider(value: $tempC, in: -20...40, step: 1)
                    Text(useFahrenheit ? Self.formatF(Self.cToF(tempC)) : Self.formatC(tempC))
                        .frame(width: 70, alignment: .trailing)
                }
                GridRow {
                    Text("Temp Sensitivity").foregroundStyle(.secondary)
                    Stepper(value: $tempSensitivityPctPerC, in: 0...3, step: 0.1) {
                        Text(String(format: "%.1f%%/°C", tempSensitivityPctPerC))
                    }
                }

                GridRow {
                    Text("Speed").foregroundStyle(.secondary)
                    Slider(value: $speedMph, in: 20...85, step: 1)
                    Text(String(format: "%.0f mph", speedMph)).frame(width: 70, alignment: .trailing)
                }
                GridRow {
                    Text("Speed Sensitivity").foregroundStyle(.secondary)
                    Stepper(value: $speedSensitivityPctPerMph, in: 0...3, step: 0.1) {
                        Text(String(format: "%.1f%%/mph", speedSensitivityPctPerMph))
                    }
                }

                GridRow {
                    Text("HVAC Load").foregroundStyle(.secondary)
                    Stepper(value: $hvacLoadKW, in: 0...8, step: 0.1) {
                        Text(String(format: "%.1f kW", hvacLoadKW))
                    }
                }

                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("SoC Start").foregroundStyle(.secondary)
                    Stepper(value: $startSOC, in: 10...100, step: 1) { Text(String(format: "%.0f%%", startSOC)) }
                }
                GridRow {
                    Text("Reserve").foregroundStyle(.secondary)
                    Stepper(value: $reserveSOC, in: 0...50, step: 1) { Text(String(format: "%.0f%%", reserveSOC)) }
                }
            }
            .font(.footnote)
        }
    }

    private var rangeChart: some View {
        Card(title: mode == .temp ? "Range vs Temperature" : "Range vs Speed",
             subtitle: mode == .temp ? "Speed fixed at \(Int(speedMph)) mph" : "Temp fixed at \(useFahrenheit ? Self.formatF(Self.cToF(tempC)) : Self.formatC(tempC))") {
            let data = (mode == .temp) ? curveTemp : curveSpeed
            Chart(data) { p in
                LineMark(
                    x: .value(mode == .temp ? "Temp" : "Speed", p.x),
                    y: .value("Range", p.y)
                )
                PointMark(
                    x: .value(mode == .temp ? "Temp" : "Speed", p.x),
                    y: .value("Range", p.y)
                )
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { v in
                    if let val = v.as(Double.self) {
                        if mode == .temp {
                            AxisValueLabel(useFahrenheit ? Self.formatF(Self.cToF(val)) : Self.formatC(val))
                        } else {
                            AxisValueLabel(String(format: "%.0f mph", val))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    if let val = v.as(Double.self) {
                        AxisValueLabel(String(format: "%.0f mi", val))
                    }
                }
            }
            .frame(height: 240)
            .kwhInteractiveDataViz()
        }
    }

    private var dataFootnote: some View {
        Text("Baseline derived from your entries: ~\(Int(baselineWhPerMileData ?? 0)) Wh/mi. You can override it above.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers
    private func extractDouble(from entry: ExpenseEntry, key: String) -> Double? {
        let mirror = Mirror(reflecting: entry)
        for child in mirror.children { if child.label == key { return child.value as? Double } }
        return nil
    }
}

// MARK: - Small models & UI helpers

private struct CurvePoint: Identifiable, Hashable { let id = UUID(); let x: Double; let y: Double }

private struct Card<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct MetricPill: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Locale helpers
private extension Locale {
    var usesFahrenheit: Bool {
        let id = (self as NSLocale).object(forKey: .countryCode) as? String ?? "US"
        return ["BS","US","BZ","KY","PW","GU","MH","FM","LR"].contains(id)
    }
}

private extension RangeForecastView {
    static func cToF(_ c: Double) -> Double { c * 9/5 + 32 }
    static func formatC(_ c: Double) -> String { String(format: "%.0f℃", c) }
    static func formatF(_ f: Double) -> String { String(format: "%.0f℉", f) }
}

#if DEBUG
#Preview {
    NavigationStack {
        RangeForecastView()
            .environmentObject(EntriesStore())
    }
}
#endif
