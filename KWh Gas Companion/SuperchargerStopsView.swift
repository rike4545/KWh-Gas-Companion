//
//  SuperchargerStopsView.swift
//  KWh Gas Companion
//
//  Offline stop planner (no network). You enter route distance and car/charging
//  assumptions; it computes number of stops, leg distances, energy added, and charge time.
//
//  Simplified model:
//  • Consumption: highway Wh/mi
//  • You choose a reserve (Min Arrival SOC) and a typical charge target (Target SOC)
//  • First leg starts at Start SOC
//  • Intermediate legs aim to arrive at Min Arrival SOC
//  • Final leg charges only what’s required (may be below Target SOC)
//  • Charge time = energy added / avg charge power (blended kW)
//

import SwiftUI

struct SuperchargerStopsView: View {

    // MARK: Inputs

    @State private var routeDistanceMi: Double = 650
    @State private var cruiseMph: Double = 70

    // Vehicle & consumption
    @State private var usableKWh: Double = 75
    @State private var highwayWhPerMi: Double = 280

    // SOC strategy
    @State private var startSOC: Double = 90     // %
    @State private var minArrivalSOC: Double = 10// %
    @State private var targetSOC: Double = 60    // %

    // Charging
    @State private var avgChargePowerKW: Double = 120

    // UI
    @State private var showDetails = true

    // MARK: Derived / Validation

    private var modelIsValid: Bool {
        usableKWh > 0 &&
        highwayWhPerMi > 0 &&
        routeDistanceMi > 0 &&
        cruiseMph > 0 &&
        avgChargePowerKW > 0 &&
        startSOC > minArrivalSOC &&
        targetSOC > minArrivalSOC &&
        startSOC <= 100 && targetSOC <= 100 && minArrivalSOC >= 0
    }

    private var kWhPerMi: Double { max(1, highwayWhPerMi) / 1000.0 }

    private var pctPerMile: Double {
        // %SOC consumed per mile
        (kWhPerMi / usableKWh) * 100.0
    }

    private var firstLegMaxMiles: Double {
        let windowPct = max(0, startSOC - minArrivalSOC)
        return windowPct / max(0.000001, pctPerMile)
    }

    private var perStopMaxMiles: Double {
        let windowPct = max(0, targetSOC - minArrivalSOC)
        return windowPct / max(0.000001, pctPerMile)
    }

    private var perStopEnergyKWhAtTarget: Double {
        usableKWh * max(0, (targetSOC - minArrivalSOC) / 100.0)
    }

