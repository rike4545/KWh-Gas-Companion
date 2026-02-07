//
//  EnergyInsightCategory.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/8/25.
//


//  EnergyCoachView.swift

import SwiftUI
import Combine

enum EnergyInsightCategory: String, CaseIterable, Identifiable {
    case savings
    case efficiency
    case planning
    case behavior

    var id: String { rawValue }

    var title: String {
        switch self {
        case .savings:   return "Savings"
        case .efficiency:return "Efficiency"
        case .planning:  return "Planning"
        case .behavior:  return "Habits"
        }
    }

    var systemImageName: String {
        switch self {
        case .savings:   return "dollarsign.arrow.circlepath"
        case .efficiency:return "speedometer"
        case .planning:  return "calendar.badge.clock"
        case .behavior:  return "brain.head.profile"
        }
    }
}

extension EnergyInsightCategory {
    var accentColor: Color {
        switch self {
        case .savings:   return .green
        case .efficiency:return .blue
        case .planning:  return .orange
        case .behavior:  return .purple
        }
    }
}

struct EnergyCoachInsight: Identifiable, Hashable {
    let id = UUID()
    let category: EnergyInsightCategory
    let title: String
    let message: String
    let impactText: String?
}

@MainActor
final class EnergyCoachViewModel: ObservableObject {
    @Published private(set) var insights: [EnergyCoachInsight] = []
    @Published private(set) var estimatedMonthlySavings: Double = 0
    @Published private(set) var percentHighPriceSessions: Double = 0

    private var sessions: [MECChargingDataSession]
    private var config: ChargingBudgetConfig

    init(
        sessions: [MECChargingDataSession],
        config: ChargingBudgetConfig = .defaultConfig
    ) {
        self.sessions = sessions
        self.config = config
        recomputeInsights()
    }

    func update(
        sessions: [MECChargingDataSession],
        config: ChargingBudgetConfig? = nil
    ) {
        self.sessions = sessions
        if let config {
            self.config = config
        }
        recomputeInsights()
    }

    private func recomputeInsights(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -90, to: referenceDate) else {
            insights = []
            estimatedMonthlySavings = 0
            percentHighPriceSessions = 0
            return
        }

        let recent = sessions.filter { $0.startDate >= start && $0.startDate <= referenceDate }

        guard !recent.isEmpty else {
            insights = [
                EnergyCoachInsight(
                    category: .planning,
                    title: "No data yet",
                    message: "Once you import or record a few weeks of charging, I'll start surfacing specific tips on timing, location mix, and price guardrails.",
                    impactText: nil
                )
            ]
            estimatedMonthlySavings = 0
            percentHighPriceSessions = 0
            return
        }

        let totalKWh = recent.reduce(0) { $0 + $1.kWh }
        let totalCost = recent.reduce(0) { $0 + $1.cost }

        let avgPrice = totalKWh > 0 ? totalCost / totalKWh : 0
        let prices = recent.map { $0.pricePerKWh }

        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 0

        let highPriceSessions = recent.filter { $0.pricePerKWh > config.maxPricePerKWh }
        let highPriceCount = highPriceSessions.count

        let potentialSavingsTotal = highPriceSessions.reduce(0) { partial, session in
            let guardrailCost = config.maxPricePerKWh * session.kWh
            let extra = max(0, session.cost - guardrailCost)
            return partial + extra
        }

        // Approximate monthly savings from last 90 days
        let estimatedMonthly = potentialSavingsTotal / 3.0

        estimatedMonthlySavings = estimatedMonthly
        percentHighPriceSessions = Double(highPriceCount) / Double(recent.count)

        let homeSessions = recent.filter { $0.provider == .home }
        let fastSessions = recent.filter { $0.provider == .dcFast || $0.provider == .supercharger }

        let homeShare = Double(homeSessions.count) / Double(recent.count)
        let fastShare = Double(fastSessions.count) / Double(recent.count)

        var newInsights: [EnergyCoachInsight] = []

        // 1. Guardrail / savings insight
        if highPriceCount > 0 {
            let percentHigh = percentHighPriceSessions * 100
            let savingsText = estimatedMonthly > 0
                ? estimatedMonthly.formatted(
                    .currency(code: Locale.current.currency?.identifier ?? "USD")
                )
                : nil

            let impact: String? = savingsText.map {
                "If you bring those sessions down to your guardrail, you can likely save about \($0)/month."
            }

            newInsights.append(
                EnergyCoachInsight(
                    category: .savings,
                    title: "Tame your most expensive \(highPriceCount == 1 ? "session" : "sessions")",
                    message: String(
                        format: "%.0f%% of your last 90 days of charging happened above your guardrail of %.2f/kWh. Focus on shifting just those sessions to cheaper windows or locations.",
                        percentHigh,
                        config.maxPricePerKWh
                    ),
                    impactText: impact
                )
            )
        }

