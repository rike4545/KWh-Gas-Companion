import SwiftUI

struct StationQualityEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var provider: String
    var rating: Int
    var uptimePercent: Double
    var stalls: Int
    var notes: String
    var date: Date
}

@MainActor
final class StationQualityStore: LocalJSONStore<StationQualityEntry> {
    init() {
        super.init(filename: "station_quality.json")
    }
}

@MainActor
struct StationQualityScoreView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var store = StationQualityStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var showingAdd = false

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No station ratings yet",
                        systemImage: "bolt.circle",
                        description: Text("Add a rating after a charging session.")
                    )
                    .padding(.top, 8)
                } else {
                    ForEach(sortedEntries) { entry in
                        stationRow(entry)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Station Quality")
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
            StationQualityEditorView { newEntry in
                store.items.insert(newEntry, at: 0)
            }
        }
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crowd‑rated station quality")
                .font(.headline)
            Text("Score combines your rating and estimated uptime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var sortedEntries: [StationQualityEntry] {
        store.items.sorted { $0.date > $1.date }
    }

    private func stationRow(_ entry: StationQualityEntry) -> some View {
        let score = qualityScore(entry)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.headline)
                    if !entry.provider.isEmpty {
                        Text(entry.provider)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(score)")
                    .font(.title3.weight(.bold))
            }

            HStack(spacing: 12) {
                Label("Rating \(entry.rating)/5", systemImage: "star.fill")
                    .font(.caption)
                Label("Uptime \(String(format: "%.0f", entry.uptimePercent))%", systemImage: "wifi")
                    .font(.caption)
                Label("\(entry.stalls) stalls", systemImage: "bolt.car")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private func qualityScore(_ entry: StationQualityEntry) -> Int {
        let ratingScore = Double(entry.rating) / 5.0
        let uptimeScore = min(max(entry.uptimePercent / 100.0, 0), 1)
        let combined = (ratingScore * 0.65 + uptimeScore * 0.35) * 100
        return Int(combined.rounded())
    }
}

struct StationQualityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var provider: String = ""
    @State private var rating: Int = 4
    @State private var uptimePercent: Double = 95
    @State private var stalls: Int = 12
    @State private var notes: String = ""

    let onSave: (StationQualityEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    TextField("Name", text: $name)
                    TextField("Provider", text: $provider)
                }

                Section("Quality") {
                    Stepper("Rating: \(rating)/5", value: $rating, in: 1...5)
                    HStack {
                        Text("Uptime %")
                        Spacer()
                        TextField("0", value: $uptimePercent, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Stepper("Stalls: \(stalls)", value: $stalls, in: 1...200)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Rating")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let entry = StationQualityEntry(
                            id: UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
                            rating: rating,
                            uptimePercent: uptimePercent,
                            stalls: stalls,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: Date()
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
