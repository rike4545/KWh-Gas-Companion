//
//  FinanceView.swift
//  MyKwH Companion
//
//  Finance & Lease calculator (safer math + better UX)
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FinanceMode: String, CaseIterable, Identifiable {
    case finance = "Finance"
    case lease   = "Lease"
    var id: String { rawValue }
}

@MainActor
struct FinanceView: View {
    @State private var mode: FinanceMode = .finance

    // Common
    @State private var termYearsText = "5" // default 5 years

    // Finance inputs
    @State private var loanAmountText = "35000"
    @State private var downPaymentText = "5000"
    @State private var aprText = "6.5"
    @State private var paymentText = "" // known payment -> implied APR

    // Lease inputs
    @State private var msrpText = "55000"
    @State private var residualPctText = "58"
    @State private var moneyFactorText = "0.0020"
    @State private var leasePaymentText = "" // known payment -> implied MF

    // Lease optional adjustments
    @State private var capReductionText = ""     // cap cost reduction (down payment)
    @State private var acquisitionFeeText = ""   // common lease fee
    @State private var showLeaseOptions = false

    // Focus
    @FocusState private var focusedField: Field?
    enum Field { case term, loan, down, apr, pay, msrp, residual, mf, leasePay, cap, acq }

    // MARK: - Parsing helpers (supports comma decimals)

    private func parseDouble(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // allow comma decimals
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        min(max(x, a), b)
    }

    private var years: Double? {
        guard let y = parseDouble(termYearsText) else { return nil }
        let v = clamp(y, 0, 50)
        return v > 0 ? v : nil
    }

