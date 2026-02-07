//
//  EVSpec.swift
//  KWh Gas Companion / My EV Companion
//
//  EV vs Muscle Car — F1-style "Race Day Showdown".
//
//  Defines:
//  • EVSpec (public)
//  • EVMake / EVPreset / EVPresetDatabase (expanded Tesla presets + Rivian)
//  • MuscleCar / MuscleCarDatabase (expanded classic + muscle cars)
//  • Winner enum
//  • MuscleCarShowdownView (theme-aware)
//
//  NOTE: Preset numbers are approximate / fun-oriented.
//
//  Swift 6 • iOS 17+
//

import SwiftUI

// MARK: - EV Spec (public, used app-wide)

public struct EVSpec: Hashable, Sendable {
    public var name: String
    public var horsepower: Int
    public var torque: Int          // lb-ft (approx for many EVs)
    public var zeroToSixty: Double  // seconds
    public var quarterMile: Double? // seconds (optional)

    public init(
        name: String,
        horsepower: Int,
        torque: Int,
        zeroToSixty: Double,
        quarterMile: Double? = nil
    ) {
        self.name = name
        self.horsepower = horsepower
        self.torque = torque
        self.zeroToSixty = zeroToSixty
        self.quarterMile = quarterMile
    }
}

// MARK: - EV Presets (Tesla / Rivian)

enum EVMake: String, CaseIterable, Identifiable {
    case tesla = "Tesla"
    case rivian = "Rivian"
    case custom = "Custom"
    var id: String { rawValue }
}

struct EVPreset: Identifiable, Hashable, Sendable {
    let id = UUID()
    let make: EVMake
    let displayName: String
    let spec: EVSpec

    /// Stable key for UI selection (avoid Picker generic inference issues).
    var key: String { "\(make.rawValue)|\(displayName)" }
}

/// Expanded presets.
/// “All Teslas” interpreted as: all Tesla vehicle lines + key performance/era trims.
enum EVPresetDatabase {

    // Convenience builders
    private static func tesla(_ name: String, hp: Int, tq: Int, z: Double, qm: Double? = nil) -> EVPreset {
        EVPreset(make: .tesla, displayName: name, spec: EVSpec(name: name, horsepower: hp, torque: tq, zeroToSixty: z, quarterMile: qm))
    }
    private static func rivian(_ name: String, hp: Int, tq: Int, z: Double, qm: Double? = nil) -> EVPreset {
        EVPreset(make: .rivian, displayName: name, spec: EVSpec(name: name, horsepower: hp, torque: tq, zeroToSixty: z, quarterMile: qm))
    }

