//
//  CalcDashCategory.swift
//  KWh Gas Companion
//
//  Extracted from CalculatorsDashboardView for compile-time improvements.
//

import Foundation

enum CalcDashCategory: Int, CaseIterable, Identifiable {
    case featured = 0
    case saveMoney
    case planAndForecast
    case chargingAndAnalytics
    case compareAndDecide
    case dataImportExport
    case vehicleTools
    case maps
    case community
    case newsAndHistory

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .featured: return "Featured"
        case .saveMoney: return "Save Money & Manage Costs"
        case .planAndForecast: return "Plan & Forecast"
        case .chargingAndAnalytics: return "Charging & Analytics"
        case .compareAndDecide: return "Compare & Decide"
        case .dataImportExport: return "Data Import / Export"
        case .vehicleTools: return "VIN & Vehicle Tools"
        case .maps: return "Maps"
        case .community: return "Community"
        case .newsAndHistory: return "News & History"
        }
    }

    var icon: String {
        switch self {
        case .featured: return "sparkles"
        case .saveMoney: return "dollarsign.circle"
        case .planAndForecast: return "chart.line.uptrend.xyaxis"
        case .chargingAndAnalytics: return "bolt.fill"
        case .compareAndDecide: return "arrow.left.arrow.right.circle"
        case .dataImportExport: return "tray.and.arrow.down"
        case .vehicleTools: return "car.2.fill"
        case .maps: return "map"
        case .community: return "person.3.fill"
        case .newsAndHistory: return "newspaper"
        }
    }
}
