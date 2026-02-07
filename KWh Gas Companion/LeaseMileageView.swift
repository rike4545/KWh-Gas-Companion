//
//  LeaseMileageView.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Calculates lease mileage pacing + overage (so far + projected).
//  IMPORTANT: Uses miles driven DURING the lease (current odometer - start odometer).
//

import SwiftUI

@MainActor
struct LeaseMileageView: View {

    // MARK: - Inputs

    @State private var startOdometer: Double = 0
    @State private var currentOdometer: Double = 0

    @State private var leaseStartDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var leaseEndDate: Date = Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date()

    private let allowedMilesOptions: [Int] = [10_000, 12_000, 15_000]

    @State private var allowedMode: AllowedMode = .preset(10_000)
    @State private var customAllowedMilesPerYear: Int = 10_000

    @State private var overageRate: Double = 0.25 // $ per mile

    @FocusState private var focusField: FocusField?

    // MARK: - Derived

    private var allowedMilesPerYear: Int {
        switch allowedMode {
        case .preset(let v): return v
        case .custom: return max(0, customAllowedMilesPerYear)
        }
    }

    private var isDateRangeValid: Bool {
        leaseEndDate >= leaseStartDate
    }

    private var leaseDurationDays: Double {
        guard isDateRangeValid else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: leaseStartDate, to: leaseEndDate).day ?? 0
        return max(0, Double(days))
    }

    /// Elapsed days from start until "today" (clamped to end date).
    private var elapsedDays: Double {
        guard isDateRangeValid else { return 0 }
        let now = Date()
        if now <= leaseStartDate { return 0 }
        let clampEnd = min(now, leaseEndDate)
        let days = Calendar.current.dateComponents([.day], from: leaseStartDate, to: clampEnd).day ?? 0
        return max(0, Double(days))
    }

    private var milesDriven: Double {
        max(currentOdometer - startOdometer, 0)
    }

    /// Allowed miles by the current date (simple prorate from allowed miles/year).
    private var allowedMilesToDate: Double {
        // allowedPerDay * elapsedDays
        let allowedPerDay = Double(allowedMilesPerYear) / 365.0
        return max(0, allowedPerDay * elapsedDays)
    }

    /// Total allowed miles over the whole lease term.
    private var allowedMilesForLease: Double {
        let allowedPerDay = Double(allowedMilesPerYear) / 365.0
        return max(0, allowedPerDay * leaseDurationDays)
    }

    private var overageMilesSoFar: Double {
        max(milesDriven - allowedMilesToDate, 0)
    }

    private var overageCostSoFar: Double {
        overageMilesSoFar * max(overageRate, 0)
    }

    /// Simple “same pace” projection (miles/day so far × lease duration).
    private var projectedMilesAtEnd: Double {
        guard leaseDurationDays > 0 else { return 0 }
        // if elapsedDays is 0, projection is unknown → 0
        guard elapsedDays > 0 else { return 0 }
        let milesPerDay = milesDriven / elapsedDays
        return max(0, milesPerDay * leaseDurationDays)
    }

    private var projectedOverageMilesAtEnd: Double {
        max(projectedMilesAtEnd - allowedMilesForLease, 0)
    }

    private var projectedOverageCostAtEnd: Double {
        projectedOverageMilesAtEnd * max(overageRate, 0)
    }

    private var paceStatus: PaceStatus {
        guard elapsedDays > 0 else { return .unknown }
        let delta = milesDriven - allowedMilesToDate
        if abs(delta) < 50 { return .onTrack }
        return delta > 0 ? .over : .under
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                Section("Lease Inputs") {

                    HStack {
                        Text("Start Odometer")
                        Spacer()
                        TextField("0", value: $startOdometer, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusField, equals: .startOdo)
                    }
                    HStack {
                        Text("Current Odometer")
                        Spacer()
                        TextField("0", value: $currentOdometer, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusField, equals: .currentOdo)
                    }

                    DatePicker("Start Date", selection: $leaseStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $leaseEndDate, displayedComponents: .date)

                    if !isDateRangeValid {
                        Text("End date must be on/after the start date.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Allowance & Rate") {

                    Picker("Allowed Miles/Year", selection: $allowedMode) {
                        ForEach(allowedMilesOptions, id: \.self) { v in
                            Text("\(v.formatted(.number))").tag(AllowedMode.preset(v))
                        }
                        Text("Custom").tag(AllowedMode.custom)
                    }

                    if allowedMode == .custom {
                        Stepper(value: $customAllowedMilesPerYear, in: 0...30_000, step: 500) {
                            HStack {
                                Text("Custom Allowance")
                                Spacer()
                                Text("\(customAllowedMilesPerYear.formatted(.number)) / yr")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Text("Overage Rate")
                        Spacer()
                        TextField("0.25", value: $overageRate, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusField, equals: .rate)
                        Text("/ mi")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Progress") {
                    HStack {
                        Text("Miles Driven")
                        Spacer()
                        Text("\(milesDriven.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Allowed To Date")
                        Spacer()
                        Text("\(allowedMilesToDate.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Allowed For Lease")
                        Spacer()
                        Text("\(allowedMilesForLease.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Label(paceStatus.title, systemImage: paceStatus.symbol)
                            .foregroundStyle(paceStatus.tint)
                        Spacer()
                        Text(paceStatus.detail(delta: milesDriven - allowedMilesToDate))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section("Overage") {

                    HStack {
                        Text("Overage Miles (So Far)")
                        Spacer()
                        Text("\(overageMilesSoFar.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Overage Cost (So Far)")
                        Spacer()
                        Text(overageCostSoFar, format: .currency(code: currencyCode))
                            .monospacedDigit()
                    }

                    Divider()

                    HStack {
                        Text("Projected Miles at End")
                        Spacer()
                        Text("\(projectedMilesAtEnd.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Projected Overage (End)")
                        Spacer()
                        Text("\(projectedOverageMilesAtEnd.formatted(.number.precision(.fractionLength(0)))) mi")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Projected Cost (End)")
                        Spacer()
                        Text(projectedOverageCostAtEnd, format: .currency(code: currencyCode))
                            .monospacedDigit()
                    }

                    Text("Projection assumes you keep your current average miles/day for the rest of the lease.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Lease Mileage")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusField = nil }
                }
            }
        }
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

// MARK: - Small Types

private enum FocusField: Hashable {
    case startOdo, currentOdo, rate
}

private enum AllowedMode: Hashable {
    case preset(Int)
    case custom
}

private enum PaceStatus {
    case unknown
    case onTrack
    case under
    case over

    var title: String {
        switch self {
        case .unknown: return "Pace Unknown"
        case .onTrack: return "On Track"
        case .under: return "Under Miles"
        case .over: return "Over Miles"
        }
    }

    var symbol: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .onTrack: return "checkmark.seal"
        case .under: return "arrow.down.circle"
        case .over: return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: return .secondary
        case .onTrack: return .green
        case .under: return .blue
        case .over: return .orange
        }
    }

    func detail(delta: Double) -> String {
        switch self {
        case .unknown:
            return "—"
        case .onTrack:
            return "±0"
        case .under:
            return "\(abs(delta).formatted(.number.precision(.fractionLength(0)))) under"
        case .over:
            return "\(abs(delta).formatted(.number.precision(.fractionLength(0)))) over"
        }
    }
}

#if DEBUG
#Preview {
    LeaseMileageView()
}
#endif
