//  EVChargingVsGasTimeCalculatorView.swift
//  My KWh Companion
//
//  Compare “time spent charging” vs “time spent fueling gas”
//  Swift 6 • iOS 17+
//

import SwiftUI
import UIKit

@MainActor
struct EVChargingVsGasTimeCalculatorView: View {

    @Environment(\.appThemeBox) private var themeBox
    @EnvironmentObject private var appearance: AppAppearance

    private var theme: any AppThemeSpec { themeBox.base }
    private var accent: Color { appearance.accentColor }

    // EV inputs
    @State private var evEnergyKWhText: String = "50"
    @State private var evAvgPowerKWText: String = "120"
    @State private var evOverheadMinText: String = "3"

    // Gas inputs
    @State private var gasGallonsText: String = "12"
    @State private var gasPumpRateGPMText: String = "8"
    @State private var gasOverheadMinText: String = "2"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing + 8) {

                header

                card(title: "EV charging time", systemImage: "bolt.car") {
                    VStack(spacing: 10) {
                        numberRow("Energy to add (kWh)", text: $evEnergyKWhText, keyboard: .decimalPad)
                        numberRow("Average charge power (kW)", text: $evAvgPowerKWText, keyboard: .decimalPad)
                        numberRow("Overhead (minutes)", text: $evOverheadMinText, keyboard: .decimalPad)

                        Divider().overlay(theme.separator.opacity(0.85))

                        resultRow("Estimated charging time", value: formatMinutes(evTotalMinutes))
                    }
                }

                card(title: "Real-world context", systemImage: "bolt.badge.clock") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This estimate assumes a stable average charging rate. Real EV charging curves taper as the battery fills, so peak power is not the same as whole-session speed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("For comparison, Tesla's premium NCA packs can briefly approach about 3C when pulling 250 kW at a Supercharger, but the average rate over the stop is much lower once taper begins.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Tesla's standard-range LFP packs are more conservative, often closer to roughly 1C to 2C at peak. A sustained 3C LFP pack would make 10% to 80% charging meaningfully faster for entry-level EVs.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                card(title: "Gas fueling time", systemImage: "fuelpump") {
                    VStack(spacing: 10) {
                        numberRow("Gallons to add", text: $gasGallonsText, keyboard: .decimalPad)
                        numberRow("Pump rate (gal/min)", text: $gasPumpRateGPMText, keyboard: .decimalPad)
                        numberRow("Overhead (minutes)", text: $gasOverheadMinText, keyboard: .decimalPad)

                        Divider().overlay(theme.separator.opacity(0.85))

                        resultRow("Estimated fueling time", value: formatMinutes(gasTotalMinutes))
                    }
                }

                card(title: "Comparison", systemImage: "stopwatch") {
                    VStack(spacing: 10) {
                        let diff = evTotalMinutes - gasTotalMinutes

                        resultRow("Difference", value: formatSignedMinutes(diff))

                        if evTotalMinutes > 0, gasTotalMinutes > 0 {
                            let ratio = evTotalMinutes / max(gasTotalMinutes, 0.0001)
                            resultRow("EV vs gas (×)", value: String(format: "%.1fx", ratio))
                        }

                        Text(helperText(for: diff))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("EV vs Gas Time")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
    }

    // MARK: - Computation

    private var evEnergyKWh: Double { Double(evEnergyKWhText) ?? 0 }
    private var evAvgPowerKW: Double { Double(evAvgPowerKWText) ?? 0 }
    private var evOverheadMin: Double { Double(evOverheadMinText) ?? 0 }

    private var gasGallons: Double { Double(gasGallonsText) ?? 0 }
    private var gasPumpRateGPM: Double { Double(gasPumpRateGPMText) ?? 0 }
    private var gasOverheadMin: Double { Double(gasOverheadMinText) ?? 0 }

    private var evTotalMinutes: Double {
        let power = max(evAvgPowerKW, 0.0001)
        let core = (max(evEnergyKWh, 0) / power) * 60.0
        return max(0, core + max(0, evOverheadMin))
    }

    private var gasTotalMinutes: Double {
        let rate = max(gasPumpRateGPM, 0.0001)
        let core = max(gasGallons, 0) / rate
        return max(0, core + max(0, gasOverheadMin))
    }

    // MARK: - UI bits

    private var header: some View {
        card(title: "Time comparison", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Estimate how long a typical EV charging stop takes versus a gas stop, including a little “overhead” time (plug in, payment, windshield, etc.).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func helperText(for diff: Double) -> String {
        if abs(diff) < 0.5 { return "About the same time for this scenario." }
        if diff > 0 { return "Charging takes longer in this scenario — tune power, kWh, and overhead to match a real stop." }
        return "Charging is faster in this scenario — this can happen for small top-ups (especially at home)."
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 60 {
            return String(format: "%.1f min", minutes)
        } else {
            let hrs = minutes / 60.0
            return String(format: "%.2f hr (%.0f min)", hrs, minutes)
        }
    }

    private func formatSignedMinutes(_ minutes: Double) -> String {
        let sign = minutes >= 0 ? "+" : "−"
        return "\(sign) \(formatMinutes(abs(minutes)))"
    }

    private func numberRow(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 10)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
        }
    }

    private func resultRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private func card<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(theme.spacing)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .strokeBorder(theme.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: theme.elevation, x: 0, y: 2)
    }
}
