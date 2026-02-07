//
//  ExpenseCategory.swift
//  MyKwH Companion – 2025-07-27 (added Energy case)

import Foundation

/// Categories for charge and expense entries
enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case energy                   = "Energy"
    case homeCharging             = "Home Charging"
    case publicCharging           = "Public Charging"
    case fastDCFC                 = "Fast (DCFC) Charging"
    case maintenance              = "Maintenance"
    case installationUpgrades     = "Installation & Upgrades"
    case insuranceRegistration    = "Insurance & Registration"
    case accessoriesConsumables   = "Accessories & Consumables"
    case parkingTolling           = "Parking & Tolling"
    case demandCharges            = "Operating Costs"
    case softwareSubscriptions    = "Software & Subscriptions"
    case roadsideAssistance       = "Roadside Assistance"
    case finance                  = "Finance"
    case lease                    = "Lease"
    case autoPayment              = "Auto Payment"
    case other                    = "Other"

    /// SF Symbol icon for each category
    var icon: String {
        switch self {
        case .energy:                return "bolt.circle"
        case .homeCharging:          return "house.fill"
        case .publicCharging:        return "bolt.fill"
        case .fastDCFC:              return "bolt.car"
        case .maintenance:           return "wrench.and.screwdriver"
        case .installationUpgrades:  return "hammer.fill"
        case .insuranceRegistration: return "doc.plaintext"
        case .accessoriesConsumables:return "cube.box.fill"
        case .parkingTolling:        return "car.fill"
        case .demandCharges:         return "flame.fill"
        case .softwareSubscriptions: return "gearshape"
        case .roadsideAssistance:    return "car.2.fill"
        case .finance:               return "dollarsign.circle.fill"
        case .lease:                 return "calendar"
        case .autoPayment:           return "arrow.left.arrow.right"
        case .other:                 return "questionmark.circle"
        }
    }
}
