import SwiftUI

struct ChargeSpeedSession: Identifiable, Codable, Hashable {
    let id: UUID
    var location: String
    var socStart: Double
    var socEnd: Double
    var avgKW: Double
    var peakKW: Double
    var outsideTempF: Double
    var date: Date
}

@MainActor
final class ChargeSpeedStore: LocalJSONStore<ChargeSpeedSession> {
    init() {
        super.init(filename: "charge_speed.json")
    }
}

@MainActor
struct ChargeSpeedProfilerView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var store = ChargeSpeedStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var showingAdd = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                bucketsCard

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "bolt.badge.clock",
                        description: Text("Add a session to see your charge‑speed profile.")
                    )
                } else {
                    ForEach(store.items.sorted { $0.date > $1.date }) { session in
                        sessionRow(session)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Charge Speed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ChargeSpeedSessionEditor { newSession in
                store.items.insert(newSession, at: 0)
            }
        }
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How fast you charge by SOC")
                .font(.headline)
            Text("Track average and peak kW vs state of charge.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var bucketsCard: some View {
        let buckets = bucketSummary
        return VStack(alignment: .leading, spacing: 10) {
            Text("SOC buckets")
                .font(.headline)

            ForEach(buckets, id: \.label) { b in
                HStack {
                    Text(b.label)
                    Spacer()
                    Text(b.value)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .themedCard()
    }

    private func sessionRow(_ s: ChargeSpeedSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.location.isEmpty ? "Charging session" : s.location)
                    .font(.headline)
                Spacer()
                Text("\(Int(s.socStart))–\(Int(s.socEnd))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(s.avgKW, specifier: "%.0f") kW avg", systemImage: "bolt.fill")
                Label("\(s.peakKW, specifier: "%.0f") kW peak", systemImage: "speedometer")
                Label("\(s.outsideTempF, specifier: "%.0f")°F", systemImage: "thermometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(s.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var bucketSummary: [(label: String, value: String)] {
        let buckets: [(label: String, range: Range<Double>)] = [
            ("0–20%", 0..<20),
            ("20–40%", 20..<40),
            ("40–60%", 40..<60),
            ("60–80%", 60..<80),
            ("80–100%", 80..<101)
        ]

        return buckets.map { bucket in
            let matching = store.items.filter { bucket.range.contains($0.socStart) }
            guard !matching.isEmpty else {
                return (bucket.label, "—")
            }
            let avg = matching.map(\.avgKW).reduce(0, +) / Double(matching.count)
            return (bucket.label, String(format: "%.0f kW", avg))
        }
    }
}

struct ChargeSpeedSessionEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var location: String = ""
    @State private var socStart: Double = 10
    @State private var socEnd: Double = 70
    @State private var avgKW: Double = 120
    @State private var peakKW: Double = 200
    @State private var tempF: Double = 65

    let onSave: (ChargeSpeedSession) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Location", text: $location)
                    HStack {
                        Text("SOC start %")
                        Spacer()
                        TextField("0", value: $socStart, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("SOC end %")
                        Spacer()
                        TextField("0", value: $socEnd, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Speed") {
                    HStack {
                        Text("Avg kW")
                        Spacer()
                        TextField("0", value: $avgKW, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Peak kW")
                        Spacer()
                        TextField("0", value: $peakKW, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Outside temp °F")
                        Spacer()
                        TextField("0", value: $tempF, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let session = ChargeSpeedSession(
                            id: UUID(),
                            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                            socStart: socStart,
                            socEnd: socEnd,
                            avgKW: avgKW,
                            peakKW: peakKW,
                            outsideTempF: tempF,
                            date: Date()
                        )
                        onSave(session)
                        dismiss()
                    }
                }
            }
        }
    }
}
