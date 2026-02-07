//
//  MuscleCarShowdownHost.swift
//  My KWh Companion
//
//  Swift 6 • iOS 17+
//
//  Fixes:
//  - EVPreset.id may be UUID or String → we store selection as AnyHashable
//  - Picker SelectionValue inference issues (tag types now match selection binding)
//

import SwiftUI

@MainActor
struct MuscleCarShowdownHost: View {

    @State private var make: EVMake = .tesla

    /// Holds either UUID or String safely for Picker selection.
    @State private var presetToken: AnyHashable = AnyHashable(EVPresetDatabase.defaultTesla.id)

    @State private var custom = EVSpec(
        name: "Custom EV",
        horsepower: 500,
        torque: 500,
        zeroToSixty: 3.5,
        quarterMile: 11.8
    )

    private var presets: [EVPreset] {
        EVPresetDatabase.presets(for: make)
    }

    private var selectedPreset: EVPreset {
        if let match = presets.first(where: { AnyHashable($0.id) == presetToken }) {
            return match
        }
        // fallback if token doesn't exist in current make (e.g., make changed)
        if let first = presets.first { return first }
        return EVPresetDatabase.defaultTesla
    }

    private var chosenSpec: EVSpec {
        make == .custom ? custom : selectedPreset.spec
    }

    var body: some View {
        Form {
            Section("Select EV") {

                Picker("Make", selection: $make) {
                    ForEach(EVMake.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .onChange(of: make) { _, newMake in
                    // When make switches, reset token to a valid preset for that make.
                    let list = EVPresetDatabase.presets(for: newMake)

                    if let first = list.first {
                        presetToken = AnyHashable(first.id)
                    } else {
                        // If no presets (shouldn't happen), keep something stable.
                        presetToken = AnyHashable(EVPresetDatabase.defaultTesla.id)
                    }
                }

                if make != .custom {
                    Picker("Preset", selection: $presetToken) {
                        ForEach(presets) { p in
                            Text(p.displayName).tag(AnyHashable(p.id))
                        }
                    }
                } else {
                    TextField("Name", text: $custom.name)

                    Stepper(
                        "Horsepower: \(custom.horsepower) hp",
                        value: $custom.horsepower,
                        in: 150...1500,
                        step: 10
                    )

                    Stepper(
                        "Torque: \(custom.torque) lb-ft",
                        value: $custom.torque,
                        in: 150...1500,
                        step: 10
                    )

                    HStack {
                        Text("0–60 (s)")
                        Spacer()
                        TextField(
                            "3.5",
                            value: $custom.zeroToSixty,
                            format: .number.precision(.fractionLength(1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("¼-mile (s)")
                        Spacer()
                        TextField(
                            "11.8",
                            value: Binding<Double>(
                                get: { custom.quarterMile ?? 0 },
                                set: { custom.quarterMile = $0 > 0 ? $0 : nil }
                            ),
                            format: .number.precision(.fractionLength(1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    }

                    Text("Tip: set ¼-mile to 0 to leave it blank.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink {
                    MuscleCarShowdownView(ev: chosenSpec)
                } label: {
                    Label("Start Showdown", systemImage: "flag.checkered.2.crossed")
                }
            }
        }
        .navigationTitle("Showdown Setup")
    }
}
