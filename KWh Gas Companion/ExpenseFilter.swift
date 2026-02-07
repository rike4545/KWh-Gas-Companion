//
//  ExpenseFilter 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/29/25.
//


// ExpenseFilter.swift
// MyKwH Companion

import Foundation

/// Filter options for expenses
enum ExpenseFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case energy = "Energy"
    case other = "Other"
    case business = "Business"

    var id: String { rawValue }

    func predicate(_ entry: ExpenseEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .energy:
            return entry.energyKWh != nil
        case .other:
            return entry.category == ExpenseCategory.other.rawValue
        case .business:
            return entry.isBusiness
        }
    }
}
