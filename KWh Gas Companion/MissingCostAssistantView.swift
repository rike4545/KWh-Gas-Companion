//
//  MissingCostAssistantView 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  MissingCostAssistantView.swift
//  My KWh Companion
//
//  Fill missing TeslaFi costs using default $/kWh.
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct MissingCostAssistantView: View {

    @EnvironmentObject private var teslaFi: TeslaFiSessionStore

    @AppStorage("defaultHomeRatePerKWh") private var homeRate: Double = 0.18
    @AppStorage("defaultFastRatePerKWh") private var fastRate: Double = 0.45

    @State private var selectedRate: RateKind = .fast
    @State private var onlyThisMonth: Bool = true

    enum RateKind: String, CaseIterable, Identifiable {
        case home, fast
        var id: String { rawValue }
        var title: String { self == .home ? "Home" : "Fast" }
    }

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var missing: [TeslaFiSession] {
        teslaFi.canonicalSessions
            .filter { $0.cost == nil }
            .sorted { $0.startDate > $1.startDate }
    }

    private var chosenRate: Double { selectedRate == .home ? homeRate : fastRate }

    private var applySinceDate: Date? { onlyThisMonth ? monthStart : nil }

    var body: some View {
        List {
            Section {
                Text("Some sessions have no cost. Set a default $/kWh and apply it to missing-cost sessions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults") {
                Picker("Rate type", selection: $selectedRate) {
                    ForEach(RateKind.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }

                HStack {
                    Text("Home $/kWh")
                    Spacer()
                    TextField("", value: $homeRate, format: .number.precision(.fractionLength(3)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                HStack {
                    Text("Fast $/kWh")
                    Spacer()
                    TextField("", value: $fastRate, format: .number.precision(.fractionLength(3)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                Toggle("Only apply to this month", isOn: $onlyThisMonth)
            }

            Section("Apply") {
                Text("Will apply \(chosenRate, format: .number.precision(.fractionLength(3))) $/kWh to missing-cost raw sessions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    teslaFi.applyEstimatedCost(ratePerKWh: chosenRate, onlySince: applySinceDate)
                } label: {
                    Text("Apply to missing-cost sessions")
                        .fontWeight(.semibold)
                }
                .disabled(chosenRate <= 0)
            }

            Section("Missing-cost canonical sessions") {
                if missing.isEmpty {
                    Text("No missing-cost sessions found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(missing) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.displayLocation)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(s.startDate.formatted(date: .abbreviated, time: .shortened)) • \(s.energyAddedKWh, specifier: "%.1f") kWh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Missing Cost Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { teslaFi.rebuildCanonicalSessions() }
    }
}
