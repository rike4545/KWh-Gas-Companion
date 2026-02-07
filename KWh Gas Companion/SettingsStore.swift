// SettingsStore.swift
// KWh Gas Companion
// Persists user settings via AppStorage

import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    /// Include tip in cost calculations
    @AppStorage("includesTip") var includesTip: Bool = false

    /// Tip percentage (e.g. 15 for 15%)
    @AppStorage("tipPercentage") var tipPercentage: Double = 15.0

    /// Include tax in cost calculations
    @AppStorage("includesTax") var includesTax: Bool = false

    /// Tax percentage (e.g. 7 for 7%)
    @AppStorage("taxPercentage") var taxPercentage: Double = 7.0

    /// Unit of measure (e.g. "oz" for ounces)
    @AppStorage("unit") var unit: String = "oz"

    /// Currency code (e.g. "USD")
    @AppStorage("currencyCode") var currencyCode: String = "USD"

    /// Vehicle Mileage Tax amount per mile
    @AppStorage("vmtTaxAmount") var vmtTaxAmount: Double = 0.0

    /// Provincial tax percentage
    @AppStorage("provincialTaxPercentage") var provincialTaxPercentage: Double = 0.0
}
