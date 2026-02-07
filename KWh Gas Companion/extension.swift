//
//  extension.swift
//  KWh Gas Companion
//
//  Created by Bryan on 9/11/25.
//


// ExpenseCategory.swift
// Add these helpers to your enum

extension ExpenseCategory {
    /// User-visible label (if you want something shorter than rawValue for some cases)
    var displayName: String { rawValue }

    /// True if this category should be treated as EV energy spend/usage.
    var isEnergyLike: Bool {
        switch self {
        case .energy, .homeCharging, .publicCharging, .fastDCFC: return true
        default: return false
        }
    }

    /// Parse tolerant strings coming from CSVs or legacy rows.
    init?(lossy value: String) {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // exact rawValue (case-insensitive)
        if let exact = ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == s }) {
            self = exact; return
        }

        // synonyms / aliases
        if s.contains("dcfc") || s.contains("fast") || s.contains("supercharger") {
            self = .fastDCFC; return
        }
        if s.contains("public") && s.contains("charg") {
            self = .publicCharging; return
        }
        if s.contains("home") && s.contains("charg") {
            self = .homeCharging; return
        }
        if s == "charging" || s == "charge" || s.contains("ev energy") || s == "energy" {
            self = .energy; return
        }
        if s.contains("maint") { self = .maintenance; return }
        if s.contains("install") || s.contains("upgrade") { self = .installationUpgrades; return }
        if s.contains("insur") || s.contains("registr") { self = .insuranceRegistration; return }
        if s.contains("accessor") || s.contains("consum") { self = .accessoriesConsumables; return }
        if s.contains("park") || s.contains("toll") { self = .parkingTolling; return }
        if s.contains("operat") || s.contains("demand") || s.contains("fee") { self = .demandCharges; return }
        if s.contains("subscript") || s.contains("software") { self = .softwareSubscriptions; return }
        if s.contains("roadside") { self = .roadsideAssistance; return }
        if s.contains("lease") { self = .lease; return }
        if s.contains("auto pay") || s.contains("autopay") { self = .autoPayment; return }
        if s.contains("finance") || s.contains("loan") { self = .finance; return }

        // fallback
        self = .other
    }
}
