//
//  TripLoggerView.swift
//  My KWh Companion
//
//  Daily trip logging with iPhone/iPad layouts, autosave, and filterable history.
//  Swift 6 / iOS 17+
//
//  Models expected elsewhere:
//    - TripLogEntry (Identifiable, Codable, Hashable) with:
//        var id: UUID
//        var date: Date
//        var currentDrive: CurrentDriveData
//        var sinceLastCharge: SinceLastChargeData
//        var tripA: TripSegmentData
//        var tripB: TripSegmentData
//    - CurrentDriveData { distance: Double, durationMinutes: Double, avgWhPerMile: Double }
//    - SinceLastChargeData { distance: Double, totalEnergyKWh: Double, avgWhPerMile: Double }
//    - TripSegmentData { distance: Double, totalEnergyKWh: Double, avgWhPerMile: Double }
//

import SwiftUI

@MainActor
public struct TripLoggerView: View {
    // Persist all logs
    @AppStorage("tripLogs") private var tripLogsData: Data = Data()

    // Working state
    @State private var tripLogs: [TripLogEntry] = []
    @State private var currentEntry = TripLogEntry()
    @State private var selectedDate: Date? = nil
    @State private var showInfo = false

    @Environment(\.horizontalSizeClass) private var hSize

    // iPad grid
    private let columns = [GridItem(.flexible(minimum: 240)), GridItem(.flexible(minimum: 240))]

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if hSize == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .navigationTitle("Trip Logger")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if selectedDate != nil {
                        Button {
                            selectedDate = nil
                        } label: {
                            Label("Clear Date Filter", systemImage: "xmark.circle")
                        }
                        .accessibilityLabel("Clear date filter")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        quickAddNow()
                    } label: {
                        Label("Add Now", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add entry for now")
                }
            }
            .onAppear(perform: loadTripLogs)
            .onChange(of: tripLogs) { _, _ in saveTripLogs() }
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        Form {
            energyInfoSection

            Section(header: Text("Current Drive")) {
                TripNumberField(label: "Distance (mi)", value: $currentEntry.currentDrive.distance)
                TripNumberField(label: "Duration (min)", value: $currentEntry.currentDrive.durationMinutes)
                TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.currentDrive.avgWhPerMile)
            }

