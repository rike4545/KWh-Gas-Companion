//
//  ExpenseEntryWriter.swift
//  My KWh Companion
//
//  Source of truth for the ExpenseEntryWriter protocol + a default concrete adapter.
//  Other features (e.g., Service Invoices) should import and depend on this file.
//
//  iOS 17+ / Swift 6
//

import Foundation

// MARK: - Protocol (source of truth)
public protocol ExpenseEntryWriter: Sendable {
    /// Return an existing expense ID if a duplicate is found for the same vehicle/date/amount.
    func findDuplicateExpense(vehicleKey: String, date: Date, amount: Decimal) async -> UUID?

    /// Create and persist a new expense; return its ID.
    func createExpense(
        vehicleKey: String,
        date: Date,
        amount: Decimal,
        note: String,
        category: String,
        affectsBudget: Bool,
        attachmentURL: URL?
    ) async throws -> UUID
}

// MARK: - Default concrete writer
/// Lightweight adapter that you can wire to your Entries store via two closures.
/// Keeps this file dependency-free and testable.
public final class DefaultExpenseEntryWriter: @unchecked Sendable, ExpenseEntryWriter {

    // Closure types
    public typealias DuplicateFinder = @Sendable (_ vehicleKey: String, _ date: Date, _ amount: Decimal) async -> UUID?
    public typealias ExpenseCreator  = @Sendable (_ vehicleKey: String, _ date: Date, _ amount: Decimal, _ note: String, _ category: String, _ affectsBudget: Bool, _ attachmentURL: URL?) async throws -> UUID

    // Stored closures
    private let findDuplicateImpl: DuplicateFinder
    private let createImpl: ExpenseCreator

    // Init
    public init(
        findDuplicate: @escaping DuplicateFinder,
        create: @escaping ExpenseCreator
    ) {
        self.findDuplicateImpl = findDuplicate
        self.createImpl = create
    }

    // MARK: ExpenseEntryWriter
    public func findDuplicateExpense(vehicleKey: String, date: Date, amount: Decimal) async -> UUID? {
        await findDuplicateImpl(vehicleKey, date, amount)
    }

    public func createExpense(
        vehicleKey: String,
        date: Date,
        amount: Decimal,
        note: String,
        category: String,
        affectsBudget: Bool,
        attachmentURL: URL?
    ) async throws -> UUID {
        try await createImpl(vehicleKey, date, amount, note, category, affectsBudget, attachmentURL)
    }
}

// MARK: - Optional utilities (can help when wiring to your store)

/// Simple duplicate policy you can use inside your `findDuplicate` closure.
public enum ExpenseDuplicatePolicy {
    /// Same vehicle, same calendar day, and amount within tolerance (in cents) counts as duplicate.
    case sameDaySameAmount(toleranceCents: Int = 0)

    public func isDuplicate(
        lhsVehicle: String, lhsDate: Date, lhsAmount: Decimal,
        rhsVehicle: String, rhsDate: Date, rhsAmount: Decimal
    ) -> Bool {
        guard lhsVehicle == rhsVehicle else { return false }
        switch self {
        case .sameDaySameAmount(let cents):
            let cal = Calendar(identifier: .gregorian)
            guard cal.isDate(lhsDate, inSameDayAs: rhsDate) else { return false }
            let tol = Decimal(cents) / 100
            return (lhsAmount - rhsAmount).magnitude <= tol
        }
    }
}

public extension Decimal {
    /// Absolute value for Decimal
    var magnitude: Decimal { self < 0 ? -self : self }
}
