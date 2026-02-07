//
//  MonthlyChargingChangeCard 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  MonthlyChargingChangeCard.swift
//  My KWh Companion
//
//  Delta explainer: this month vs last month.
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct MonthlyChargingChangeCard: View {

    @EnvironmentObject private var teslaFi: TeslaFiSessionStore
    @EnvironmentObject private var entriesStore: EntriesStore

    private func monthRange(_ offsetMonths: Int) -> (Date, Date) {
        let cal = Calendar.current
        let startThis = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let start = cal.date(byAdding: .month, value: offsetMonths, to: startThis) ?? startThis
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? Date()
        return (start, end)
    }

    private func summarizeSessions(start: Date, end: Date) -> (kwh: Double, cost: Double, count: Int) {
        let xs = teslaFi.sessionsForUI.filter { $0.startDate >= start && $0.startDate < end }
        let kwh = xs.reduce(0) { $0 + $1.energyAddedKWh }
        let cost = xs.compactMap(\.cost).reduce(0, +)
        return (kwh, cost, xs.count)
    }

    private func summarizeLedger(start: Date, end: Date) -> Double {
        entriesStore.energyEntries()
            .filter { $0.date >= start && $0.date < end }
            .map(\.amount)
            .reduce(0, +)
    }

    var body: some View {
        let (s0, e0) = monthRange(0)
        let (s1, e1) = monthRange(-1)

        let now = summarizeSessions(start: s0, end: e0)
        let prev = summarizeSessions(start: s1, end: e1)

        let ledgerNow = summarizeLedger(start: s0, end: e0)
        let ledgerPrev = summarizeLedger(start: s1, end: e1)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("What changed this month?", systemImage: "arrow.up.right")
                    .font(.headline)
                Spacer()
                Text(s0.formatted(.dateTime.year().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("TeslaFi: \(now.count) sessions • \(now.kwh, specifier: "%.1f") kWh • \(now.cost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Ledger: \(ledgerNow, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            DeltaRow(label: "Sessions", value: Double(now.count - prev.count), isCurrency: false, fractionDigits: 0)
            DeltaRow(label: "kWh", value: now.kwh - prev.kwh, isCurrency: false, fractionDigits: 1)
            DeltaRow(label: "TeslaFi cost", value: now.cost - prev.cost, isCurrency: true, fractionDigits: 2)
            DeltaRow(label: "Ledger cost", value: ledgerNow - ledgerPrev, isCurrency: true, fractionDigits: 2)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            if teslaFi.canonicalSessions.isEmpty { teslaFi.rebuildCanonicalSessions() }
        }
    }
}

@MainActor
fileprivate struct DeltaRow: View {
    let label: String
    let value: Double
    var isCurrency: Bool
    var fractionDigits: Int

    private var tint: Color {
        if abs(value) < 0.000_001 { return Color.secondary }
        return value > 0 ? Color.orange : Color.blue
    }

    var body: some View {
        HStack {
            Text(label).font(.subheadline.weight(.semibold))
            Spacer()
            let code = Locale.current.currency?.identifier ?? "USD"

            if isCurrency {
                Text(value, format: .currency(code: code).precision(.fractionLength(fractionDigits)))
                    .foregroundStyle(tint)
                    .font(.subheadline.weight(.semibold))
            } else {
                Text(value, format: .number.precision(.fractionLength(fractionDigits)))
                    .foregroundStyle(tint)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}