    private var months: Int? {
        guard let y = years else { return nil }
        let m = Int(round(y * 12))
        return m > 0 ? m : nil
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: - Finance math

    private func amortizedPayment(principal: Double, aprPct: Double, months: Int) -> Double? {
        let p = max(principal, 0)
        guard p > 0, months > 0 else { return nil }

        let monthlyRate = max(aprPct, 0) / 100.0 / 12.0

        // 0% APR case
        if monthlyRate == 0 {
            return p / Double(months)
        }

        let r = monthlyRate
        let n = Double(months)
        let powVal = pow(1 + r, n)
        let denom = (powVal - 1)
        guard denom != 0 else { return nil }

        return p * (r * powVal) / denom
    }

    private func impliedAprFromPayment(principal: Double, months: Int, payment: Double) -> Double? {
        let p = max(principal, 0)
        let pay = max(payment, 0)
        guard p > 0, months > 0, pay > 0 else { return nil }

        // If payment is too small to ever pay off principal (even at 0% APR), bail.
        let minPay = p / Double(months)
        guard pay >= minPay - 0.0001 else { return nil }

        // Binary search monthly rate r in [0, 1] (0%..1200% APR) for robustness.
        var lo = 0.0
        var hi = 1.0

        func paymentAt(monthlyRate r: Double) -> Double {
            if r == 0 { return p / Double(months) }
            let n = Double(months)
            let powVal = pow(1 + r, n)
            let denom = (powVal - 1)
            if denom == 0 { return .infinity }
            return p * (r * powVal) / denom
        }

        // Ensure hi is high enough
        while paymentAt(monthlyRate: hi) < pay && hi < 10 {
            hi *= 2
        }

        for _ in 0..<70 {
            let mid = (lo + hi) / 2
            let midPay = paymentAt(monthlyRate: mid)
            if midPay > pay {
                hi = mid
            } else {
                lo = mid
            }
        }

        let monthly = (lo + hi) / 2
        let apr = monthly * 12 * 100
        // sane cap for display
        return apr.isFinite ? apr : nil
    }

    private var financePrincipal: Double? {
        guard
            let loan = parseDouble(loanAmountText),
            let down = parseDouble(downPaymentText)
        else { return nil }
        let principal = max(loan - down, 0)
        return principal > 0 ? principal : nil
    }

    private var financeMonthlyPayment: Double? {
        guard
            let principal = financePrincipal,
            let apr = parseDouble(aprText),
            let m = months
        else { return nil }
        return amortizedPayment(principal: principal, aprPct: apr, months: m)
    }

    private var financeTotals: (totalPaid: Double, totalInterest: Double)? {
        guard let principal = financePrincipal,
              let m = months,
              let pay = financeMonthlyPayment else { return nil }
        let totalPaid = pay * Double(m)
        let totalInterest = max(totalPaid - principal, 0)
        return (totalPaid, totalInterest)
    }

    private var financeImpliedApr: Double? {
        guard
            let principal = financePrincipal,
            let m = months,
            let knownPay = parseDouble(paymentText)
        else { return nil }
        return impliedAprFromPayment(principal: principal, months: m, payment: knownPay)
    }

    // MARK: - Lease math

    private var leaseMsrp: Double? { parseDouble(msrpText).map { max($0, 0) }.flatMap { $0 > 0 ? $0 : nil } }
    private var leaseResidualPct: Double? { parseDouble(residualPctText).map { clamp($0, 0, 100) } }
    private var leaseMoneyFactor: Double? { parseDouble(moneyFactorText).map { max($0, 0) } }
    private var capReduction: Double { parseDouble(capReductionText).map { max($0, 0) } ?? 0 }
    private var acquisitionFee: Double { parseDouble(acquisitionFeeText).map { max($0, 0) } ?? 0 }

    private var leaseResidualValue: Double? {
        guard let msrp = leaseMsrp, let rp = leaseResidualPct else { return nil }
        return msrp * (rp / 100.0)
    }

    private var leaseCapCost: Double? {
        guard let msrp = leaseMsrp else { return nil }
        // Simple cap cost approximation
        return max(msrp - capReduction + acquisitionFee, 0)
    }

    private var computedLeasePayment: Double? {
        guard let cap = leaseCapCost,
              let residual = leaseResidualValue,
              let mf = leaseMoneyFactor,
              let y = years
        else { return nil }

        let months = max(Int(round(y * 12)), 1)
        let depreciation = (cap - residual) / Double(months)
        let financeCharge = (cap + residual) * mf
        return depreciation + financeCharge
    }

    private var impliedMoneyFactor: Double? {
        guard let cap = leaseCapCost,
              let residual = leaseResidualValue,
              let y = years,
              let knownPay = parseDouble(leasePaymentText)
        else { return nil }

        let months = max(Int(round(y * 12)), 1)
        let depreciation = (cap - residual) / Double(months)
        let denom = (cap + residual)
        guard denom > 0 else { return nil }

        let mf = (knownPay - depreciation) / denom
        return mf.isFinite ? max(mf, 0) : nil
    }

    private var moneyFactorToAprPct: Double? {
        // Rough convention: APR ≈ MF * 2400
        guard let mf = leaseMoneyFactor else { return nil }
        return mf * 2400
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Mode"),
                    footer: Text("Finance computes a loan payment or implied APR. Lease computes a base lease payment or implied money factor (MF). Taxes and local fees vary; this is an estimate tool.")
                ) {
                    Picker("Mode", selection: $mode) {
                        ForEach(FinanceMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Term")) {
                    HStack {
                        Text("Term (years)")
                        Spacer(minLength: 12)
                        TextField("e.g. 5", text: $termYearsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .term)
                            .monospacedDigit()
                    }

                    if let m = months {
                        LabeledContent("Term (months)") {
                            Text("\(m)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if mode == .finance {
                    financeSection
                } else {
                    leaseSection
                }

                Section {
                    Button(role: .destructive) { reset() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Finance & Lease")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Finance UI

    private var financeSection: some View {
        Group {
            Section(
                header: Text("Finance Inputs"),
                footer: Text("Loan Amount minus Down Payment = principal. 0% APR is handled correctly.")
            ) {
                TextField("Loan Amount ($)", text: $loanAmountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .loan)

                TextField("Down Payment ($)", text: $downPaymentText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .down)

                TextField("APR (%)", text: $aprText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .apr)
            }

            Section(header: Text("Results")) {
                if let principal = financePrincipal {
                    LabeledContent("Principal") {
                        Text(principal, format: .currency(code: currencyCode)).monospacedDigit()
                    }
                }

                if let pay = financeMonthlyPayment {
                    LabeledContent("Monthly Payment") {
                        Text(pay, format: .currency(code: currencyCode)).monospacedDigit().bold()
                    }
                } else {
                    Text("Enter valid numbers to calculate payment.")
                        .foregroundStyle(.secondary)
                }

                if let totals = financeTotals {
                    LabeledContent("Total Paid") {
                        Text(totals.totalPaid, format: .currency(code: currencyCode)).monospacedDigit()
                    }
                    LabeledContent("Total Interest") {
                        Text(totals.totalInterest, format: .currency(code: currencyCode)).monospacedDigit()
                    }
                }
            }

            Section(
                header: Text("Find APR from Payment"),
                footer: Text("Enter a known monthly payment and we’ll estimate the implied APR.")
            ) {
                TextField("Known Monthly Payment ($)", text: $paymentText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .pay)

                if let apr = financeImpliedApr {
                    LabeledContent("Implied APR") {
                        Text(apr / 100, format: .percent.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }
                } else if !paymentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Payment is too low for this principal/term, or inputs are invalid.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Lease UI

    private var leaseSection: some View {
        Group {
            Section(
                header: Text("Lease Inputs"),
                footer: Text("Base lease estimate: depreciation + finance charge. MF→APR shown as a rough convention (APR ≈ MF × 2400).")
            ) {
                TextField("MSRP ($)", text: $msrpText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .msrp)

                TextField("Residual (%)", text: $residualPctText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .residual)

                TextField("Money Factor (MF)", text: $moneyFactorText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .mf)

                DisclosureGroup(isExpanded: $showLeaseOptions) {
                    TextField("Cap Cost Reduction ($) (optional)", text: $capReductionText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cap)

                    TextField("Acquisition Fee ($) (optional)", text: $acquisitionFeeText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .acq)

                    Text("Future pathway: add tax rate, doc fees, registration, and incentives here without changing core math.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Optional adjustments", systemImage: "slider.horizontal.3")
                }
            }

            Section(header: Text("Results")) {
                if let cap = leaseCapCost {
                    LabeledContent("Cap Cost (est.)") {
                        Text(cap, format: .currency(code: currencyCode)).monospacedDigit()
                    }
                }
                if let residual = leaseResidualValue {
                    LabeledContent("Residual Value") {
                        Text(residual, format: .currency(code: currencyCode)).monospacedDigit()
                    }
                }
                if let mfApr = moneyFactorToAprPct {
                    LabeledContent("MF ≈ APR") {
                        Text(mfApr / 100, format: .percent.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if let lease = computedLeasePayment {
                    LabeledContent("Lease Payment (base)") {
                        Text(lease, format: .currency(code: currencyCode))
                            .monospacedDigit()
                            .bold()
                    }
                } else {
                    Text("Enter valid numbers to calculate lease payment.")
                        .foregroundStyle(.secondary)
                }
            }

            Section(
                header: Text("Find Money Factor from Payment"),
                footer: Text("Provide a known lease payment to estimate implied MF. This uses the same cap cost + residual assumptions above.")
            ) {
                TextField("Known Lease Payment ($)", text: $leasePaymentText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .leasePay)

                if let mf = impliedMoneyFactor {
                    LabeledContent("Implied MF") {
                        Text(mf, format: .number.precision(.fractionLength(5)))
                            .monospacedDigit()
                    }
                    LabeledContent("Implied MF ≈ APR") {
                        Text((mf * 2400) / 100, format: .percent.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Reset

    private func reset() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        mode = .finance
        termYearsText = "5"

        loanAmountText = "35000"
        downPaymentText = "5000"
        aprText = "6.5"
        paymentText = ""

        msrpText = "55000"
        residualPctText = "58"
        moneyFactorText = "0.0020"
        leasePaymentText = ""

        capReductionText = ""
        acquisitionFeeText = ""
        showLeaseOptions = false

        focusedField = nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { FinanceView() }
}
