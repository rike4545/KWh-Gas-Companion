//  EVLoanLeaseOptimizerView.swift — Fixed
//  My EV Companion
//
//  Compare keep vs refinance vs lease buyout with resale projections.
//  Fix: All LabeledContent(value:) now pass String (not Text) to satisfy the API.
//  iOS 17+ / Swift 6

import SwiftUI
import Charts

@MainActor
public struct EVLoanLeaseOptimizerView: View {
    // Mode
    @State private var isLease: Bool = false

    // Vehicle & Market
    @State private var msrp: Double = 48_000
    @State private var currentValue: Double = 36_000
    @State private var annualDepreciationPct: Double = 12.0

    // Loan
    @State private var loanBalance: Double = 32_000
    @State private var aprPercent: Double = 5.9
    @State private var monthsRemaining: Int = 48

    // Lease
    @State private var buyoutPrice: Double = 30_000
    @State private var residualValue: Double = 30_000
    @State private var monthsLeftLease: Int = 18

    // Refinance
    @State private var refiAPRPercent: Double = 4.1
    @State private var refiTermMonths: Int = 60

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Mode") { Toggle("This is a lease", isOn: $isLease) }

                Section("Vehicle & Market") {
                    HStack { Text("MSRP"); Spacer(); CurrencyTextField(value: $msrp) }
                    HStack { Text("Current Value"); Spacer(); CurrencyTextField(value: $currentValue) }
                    Stepper(value: $annualDepreciationPct, in: 5...25, step: 0.5) {
                        LabeledContent("Annual Depreciation", value: String(format: "%.1f%%", annualDepreciationPct))
                    }
                }

                if !isLease {
                    Section("Current Loan") {
                        HStack { Text("Balance"); Spacer(); CurrencyTextField(value: $loanBalance) }
                        Stepper(value: $aprPercent, in: 0...20, step: 0.1) {
                            LabeledContent("APR", value: String(format: "%.1f%%", aprPercent))
                        }
                        Stepper(value: $monthsRemaining, in: 1...84) {
                            LabeledContent("Months Remaining", value: "\(monthsRemaining)")
                        }
                    }
                } else {
                    Section("Lease Details") {
                        HStack { Text("Buyout Price"); Spacer(); CurrencyTextField(value: $buyoutPrice) }
                        HStack { Text("Residual Value"); Spacer(); CurrencyTextField(value: $residualValue) }
                        Stepper(value: $monthsLeftLease, in: 1...36) {
                            LabeledContent("Months Left", value: "\(monthsLeftLease)")
                        }
                    }
                }

                Section("Refinance Scenario") {
                    Stepper(value: $refiAPRPercent, in: 0...20, step: 0.1) {
                        LabeledContent("Refi APR", value: String(format: "%.1f%%", refiAPRPercent))
                    }
                    Stepper(value: $refiTermMonths, in: 12...84, step: 12) {
                        LabeledContent("Refi Term", value: "\(refiTermMonths) mo")
                    }
                }

                summarySection
                projectionSection
            }
            .navigationTitle("Loan/Lease Optimizer")
        }
    }

    // MARK: - Results
    private var summarySection: some View {
        let keep = !isLease ? amortized(balance: loanBalance, aprPct: aprPercent, months: monthsRemaining) : leaseKeepCost()
        let refi = amortized(balance: isLease ? buyoutPrice : loanBalance, aprPct: refiAPRPercent, months: refiTermMonths)
        let tradeDelta = currentValue - (isLease ? buyoutPrice : loanBalance)

        return Section("Summary") {
            ResultRow(label: !isLease ? "Keep Current Loan (interest)" : "Finish Lease (est.)", value: keep.totalInterest)
            ResultRow(label: "Refinance (interest)", value: refi.totalInterest)
            ResultRow(label: "Trade-in Delta now", value: tradeDelta)

            let rec = recommendation(keep: keep, refi: refi, tradeDelta: tradeDelta)
            VStack(alignment: .leading, spacing: 6) {
                Text(rec.title).font(.headline)
                Text(rec.detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var projectionSection: some View {
        let months = max(monthsRemaining, refiTermMonths, monthsLeftLease)
        let series: [Point] = (0..<months).map { m in .init(m: m, v: projectedValue(current: currentValue, annualDepPct: annualDepreciationPct, months: m)) }
        return Section("Resale Projection") {
            Chart(series) {
                LineMark(x: .value("Month", $0.m), y: .value("Est. Value", $0.v))
            }
            .frame(height: 200)
            .kwhInteractiveDataViz()
        }
    }

    // MARK: - Math
    struct Amortization { let monthlyPayment: Double; let totalInterest: Double }

    private func amortized(balance: Double, aprPct: Double, months: Int) -> Amortization {
        let r = aprPct / 100 / 12
        guard r > 0 else { return .init(monthlyPayment: balance / Double(max(months, 1)), totalInterest: 0) }
        let pmt = balance * (r * pow(1 + r, Double(months))) / (pow(1 + r, Double(months)) - 1)
        let total = pmt * Double(months)
        return .init(monthlyPayment: pmt, totalInterest: max(total - balance, 0))
    }

    private func leaseKeepCost() -> Amortization {
        // Coarse comparator for finishing the lease; use detail view for exact payment schedule.
        .init(monthlyPayment: 0, totalInterest: 0)
    }

    private func projectedValue(current: Double, annualDepPct: Double, months: Int) -> Double {
        let mDep = annualDepPct / 100 / 12
        return current * pow(1 - mDep, Double(months))
    }

    private func recommendation(keep: Amortization, refi: Amortization, tradeDelta: Double) -> (title: String, detail: String) {
        if tradeDelta > 2000 {
            return ("Trade-in looks favorable", "Equity of ~$\(Int(tradeDelta)) suggests trading now could be sensible.")
        }
        if refi.totalInterest + 300 < keep.totalInterest {
            return ("Refinance recommended", "Lower APR saves ~$\(Int(keep.totalInterest - refi.totalInterest)).")
        }
        return ("Keep current plan", "Savings from refi/trade appear marginal given your inputs.")
    }

    struct Point: Identifiable { let id = UUID(); let m: Int; let v: Double }
}

// MARK: - Small helpers (file-private)
fileprivate struct ResultRow: View {
    let label: String
    let value: Double
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
        }
    }
}

fileprivate struct CurrencyTextField: View {
    @Binding var value: Double
    var body: some View {
        TextField("$", value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
    }
}

// MARK: - Preview
#Preview {
    EVLoanLeaseOptimizerView()
}
