//
//  DateRangeSheet.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/23/25.
//


// DateRangeSheet.swift
// MyKwH Companion – 2025-07-23
// Reusable date-range picker sheet with preset & custom modes.

import SwiftUI

/// Bind a `ClosedRange<Date>?` (nil = All Time). Presents presets or custom start/end pickers.
struct DateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dateRange: ClosedRange<Date>?

    @State private var mode: Mode = .preset
    @State private var preset: Preset = .last30
    @State private var start: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var end: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("", selection: $mode) {
                        Text("Preset").tag(Mode.preset)
                        Text("Custom").tag(Mode.custom)
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .preset {
                    Section("Preset Range") {
                        Picker("Preset", selection: $preset) {
                            ForEach(Preset.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                    }
                } else {
                    Section("Custom Range") {
                        DatePicker("Start", selection: $start, displayedComponents: .date)
                        DatePicker("End", selection: $end, in: start...Date(), displayedComponents: .date)
                    }
                }

                if dateRange != nil {
                    Section {
                        Button("Clear Range", role: .destructive) { dateRange = nil }
                    }
                }
            }
            .navigationTitle("Select Range")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        switch mode {
                        case .preset:
                            dateRange = preset.range()
                        case .custom:
                            dateRange = start...end
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Types --------------------------------------------------------
    private enum Mode { case preset, custom }

    private enum Preset: CaseIterable {
        case last7, last30, last90, thisMonth, prevMonth, ytd, allTime

        var label: String {
            switch self {
            case .last7:      return "Last 7 Days"
            case .last30:     return "Last 30 Days"
            case .last90:     return "Last 90 Days"
            case .thisMonth:  return "This Month"
            case .prevMonth:  return "Previous Month"
            case .ytd:        return "Year to Date"
            case .allTime:    return "All Time"
            }
        }

        func range(ref: Date = Date()) -> ClosedRange<Date>? {
            let cal = Calendar.current
            switch self {
            case .last7:
                let s = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: ref))!
                return s...ref
            case .last30:
                let s = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: ref))!
                return s...ref
            case .last90:
                let s = cal.date(byAdding: .day, value: -89, to: cal.startOfDay(for: ref))!
                return s...ref
            case .thisMonth:
                let comps = cal.dateComponents([.year, .month], from: ref)
                let s = cal.date(from: comps)!
                return s...ref
            case .prevMonth:
                let comps = cal.dateComponents([.year, .month], from: ref)
                let prev = cal.date(from: DateComponents(year: comps.year, month: (comps.month ?? 1) - 1))!
                let startPrev = cal.date(from: cal.dateComponents([.year, .month], from: prev))!
                let endPrev = cal.date(byAdding: DateComponents(month: 1, day: -1), to: startPrev) ?? prev
                return startPrev...endPrev
            case .ytd:
                let y = cal.component(.year, from: ref)
                let s = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
                return s...ref
            case .allTime:
                return nil
            }
        }
    }
}

// MARK: - Preview ----------------------------------------------------------
#if DEBUG
struct DateRangeSheet_Previews: PreviewProvider {
    struct Host: View {
        @State var range: ClosedRange<Date>? = nil
        var body: some View {
            DateRangeSheet(dateRange: $range)
        }
    }
    static var previews: some View { Host() }
}
#endif
