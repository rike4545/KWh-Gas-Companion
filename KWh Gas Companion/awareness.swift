//  awareness.swift
//  My KWh Companion
//
//  Helpers derived from ExpenseEntry without redeclaring items that already
//  live in ExpenseEntry.swift.

import Foundation

extension ExpenseEntry {
    // Convenience flags that do NOT clash with properties in ExpenseEntry.swift

    var isSuperchargerExpense: Bool {
        if charging?.isSupercharger == true { return true }
        if (chargeType ?? "").localizedCaseInsensitiveContains("supercharger") { return true }
        if category.lowercased().contains("supercharger") { return true }
        if charging?.fastChargerBrand?.lowercased().contains("tesla") == true { return true }
        return (category == ExpenseCategory.fastDCFC.rawValue)
    }

    var isPublicChargingExpense: Bool {
        category == ExpenseCategory.publicCharging.rawValue ||
        category == ExpenseCategory.fastDCFC.rawValue ||
        (chargeType ?? "").localizedCaseInsensitiveContains("public")
    }

    var isHomeChargingExpense: Bool {
        category == ExpenseCategory.homeCharging.rawValue ||
        (chargeType ?? "").localizedCaseInsensitiveContains("home")
    }

    /// Preferred site label used by analytics (matches SparkPanel.extractEntries fallbacks).
    var siteDisplayName: String {
        charging?.siteName ?? location ?? notes ?? "(Unknown)"
    }
}