    private var plan: PlanResult {
        guard modelIsValid else { return .invalid }
        return makePlan(distanceMiles: routeDistanceMi)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                Card(title: "Route & Vehicle", subtitle: "Distance and baseline assumptions") {
                    routeVehicleForm
                }

                Card(title: "SOC Strategy", subtitle: "Reserve and typical charge target") {
                    socForm
                }

                Card(title: "Results", subtitle: "Stops, time, and energy") {
                    if !modelIsValid {
                        EmptyNote(
                            title: "Enter realistic values",
                            message: "Check battery size, SOCs, Wh/mi, and power. Start/Target must be greater than Min Arrival."
                        )
                    } else {
                        resultsSummary(plan)

                        if showDetails, case let .ok(legs, totals) = plan {
                            Divider().padding(.vertical, 6)
                            legsTable(legs)
                            Divider().padding(.vertical, 6)
                            totalsView(totals)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Supercharger Stops")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: UI Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan Supercharger Stops")
                .font(.title.bold())

            Text("Offline estimate — tweak assumptions to match your car, weather, and route.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeVehicleForm: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Text("Route Distance").foregroundStyle(.secondary)
                Stepper(value: $routeDistanceMi, in: 10...3000, step: 10) {
                    HStack {
                        Text(number(routeDistanceMi, 0)).monospacedDigit()
                        Text("mi").foregroundStyle(.secondary)
                    }
                }
            }
            GridRow {
                Text("Cruise Speed").foregroundStyle(.secondary)
                Stepper(value: $cruiseMph, in: 30...90, step: 5) {
                    HStack {
                        Text(number(cruiseMph, 0)).monospacedDigit()
                        Text("mph").foregroundStyle(.secondary)
                    }
                }
            }
            GridRow {
                Text("Usable Battery").foregroundStyle(.secondary)
                Stepper(value: $usableKWh, in: 20...120, step: 1) {
                    HStack {
                        Text(number(usableKWh, 0)).monospacedDigit()
                        Text("kWh").foregroundStyle(.secondary)
                    }
                }
            }
            GridRow {
                Text("Highway Consumption").foregroundStyle(.secondary)
                Stepper(value: $highwayWhPerMi, in: 150...500, step: 5) {
                    HStack {
                        Text(number(highwayWhPerMi, 0)).monospacedDigit()
                        Text("Wh/mi").foregroundStyle(.secondary)
                    }
                }
            }
            GridRow {
                Text("Avg Charge Power").foregroundStyle(.secondary)
                Stepper(value: $avgChargePowerKW, in: 30...250, step: 5) {
                    HStack {
                        Text(number(avgChargePowerKW, 0)).monospacedDigit()
                        Text("kW").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.footnote)
    }

    private var socForm: some View {
        VStack(spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Start SOC").foregroundStyle(.secondary)
                    Stepper(value: $startSOC, in: 20...100, step: 5) {
                        Text(number(startSOC, 0) + " %").monospacedDigit()
                    }
                }
                GridRow {
                    Text("Target SOC").foregroundStyle(.secondary)
                    Stepper(value: $targetSOC, in: 30...100, step: 5) {
                        Text(number(targetSOC, 0) + " %").monospacedDigit()
                    }
                }
                GridRow {
                    Text("Min Arrival SOC").foregroundStyle(.secondary)
                    Stepper(value: $minArrivalSOC, in: 0...50, step: 5) {
                        Text(number(minArrivalSOC, 0) + " %").monospacedDigit()
                    }
                }
            }
            .font(.footnote)

            Toggle(isOn: $showDetails) {
                Text("Show Leg Details")
            }
            .font(.footnote)

            Text("Meaning: You try to arrive around \(Int(minArrivalSOC))% and usually charge up toward \(Int(targetSOC))% (except the last leg, which only charges what it needs).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Results

    @ViewBuilder
    private func resultsSummary(_ plan: PlanResult) -> some View {
        switch plan {
        case .invalid:
            EmptyNote(title: "Not enough info", message: "Please complete the fields above with valid values.")
        case let .ok(_, totals):
            VStack(spacing: 12) {

                // Time pills (responsive)
                ViewThatFits {
                    HStack(spacing: 12) {
                        MetricPill(title: "Stops", value: "\(totals.stops)", icon: "bolt.car")
                        MetricPill(title: "Drive", value: timeHMM(totals.driveHours), icon: "steeringwheel")
                        MetricPill(title: "Charge", value: timeHMM(totals.chargeHours), icon: "bolt.fill")
                        MetricPill(title: "Total", value: timeHMM(totals.totalHours), icon: "timer")
                    }
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            MetricPill(title: "Stops", value: "\(totals.stops)", icon: "bolt.car")
                            MetricPill(title: "Drive", value: timeHMM(totals.driveHours), icon: "steeringwheel")
                        }
                        HStack(spacing: 12) {
                            MetricPill(title: "Charge", value: timeHMM(totals.chargeHours), icon: "bolt.fill")
                            MetricPill(title: "Total", value: timeHMM(totals.totalHours), icon: "timer")
                        }
                    }
                }

                ViewThatFits {
                    HStack(spacing: 12) {
                        MetricPill(title: "First Leg Max", value: number(totals.firstLegMaxMiles, 0) + " mi", icon: "1.circle")
                        MetricPill(title: "Per-Stop Max", value: number(totals.perStopMaxMiles, 0) + " mi", icon: "repeat")
                        MetricPill(title: "Energy to Target", value: number(totals.perStopEnergyAtTargetKWh, 1) + " kWh", icon: "battery.100")
                    }
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            MetricPill(title: "First Leg Max", value: number(totals.firstLegMaxMiles, 0) + " mi", icon: "1.circle")
                            MetricPill(title: "Per-Stop Max", value: number(totals.perStopMaxMiles, 0) + " mi", icon: "repeat")
                        }
                        MetricPill(title: "Energy to Target", value: number(totals.perStopEnergyAtTargetKWh, 1) + " kWh", icon: "battery.100")
                    }
                }
            }
        }
    }

    private func legsTable(_ legs: [Leg]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {

                // Header row
                HStack(spacing: 12) {
                    headerCell("Leg", w: 80, align: .leading)
                    headerCell("Miles", w: 70, align: .trailing)
                    headerCell("Depart %", w: 70, align: .trailing)
                    headerCell("Arrive %", w: 70, align: .trailing)
                    headerCell("Charge kWh", w: 90, align: .trailing)
                    headerCell("Charge min", w: 90, align: .trailing)
                    headerCell("Note", w: 220, align: .leading)
                }

                ForEach(legs) { leg in
                    HStack(spacing: 12) {
                        cell(leg.label, w: 80, align: .leading)
                        cell(number(leg.miles, 0), w: 70, align: .trailing)
                        cell(number(leg.departSOC, 0), w: 70, align: .trailing)
                        cell(number(leg.arriveSOC, 0), w: 70, align: .trailing)
                        cell(number(leg.chargeKWh, 1), w: 90, align: .trailing)
                        cell(number(leg.chargeMinutes, 0), w: 90, align: .trailing)
                        cell(leg.note ?? "—", w: 220, align: .leading)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func headerCell(_ text: String, w: CGFloat, align: Alignment) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: w, alignment: align)
    }

    private func cell(_ text: String, w: CGFloat, align: Alignment) -> some View {
        Text(text)
            .frame(width: w, alignment: align)
    }

    private func totalsView(_ t: Totals) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Assumptions Recap").font(.headline)

            Text("• Consumption: \(number(highwayWhPerMi, 0)) Wh/mi • Usable: \(number(usableKWh, 0)) kWh")
                .font(.footnote).foregroundStyle(.secondary)

            Text("• Start: \(number(startSOC, 0))% • Arrive reserve: \(number(minArrivalSOC, 0))% • Typical target: \(number(targetSOC, 0))%")
                .font(.footnote).foregroundStyle(.secondary)

            Text("• First-leg max: \(number(t.firstLegMaxMiles, 0)) mi • Per-stop max: \(number(t.perStopMaxMiles, 0)) mi")
                .font(.footnote).foregroundStyle(.secondary)

            Text("• Avg charge power: \(number(avgChargePowerKW, 0)) kW (blended). Actual time varies with taper, stall sharing, and temperature.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Planning Math

    private func driveHours(forDistance miles: Double) -> Double {
        guard cruiseMph > 0 else { return 0 }
        return miles / cruiseMph
    }

    private func chargeMinutes(forEnergy kWh: Double) -> Double {
        guard avgChargePowerKW > 0 else { return 0 }
        return (kWh / avgChargePowerKW) * 60.0
    }

    private func makePlan(distanceMiles: Double) -> PlanResult {
        let dist = max(0, distanceMiles)

        let firstMax = max(0, firstLegMaxMiles)
        let perStopMax = max(0, perStopMaxMiles)

        if pctPerMile <= 0.0000001 || perStopMax <= 0 {
            return .invalid
        }

        // If first leg covers the whole route:
        if dist <= firstMax {
            let arrive = max(0, startSOC - dist * pctPerMile)
            let legs = [
                Leg(label: "Start",
                    miles: dist,
                    departSOC: startSOC,
                    arriveSOC: arrive,
                    chargeKWh: 0,
                    chargeMinutes: 0,
                    note: "No charging needed")
            ]
            let totals = Totals(
                stops: 0,
                driveHours: driveHours(forDistance: dist),
                chargeHours: 0,
                totalHours: driveHours(forDistance: dist),
                firstLegMaxMiles: firstMax,
                perStopMaxMiles: perStopMax,
                perStopEnergyAtTargetKWh: perStopEnergyKWhAtTarget
            )
            return .ok(legs, totals)
        }

        // Otherwise: first leg to reserve:
        var legs: [Leg] = []
        legs.append(
            Leg(label: "Start",
                miles: firstMax,
                departSOC: startSOC,
                arriveSOC: minArrivalSOC,
                chargeKWh: 0,
                chargeMinutes: 0,
                note: "Arrive ~\(Int(minArrivalSOC))%")
        )

        var remaining = dist - firstMax
        var stopIndex = 1

        // Each charging stop begins at minArrivalSOC
        while remaining > 0.01 {
            let maxThisLeg = perStopMax

            if remaining <= maxThisLeg {
                // Final leg: only charge what is required (may be below target)
                let requiredDepart = minArrivalSOC + (remaining * pctPerMile)
                var depart = requiredDepart
                var note: String? = "Charge only what’s needed"

                if depart > targetSOC {
                    note = "Needs \(Int(ceil(depart)))% (above target)"
                } else if depart < targetSOC {
                    // keep it as required; not charging to target saves time
                    note = "Charge to ~\(Int(ceil(depart)))% (below target)"
                }

                depart = min(max(depart, minArrivalSOC), 100)

                let deltaPct = max(0, depart - minArrivalSOC)
                let chargeKWh = usableKWh * (deltaPct / 100.0)
                let chargeMin = chargeMinutes(forEnergy: chargeKWh)

                let arrive = max(0, depart - (remaining * pctPerMile))

                legs.append(
                    Leg(label: "Stop \(stopIndex)",
                        miles: remaining,
                        departSOC: depart,
                        arriveSOC: arrive,
                        chargeKWh: chargeKWh,
                        chargeMinutes: chargeMin,
                        note: note)
                )

                remaining = 0
            } else {
                // Intermediate leg: charge to target and drive full window
                let depart = targetSOC
                let deltaPct = max(0, depart - minArrivalSOC)
                let chargeKWh = usableKWh * (deltaPct / 100.0)
                let chargeMin = chargeMinutes(forEnergy: chargeKWh)

                legs.append(
                    Leg(label: "Stop \(stopIndex)",
                        miles: maxThisLeg,
                        departSOC: depart,
                        arriveSOC: minArrivalSOC,
                        chargeKWh: chargeKWh,
                        chargeMinutes: chargeMin,
                        note: "Standard window")
                )

                remaining -= maxThisLeg
            }

            stopIndex += 1
            if stopIndex > 60 { break } // hard safety guard
        }

        let driveH = driveHours(forDistance: dist)
        let chargeH = legs.reduce(0.0) { $0 + ($1.chargeMinutes / 60.0) } // includes 0 for first leg
        let stops = max(0, legs.count - 1) // charging sessions (everything after Start)

        let totals = Totals(
            stops: stops,
            driveHours: driveH,
            chargeHours: chargeH,
            totalHours: driveH + chargeH,
            firstLegMaxMiles: firstMax,
            perStopMaxMiles: perStopMax,
            perStopEnergyAtTargetKWh: perStopEnergyKWhAtTarget
        )

        return .ok(legs, totals)
    }

    // MARK: Formatting

    private func number(_ v: Double, _ digits: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = digits
        nf.minimumFractionDigits = digits
        return nf.string(from: NSNumber(value: v)) ?? String(format: "%.\(digits)f", v)
    }

    private func timeHMM(_ hours: Double) -> String {
        let totalMin = Int((hours * 60).rounded())
        let h = totalMin / 60
        let m = totalMin % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Models

private enum PlanResult {
    case invalid
    case ok([Leg], Totals)
}

private struct Leg: Identifiable {
    let id = UUID()
    let label: String
    let miles: Double
    let departSOC: Double
    let arriveSOC: Double
    let chargeKWh: Double
    let chargeMinutes: Double
    let note: String?
}

private struct Totals {
    let stops: Int
    let driveHours: Double
    let chargeHours: Double
    let totalHours: Double

    let firstLegMaxMiles: Double
    let perStopMaxMiles: Double
    let perStopEnergyAtTargetKWh: Double
}

// MARK: - Small UI bits

private struct Card<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct MetricPill: View {
    let title: String, value: String, icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1))
    }
}

private struct EmptyNote: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .tertiarySystemBackground)))
    }
}

#if DEBUG
#Preview {
    NavigationStack { SuperchargerStopsView() }
}
#endif
