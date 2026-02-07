import SwiftUI

@MainActor
struct HomeChargerOptimizerView: View {
    @Environment(\.appThemeBox) private var themeBox
    private var theme: any AppThemeSpec { themeBox.base }

    @AppStorage("planner.offPeakStart") private var offPeakStart: Int = 22
    @AppStorage("planner.offPeakEnd") private var offPeakEnd: Int = 6
    @AppStorage("planner.offPeakRate") private var offPeakRate: Double = 0.18
    @AppStorage("planner.peakRate") private var peakRate: Double = 0.35
    @AppStorage("planner.sessionKWh") private var sessionKWh: Double = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                inputs
                results
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Home Charger Optimizer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Optimize home charging")
                .font(.headline)
            Text("Set your time‑of‑use rates and session size. We’ll suggest the cheapest daily window.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Off‑peak window")
                Spacer()
                Stepper("\(offPeakStart):00", value: $offPeakStart, in: 0...23)
                Stepper("\(offPeakEnd):00", value: $offPeakEnd, in: 0...23)
            }
            HStack {
                Text("Off‑peak rate")
                Spacer()
                TextField("0.00", value: $offPeakRate, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Peak rate")
                Spacer()
                TextField("0.00", value: $peakRate, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Typical session kWh")
                Spacer()
                TextField("0", value: $sessionKWh, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .themedCard()
    }

    private var results: some View {
        let offCost = sessionKWh * offPeakRate
        let peakCost = sessionKWh * peakRate
        let savings = max(0, peakCost - offCost)
        let currency = Locale.current.currency?.identifier ?? "USD"

        return VStack(alignment: .leading, spacing: 8) {
            Text("Recommendation")
                .font(.headline)
            Text("Best window: \(formatHour(offPeakStart)) → \(formatHour(offPeakEnd))")
                .font(.subheadline.weight(.semibold))
            Text("Estimated savings per session: \(savings.formatted(.currency(code: currency)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func formatHour(_ h: Int) -> String {
        let hour = (h % 24 + 24) % 24
        let suffix = hour < 12 ? "AM" : "PM"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(hour12)\(suffix)"
    }
}