    static let all: [EVPreset] = [

        // --- TESLA: Roadster (original) ---
        tesla("2010 Tesla Roadster 2.5 Sport", hp: 288, tq: 295, z: 3.7, qm: 12.6),

        // --- TESLA: Model S (key eras) ---
        tesla("2013 Tesla Model S P85", hp: 416, tq: 443, z: 4.2, qm: 12.6),
        tesla("2014 Tesla Model S P85D", hp: 691, tq: 713, z: 3.2, qm: 11.6),
        tesla("2016 Tesla Model S P90D (Ludicrous)", hp: 762, tq: 713, z: 2.8, qm: 11.0),
        tesla("2017 Tesla Model S P100D", hp: 762, tq: 713, z: 2.4, qm: 10.6),
        tesla("2021 Tesla Model S Long Range", hp: 670, tq: 723, z: 3.1, qm: 11.3),
        tesla("2021 Tesla Model S Plaid", hp: 1020, tq: 1050, z: 2.0, qm: 9.2),
        tesla("2024 Tesla Model S Long Range", hp: 670, tq: 723, z: 3.1, qm: 11.2),
        tesla("2024 Tesla Model S Plaid", hp: 1020, tq: 1050, z: 2.0, qm: 9.2),

        // --- TESLA: Model X (key eras) ---
        tesla("2016 Tesla Model X P90D (Ludicrous)", hp: 762, tq: 713, z: 3.2, qm: 11.7),
        tesla("2017 Tesla Model X P100D", hp: 762, tq: 713, z: 2.9, qm: 11.4),
        tesla("2021 Tesla Model X Long Range", hp: 670, tq: 713, z: 3.8, qm: 11.6),
        tesla("2021 Tesla Model X Plaid", hp: 1020, tq: 1050, z: 2.5, qm: 9.9),
        tesla("2024 Tesla Model X Long Range", hp: 670, tq: 713, z: 3.8, qm: 11.5),
        tesla("2024 Tesla Model X Plaid", hp: 1020, tq: 1050, z: 2.5, qm: 9.6),

        // --- TESLA: Model 3 (multiple eras) ---
        tesla("2018 Tesla Model 3 Long Range AWD", hp: 346, tq: 376, z: 4.4, qm: 12.6),
        tesla("2018 Tesla Model 3 Performance", hp: 450, tq: 471, z: 3.3, qm: 11.8),
        tesla("2021 Tesla Model 3 Long Range AWD", hp: 390, tq: 380, z: 4.2, qm: 12.6),
        tesla("2021 Tesla Model 3 Performance", hp: 480, tq: 471, z: 3.1, qm: 11.6),
        tesla("2024 Tesla Model 3 RWD (Highland)", hp: 255, tq: 310, z: 5.8, qm: 14.2),
        tesla("2024 Tesla Model 3 Long Range (Highland)", hp: 390, tq: 380, z: 4.2, qm: 12.7),
        tesla("2024 Tesla Model 3 Performance (Highland)", hp: 510, tq: 500, z: 3.1, qm: 11.5),

        // --- TESLA: Model Y (key eras) ---
        tesla("2020 Tesla Model Y Long Range", hp: 384, tq: 376, z: 4.8, qm: 13.3),
        tesla("2020 Tesla Model Y Performance", hp: 456, tq: 497, z: 3.6, qm: 12.0),
        tesla("2024 Tesla Model Y RWD", hp: 299, tq: 310, z: 6.0, qm: 14.5),
        tesla("2024 Tesla Model Y Long Range", hp: 384, tq: 378, z: 4.8, qm: 13.0),
        tesla("2024 Tesla Model Y Performance", hp: 456, tq: 497, z: 3.5, qm: 11.9),

        // --- TESLA: Cybertruck ---
        tesla("2024 Tesla Cybertruck AWD", hp: 600, tq: 700, z: 4.1, qm: 12.5),
        tesla("2024 Tesla Cybertruck Cyberbeast", hp: 845, tq: 900, z: 2.6, qm: 11.0),

        // --- TESLA: Semi + Roadster (aspirational fun presets) ---
        tesla("Tesla Semi (fun/estimate)", hp: 1000, tq: 1500, z: 5.0, qm: 12.0),
        tesla("Tesla Roadster (next-gen, aspirational)", hp: 1100, tq: 1500, z: 1.9, qm: 8.9),

        // --- RIVIAN: R1T / R1S ---
        rivian("Rivian R1T Dual-Motor Performance", hp: 533, tq: 610, z: 4.0, qm: 12.7),
        rivian("Rivian R1T Quad-Motor", hp: 835, tq: 908, z: 3.0, qm: 11.8),
        rivian("Rivian R1S Dual-Motor Performance", hp: 533, tq: 610, z: 4.1, qm: 12.9),
        rivian("Rivian R1S Quad-Motor", hp: 835, tq: 908, z: 3.1, qm: 12.0),
    ]

    static func presets(for make: EVMake) -> [EVPreset] {
        all.filter { $0.make == make }
    }

    // ✅ Restore these for your Host code
    static var defaultTesla: EVPreset {
        presets(for: .tesla).first ?? all.first!
    }

    static var defaultRivian: EVPreset {
        presets(for: .rivian).first ?? all.first!
    }

    // Convenience: resolve by stable key
    static func preset(forKey key: String) -> EVPreset? {
        all.first { $0.key == key }
    }
}

// MARK: - Muscle Car Model

fileprivate struct MuscleCar: Identifiable {
    let id = UUID()
    let name: String
    let year: Int
    let horsepower: Int
    let torque: Int
    let zeroToSixty: Double
    let quarterMile: Double
    let emoji: String
    let funFact: String
}

fileprivate enum Winner { case ev, car, tie }

// MARK: - Muscle / Classic DB (expanded)

