import Foundation
import SwiftUI

struct PriceWatchlistItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var provider: String?
    var lastPricePerKWh: Double?
    var previousPricePerKWh: Double?
    var lastUpdated: Date?
    var note: String?
}

@MainActor
final class PriceWatchlistStore: ObservableObject {
    private enum Keys {
        static let items = "priceWatchlist.items"
    }

    @Published var items: [PriceWatchlistItem] = [] {
        didSet { persist() }
    }

    init() {
        load()
    }

    func add(_ item: PriceWatchlistItem) {
        items.insert(item, at: 0)
    }

    func update(_ item: PriceWatchlistItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        }
    }

    func remove(_ item: PriceWatchlistItem) {
        items.removeAll { $0.id == item.id }
    }

    func markPrice(for id: UUID, price: Double) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[idx]
        item.previousPricePerKWh = item.lastPricePerKWh
        item.lastPricePerKWh = price
        item.lastUpdated = Date()
        items[idx] = item
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.items),
              let decoded = try? JSONDecoder().decode([PriceWatchlistItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persist() {
        let data = try? JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: Keys.items)
    }
}
