import SwiftUI

@MainActor
struct WinterRangeImpactPlannerView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @AppStorage("winter.range.base") private var baseRangeMiles: Double = 310
    @AppStorage("winter.range.tempF") private var tempF: Double = 32
    @AppStorage("winter.range.speed") private var speedMPH: Double = 70
    @AppStorage("winter.range.hvac") private var hvacLevel: Double = 2

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let adjusted = adjustedRange()
        let lossPct = max(0, (1 - adjusted / max(1, baseRangeMiles)) * 100)

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                inputsCard
                resultCard(adjusted: adjusted, lossPct: lossPct)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Winter Range Impact")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimate cold‑weather range impact")
                .font(.headline)
            Text("Adjust temperature, speed, and HVAC use to see expected range loss.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow("Base range (mi)", value: $baseRangeMiles)

            HStack {
                Text("Temperature")
                Spacer()
                Text("\(Int(tempF))°F")
                    .monospacedDigit()
            }
            Slider(value: $tempF, in: -10...80, step: 1)

            HStack {
                Text("Speed")
                Spacer()
                Text("\(Int(speedMPH)) mph")
                    .monospacedDigit()
            }
            Slider(value: $speedMPH, in: 45...85, step: 1)

            HStack {
                Text("HVAC use")
                Spacer()
                Text(hvacLabel)
            }
            Slider(value: $hvacLevel, in: 0...3, step: 1)
        }
        .themedCard()
    }

    private func resultCard(adjusted: Double, lossPct: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estimated Range")
                .font(.headline)
            Text("\(adjusted, specifier: "%.0f") miles")
                .font(.title2.weight(.bold))
            Text("≈ \(lossPct, specifier: "%.0f")% reduction")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var hvacLabel: String {
        switch Int(hvacLevel) {
        case 0: return "Off"
        case 1: return "Low"
        case 2: return "Medium"
        default: return "High"
        }
    }

    private func adjustedRange() -> Double {
        let base = max(1, baseRangeMiles)

        // Temperature penalty: below 65F loses ~0.5% per degree, above 65 gains ~0.1% per degree (capped).
        let tempDelta = tempF - 65
        let tempFactor: Double
        if tempDelta < 0 {
            tempFactor = max(0.60, 1 + tempDelta * 0.005) // down to -40% min
        } else {
            tempFactor = min(1.05, 1 + tempDelta * 0.001)
        }

        // Speed penalty: above 65 mph loses ~0.6% per mph, below 65 gains ~0.2% per mph (capped).
        let speedDelta = speedMPH - 65
        let speedFactor: Double
        if speedDelta > 0 {
            speedFactor = max(0.55, 1 - speedDelta * 0.006)
        } else {
            speedFactor = min(1.06, 1 - speedDelta * 0.002)
        }

        // HVAC penalty: 0–3 => 0–12% loss
        let hvacFactor = 1 - (hvacLevel * 0.04)

        return base * tempFactor * speedFactor * hvacFactor
    }

    private func fieldRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }
}