fileprivate enum MuscleCarDatabase {
    static let all: [MuscleCar] = [
        // 60s
        MuscleCar(name: "Pontiac GTO", year: 1964, horsepower: 325, torque: 348, zeroToSixty: 6.6, quarterMile: 14.7, emoji: "🏛️",
                  funFact: "The ‘muscle car’ argument starter. Everyone has an opinion. Nobody agrees."),
        MuscleCar(name: "Chevrolet Camaro Z/28", year: 1969, horsepower: 290, torque: 290, zeroToSixty: 6.9, quarterMile: 15.2, emoji: "🏁",
                  funFact: "More corner-carving attitude than straight-line numbers—and that’s the point."),
        MuscleCar(name: "Ford Mustang Boss 429", year: 1969, horsepower: 375, torque: 450, zeroToSixty: 5.1, quarterMile: 13.7, emoji: "👑",
                  funFact: "A homologation special that basically exists to flex on history."),

        // 70s
        MuscleCar(name: "Plymouth Hemi 'Cuda", year: 1970, horsepower: 425, torque: 490, zeroToSixty: 5.6, quarterMile: 13.4, emoji: "🦂",
                  funFact: "A mythical creature. Spotted rarely. Usually accompanied by screaming tires."),
        MuscleCar(name: "Chevrolet Chevelle SS 454", year: 1972, horsepower: 270, torque: 390, zeroToSixty: 6.0, quarterMile: 14.3, emoji: "🧀",
                  funFact: "Comes with 454 cubic inches and approximately 454% more gas smell than your EV."),
        MuscleCar(name: "Pontiac Firebird Trans Am 455 SD", year: 1973, horsepower: 290, torque: 395, zeroToSixty: 5.4, quarterMile: 13.8, emoji: "🔥",
                  funFact: "Required more decals per horsepower than any car before or since."),

        // 80s/90s icons
        MuscleCar(name: "Buick GNX", year: 1987, horsepower: 276, torque: 360, zeroToSixty: 4.7, quarterMile: 13.5, emoji: "🖤",
                  funFact: "The villain car from every 80s movie that didn’t have the budget for a Ferrari."),
        MuscleCar(name: "Ford Mustang 5.0 LX", year: 1990, horsepower: 225, torque: 300, zeroToSixty: 6.2, quarterMile: 14.7, emoji: "🦊",
                  funFact: "More burnout smoke than actual forward progress in most high school parking lots."),
        MuscleCar(name: "Pontiac Firebird Trans Am WS6", year: 2002, horsepower: 325, torque: 350, zeroToSixty: 5.2, quarterMile: 13.5, emoji: "🕶️",
                  funFact: "T-tops, screaming chicken, and a ride quality best described as ‘patriotic pogo stick.’"),

        // modern monsters
        MuscleCar(name: "Ford Mustang GT 5.0", year: 2013, horsepower: 420, torque: 390, zeroToSixty: 4.3, quarterMile: 12.7, emoji: "🐎",
                  funFact: "More horsepower than the Apollo missions, but still needs oil changes."),
        MuscleCar(name: "Dodge Challenger SRT Hellcat", year: 2015, horsepower: 707, torque: 650, zeroToSixty: 3.6, quarterMile: 11.2, emoji: "😈",
                  funFact: "0–60 in one ‘oops’ and the rest of the tank in a single pull."),
        MuscleCar(name: "Chevrolet Camaro ZL1", year: 2020, horsepower: 650, torque: 650, zeroToSixty: 3.5, quarterMile: 11.4, emoji: "🌀",
                  funFact: "Faster than your attention span when you try to explain kilowatt-hours to it."),
        MuscleCar(name: "Dodge Challenger SRT Demon", year: 2018, horsepower: 840, torque: 770, zeroToSixty: 2.3, quarterMile: 9.7, emoji: "🧯",
                  funFact: "This is less a car and more a tire-smoking press release."),
    ]

    static func random() -> MuscleCar {
        all.randomElement() ?? all[0]
    }
}

// MARK: - Showdown View

@MainActor
struct MuscleCarShowdownView: View {
    let ev: EVSpec

    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    @State private var muscleCar: MuscleCar = MuscleCarDatabase.random()
    @State private var gridPulse: Bool = false
    @State private var showTelemetry: Bool = false

    // F1 accent colors
    private var f1Red: Color { Color(red: 0.9, green: 0.05, blue: 0.15) }
    private var f1Green: Color { Color(red: 0.1, green: 0.8, blue: 0.4) }
    private var f1Yellow: Color { Color(red: 0.95, green: 0.8, blue: 0.2) }

    private var textPrimary: Color { scheme == .dark ? .white : .primary }
    private var textSecondary: Color { scheme == .dark ? Color.white.opacity(0.72) : .secondary }

