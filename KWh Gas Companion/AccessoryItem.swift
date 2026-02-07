//  AccessoryItem.swift — Fixed
//  My EV Companion
//
//  Model + store + form for accessories. Fixes LabeledContent(value:) to use String.
//  iOS 17+ / Swift 6

import SwiftUI

// MARK: - Model
public struct AccessoryItem: Identifiable, Codable, Hashable {
    public enum Category: String, CaseIterable, Codable {
        case charger = "Charger"
        case tires = "Tires"
        case adapter = "Adapter"
        case interior = "Interior"
        case exterior = "Exterior"
        case maintenance = "Maintenance"
        case other = "Other"
    }

    public var id: UUID = .init()
    public var name: String
    public var category: Category
    public var price: Double
    public var purchaseDate: Date
    public var notes: String?
    public var replacementMonths: Int? // e.g. wipers 12, cabin filter 12

    public init(id: UUID = .init(), name: String, category: Category, price: Double, purchaseDate: Date, notes: String?, replacementMonths: Int?) {
        self.id = id
        self.name = name
        self.category = category
        self.price = price
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.replacementMonths = replacementMonths
    }
}

// MARK: - Store
public final class AccessoryStore: ObservableObject {
    @Published public var items: [AccessoryItem]
    public init(items: [AccessoryItem] = []) { self.items = items }
    public var total: Double { items.reduce(0) { $0 + $1.price } }
    public func add(_ item: AccessoryItem) { items.append(item) }
    public func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets) }
}

// MARK: - Form
@MainActor
public struct AccessoryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var item: AccessoryItem
    var onSave: (AccessoryItem) -> Void

    public init(item: Binding<AccessoryItem>, onSave: @escaping (AccessoryItem) -> Void) {
        self._item = item
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: Binding(get: { item.name }, set: { item.name = $0 }))
                Picker("Category", selection: Binding(get: { item.category }, set: { item.category = $0 })) {
                    ForEach(AccessoryItem.Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                HStack { Text("Price"); Spacer(); CurrencyField(value: Binding(get: { item.price }, set: { item.price = $0 })) }
                DatePicker("Purchased", selection: Binding(get: { item.purchaseDate }, set: { item.purchaseDate = $0 }), displayedComponents: .date)
                TextField("Notes", text: Binding(get: { item.notes ?? "" }, set: { item.notes = $0.isEmpty ? nil : $0 }))
                Stepper(value: Binding(get: { item.replacementMonths ?? 0 }, set: { item.replacementMonths = $0 == 0 ? nil : $0 }), in: 0...60) {
                    // FIX: value is String, not Text
                    LabeledContent("Replace Every", value: "\(item.replacementMonths ?? 0) months")
                }
            }
        }
        .navigationTitle("Accessory")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Save") { onSave(item); dismiss() }.bold() }
        }
    }
}

// MARK: - Small helpers
fileprivate struct CurrencyField: View {
    @Binding var value: Double
    var body: some View {
        TextField("$", value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AccessoryForm(item: .constant(.init(name: "Cabin Filter", category: .maintenance, price: 35, purchaseDate: .now, notes: "HEPA", replacementMonths: 12))) { _ in }
    }
}
