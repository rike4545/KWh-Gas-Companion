//  PaymentMethodView.swift
//  My KWh Companion
//
//  End‑user friendly calculator to compare monthly charging cost
//  between EVgo plans, Tesla Supercharger schedules, and (optional) Electrify America.
//
//  • Two modes: Month‑to‑Date (uses your saved entries) or Custom inputs
//  • Advanced options: EVgo payment method, include EA, Level‑2 avg kW
//  • Clear results: Cheapest badge, savings vs Tesla, and break‑even banner
//  • Disclaimers included per provider variability and ChargePoint rationale
//
//  Depends on: EVgoPlan.swift, EVgoPlanSpec.swift, ProviderComparison.swift,
//              EVgoVsTeslaAnalyzer.swift, RateModel.swift, MonthToDateSummary.swift
//
//  NOTE: This file intentionally avoids any `public` API to prevent access‑control conflicts.

import SwiftUI
import Foundation

@MainActor
struct PaymentMethodView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entriesStore: EntriesStore

    // MARK: - UI Mode & basic inputs
    private enum Mode: String, CaseIterable, Identifiable { case mtd, custom; var id: String { rawValue } }
    private enum TeslaSchedule: String, CaseIterable, Identifiable { case owner = "Tesla Owner", allEVs = "All EVs"; var id: String { rawValue } }
    private enum EVgoKind: String, CaseIterable, Identifiable { case dcfc = "EVgo DC Fast", l2 = "EVgo Level 2"; var id: String { rawValue } }

    @State private var mode: Mode = .mtd
    @State private var teslaSchedule: TeslaSchedule = .owner
    @State private var evgoPlan: EVgoPlan = .plusMax
    @State private var evgoKind: EVgoKind = .dcfc
    @State private var paymentMethod: PaymentMethod = .appOrRFID
    @State private var includeEA: Bool = true

    // Custom mode minimal inputs
    @State private var monthlyKWh: Double = 120
    @State private var sessionsPerMonth: Int = 6

    // Advanced (hidden by default)
    @State private var l2AvgPowerkW: Double = 7.2

    var body: some View {
        NavigationStack {
            List {
                // MODE
                Section {
                    Picker("Mode", selection: $mode) {
                        Text("Use Month‑to‑Date").tag(Mode.mtd)
                        Text("Enter Custom").tag(Mode.custom)
                    }
                    .pickerStyle(.segmented)

                    Group {
                        if mode == .mtd {
                            if let s = mtdSummary() {
                                HStack {
                                    Label("This month so far", systemImage: "calendar")
                                    Spacer()
                                    Text("\(formatKWh(s.kWh)) kWh • \(s.sessions) sessions")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("No charging entries this month.")
                                        .font(.subheadline)
                                    Text("Switch to Custom mode or add entries to use Month‑to‑Date.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: { Text("Mode") }

                // INPUTS
                Section {
                    if mode == .custom {
                        RowNumberField(title: "kWh per month", value: $monthlyKWh, placeholder: "0", width: 110, keyboard: .decimalPad)
                        RowIntField(title: "Sessions per month", value: $sessionsPerMonth, placeholder: "0", width: 110)
                    }

                    Picker("EVgo plan", selection: $evgoPlan) {
                        ForEach(EVgoPlan.allCases, id: \.self) { plan in
                            Text(plan.readableName).tag(plan)
                        }
                    }

                    Picker("Tesla schedule", selection: $teslaSchedule) {
                        Text(TeslaSchedule.owner.rawValue).tag(TeslaSchedule.owner)
                        Text(TeslaSchedule.allEVs.rawValue).tag(TeslaSchedule.allEVs)
                    }
                    .pickerStyle(.segmented)

                    Picker("EVgo charger type", selection: $evgoKind) {
                        Text(EVgoKind.dcfc.rawValue).tag(EVgoKind.dcfc)
                        Text(EVgoKind.l2.rawValue).tag(EVgoKind.l2)
                    }
                    .pickerStyle(.segmented)

                    DisclosureGroup {
                        Picker("EVgo payment", selection: $paymentMethod) {
                            Text("App / RFID").tag(PaymentMethod.appOrRFID)
                            Text("Credit Card").tag(PaymentMethod.creditCard)
                        }
                        Toggle("Include Electrify America", isOn: $includeEA)

                        if evgoKind == .l2 {
                            RowNumberField(title: "L2 avg power (kW)", value: $l2AvgPowerkW, placeholder: "7.2", width: 110, keyboard: .decimalPad)
                            Text("Used to convert $/hour to $/kWh.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                } header: { Text("Inputs") }

                // RESULTS
                Section {
                    let tuple = computeComparisons()
                    if let comps = tuple.comparisons, !comps.isEmpty {
                        let minCost = comps.map { $0.monthly }.min() ?? 0
                        ForEach(comps, id: \.label) { item in
                            ProviderRow(
                                label: item.label,
                                monthly: item.monthly,
                                savingsVsTesla: item.savingsVsTesla,
                                isCheapest: item.monthly == minCost,
                                currencyCode: currencyCode()
                            )
                        }
                        if let be = tuple.breakEvenKWh {
                            BreakEvenBanner(kWh: be)
                        }
                    } else {
                        Text("Nothing to compare yet.")
                            .foregroundStyle(.secondary)
                    }
                } header: { Text("Estimated Monthly Cost") }

                // WHAT‑IF vs ACTUAL (MTD only)
                if mode == .mtd, let s = mtdSummary() {
                    Section {
                        let whatIf = computeWhatIfMTD()
                        if !whatIf.deltas.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Actual spend so far: \(formatCurrency(s.actualSpend, currencyCode()))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ForEach(whatIf.deltas, id: \.label) { d in
                                    WhatIfRow(label: d.label,
                                              estMonthly: d.estMonthlyCost,
                                              deltaVsActualMTD: d.deltaVsActualMTD,
                                              currencyCode: currencyCode())
                                }
                            }
                        } else {
                            Text("No Month‑to‑Date energy found.")
                                .foregroundStyle(.secondary)
                        }
                    } header: { Text("What‑If vs Actual (Month‑to‑Date)") }
                }

                // DISCLAIMERS
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rates and fees change. Always check the app at the station.")
                        Text("Tesla Supercharger rates vary by location and can fluctuate with demand, time of day, and station speed. EVgo pricing depends on plan, location, and time of use. Station‑specific pricing is available in the EVgo app.")
                        Text("ChargePoint isn’t compared here because stations are independently owned and set their own prices. Use the ChargePoint app to see station‑specific rates and filter for free stations.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Charging Cost Compare")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    // MARK: - Computation
    private func computeComparisons() -> (comparisons: [ProviderComparison]?, breakEvenKWh: Double?) {
        let teslaRate: RateModel = (teslaSchedule == .owner)
            ? .timeOfUse(ChargingDefaults.teslaOwner_TOU, hourMix: nil)
            : .timeOfUse(ChargingDefaults.teslaAllEVs_TOU, hourMix: nil)

        let evgoStationRate: RateModel = (evgoKind == .dcfc)
            ? .perKWh(ChargingDefaults.evgoCCS_BasePricePerKWh)
            : .perHour(ChargingDefaults.evgoL2_PerHour, avgPowerkW: max(1.0, l2AvgPowerkW))

        let planSpec = EVgoPlanSpec.defaults(for: evgoPlan)

        if mode == .mtd, let s = mtdSummary() {
            let comps = EVgoVsTeslaAnalyzer.compareAllProviders(
                monthlyKWh: s.kWh,
                sessionsPerMonth: s.sessions,
                evgoStationRate: evgoStationRate,
                teslaRate: teslaRate,
                paymentMethod: paymentMethod,
                includeEA: includeEA
            )
            let be = EVgoVsTeslaAnalyzer.breakEvenKWh(
                sessionsPerMonth: s.sessions,
                evgoStationRate: evgoStationRate,
                planSpec: (evgoKind == .l2 ? planSpec.withEnergyDiscount(0) : planSpec),
                paymentMethod: paymentMethod,
                teslaRate: teslaRate
            )
            return (comps, be)
        } else {
            let comps = EVgoVsTeslaAnalyzer.compareAllProviders(
                monthlyKWh: max(0, monthlyKWh),
                sessionsPerMonth: max(0, sessionsPerMonth),
                evgoStationRate: evgoStationRate,
                teslaRate: teslaRate,
                paymentMethod: paymentMethod,
                includeEA: includeEA
            )
            let be = EVgoVsTeslaAnalyzer.breakEvenKWh(
                sessionsPerMonth: max(0, sessionsPerMonth),
                evgoStationRate: evgoStationRate,
                planSpec: (evgoKind == .l2 ? planSpec.withEnergyDiscount(0) : planSpec),
                paymentMethod: paymentMethod,
                teslaRate: teslaRate
            )
            return (comps, be)
        }
    }

    private func computeWhatIfMTD() -> (summary: MonthToDateSummary, deltas: [ProviderDelta]) {
        let teslaRate: RateModel = (teslaSchedule == .owner)
            ? .timeOfUse(ChargingDefaults.teslaOwner_TOU, hourMix: nil)
            : .timeOfUse(ChargingDefaults.teslaAllEVs_TOU, hourMix: nil)

        let evgoStationRate: RateModel = (evgoKind == .dcfc)
            ? .perKWh(ChargingDefaults.evgoCCS_BasePricePerKWh)
            : .perHour(ChargingDefaults.evgoL2_PerHour, avgPowerkW: max(1.0, l2AvgPowerkW))

        let planSpec = EVgoPlanSpec.defaults(for: evgoPlan)
        return EVgoVsTeslaAnalyzer.monthToDateWhatIfComparisons(
            entries: entriesStore.entries,
            teslaRate: teslaRate,
            evgoStationRate: evgoStationRate,
            evgoPlan: (evgoKind == .l2 ? planSpec.withEnergyDiscount(0) : planSpec),
            paymentMethod: paymentMethod,
            includeEA: includeEA
        )
    }

    private func mtdSummary() -> MonthToDateSummary? {
        let s = EVgoVsTeslaAnalyzer.monthToDateSummary(entries: entriesStore.entries)
        return (s.kWh > 0 && s.sessions > 0) ? s : nil
    }

    // MARK: - Formatting helpers
    private func currencyCode() -> String {
        Locale.current.currency?.identifier ?? "USD"
    }
    private func formatCurrency(_ value: Double, _ code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code
        return f.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
    }
    private func formatKWh(_ v: Double) -> String {
        let x = max(0, v)
        if x >= 100 { return String(format: "%.0f", x) }
        if x >= 10 { return String(format: "%.1f", x) }
        return String(format: "%.2f", x)
    }
}

// MARK: - Rows & subviews
fileprivate struct ProviderRow: View {
    let label: String
    let monthly: Double
    let savingsVsTesla: Double
    let isCheapest: Bool
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(label).font(.headline)
                    if isCheapest { CapsuleBadge(text: "Cheapest") }
                }
                Text(deltaText)
                    .font(.caption)
                    .foregroundStyle(deltaColor)
            }
            Spacer()
            Text(formatCurrency(monthly, currencyCode))
                .font(.headline)
                .monospacedDigit()
        }
    }

    private var deltaText: String {
        let s = savingsVsTesla
        if abs(s) < 0.01 { return "Same as Tesla Rates" }
        return s < 0 ? String(format: "More than $%.2f Tesla rates", abs(s))
                     : String(format: "+$%.2f vs normal Tesla rates", s)
    }

    private var deltaColor: Color { savingsVsTesla < 0 ? .green : .secondary }

    private func formatCurrency(_ value: Double, _ code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code
        return f.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
    }
}

fileprivate struct WhatIfRow: View {
    let label: String
    let estMonthly: Double
    let deltaVsActualMTD: Double?
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline)
                if let d = deltaVsActualMTD {
                    Text(deltaText(d)).font(.caption).foregroundStyle(d < 0 ? .green : .secondary)
                }
            }
            Spacer()
            Text(formatCurrency(estMonthly)).font(.subheadline).monospacedDigit()
        }
    }

    private func deltaText(_ d: Double) -> String {
        return d < 0 ? String(format: "−$%.2f vs actual so far", abs(d))
                     : String(format: "+$%.2f vs actual so far", d)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currencyCode
        return f.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
    }
}

fileprivate struct CapsuleBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
    }
}

fileprivate struct BreakEvenBanner: View {
    let kWh: Double
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
            Text(String(format: "EVgo break‑even ~ %.0f kWh/month", max(0, kWh)))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Reusable row fields
fileprivate struct RowNumberField: View {
    let title: String
    @Binding var value: Double
    let placeholder: String
    let width: CGFloat
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, value: $value, format: .number)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
        }
    }
}

fileprivate struct RowIntField: View {
    let title: String
    @Binding var value: Int
    let placeholder: String
    let width: CGFloat

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
        }
    }
}

// MARK: - Preview
#Preview {
    PaymentMethodView()
        .environmentObject(EntriesStore())
}
