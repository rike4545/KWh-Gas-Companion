import SwiftUI

struct TaxTreatmentView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("currencyCode") private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    @State private var selectedVehicleID: UUID?

    // MARK: Expense Data
    private var businessEntries: [ExpenseEntry] {
        entriesStore.entries.filter { $0.isBusiness }
    }
    private var expensesByCategory: [(category: String, total: Double)] {
        Dictionary(grouping: businessEntries, by: \.category)
            .map { cat, items in (cat, items.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.category < $1.category }
    }
    private var totalBusinessExpenses: Double {
        businessEntries.reduce(0) { $0 + $1.amount }
    }

    // MARK: Depreciation Data
    private var selectedVehicle: VehicleProfile? {
        guard let id = selectedVehicleID else { return nil }
        return profileStore.vehicles.first { $0.id == id }
    }
    private var depreciationSchedule: [(year: Int, amount: Double)] {
        guard let price = selectedVehicle?.purchasePrice else { return [] }
        let years = 5
        let annual = price / Double(years)
        return (1...years).map { (year: $0, amount: annual) }
    }

    var body: some View {
        NavigationStack {
            if horizontalSizeClass == .regular {
                // iPad: two-column layout
                ScrollView {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            businessSection
                            depreciationSection
                        }
                        VStack(alignment: .leading, spacing: 24) {
                            resourcesSection
                            disclaimerSection
                        }
                    }
                    .padding()
                }
                .navigationTitle("Tax Treatment")
            } else {
                // iPhone: single-column form
                Form {
                    businessSection
                    depreciationSection
                    resourcesSection
                    disclaimerSection
                }
                .navigationTitle("Tax Treatment")
            }
        }
        .onAppear {
            if selectedVehicleID == nil {
                selectedVehicleID = profileStore.vehicles.first?.id
            }
        }
    }

    // MARK: Sections
    private var businessSection: some View {
        Section(header: Text("Business Expenses")) {
            HStack {
                Text("Total")
                Spacer()
                Text(totalBusinessExpenses, format: .currency(code: currencyCode))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total business expenses")
            .accessibilityValue(Text(totalBusinessExpenses, format: .currency(code: currencyCode)))

            ForEach(expensesByCategory, id: \.category) { item in
                HStack {
                    Text(item.category)
                    Spacer()
                    Text(item.total, format: .currency(code: currencyCode))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.category) expenses")
                .accessibilityValue(Text(item.total, format: .currency(code: currencyCode)))
            }
        }
    }

    private var depreciationSection: some View {
        Section(header: Text("Depreciation (Straight-Line, 5 yrs)")) {
            Picker("Vehicle", selection: $selectedVehicleID) {
                ForEach(profileStore.vehicles) { v in
                    Text(v.name).tag(v.id as UUID?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .accessibilityLabel("Select vehicle for depreciation")
            .accessibilityValue(Text(selectedVehicle?.name ?? ""))

            if depreciationSchedule.isEmpty {
                Text("Enter purchase price in vehicle profile.")
                    .italic()
            } else {
                ForEach(depreciationSchedule, id: \.year) { e in
                    HStack {
                        Text("Year \(e.year)")
                        Spacer()
                        Text(e.amount, format: .currency(code: currencyCode))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Year \(e.year) depreciation")
                    .accessibilityValue(Text(e.amount, format: .currency(code: currencyCode)))
                }
            }
        }
    }

    private var resourcesSection: some View {
        Section(header: Text("Tax Info & Resources")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("• Deduct business car expenses via actual costs or IRS standard mileage (2025: $0.70/mi).")
                Link("IRS Standard Mileage Rates", destination: URL(string: "https://www.irs.gov/tax-professionals/standard-mileage-rates")!)
                    .font(.caption)
                Text("• Depreciate business-use portion (straight-line).")
                Link("IRS Pub. 463: Car Expenses", destination: URL(string: "https://www.irs.gov/publications/p463")!)
                    .font(.caption)
                Text("• Standard mileage vs. actual expenses.")
                Link("TurboTax: Mileage vs. Actual", destination: URL(string: "https://turbotax.intuit.com/tax-tips/self-employment-taxes/standard-mileage-vs-actual-expenses-getting-the-biggest-tax-deduction/L0wIEUYhh")!)
                    .font(.caption)
                Text("• More write-off rules at Jackson Hewitt.")
                Link("Jackson Hewitt: Car Deductions", destination: URL(string: "https://www.jacksonhewitt.com/tax-help/tax-tips-topics/employment/tax-guide-to-writing-off-car-expenses-and-deductions/")!)
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tax resources and links")
    }

    private var disclaimerSection: some View {
        Section {
            Text("Disclaimer: For educational purposes only, not tax advice. Consult a qualified tax professional. U.S. residents only.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TaxTreatmentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TaxTreatmentView()
                .environmentObject(EntriesStore())
                .environmentObject(ProfileStore())
                .environment(\.horizontalSizeClass, .compact)
                .previewDisplayName("iPhone")

            TaxTreatmentView()
                .environmentObject(EntriesStore())
                .environmentObject(ProfileStore())
                .environment(\.horizontalSizeClass, .regular)
                .previewLayout(.fixed(width: 1024, height: 768))
                .previewDisplayName("iPad")
        }
    }
}
