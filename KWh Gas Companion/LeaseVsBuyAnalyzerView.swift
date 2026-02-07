import SwiftUI

@MainActor
struct LeaseVsBuyAnalyzerView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // Buy
    @AppStorage("leasebuy.price") private var purchasePrice: Double = 52000
    @AppStorage("leasebuy.down") private var downPayment: Double = 5000
    @AppStorage("leasebuy.apr") private var apr: Double = 6.2
    @AppStorage("leasebuy.term") private var loanTermMonths: Int = 60
    @AppStorage("leasebuy.resale") private var resaleValue: Double = 28000

    // Lease
    @AppStorage("leasebuy.leaseDue") private var leaseDueAtSigning: Double = 3500
    @AppStorage("leasebuy.leaseMonthly") private var leaseMonthly: Double = 599
    @AppStorage("leasebuy.leaseTerm") private var leaseTermMonths: Int = 36
    @AppStorage("leasebuy.leaseBuyout") private var leaseBuyout: Double = 30000

    // Shared
    @AppStorage("leasebuy.insuranceMonthly") private var insuranceMonthly: Double = 140
    @AppStorage("leasebuy.maintenanceMonthly") private var maintenanceMonthly: Double = 35

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        let currency = Locale.current.currency?.identifier ?? "USD"
        let buyTotal = buyTotalCost
        let leaseTotal = leaseTotalCost
        let diff = leaseTotal - buyTotal

        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                buyInputsCard
                leaseInputsCard
                sharedInputsCard
                comparisonCard(buyTotal: buyTotal, leaseTotal: leaseTotal, diff: diff, currency: currency)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Lease vs Buy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All‑in cost comparison")
                .font(.headline)
            Text("Estimate total cost over the term with insurance and maintenance included.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var buyInputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buy")
                .font(.headline)
            fieldRow("Purchase price", value: $purchasePrice)
            fieldRow("Down payment", value: $downPayment)
            fieldRow("APR (%)", value: $apr)
            stepperRow("Loan term (months)", value: $loanTermMonths, range: 24...96)
            fieldRow("Resale value at term", value: $resaleValue)
        }
        .themedCard()
    }

    private var leaseInputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lease")
                .font(.headline)
            fieldRow("Due at signing", value: $leaseDueAtSigning)
            fieldRow("Monthly payment", value: $leaseMonthly)
            stepperRow("Lease term (months)", value: $leaseTermMonths, range: 24...48)
            fieldRow("Buyout / residual", value: $leaseBuyout)
        }
        .themedCard()
    }

    private var sharedInputsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared costs")
                .font(.headline)
            fieldRow("Insurance / month", value: $insuranceMonthly)
            fieldRow("Maintenance / month", value: $maintenanceMonthly)
        }
        .themedCard()
    }

    private func comparisonCard(buyTotal: Double, leaseTotal: Double, diff: Double, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparison")
                .font(.headline)

            costRow("Buy total", buyTotal, currency: currency)
            costRow("Lease total", leaseTotal, currency: currency)

            Divider().opacity(0.2)

            Text(diff >= 0 ? "Buying saves" : "Leasing saves")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(abs(diff), format: .currency(code: currency))
                .font(.title3.weight(.bold))
        }
        .themedCard()
    }

    private var buyTotalCost: Double {
        let principal = max(0, purchasePrice - downPayment)
        let monthlyRate = max(0, apr) / 100.0 / 12.0
        let term = max(1, loanTermMonths)
        let monthlyPayment: Double
        if monthlyRate == 0 {
            monthlyPayment = principal / Double(term)
        } else {
            let factor = pow(1 + monthlyRate, Double(term))
            monthlyPayment = principal * (monthlyRate * factor) / (factor - 1)
        }
        let financeTotal = monthlyPayment * Double(term)
        let shared = (insuranceMonthly + maintenanceMonthly) * Double(term)
        return financeTotal + downPayment + shared - max(0, resaleValue)
    }

    private var leaseTotalCost: Double {
        let term = max(1, leaseTermMonths)
        let leasePayments = max(0, leaseMonthly) * Double(term)
        let shared = (insuranceMonthly + maintenanceMonthly) * Double(term)
        return max(0, leaseDueAtSigning) + leasePayments + shared + max(0, leaseBuyout)
    }

    private func fieldRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 140)
        }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .labelsHidden()
        }
    }

    private func costRow(_ title: String, _ amount: Double, currency: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount, format: .currency(code: currency))
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
