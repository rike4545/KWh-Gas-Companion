//  DepreciationCurveView.swift
//  My KWh Companion
//
//  Regenerated to read purchase price from VehicleProfile and render a simple depreciation curve.
//  Assumptions: VehicleProfile exposes purchasePrice (Double?), purchaseDate (Date?),
//  and optional annualDepreciationRate (Double? as 0.0–1.0).

import SwiftUI
import Foundation

#if canImport(Charts)
import Charts
#endif

// MARK: - ViewModel
final class DepreciationCurveViewModel: ObservableObject {
    struct DepPoint: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    @Published var purchasePrice: Double
    @Published var purchaseDate: Date
    @Published var annualRate: Double
    @Published var horizonMonths: Int
    @Published var points: [DepPoint] = []

    init(vehicle: VehicleProfile, startDate: Date = Date(), defaultRate: Double = 0.12, horizonMonths: Int = 84) {
        self.purchasePrice = vehicle.purchasePrice ?? 0
        self.purchaseDate = startDate
        self.annualRate = max(0, min(defaultRate, 0.95))
        self.horizonMonths = horizonMonths
        recalc()
    }

    func recalc() {
        guard purchasePrice > 0 else {
            points = []
            return
        }
        let r = annualRate
        let months = max(1, horizonMonths)
        let cal = Calendar.current

        points = (0...months).compactMap { m in
            let date = cal.date(byAdding: .month, value: m, to: purchaseDate) ?? purchaseDate
            let years = Double(m) / 12.0
            // Exponential decay from purchase price
            let value = purchasePrice * pow(1.0 - r, years)
            return DepPoint(date: date, value: max(value, 0))
        }
    }
}

// MARK: - View
struct DepreciationCurveView: View {
    @StateObject private var vm: DepreciationCurveViewModel

    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    init(vehicle: VehicleProfile, startDate: Date = Date(), defaultAnnualRate: Double = 0.12) {
        _vm = StateObject(wrappedValue: DepreciationCurveViewModel(vehicle: vehicle, startDate: startDate, defaultRate: defaultAnnualRate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if vm.purchasePrice <= 0 {
                missingPriceBanner
            } else {
                chartSection
            }

            controls
        }
        .padding()
        .navigationTitle("Depreciation")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vehicle Depreciation")
                .font(.title2).bold()
            HStack(spacing: 12) {
                Label(valueText(vm.purchasePrice), systemImage: "dollarsign.circle")
                Label(vm.purchaseDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                Label("\(Int(vm.annualRate * 100))%/yr", systemImage: "chart.line.downtrend.xyaxis")
            }
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }

    private var missingPriceBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Missing purchase price", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("Set a purchase price in your Vehicle Profile to see the depreciation curve.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var chartSection: some View {
        #if canImport(Charts)
        Chart(vm.points) { p in
            LineMark(
                x: .value("Date", p.date),
                y: .value("Value", p.value)
            )
            .interpolationMethod(.monotone)
        }
        .chartXAxisLabel("Date")
        .chartYAxisLabel("Value")
        .frame(height: 240)
        .kwhInteractiveDataViz()
        #else
        // Fallback: simple list of points if Charts is not available
        VStack(alignment: .leading, spacing: 8) {
            ForEach(vm.points) { p in
                HStack {
                    Text(p.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text(valueText(p.value))
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .frame(maxHeight: 260)
        #endif
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjustments").font(.headline)

            // Annual rate slider (0–40%)
            VStack(alignment: .leading) {
                HStack {
                    Text("Annual rate")
                    Spacer()
                    Text("\(Int(vm.annualRate * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { vm.annualRate },
                    set: { vm.annualRate = $0; vm.recalc() }
                ), in: 0...0.40, step: 0.005)
            }

            // Horizon picker (years)
            HStack {
                Text("Horizon")
                Spacer()
                Picker("Horizon", selection: Binding(
                    get: { vm.horizonMonths },
                    set: { vm.horizonMonths = $0; vm.recalc() }
                )) {
                    Text("5y").tag(60)
                    Text("7y").tag(84)
                    Text("10y").tag(120)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers
    private func valueText(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }
}
