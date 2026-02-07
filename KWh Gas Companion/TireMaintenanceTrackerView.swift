import SwiftUI

struct MaintenanceRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var mileage: Double
    var cost: Double
    var notes: String
    var reminderMiles: Double
    var reminderMonths: Int
}

@MainActor
final class MaintenanceStore: LocalJSONStore<MaintenanceRecord> {
    init() {
        super.init(filename: "maintenance_records.json")
    }
}

@MainActor
struct TireMaintenanceTrackerView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var store = MaintenanceStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @State private var showingAdd = false

    @AppStorage("maintenance.currentMileage") private var currentMileage: Double = 25000

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                mileageCard

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No maintenance records yet",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add tire, brake, and service costs to track ownership.")
                    )
                } else {
                    ForEach(store.items.sorted { $0.date > $1.date }) { record in
                        recordRow(record)
                    }
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Tire & Maintenance")
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
            MaintenanceEditorView { newRecord in
                store.items.insert(newRecord, at: 0)
            }
        }
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track ownership maintenance")
                .font(.headline)
            Text("Record tire and service events and set reminders.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var mileageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current odometer")
                .font(.headline)
            HStack {
                Text("Miles")
                Spacer()
                TextField("0", value: $currentMileage, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
        }
        .themedCard()
    }

    private func recordRow(_ r: MaintenanceRecord) -> some View {
        let status = dueStatus(for: r)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(r.title)
                    .font(.headline)
                Spacer()
                Text(r.cost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 12) {
                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                Text("\(Int(r.mileage)) mi")
                if status.label != nil {
                    Text(status.label!)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(status.color.opacity(0.2)))
                        .foregroundStyle(status.color)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !r.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(r.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .themedCard()
    }

    private func dueStatus(for r: MaintenanceRecord) -> (label: String?, color: Color) {
        let milesDue = r.reminderMiles > 0 ? (r.mileage + r.reminderMiles) : nil
        let monthsDue = r.reminderMonths > 0 ? Calendar.current.date(byAdding: .month, value: r.reminderMonths, to: r.date) : nil

        var isDueSoon = false
        var isOverdue = false

        if let milesDue {
            let remaining = milesDue - currentMileage
            if remaining <= 0 { isOverdue = true }
            else if remaining <= 500 { isDueSoon = true }
        }

        if let monthsDue {
            let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: monthsDue).day ?? 0
            if remainingDays <= 0 { isOverdue = true }
            else if remainingDays <= 14 { isDueSoon = true }
        }

        if isOverdue { return ("Overdue", .red) }
        if isDueSoon { return ("Due soon", .orange) }
        return (nil, .secondary)
    }
}

struct MaintenanceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = "Tire rotation"
    @State private var date: Date = Date()
    @State private var mileage: Double = 25000
    @State private var cost: Double = 0
    @State private var notes: String = ""
    @State private var reminderMiles: Double = 5000
    @State private var reminderMonths: Int = 6

    let onSave: (MaintenanceRecord) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Record") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Mileage")
                        Spacer()
                        TextField("0", value: $mileage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("0", value: $cost, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section("Reminders") {
                    HStack {
                        Text("Miles interval")
                        Spacer()
                        TextField("0", value: $reminderMiles, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Stepper("Months interval: \(reminderMonths)", value: $reminderMonths, in: 0...24)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Record")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let record = MaintenanceRecord(
                            id: UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date,
                            mileage: mileage,
                            cost: cost,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            reminderMiles: reminderMiles,
                            reminderMonths: reminderMonths
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
