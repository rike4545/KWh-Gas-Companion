//
//  ChargingBudgetConfig.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/8/25.
//


//  ChargingBudgetGuardView.swift

import SwiftUI
import Combine

struct ChargingBudgetConfig {
    var monthlyBudget: Double
    var maxPricePerKWh: Double

    static let defaultConfig = ChargingBudgetConfig(
        monthlyBudget: 120,
        maxPricePerKWh: 0.35
    )
}

@MainActor
final class ChargingBudgetGuardViewModel: ObservableObject {
    @Published var config: ChargingBudgetConfig

    @Published private(set) var currentMonthCost: Double = 0
    @Published private(set) var currentMonthKWh: Double = 0
    @Published private(set) var projectedMonthCost: Double = 0
    @Published private(set) var highPriceSessions: [MECChargingDataSession] = []

    private var allSessions: [MECChargingDataSession]

    init(
        sessions: [MECChargingDataSession],
        config: ChargingBudgetConfig = .defaultConfig
    ) {
        self.allSessions = sessions
        self.config = config
        recalc()
    }

    func updateSessions(_ sessions: [MECChargingDataSession]) {
        self.allSessions = sessions
        recalc()
    }

    func recalc(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.year, .month], from: referenceDate)

        let monthSessions = allSessions.filter { session in
            let comps = calendar.dateComponents([.year, .month], from: session.startDate)
            return comps.year == targetComponents.year && comps.month == targetComponents.month
        }

        let totalCost = monthSessions.reduce(0) { $0 + $1.cost }
        let totalKWh = monthSessions.reduce(0) { $0 + $1.kWh }

        currentMonthCost = totalCost
        currentMonthKWh = totalKWh

        if let range = calendar.range(of: .day, in: .month, for: referenceDate) {
            let day = calendar.component(.day, from: referenceDate)
            let progress = Double(day) / Double(range.count)
            if progress > 0 {
                projectedMonthCost = totalCost / progress
            } else {
                projectedMonthCost = totalCost
            }
        } else {
            projectedMonthCost = totalCost
        }

        highPriceSessions = monthSessions.filter {
            $0.pricePerKWh > config.maxPricePerKWh
        }
    }
}

@MainActor
struct ChargingBudgetGuardView: View {
    @StateObject private var viewModel: ChargingBudgetGuardViewModel

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    init(
        sessions: [MECChargingDataSession] = MECChargingDataSession.sampleSessions(),
        config: ChargingBudgetConfig = .defaultConfig
    ) {
        _viewModel = StateObject(
            wrappedValue: ChargingBudgetGuardViewModel(
                sessions: sessions,
                config: config
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                budgetControls

                if !viewModel.highPriceSessions.isEmpty {
                    highPriceSection
                }
            }
            .padding()
        }
        .navigationTitle("Charging Guardrails")
    }

    private var headerCard: some View {
        let budget = max(viewModel.config.monthlyBudget, 1)
        let spent = viewModel.currentMonthCost
        let projected = viewModel.projectedMonthCost

        let spentRatio = min(spent / budget, 1.5)
        let projectedRatio = min(projected / budget, 1.5)

        let statusText: String
        let statusColor: Color

        if projectedRatio < 0.9 {
            statusText = "On track"
            statusColor = .green
        } else if projectedRatio <= 1.05 {
            statusText = "Tight but OK"
            statusColor = .orange
        } else {
            statusText = "Over budget"
            statusColor = .red
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)

            Gauge(
                value: spentRatio,
                in: 0...1
            ) {
                Text("Budget")
            } currentValueLabel: {
                Text(spent, format: .currency(code: currencyCode))
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text(budget, format: .currency(code: currencyCode))
            }
            .gaugeStyle(.accessoryLinearCapacity)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projected spend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        projected,
                        format: .currency(code: currencyCode)
                    )
                    .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                    Text(
                        "Guardrail: \(viewModel.config.maxPricePerKWh.formatted(.currency(code: currencyCode)))/kWh"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var budgetControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget & Guardrails")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Charging Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "Budget",
                    value: $viewModel.config.monthlyBudget,
                    format: .currency(code: currencyCode)
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Max Comfortable Price per kWh")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "Max price",
                    value: $viewModel.config.maxPricePerKWh,
                    format: .number.precision(.fractionLength(2))
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

                Text(
                    "Sessions above this line will be flagged so you can shift them to cheaper windows."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var highPriceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("High-price sessions this month")
                .font(.headline)

            Text(
                "These sessions exceeded your guardrail. Shifting them to cheaper times or locations is where most savings live."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            ForEach(
                viewModel.highPriceSessions.sorted(by: { $0.startDate > $1.startDate })
            ) { session in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.location)
                                .font(.subheadline)
                            HStack(spacing: 4) {
                                Text(session.startDate, style: .date)
                                Text("·")
                                Text(session.startDate, style: .time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(
                                session.cost,
                                format: .currency(code: currencyCode)
                            )
                            .font(.subheadline)

                            Text(
                                "\(session.pricePerKWh.formatted(.currency(code: currencyCode)))/kWh"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

struct ChargingBudgetGuardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChargingBudgetGuardView()
        }
    }
}
