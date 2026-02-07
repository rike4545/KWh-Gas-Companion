import SwiftUI

@MainActor
struct InsuranceFinanceTrackerView: View {
    @Environment(\.appThemeBox) private var themeBox
    private var theme: any AppThemeSpec { themeBox.base }

    @AppStorage("finance.insuranceMonthly") private var insuranceMonthly: Double = 0
    @AppStorage("finance.loanMonthly") private var loanMonthly: Double = 0
    @AppStorage("finance.leaseMonthly") private var leaseMonthly: Double = 0
    @AppStorage("finance.otherMonthly") private var otherMonthly: Double = 0
    @AppStorage("finance.nextDueDate") private var nextDueDate: Double = Date().timeIntervalSince1970

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                header
                inputs
                summary
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Insurance & Finance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly obligations")
                .font(.headline)
            Text("Track recurring payments so your monthly cost picture stays accurate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Insurance", value: $insuranceMonthly)
            labeledField("Loan payment", value: $loanMonthly)
            labeledField("Lease payment", value: $leaseMonthly)
            labeledField("Other", value: $otherMonthly)
            DatePicker("Next due date", selection: Binding(
                get: { Date(timeIntervalSince1970: nextDueDate) },
                set: { nextDueDate = $0.timeIntervalSince1970 }
            ), displayedComponents: .date)
        }
        .themedCard()
    }

    private var summary: some View {
        let total = insuranceMonthly + loanMonthly + leaseMonthly + otherMonthly
        let currency = Locale.current.currency?.identifier ?? "USD"
        return VStack(alignment: .leading, spacing: 8) {
            Text("Monthly total")
                .font(.headline)
            Text(total.formatted(.currency(code: currency)))
                .font(.title3.weight(.semibold))
            Text("Next due: \(Date(timeIntervalSince1970: nextDueDate).formatted(date: .abbreviated, time: .omitted))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private func labeledField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.00", value: value, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
        .font(.subheadline)
    }
}