    var body: some View {
        let t = themeBox.base

        ZStack {
            Rectangle()
                .fill(t.screenBackground)
                .ignoresSafeArea()

            F1TrackBackground(accent: t.accent, isDark: scheme == .dark, pulse: gridPulse)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: t.spacing + 4) {
                    headerTimingBar(theme: t)
                    verdictCard(theme: t)
                    compactStatsCard(theme: t)
                    telemetryDisclosure(theme: t)

                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            muscleCar = MuscleCarDatabase.random()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text("Next challenger on the grid")
                        }
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(f1Red)
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("* Numbers are approximate, jokes are absolutely intentional.")
                            .font(.footnote)
                            .foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Race Day Showdown")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                gridPulse.toggle()
            }
        }
    }

    // MARK: - UI

    private func headerTimingBar(theme t: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label {
                    Text("Race Day Showdown")
                        .font(.headline.bold())
                } icon: {
                    Image(systemName: "flag.checkered.2.crossed")
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(textPrimary)

                Spacer()

                polePositionChip
            }

            HStack(spacing: 8) {
                timingSegment(label: "0–60", winner: zeroToSixtyWinner)
                timingSegment(label: "¼-mile", winner: quarterMileWinner)
                timingSegment(label: "Power", winner: horsepowerWinner)
                timingSegment(label: "Torque", winner: torqueWinner)
            }
            .font(.caption2)
        }
        .padding(12)
        .background(cardBackground(theme: t, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: t.corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [f1Red, f1Yellow.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.4
                )
        )
    }

    private var polePositionChip: some View {
        let evOnPole = overallScoreDelta >= 0
        let text = evOnPole ? "EV on pole" : "Muscle car on pole"
        let icon = evOnPole ? "bolt.car.fill" : "fuelpump.fill"
        let color = evOnPole ? f1Green : f1Red

        return HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text.uppercased())
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                .shadow(radius: 4, y: 2)
                .scaleEffect(gridPulse ? 1.03 : 1.0)
        )
        .foregroundStyle(Color.black.opacity(0.9))
    }

    private func timingSegment(label: String, winner: Winner) -> some View {
        let color: Color
        let icon: String

        switch winner {
        case .ev:  color = f1Green;  icon = "checkmark.seal.fill"
        case .car: color = f1Red;    icon = "exclamationmark.triangle.fill"
        case .tie: color = f1Yellow; icon = "equal.circle.fill"
        }

        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
            Image(systemName: icon)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(scheme == .dark ? 0.10 : 0.06))
        )
        .foregroundStyle(textPrimary.opacity(0.92))
    }

    private func compactStatsCard(theme t: any AppThemeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your EV").font(.caption).foregroundStyle(textSecondary)
                    Text(ev.name).font(.subheadline.bold()).foregroundStyle(textPrimary).lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Challenger").font(.caption).foregroundStyle(textSecondary)
                    HStack(spacing: 4) {
                        Text("\(muscleCar.year) \(muscleCar.name)")
                            .font(.subheadline.bold())
                            .foregroundStyle(textPrimary)
                            .lineLimit(2)
                        Text(muscleCar.emoji).font(.subheadline)
                    }
                }
            }

            Divider().opacity(scheme == .dark ? 0.25 : 0.35)

            VStack(spacing: 6) {
                statRow(title: "Horsepower", ev: "\(ev.horsepower) hp", car: "\(muscleCar.horsepower) hp")
                statRow(title: "Torque", ev: "\(ev.torque) lb-ft", car: "\(muscleCar.torque) lb-ft")
                statRow(title: "0–60 mph",
                        ev: String(format: "%.1f s", ev.zeroToSixty),
                        car: String(format: "%.1f s", muscleCar.zeroToSixty))

                let evQM = ev.quarterMile ?? (ev.zeroToSixty * 2.0 + 4.0)
                statRow(title: "¼-mile",
                        ev: String(format: "%.1f s*", evQM),
                        car: String(format: "%.1f s", muscleCar.quarterMile))
            }
        }
        .padding(12)
        .background(cardBackground(theme: t, elevated: true))
        .overlay(cardStroke(theme: t))
    }

    private func statRow(title: String, ev: String, car: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(textSecondary)
            Spacer(minLength: 8)
            Text(ev).font(.caption).foregroundStyle(textPrimary)
            Spacer(minLength: 8)
            Text(car).font(.caption).foregroundStyle(textPrimary.opacity(0.9))
        }
    }

    private func telemetryDisclosure(theme t: any AppThemeSpec) -> some View {
        DisclosureGroup(isExpanded: $showTelemetry) {
            VStack(spacing: 8) {
                metricRow(label: "Horsepower", evValue: "\(ev.horsepower) hp", carValue: "\(muscleCar.horsepower) hp", winner: horsepowerWinner,
                          commentary: "HR = Horsepower Rating, not Human Resources. No one’s getting written up… probably.", theme: t)

                metricRow(label: "Torque", evValue: "\(ev.torque) lb-ft", carValue: "\(muscleCar.torque) lb-ft", winner: torqueWinner,
                          commentary: "Torque is launch control. Your EV does it now; the carburetor does it after coffee.", theme: t)

                metricRow(label: "0–60 mph", evValue: String(format: "%.1f s", ev.zeroToSixty), carValue: String(format: "%.1f s", muscleCar.zeroToSixty),
                          winner: zeroToSixtyWinner, commentary: "0–60 is just ‘how fast can you regret not hitting record.’", theme: t)

                let evQM = ev.quarterMile ?? (ev.zeroToSixty * 2.0 + 4.0)
                metricRow(label: "¼-mile", evValue: String(format: "%.1f s*", evQM), carValue: String(format: "%.1f s", muscleCar.quarterMile),
                          winner: quarterMileWinner, commentary: "We know you’re not drag racing at the Supercharger. You thought about it, though.", theme: t)
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Full telemetry (nerd mode)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textPrimary)
                Spacer()
                Image(systemName: showTelemetry ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(12)
        .background(cardBackground(theme: t, elevated: false))
        .overlay(cardStroke(theme: t))
        .tint(textPrimary)
    }

    private func verdictCard(theme t: any AppThemeSpec) -> some View {
        let evWins = overallScoreDelta >= 0
        let outlineColor = evWins ? f1Green : f1Red

        return VStack(alignment: .leading, spacing: 8) {
            Text(verdictTitle).font(.headline).foregroundStyle(textPrimary)
            Text(verdictBody).font(.footnote).foregroundStyle(textPrimary.opacity(0.92))
        }
        .padding(12)
        .background(cardBackground(theme: t, elevated: true))
        .overlay(cardStroke(theme: t, color: outlineColor.opacity(0.85), lineWidth: 1.4))
    }

    // MARK: - Theme card helpers

    private func cardBackground(theme t: any AppThemeSpec, elevated: Bool) -> some View {
        RoundedRectangle(cornerRadius: t.corner, style: .continuous)
            .fill(t.cardBackground)
            .shadow(
                color: Color.black.opacity(
                    scheme == .dark ? (elevated ? 0.40 : 0.18) : (elevated ? 0.12 : 0.06)
                ),
                radius: elevated ? t.elevation : max(1, t.elevation * 0.7),
                x: 0,
                y: elevated ? 4 : 2
            )
    }

    private func cardStroke(theme t: any AppThemeSpec, color: Color? = nil, lineWidth: CGFloat = 1) -> some View {
        RoundedRectangle(cornerRadius: t.corner, style: .continuous)
            .strokeBorder((color ?? t.separator).opacity(scheme == .dark ? 0.55 : 0.75), lineWidth: lineWidth)
    }

    private func metricRow(
        label: String,
        evValue: String,
        carValue: String,
        winner: Winner,
        commentary: String,
        theme t: any AppThemeSpec
    ) -> some View {
        let winnerColor: Color = {
            switch winner { case .ev: return f1Green; case .car: return f1Red; case .tie: return f1Yellow }
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(textPrimary)
                Spacer()
                Circle().fill(winnerColor).frame(width: 8, height: 8)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your EV").font(.caption2).foregroundStyle(textSecondary)
                    Text(evValue).font(.callout).foregroundStyle(textPrimary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Muscle car").font(.caption2).foregroundStyle(textSecondary)
                    Text(carValue).font(.callout).foregroundStyle(textPrimary)
                }
            }

            Text(commentary).font(.caption2).foregroundStyle(textSecondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: t.smallCorner, style: .continuous)
                .fill(Color.primary.opacity(scheme == .dark ? 0.10 : 0.06))
        )
    }

    // MARK: - Winner logic

    private func winner(ev: Double, car: Double, higherIsBetter: Bool) -> Winner {
        let epsilon = 0.05
        if abs(ev - car) < epsilon { return .tie }
        return higherIsBetter ? (ev > car ? .ev : .car) : (ev < car ? .ev : .car)
    }

    private var horsepowerWinner: Winner { winner(ev: Double(ev.horsepower), car: Double(muscleCar.horsepower), higherIsBetter: true) }
    private var torqueWinner: Winner { winner(ev: Double(ev.torque), car: Double(muscleCar.torque), higherIsBetter: true) }
    private var zeroToSixtyWinner: Winner { winner(ev: ev.zeroToSixty, car: muscleCar.zeroToSixty, higherIsBetter: false) }
    private var quarterMileWinner: Winner {
        let evQM = ev.quarterMile ?? (ev.zeroToSixty * 2.0 + 4.0)
        return winner(ev: evQM, car: muscleCar.quarterMile, higherIsBetter: false)
    }

    private var overallScoreDelta: Double {
        var score = 0.0
        if horsepowerWinner == .ev { score += 1 } else if horsepowerWinner == .car { score -= 1 }
        if torqueWinner == .ev { score += 1 } else if torqueWinner == .car { score -= 1 }
        if zeroToSixtyWinner == .ev { score += 1 } else if zeroToSixtyWinner == .car { score -= 1 }
        if quarterMileWinner == .ev { score += 1 } else if quarterMileWinner == .car { score -= 1 }
        return score
    }

    private var verdictTitle: String {
        switch overallScoreDelta {
        case let d where d > 2: return "EV takes pole and fastest lap."
        case let d where d > 0.5: return "EV wins on strategy and pace."
        case let d where d > -0.5: return "Photo finish. Call the stewards."
        case let d where d > -2: return "Muscle car goes full send."
        default: return "The dinosaur still bites hard."
        }
    }

    private var verdictBody: String {
        var lines: [String] = []
        if overallScoreDelta > 1 {
            lines.append("Your EV is out-dragging a legend while streaming podcasts and keeping the cabin at 72°F.")
        } else if overallScoreDelta > 0 {
            lines.append("The EV edges ahead. The muscle car sounds angrier, but mostly because it saw a fast charger and got jealous.")
        } else if overallScoreDelta > -1 {
            lines.append("Statistically close! In traffic your EV wins, at car meets the muscle car wins, and your neighbors lose either way.")
        } else {
            lines.append("Today the fossil has the pace. It also drinks like it’s trying to personally keep OPEC in business.")
        }
        lines.append("Pit strategy: EV stops fewer times, buys fewer snacks, and still somehow leaves with more smugness.")
        return lines.joined(separator: " ")
    }
}

