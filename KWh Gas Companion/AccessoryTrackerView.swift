//  AccessoryTrackerView.swift — Regenerated v2
//  My EV Companion
//
//  A clean, compile-ready tracker for EV accessories and ownership add-ons.
//  Depends on AccessoryItem.swift for `AccessoryItem`, `AccessoryStore`, and `AccessoryForm`.
//  iOS 17+ / Swift 6

import SwiftUI
import UIKit

@MainActor
public struct AccessoryTrackerView: View {
    // Inject or create a store
    @StateObject private var store: AccessoryStore

    // UI State
    @State private var showAdd = false
    @State private var editItem: AccessoryItem? = nil
    @State private var query: String = ""
    @State private var sort: Sort = .dateDesc

    public enum Sort: String, CaseIterable, Identifiable { case dateDesc, dateAsc, priceDesc, priceAsc, nameAsc
        public var id: String { rawValue }
        var title: String { switch self { case .dateDesc: return "Newest"; case .dateAsc: return "Oldest"; case .priceDesc: return "Price ↓"; case .priceAsc: return "Price ↑"; case .nameAsc: return "Name A→Z" } }
    }

    // MARK: - Init
    public init(store: AccessoryStore = AccessoryStore()) {
        _store = StateObject(wrappedValue: store)
    }

    // MARK: - Body
    public var body: some View {
        NavigationStack {
            List {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    Section(footer: totalFooter) {
                        ForEach(filteredItems) { item in
                            Button { editItem = item } label: { row(for: item) }
                        }
                        .onDelete(perform: store.remove)
                    }
                }

                upcomingSection
            }
            .navigationTitle("Accessory Tracker")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text("Search accessories"))
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAdd) { addSheet }
            .sheet(item: $editItem) { item in EditAccessorySheet(item: item) { updated in
                if let idx = store.items.firstIndex(where: { $0.id == item.id }) { store.items[idx] = updated }
            } }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "bag").font(.largeTitle)
            Text("No accessories yet").font(.headline)
            Text("Track chargers, mats, adapters and more. Add the first one to get started.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                showAdd = true
            } label: {
                Label("Add Accessory", systemImage: "plus").padding(.horizontal, 14).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    // MARK: - Computed
    private var filteredItems: [AccessoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = store.items.filter { item in
            guard !q.isEmpty else { return true }
            return item.name.lowercased().contains(q)
                || item.category.rawValue.lowercased().contains(q)
                || (item.notes?.lowercased().contains(q) ?? false)
        }
        switch sort {
        case .dateDesc: items.sort { $0.purchaseDate > $1.purchaseDate }
        case .dateAsc:  items.sort { $0.purchaseDate < $1.purchaseDate }
        case .priceDesc: items.sort { $0.price > $1.price }
        case .priceAsc: items.sort { $0.price < $1.price }
        case .nameAsc: items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return items
    }

    private var totalFooter: some View {
        HStack {
            Text("Total").font(.callout)
            Spacer()
            Text(store.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).font(.callout).bold()
        }
    }

    // MARK: - Sections
    private var upcomingSection: some View {
        let upcoming = store.items.compactMap { item -> (AccessoryItem, Date)? in
            guard let m = item.replacementMonths, let due = Calendar.current.date(byAdding: .month, value: m, to: item.purchaseDate) else { return nil }
            return (item, due)
        }.sorted { $0.1 < $1.1 }

        return Section("Upcoming Replacements") {
            if upcoming.isEmpty {
                Text("No upcoming replacements.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(upcoming.enumerated()), id: \.offset) { _, pair in
                    HStack {
                        Text(pair.0.name)
                        Spacer()
                        Text(pair.1, style: .date).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Rows
    private func row(for item: AccessoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(categoryColor(item.category).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon(item.category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(categoryColor(item.category))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.body)
                Text("\(item.category.rawValue) • \(item.purchaseDate, style: .date)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                if let m = item.replacementMonths { Text("Every \(m) mo").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Sheets
    private var addSheet: some View {
        NavigationStack {
            AccessoryForm(item: .constant(.init(name: "", category: .other, price: 0, purchaseDate: .now, notes: nil, replacementMonths: nil))) { new in
                store.add(new)
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAdd = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add accessory")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases) { s in Text(s.title).tag(s) }
                }
                Button("Export CSV") { exportCSV() }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: - Export CSV
    private func exportCSV() {
        let header = "id,name,category,price,purchaseDate,notes,replacementMonths"
        let df = ISO8601DateFormatter()
        let rows = store.items.map { item in
            let date = df.string(from: item.purchaseDate)
            let notes = (item.notes ?? "").replacingOccurrences(of: ",", with: " ")
            let repl = item.replacementMonths.map(String.init) ?? ""
            return "\(item.id.uuidString),\(item.name),\(item.category.rawValue),\(item.price),\(date),\(notes),\(repl)"
        }
        let csv = ([header] + rows).joined(separator: "\n")
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("accessories.csv")
        try? csv.data(using: .utf8)?.write(to: tmp)
        // Present share sheet
        let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(av, animated: true)
    }

    // MARK: - Visual helpers
    private func categoryIcon(_ c: AccessoryItem.Category) -> String {
        switch c {
        case .charger: return "bolt"
        case .tires: return "circle.hexagongrid"
        case .adapter: return "arrow.triangle.2.circlepath"
        case .interior: return "square.grid.2x2"
        case .exterior: return "paintbrush"
        case .maintenance: return "wrench.and.screwdriver"
        case .other: return "bag"
        }
    }
    private func categoryColor(_ c: AccessoryItem.Category) -> Color {
        switch c {
        case .charger: return .blue
        case .tires: return .brown
        case .adapter: return .purple
        case .interior: return .teal
        case .exterior: return .orange
        case .maintenance: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Edit Sheet Wrapper
fileprivate struct EditAccessorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: AccessoryItem
    var onSave: (AccessoryItem) -> Void

    init(item: AccessoryItem, onSave: @escaping (AccessoryItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        AccessoryForm(item: Binding(get: { draft }, set: { draft = $0 })) { updated in
            onSave(updated)
            dismiss()
        }
    }
}

// MARK: - UIApplication helper (for share controller)
fileprivate extension UIApplication {
    var firstKeyWindow: UIWindow? {
        // iOS 15+
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - Preview
#Preview {
    let demo = AccessoryStore(items: [
        .init(name: "Mobile Connector", category: .charger, price: 230, purchaseDate: Calendar.current.date(byAdding: .month, value: -10, to: .now)!, notes: "Spare", replacementMonths: nil),
        .init(name: "Cabin Air Filter", category: .maintenance, price: 35, purchaseDate: Calendar.current.date(byAdding: .month, value: -11, to: .now)!, notes: nil, replacementMonths: 12),
        .init(name: "All-Weather Mats", category: .interior, price: 220, purchaseDate: Calendar.current.date(byAdding: .month, value: -5, to: .now)!, notes: "3D MAXpider", replacementMonths: nil)
    ])
    return AccessoryTrackerView(store: demo)
}