            Section(header: Text("Since Last Charge")) {
                TripNumberField(label: "Distance (mi)", value: $currentEntry.sinceLastCharge.distance)
                TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.sinceLastCharge.totalEnergyKWh)
                TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.sinceLastCharge.avgWhPerMile)
            }

            Section(header: Text("Trip A")) {
                TripNumberField(label: "Distance (mi)", value: $currentEntry.tripA.distance)
                TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.tripA.totalEnergyKWh)
                TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.tripA.avgWhPerMile)
            }

            Section(header: Text("Trip B")) {
                TripNumberField(label: "Distance (mi)", value: $currentEntry.tripB.distance)
                TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.tripB.totalEnergyKWh)
                TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.tripB.avgWhPerMile)
            }

            saveButton

            historyHeader
            historyList
        }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                energyInfoSection
                    .padding(.horizontal)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    inputCard(title: "Current Drive") {
                        TripNumberField(label: "Distance (mi)", value: $currentEntry.currentDrive.distance)
                        TripNumberField(label: "Duration (min)", value: $currentEntry.currentDrive.durationMinutes)
                        TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.currentDrive.avgWhPerMile)
                    }
                    inputCard(title: "Since Last Charge") {
                        TripNumberField(label: "Distance (mi)", value: $currentEntry.sinceLastCharge.distance)
                        TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.sinceLastCharge.totalEnergyKWh)
                        TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.sinceLastCharge.avgWhPerMile)
                    }
                    inputCard(title: "Trip A") {
                        TripNumberField(label: "Distance (mi)", value: $currentEntry.tripA.distance)
                        TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.tripA.totalEnergyKWh)
                        TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.tripA.avgWhPerMile)
                    }
                    inputCard(title: "Trip B") {
                        TripNumberField(label: "Distance (mi)", value: $currentEntry.tripB.distance)
                        TripNumberField(label: "Total Energy (kWh)", value: $currentEntry.tripB.totalEnergyKWh)
                        TripNumberField(label: "Avg. Wh/mi", value: $currentEntry.tripB.avgWhPerMile)
                    }
                }
                .padding(.horizontal)

                saveButton
                    .padding(.horizontal)

                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    historyHeader
                    historyList
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Shared Sections

    private var energyInfoSection: some View {
        Section {
            DisclosureGroup("Why Do Energy Numbers Matter?", isExpanded: $showInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• **Total Energy (kWh):** How much electricity was consumed — useful for planning charge sessions.")
                    Text("• **Average Energy (Wh/mi):** Indicates driving efficiency. Lower is better for range and cost.")
                    Text("Regular tracking helps optimize habits, reduce charging frequency, and predict range more accurately.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Energy information")
    }

    private var saveButton: some View {
        Button {
            saveNewEntry()
        } label: {
            Label("Save Trip Entry", systemImage: "tray.and.arrow.down")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.borderedProminent)
        .padding(.vertical, 6)
        .accessibilityLabel("Save trip entry")
    }

    private var historyHeader: some View {
        Section(header: Text("History")) {
            DatePicker(
                "Filter by Date",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .accessibilityLabel("Filter by date")

            if let day = selectedDate {
                // Show daily totals when a filter is active
                let totals = totalsFor(day: day)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily totals")
                        .font(.headline)
                    Text("Distance: \(totals.distance, specifier: "%.1f") mi")
                    Text("Energy: \(totals.energyKWh, specifier: "%.2f") kWh")
                    Text("Avg: \(totals.avgWhPerMile, specifier: "%.0f") Wh/mi")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if selectedDate != nil {
                Button {
                    selectedDate = nil
                } label: {
                    Label("Clear Date Filter", systemImage: "xmark.circle")
                }
                .font(.caption)
            }
        }
    }

    private var historyList: some View {
        let filtered = filteredLogs()
        return Group {
            if filtered.isEmpty {
                Text("No entries for this date")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.headline)
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Compact rollup per section (distance/energy/avg)
                        summaryRow(title: "Current",
                                   distance: entry.currentDrive.distance,
                                   energy: nil,
                                   avg: entry.currentDrive.avgWhPerMile)

                        summaryRow(title: "Since Last",
                                   distance: entry.sinceLastCharge.distance,
                                   energy: entry.sinceLastCharge.totalEnergyKWh,
                                   avg: entry.sinceLastCharge.avgWhPerMile)

                        summaryRow(title: "Trip A",
                                   distance: entry.tripA.distance,
                                   energy: entry.tripA.totalEnergyKWh,
                                   avg: entry.tripA.avgWhPerMile)

                        summaryRow(title: "Trip B",
                                   distance: entry.tripB.distance,
                                   energy: entry.tripB.totalEnergyKWh,
                                   avg: entry.tripB.avgWhPerMile)
                    }
                    .padding(.vertical, 6)
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(historyAX(for: entry))
                }
            }
        }
    }

    // MARK: - Rows & Cards

    private func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func summaryRow(title: String, distance: Double, energy: Double?, avg: Double) -> some View {
        HStack {
            Text(title)
                .frame(width: 90, alignment: .leading)
            Spacer(minLength: 8)
            Text("\(distance, specifier: "%.1f") mi")
                .monospacedDigit()
            if let kwh = energy {
                Text("• \(kwh, specifier: "%.2f") kWh")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text("• \(avg, specifier: "%.0f") Wh/mi")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    // MARK: - Data Ops

    private func filteredLogs() -> [TripLogEntry] {
        let sorted = tripLogs.sorted { $0.date > $1.date }
        guard let day = selectedDate else { return sorted }
        return sorted.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private func totalsFor(day: Date) -> (distance: Double, energyKWh: Double, avgWhPerMile: Double) {
        let dayLogs = tripLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        // Use “Since Last Charge” as a daily proxy
        let totalDist = dayLogs.reduce(0.0) { $0 + $1.sinceLastCharge.distance }
        let totalEnergy = dayLogs.reduce(0.0) { $0 + $1.sinceLastCharge.totalEnergyKWh }
        let avg = totalDist > 0 ? (totalEnergy * 1000.0 / totalDist) : 0.0 // Wh/mi
        return (totalDist, totalEnergy, avg)
    }

    private func saveNewEntry() {
        sanitize(&currentEntry)
        currentEntry.date = Date()
        tripLogs.insert(currentEntry, at: 0)
        currentEntry = TripLogEntry()
    }

    private func deleteEntry(_ entry: TripLogEntry) {
        if let idx = tripLogs.firstIndex(where: { $0.id == entry.id }) {
            tripLogs.remove(at: idx)
        }
    }

    private func saveTripLogs() {
        do {
            let data = try JSONEncoder().encode(tripLogs)
            tripLogsData = data
        } catch {
            #if DEBUG
            print("Failed to encode trip logs: \(error)")
            #endif
        }
    }

    private func loadTripLogs() {
        guard !tripLogsData.isEmpty else { return }
        do {
            let logs = try JSONDecoder().decode([TripLogEntry].self, from: tripLogsData)
            tripLogs = logs
        } catch {
            #if DEBUG
            print("Failed to decode trip logs: \(error)")
            #endif
            tripLogs = []
        }
    }

    // MARK: - Quick Add

    private func quickAddNow() {
        var entry = TripLogEntry()
        entry.date = Date()
        tripLogs.insert(entry, at: 0)
    }

    // MARK: - Sanitization

    private func sanitize(_ entry: inout TripLogEntry) {
        // Ensure no negatives sneak in
        func clamp(_ v: Double) -> Double { max(0, v) }
        entry.currentDrive.distance = clamp(entry.currentDrive.distance)
        entry.currentDrive.durationMinutes = clamp(entry.currentDrive.durationMinutes)
        entry.currentDrive.avgWhPerMile = clamp(entry.currentDrive.avgWhPerMile)
        entry.sinceLastCharge.distance = clamp(entry.sinceLastCharge.distance)
        entry.sinceLastCharge.totalEnergyKWh = clamp(entry.sinceLastCharge.totalEnergyKWh)
        entry.sinceLastCharge.avgWhPerMile = clamp(entry.sinceLastCharge.avgWhPerMile)
        entry.tripA.distance = clamp(entry.tripA.distance)
        entry.tripA.totalEnergyKWh = clamp(entry.tripA.totalEnergyKWh)
        entry.tripA.avgWhPerMile = clamp(entry.tripA.avgWhPerMile)
        entry.tripB.distance = clamp(entry.tripB.distance)
        entry.tripB.totalEnergyKWh = clamp(entry.tripB.totalEnergyKWh)
        entry.tripB.avgWhPerMile = clamp(entry.tripB.avgWhPerMile)
    }

    // MARK: - Accessibility

    private func historyAX(for entry: TripLogEntry) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let when = df.string(from: entry.date)

        func seg(_ title: String, d: Double, kwh: Double?, whpm: Double) -> String {
            let dPart = "\(String(format: "%.1f", d)) miles"
            let ePart = kwh != nil ? ", \(String(format: "%.2f", kwh!)) kilowatt hours" : ""
            let aPart = ", \(Int(round(whpm))) watt hours per mile"
            return "\(title): \(dPart)\(ePart)\(aPart)"
        }

        let s0 = seg("Current", d: entry.currentDrive.distance, kwh: nil, whpm: entry.currentDrive.avgWhPerMile)
        let s1 = seg("Since last charge", d: entry.sinceLastCharge.distance, kwh: entry.sinceLastCharge.totalEnergyKWh, whpm: entry.sinceLastCharge.avgWhPerMile)
        let s2 = seg("Trip A", d: entry.tripA.distance, kwh: entry.tripA.totalEnergyKWh, whpm: entry.tripA.avgWhPerMile)
        let s3 = seg("Trip B", d: entry.tripB.distance, kwh: entry.tripB.totalEnergyKWh, whpm: entry.tripB.avgWhPerMile)

        return "Trip on \(when). \(s0). \(s1). \(s2). \(s3)."
    }
}

// MARK: - Local numeric field (unique name to avoid collisions)

fileprivate struct TripNumberField: View {
    let label: String
    @Binding var value: Double

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, newValue in apply(newValue) }
                .onAppear { text = formatted(value) }
                .onSubmit { apply(text) }
                .textInputAutocapitalization(.never)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "0" : text)
    }

    private func apply(_ input: String) {
        // Accept both "." and "," as decimal separators
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized) {
            value = v
        }
    }

    private func formatted(_ v: Double) -> String {
        if v == 0 { return "" }
        return String(format: "%.3f", v).trimmedTrailingZeros()
    }
}

fileprivate extension String {
    func trimmedTrailingZeros() -> String {
        var s = self
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            if s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast(); break }
        }
        return s
    }
}

#if DEBUG
#Preview {
    TripLoggerView()
}
#endif
