import SwiftUI

enum DashboardCardKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case greeting
    case actionCenter
    case insights
    case savingsScore
    case weeklyForecast
    case weeklyHealth
    case schedulePlanner
    case priceWatchlist
    case spendingBreakdown
    case budget
    case dataSources
    case recentActivity

    var id: String { rawValue }

    static var defaultOrder: [DashboardCardKind] {
        [
            .greeting,
            .actionCenter,
            .insights,
            .savingsScore,
            .weeklyForecast,
            .weeklyHealth,
            .schedulePlanner,
            .priceWatchlist,
            .spendingBreakdown,
            .budget,
            .dataSources,
            .recentActivity
        ]
    }
}

@MainActor
final class DashboardLayoutStore: ObservableObject {
    private enum Keys {
        static let order = "dashboard.layout.order"
        static let hidden = "dashboard.layout.hidden"
        static let collapsed = "dashboard.layout.collapsed"
    }

    private static let defaultHidden: Set<DashboardCardKind> = [
        .weeklyForecast,
        .weeklyHealth,
        .schedulePlanner,
        .priceWatchlist,
        .dataSources,
        .savingsScore
    ]

    @Published var order: [DashboardCardKind] {
        didSet { persistOrder() }
    }

    @Published var hidden: Set<DashboardCardKind> {
        didSet { persistHidden() }
    }

    @Published var collapsed: Set<DashboardCardKind> {
        didSet { persistCollapsed() }
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.order),
           let decoded = try? JSONDecoder().decode([DashboardCardKind].self, from: data),
           !decoded.isEmpty {
            self.order = decoded
        } else {
            self.order = DashboardCardKind.defaultOrder
        }

        if let data = defaults.data(forKey: Keys.hidden),
           let decoded = try? JSONDecoder().decode(Set<DashboardCardKind>.self, from: data) {
            self.hidden = decoded
        } else {
            self.hidden = Self.defaultHidden
        }

        if let data = defaults.data(forKey: Keys.collapsed),
           let decoded = try? JSONDecoder().decode(Set<DashboardCardKind>.self, from: data) {
            self.collapsed = decoded
        } else {
            self.collapsed = []
        }
    }

    var visibleOrder: [DashboardCardKind] {
        order.filter { !hidden.contains($0) }
    }

    func toggleHidden(_ kind: DashboardCardKind) {
        if hidden.contains(kind) {
            hidden.remove(kind)
        } else {
            hidden.insert(kind)
        }
    }

    func toggleCollapsed(_ kind: DashboardCardKind) {
        if collapsed.contains(kind) {
            collapsed.remove(kind)
        } else {
            collapsed.insert(kind)
        }
    }

    func isCollapsed(_ kind: DashboardCardKind) -> Bool {
        collapsed.contains(kind)
    }

    private func persistOrder() {
        let data = try? JSONEncoder().encode(order)
        UserDefaults.standard.set(data, forKey: Keys.order)
    }

    private func persistHidden() {
        let data = try? JSONEncoder().encode(hidden)
        UserDefaults.standard.set(data, forKey: Keys.hidden)
    }

    private func persistCollapsed() {
        let data = try? JSONEncoder().encode(collapsed)
        UserDefaults.standard.set(data, forKey: Keys.collapsed)
    }
}