// MARK: - Track background (self-contained)

fileprivate struct F1TrackBackground: View {
    let accent: Color
    let isDark: Bool
    let pulse: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RadialGradient(
                    colors: [accent.opacity(isDark ? 0.22 : 0.12), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(w, h) * 0.65
                )
                .blur(radius: isDark ? 26 : 20)

                LinearGradient(
                    colors: [
                        Color.black.opacity(isDark ? 0.16 : 0.06),
                        Color.black.opacity(isDark ? 0.30 : 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Canvas { ctx, size in
                    let grid = 22.0
                    var p = Path()

                    for x in stride(from: 0.0, through: size.width, by: grid) {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0.0, through: size.height, by: grid) {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }

                    ctx.stroke(
                        p,
                        with: .color(Color.white.opacity(isDark ? (pulse ? 0.06 : 0.045) : 0.03)),
                        lineWidth: 1
                    )
                }
                .blendMode(.overlay)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isDark ? 0.06 : 0.03))
                    .frame(width: max(w, h) * 0.95, height: 14)
                    .rotationEffect(.degrees(-18))
                    .offset(y: h * 0.12)

                Capsule(style: .continuous)
                    .fill(accent.opacity(isDark ? 0.10 : 0.06))
                    .frame(width: max(w, h) * 0.78, height: 10)
                    .rotationEffect(.degrees(-18))
                    .offset(y: h * 0.12)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MuscleCarShowdownView(ev: EVPresetDatabase.defaultTesla.spec)
    }
    .preferredColorScheme(.dark)
    .appTheme(DefaultAppTheme())
}
#endif
