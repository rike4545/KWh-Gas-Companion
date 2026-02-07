import SwiftUI

@MainActor
struct PriceWatchlistView: View {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @StateObject private var store = PriceWatchlistStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var showingAdd = false
    @State private var editingItem: PriceWatchlistItem?

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No watchlist items yet",
                        systemImage: "tag",
                        description: Text("Add favorite chargers to track manual price updates.")
                    )
                    .padding(.top, 20)
                } else {
                    ForEach(store.items) { item in
                        watchlistRow(item)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Price Watchlist")
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
            PriceWatchlistEditorView { newItem in
                store.add(newItem)
            }
        }
        .sheet(item: $editingItem) { item in
            PriceWatchlistEditorView(existing: item) { updated in
                store.update(updated)
            }
        }
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track live pricing manually")
                .font(.headline)
            Text("Add your favorite chargers and update prices when you see them in the field. We’ll show deltas and trends.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private func watchlistRow(_ item: PriceWatchlistItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    if let provider = item.provider, !provider.isEmpty {
                        Text(provider)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let price = item.lastPricePerKWh {
                    Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if let prev = item.previousPricePerKWh, let current = item.lastPricePerKWh {
                    let delta = current - prev
                    Text(delta >= 0 ? "▲ " : "▼ ")
                        .foregroundStyle(delta >= 0 ? .red : .green)
                    Text(delta, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .foregroundStyle(delta >= 0 ? .red : .green)
                } else {
                    Text("No previous price")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let date = item.lastUpdated {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    editingItem = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    store.remove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .themedCard()
    }
}

struct PriceWatchlistEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var provider: String
    @State private var priceText: String
    @State private var note: String

    private let existing: PriceWatchlistItem?
    let onSave: (PriceWatchlistItem) -> Void

    init(existing: PriceWatchlistItem? = nil, onSave: @escaping (PriceWatchlistItem) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _provider = State(initialValue: existing?.provider ?? "")
        _priceText = State(initialValue: existing?.lastPricePerKWh.map { String(format: "%.2f", $0) } ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Charger") {
                    TextField("Name", text: $name)
                    TextField("Provider (optional)", text: $provider)
                }
                Section("Latest Price") {
                    TextField("$/kWh", text: $priceText)
                        .keyboardType(.decimalPad)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $note)
                }
            }
            .navigationTitle(existing == nil ? "Add Charger" : "Edit Charger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let price = Double(priceText.replacingOccurrences(of: ",", with: "."))
                        var item = existing ?? PriceWatchlistItem(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            provider: provider.trimmedNonEmpty,
                            lastPricePerKWh: price,
                            previousPricePerKWh: existing?.previousPricePerKWh,
                            lastUpdated: price == nil ? existing?.lastUpdated : Date(),
                            note: note.trimmedNonEmpty
                        )
                        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.provider = provider.trimmedNonEmpty
                        if let price {
                            item.previousPricePerKWh = existing?.lastPricePerKWh
                            item.lastPricePerKWh = price
                            item.lastUpdated = Date()
                        }
                        item.note = note.trimmedNonEmpty
                        onSave(item)
                        dismiss()
                    }
                    .disabled(name.trimmedNonEmpty == nil)
                }
            }
        }
    }
}