        // 2. Price spread / timing insight
        if maxPrice > minPrice, avgPrice > 0 {
            newInsights.append(
                EnergyCoachInsight(
                    category: .planning,
                    title: "Lock in more of your cheapest price window",
                    message: String(
                        format: "Over the last 90 days your prices ranged from %.2f to %.2f per kWh, with an average of %.2f. You clearly *can* get that low price—it's just not happening every time.",
                        minPrice,
                        maxPrice,
                        avgPrice
                    ),
                    impactText: "Try to cluster regular charging around your known low-price windows (often overnight at home) and use fast charging only when you're truly on the road."
                )
            )
        }

        // 3. Location mix insight
        if fastShare > 0.5 && homeShare < 0.4 {
            newInsights.append(
                EnergyCoachInsight(
                    category: .efficiency,
                    title: "You're living on public fast charging",
                    message: String(
                        format: "Roughly %.0f%% of your recent sessions were DC fast or Supercharging, while only %.0f%% were at home.",
                        fastShare * 100,
                        homeShare * 100
                    ),
                    impactText: "Fast charging is great for road trips, but expensive and harder on the pack as a default. If you can, shift more routine charging back to home or workplace."
                )
            )
        } else if homeShare > 0.7 {
            newInsights.append(
                EnergyCoachInsight(
                    category: .efficiency,
                    title: "Nice home charging base",
                    message: String(
                        format: "Around %.0f%% of your recent sessions are at home. That's usually the cheapest and most convenient strategy.",
                        homeShare * 100
                    ),
                    impactText: "Your next gains are mostly about *timing* (off-peak vs peak) rather than location."
                )
            )
        }

        // 4. Session size / habit insight
        let smallButExpensive = recent.filter {
            $0.kWh < 10 && $0.pricePerKWh > avgPrice
        }

        if !smallButExpensive.isEmpty {
            newInsights.append(
                EnergyCoachInsight(
                    category: .behavior,
                    title: "Stop 'panic topping' in pricey slots",
                    message: "You have several short, relatively expensive sessions (under 10 kWh, above your average price). These are often 'panic' top-ups at whatever station is nearby.",
                    impactText: "If possible, plan slightly earlier home or workplace charges so those 'oh no' stops become optional instead of mandatory."
                )
            )
        }

        if newInsights.isEmpty {
            newInsights.append(
                EnergyCoachInsight(
                    category: .planning,
                    title: "You're already doing pretty well",
                    message: "Your recent sessions cluster fairly tightly on price and are weighted toward cheaper locations.",
                    impactText: "Small tweaks—like shifting a couple of fast-charge sessions back to home or nudging more energy into off-peak windows—will give diminishing but still real returns."
                )
            )
        }

        insights = newInsights
    }
}

@MainActor
struct EnergyCoachView: View {
    @StateObject private var viewModel: EnergyCoachViewModel

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    init(
        sessions: [MECChargingDataSession] = MECChargingDataSession.sampleSessions(),
        config: ChargingBudgetConfig = .defaultConfig
    ) {
        _viewModel = StateObject(
            wrappedValue: EnergyCoachViewModel(
                sessions: sessions,
                config: config
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                ForEach(viewModel.insights) { insight in
                    insightCard(insight)
                }
            }
            .padding()
        }
        .navigationTitle("Energy Coach")
    }

    private var headerCard: some View {
        let savings = viewModel.estimatedMonthlySavings
        let highPercent = viewModel.percentHighPriceSessions * 100

        return VStack(alignment: .leading, spacing: 8) {
            Text("Personalized tips from your real charging data.")
                .font(.headline)

            if savings > 0 {
                Text(
                    "If you just move your highest-price sessions down to your guardrail, you're likely leaving about \(savings.formatted(.currency(code: currencyCode))) per month on the table."
                )
                .font(.subheadline)
            } else {
                Text(
                    "As more variety shows up in your charging history, I'll highlight specific sessions and patterns that are worth changing."
                )
                .font(.subheadline)
            }

            if highPercent > 0 {
                Text(
                    String(
                        format: "%.0f%% of your recent sessions are above your guardrail — those are the biggest savings targets.",
                        highPercent
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func insightCard(_ insight: EnergyCoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: insight.category.systemImageName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
                    .foregroundStyle(insight.category.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)

                    Text(insight.message)
                        .font(.subheadline)
                }
            }

            if let impact = insight.impactText {
                Text(impact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
    }
}

struct EnergyCoachView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EnergyCoachView()
        }
    }
}
