//
//  CalculatorKind.swift
//  KWh Gas Companion
//
//  Extracted from CalculatorsDashboardView for compile-time improvements.
//  ✅ lemonLawGuide added
//

import Foundation

public enum CalculatorKind: String, CaseIterable, Identifiable, Hashable, Sendable {

    // A
    case accessoryTracker
    case analyticsCharts
    case businessDeductionReport

    // C
    case carbonImpactDashboard
    case carbonOffset
    case carsVsEVCalculator
    case chargeTime
    case chargingBudgetGuard
    case chargingDataStudio
    case chargingDataIntegrity
    case chargingEtiquette
    case chargingReconciliation
    case caughtaKWH
    case chartsBudget
    case cheapestChargerShift
    case combinedChargeSession
    case costBreakdownDetail
    case costOfOwnershipAnalysis
    case costPerKWhTrend
    case costPerMileAndCO2
    case csvChargingWizard
    case csvExport

    // D
    case dataQualityCenter
    case deliveryTracker
    case deliveryChecklist
    case deepDepthShift
    case discounts
    case evContent
    case doGoodDonationShift
    case dynamicSuperchargingExplainer

    // E
    case entriesAnomalies
    case energyCoach
    case evNews
    case evVsCarComparison
    case evChargingVsGasTime

    // F
    case fastVsHomeImpact
    case forecastChart
    case forecastDashboard
    case forecastWeekly

    // G
    case gasTax
    case gasToKWhConverter
    case garage
    case gridEmissionsForecast

    // L
    case libreNav
    case routeDiscovery

    // H
    case historyOfTeslaAndRivian
    case homeVsPublicSplit

    // I
    case incentives

    // K
    case kWhRates

    // L
    case leaseMileage
    case lemonLawGuide

    // M
    case maintenanceGuides
    case mpgeCalculator
    case materialsShift
    case muscleCarShowdown

    // N
    case nearMe
    case nhtsaCrashReporting
    case superchargeInfoNearMe

    // P
    case paymentMethod
    case publicIncentiveFinder
    case productPlateScannerArchive
    case priceWatchlist

    // Q
    case quarterlyTaxSummary

    // R
    case rangeForecast
    case recalls
    case reimbursementGenerator
    case resaleMarketplace
    case rivianVINDecoder
    case rightToRepair

    // S
    case savingsScore
    case schedulePlanner
    case sessionConfidence
    case duplicateResolver
    case bestValueChargers
    case weeklyCostRollup
    case batteryHealthTimeline
    case homeChargerOptimizer
    case monthlyBurnDown
    case costPerMileVsGas
    case insuranceFinanceTracker
    case tripBudgetPlanner
    case leaseVsBuyAnalyzer
    case roadTaxEstimator
    case stationQualityScore
    case chargeSpeedProfiler
    case tireMaintenanceTracker
    case diyServiceVault
    case netCostPerMile
    case monthlyHeatmap
    case shareableReports
    case serviceReminders
    case serviceInvoices
    case sessionAnalytics
    case sessionEfficiencyScatter
    case sparkPanel
    case superChargerSessionCostCalculator
    case superchargerLivePricePredictor
    case superchargerStops

    // T
    case tcoTimeline
    case taxTreatment
    case teslaOffer
    case teslaOwnersClub
    case teslaVINDecoder
    case teslaServiceAlerts
    case teslaEPCPartsCatalog
    case altitudeCockpit
    case weatherCockpit
    case tripCockpit
    case ticTacToe
    case tripCostEstimator
    case tripPlanner
    case tripLogger

    // U
    case annualCostSimulator
    case unitConversion
    case evLoanLeaseOptimizer
    case finance
    case weeklyHealthReport

    // W
    case winterDrivingTechniques
    case winterRangeImpactPlanner
    case whatIfForecast
    case weeklyEVVsGasCost

    // Feature pack
    case receiptOCR
    case routeCostCompare
    case tcoMonthlyTimeline
    case chargingSafetyChecklist
    case emergencyPackChecklist
    case teslaInvoiceScan

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessoryTracker:            return "Accessory Cost Tracker"
        case .analyticsCharts:             return "Charging Analytics Charts"
        case .businessDeductionReport:     return "Business Deduction Report"

        case .carbonImpactDashboard:       return "Carbon Impact Dashboard"
        case .carbonOffset:                return "Carbon Offset Calc."
        case .carsVsEVCalculator:          return "Cars vs EV Calculator"
        case .chargeTime:                  return "Estimated Charging Time"
        case .chargingBudgetGuard:         return "Charging Budget Guardrails"
        case .chargingDataStudio:          return "Charging Data Studio"
        case .chargingDataIntegrity:       return "Charging Data Integrity"
        case .chargingEtiquette:           return "Charging Etiquette"
        case .chargingReconciliation:      return "Charging Reconciliation"
        case .caughtaKWH:                  return "CaughtaKWH"
        case .chartsBudget:                return "Charts & Budget"
        case .cheapestChargerShift:        return "Cheapest Charger Finder"
        case .combinedChargeSession:       return "Combined Charge Session"
        case .costBreakdownDetail:         return "Cost Breakdown"
        case .costOfOwnershipAnalysis:     return "Cost of Ownership"
        case .costPerKWhTrend:             return "Cost per kWh Trend"
        case .costPerMileAndCO2:           return "$/Mile & CO2"
        case .csvChargingWizard:           return "CSV Charging Wizard"
        case .csvExport:                   return "CSV Export"

        case .deliveryTracker:             return "Tesla Delivery Tracker"
        case .deliveryChecklist:           return "Delivery Day Checklist"
        case .deepDepthShift:              return "Deep Analytics"
        case .dataQualityCenter:           return "Data Quality Center"
        case .doGoodDonationShift:         return "Shifting Do Good"
        case .discounts:                   return "Discounts & Referrals"
        case .evContent:                   return "EV Content"
        case .dynamicSuperchargingExplainer: return "Dynamic Supercharging vs TOU"

        case .entriesAnomalies:            return "Expense Entry Anomalies"
        case .energyCoach:                 return "Energy Coach"
        case .evNews:                      return "EV News"
        case .evVsCarComparison:           return "EV vs Gas Comparison"
        case .evChargingVsGasTime:         return "EV Charging vs Gas Time"

        case .fastVsHomeImpact:            return "Fast vs Home Impact"
        case .forecastChart:               return "Forecast Charts"
        case .forecastDashboard:           return "Forecast Dashboard"
        case .forecastWeekly:              return "Weekly Forecast"

        case .gasTax:                      return "Gas Tax"
        case .gasToKWhConverter:           return "Gas to kWh Converter"
        case .garage:                      return "Garage & Vehicles"
        case .gridEmissionsForecast:       return "Grid Emissions Forecast"

        case .historyOfTeslaAndRivian:     return "History: Tesla & Rivian"
        case .homeVsPublicSplit:           return "Home vs Public Split"

        case .incentives:                  return "Incentives & Rebates"

        case .kWhRates:                    return "Energy Rates"

        case .leaseMileage:                return "Lease Mileage Overage"
        case .lemonLawGuide:              return "Lemon Law Guide"

        case .maintenanceGuides:           return "DIY & Maintenance Guides"
        case .mpgeCalculator:              return "MPGe Calculator"
        case .materialsShift:             return "EV Materials & Environment"
        case .muscleCarShowdown:           return "EV vs Muscle Car Showdown"

        case .nearMe:                      return "Superchargers Near Me"
        case .nhtsaCrashReporting:         return "NHTSA Crash Reporting"
        case .superchargeInfoNearMe:       return "Supercharge.info Near Me"

        case .paymentMethod:               return "Third-Party Charging Plans"
        case .publicIncentiveFinder:       return "Vehicle Incentive Finder"
        case .productPlateScannerArchive:  return "Plate Scanner Archive"
        case .priceWatchlist:              return "Price Watchlist"

        case .quarterlyTaxSummary:         return "Quarterly Tax Summary"

        case .rangeForecast:               return "Range Forecast"
        case .recalls:                     return "Recalls"
        case .reimbursementGenerator:      return "Reimbursement Generator"
        case .resaleMarketplace:           return "Secondary Market"
        case .rivianVINDecoder:            return "Rivian VIN Decoder"
        case .rightToRepair:               return "Right to Repair"

        case .savingsScore:                return "Savings Score"
        case .schedulePlanner:             return "Smart Charging Planner"
        case .sessionConfidence:           return "Session Confidence"
        case .duplicateResolver:           return "Duplicate Resolver"
        case .bestValueChargers:           return "Best Value Chargers"
        case .weeklyCostRollup:            return "Weekly Cost Rollup"
        case .batteryHealthTimeline:       return "Battery Health Timeline"
        case .homeChargerOptimizer:        return "Home Charger Optimizer"
        case .monthlyBurnDown:             return "Monthly Burn-Down"
        case .costPerMileVsGas:            return "Cost per Mile vs Gas"
        case .insuranceFinanceTracker:     return "Insurance & Finance Tracker"
        case .tripBudgetPlanner:           return "Trip Budget Planner"
        case .leaseVsBuyAnalyzer:          return "Lease vs Buy Analyzer"
        case .roadTaxEstimator:            return "EV Road-Tax Estimator"
        case .stationQualityScore:         return "Station Quality Score"
        case .chargeSpeedProfiler:         return "Charge Speed Profiler"
        case .tireMaintenanceTracker:      return "Tire & Maintenance Tracker"
        case .diyServiceVault:             return "DIY Service Vault"
        case .netCostPerMile:              return "Net Cost per Mile"
        case .monthlyHeatmap:              return "Monthly Heatmap"
        case .shareableReports:            return "Shareable Reports"
        case .serviceReminders:            return "Service Reminders"
        case .serviceInvoices:             return "Service Invoices (PDF)"
        case .sessionAnalytics:            return "Session Analytics"
        case .sessionEfficiencyScatter:    return "Efficiency Scatter"
        case .sparkPanel:                  return "Spark: AI Summary"
        case .superChargerSessionCostCalculator: return "Supercharger Cost Calc"
        case .superchargerLivePricePredictor: return "Supercharger Live Price Predictor"
        case .superchargerStops:           return "Plan Supercharger Stops"

        case .tcoTimeline:                 return "TCO Timeline"
        case .taxTreatment:                return "Tax Treatment"
        case .teslaOffer:                  return "Tesla Offers"
        case .teslaOwnersClub:             return "Tesla Owners Club"
        case .teslaVINDecoder:             return "Tesla VIN Decoder"
        case .teslaServiceAlerts:          return "Tesla Service Alerts"
        case .teslaEPCPartsCatalog:        return "Tesla EPC Parts Catalog"
        case .altitudeCockpit:             return "Altitude Cockpit"
        case .weatherCockpit:              return "Weather Cockpit"
        case .tripCockpit:                 return "Trip Cockpit"
        case .ticTacToe:                   return "Tic Tac Toe"
        case .tripCostEstimator:           return "Trip Cost Estimator"
        case .tripPlanner:                 return "Trip Planner"
        case .tripLogger:                  return "Trip Logger"

        case .unitConversion:              return "Unit Conversion"
        case .evLoanLeaseOptimizer:        return "EV Loan/Lease Optimizer"
        case .finance:                     return "Finance"
        case .annualCostSimulator:         return "Annual Cost Simulator"
        case .weeklyHealthReport:          return "Weekly Health Report"

        case .winterDrivingTechniques:     return "Winter Driving Techniques"
        case .winterRangeImpactPlanner:    return "Winter Range Impact"
        case .whatIfForecast:              return "What-If Forecast"
        case .weeklyEVVsGasCost:           return "Weekly EV vs Gas"

        case .receiptOCR:                  return "Receipt Scan (OCR)"
        case .routeCostCompare:            return "Route Cost Compare"
        case .tcoMonthlyTimeline:          return "TCO Timeline (Monthly)"
        case .chargingSafetyChecklist:     return "Charging Safety Checklist"
        case .emergencyPackChecklist:      return "Emergency Pack Checklist"
        case .teslaInvoiceScan:            return "Tesla Invoice Scan"
        case .libreNav:                    return "LibreNav Navigation"
        case .routeDiscovery:              return "Route Discovery"
        }
    }

    public var systemImage: String {
        switch self {
        case .accessoryTracker:            return "shippingbox"
        case .analyticsCharts:             return "chart.pie"
        case .businessDeductionReport:     return "doc.text"

        case .carbonImpactDashboard:       return "leaf.circle"
        case .carbonOffset:                return "leaf.arrow.circlepath"
        case .carsVsEVCalculator:          return "car.2"
        case .chargeTime:                  return "timer"
        case .chargingBudgetGuard:         return "shield.lefthalf.filled"
        case .chargingDataStudio:          return "tablecells"
        case .chargingDataIntegrity:       return "checkmark.shield"
        case .chargingEtiquette:           return "hand.raised"
        case .chargingReconciliation:      return "arrow.triangle.2.circlepath"
        case .caughtaKWH:                  return "bolt.badge.exclamationmark"
        case .chartsBudget:                return "chart.bar.xaxis"
        case .cheapestChargerShift:        return "bolt.circle"
        case .combinedChargeSession:       return "bolt.circle"
        case .costBreakdownDetail:         return "square.grid.2x2"
        case .costOfOwnershipAnalysis:     return "wallet.pass"
        case .costPerKWhTrend:             return "bolt.fill"
        case .costPerMileAndCO2:           return "leaf"
        case .csvChargingWizard:           return "tray.and.arrow.down"
        case .csvExport:                   return "square.and.arrow.up"

        case .deliveryTracker:             return "shippingbox.and.arrow.backward"
        case .deliveryChecklist:           return "checklist.checked"
        case .deepDepthShift:              return "brain"
        case .dataQualityCenter:           return "checkmark.shield"
        case .doGoodDonationShift:         return "heart"
        case .discounts:                   return "tag"
        case .evContent:                   return "play.rectangle"
        case .dynamicSuperchargingExplainer: return "bolt.badge.clock"

        case .entriesAnomalies:            return "sparkles"
        case .energyCoach:                 return "brain.head.profile"
        case .evNews:                      return "newspaper"
        case .evVsCarComparison:           return "arrow.left.arrow.right"
        case .evChargingVsGasTime:         return "clock"

        case .fastVsHomeImpact:            return "bolt.badge.clock"
        case .forecastChart:               return "chart.line.uptrend.xyaxis"
        case .forecastDashboard:           return "chart.line.uptrend.xyaxis"
        case .forecastWeekly:              return "chart.line.uptrend.xyaxis"
        case .whatIfForecast:              return "chart.line.uptrend.xyaxis"
        case .winterDrivingTechniques:     return "thermometer.snowflake"
        case .winterRangeImpactPlanner:    return "snowflake"

        case .gasTax:                      return "fuelpump"
        case .gasToKWhConverter:           return "arrow.left.arrow.right.circle"
        case .garage:                      return "car.2.fill"
        case .gridEmissionsForecast:       return "leaf.circle"

        case .historyOfTeslaAndRivian:     return "book"

        case .incentives:                  return "creditcard"
        case .publicIncentiveFinder:       return "creditcard"

        case .kWhRates:                    return "bolt"

        case .leaseMileage:                return "gauge"
        case .lemonLawGuide:              return "car.badge.exclamationmark"

        case .maintenanceGuides:           return "wrench.and.screwdriver.fill"
        case .mpgeCalculator:              return "gauge"
        case .rangeForecast:               return "gauge"
        case .materialsShift:              return "leaf"
        case .muscleCarShowdown:           return "flag.checkered"

        case .nearMe:                      return "location"
        case .nhtsaCrashReporting:         return "car.rear.and.tire.marks"
        case .superchargeInfoNearMe:       return "map.circle"
        case .homeVsPublicSplit:           return "chart.bar"

        case .paymentMethod:               return "creditcard"
        case .priceWatchlist:              return "tag"
        case .productPlateScannerArchive:  return "archivebox"

        case .quarterlyTaxSummary:         return "calendar"

        case .recalls:                     return "exclamationmark.triangle"
        case .reimbursementGenerator:      return "dollarsign.circle"
        case .resaleMarketplace:           return "cart"
        case .rivianVINDecoder:            return "textformat.123"
        case .teslaVINDecoder:             return "textformat.123"
        case .rightToRepair:               return "wrench.and.screwdriver.fill"

        case .savingsScore:                return "gauge.high"
        case .schedulePlanner:             return "clock.badge.checkmark"
        case .sessionConfidence:           return "checkmark.seal"
        case .duplicateResolver:           return "square.stack.3d.up"
        case .bestValueChargers:           return "bolt.circle"
        case .weeklyCostRollup:            return "calendar.badge.clock"
        case .batteryHealthTimeline:       return "battery.100percent"
        case .homeChargerOptimizer:        return "house.and.flag"
        case .monthlyBurnDown:             return "chart.bar"
        case .costPerMileVsGas:            return "gauge"
        case .insuranceFinanceTracker:     return "doc.text"
        case .tripBudgetPlanner:           return "suitcase.rolling"
        case .leaseVsBuyAnalyzer:          return "scale.3d"
        case .roadTaxEstimator:            return "fuelpump"
        case .stationQualityScore:         return "star.circle"
        case .chargeSpeedProfiler:         return "speedometer"
        case .tireMaintenanceTracker:      return "wrench.and.screwdriver"
        case .diyServiceVault:             return "photo.on.rectangle"
        case .netCostPerMile:              return "chart.bar.doc.horizontal"
        case .monthlyHeatmap:              return "calendar"
        case .shareableReports:            return "square.and.arrow.up"
        case .serviceReminders:            return "wrench.and.screwdriver"
        case .serviceInvoices:             return "doc.richtext"
        case .sessionAnalytics:            return "chart.xyaxis.line"
        case .sessionEfficiencyScatter:    return "chart.xyaxis.line"

        case .sparkPanel:                  return "sparkles"
        case .superChargerSessionCostCalculator: return "bolt.fill"
        case .superchargerLivePricePredictor: return "bolt.badge.clock"
        case .superchargerStops:           return "bolt.circle"

        case .tcoTimeline:                 return "clock.arrow.circlepath"
        case .taxTreatment:                return "scalemass"
        case .teslaOffer:                  return "gift"
        case .teslaOwnersClub:             return "person.3.fill"
        case .teslaServiceAlerts:          return "exclamationmark.bubble"
        case .teslaEPCPartsCatalog:        return "wrench.adjustable"
        case .altitudeCockpit:             return "mountain.2"
        case .weatherCockpit:              return "cloud.sun"
        case .tripCockpit:                 return "road.lanes"
        case .ticTacToe:                   return "grid"
        case .tripCostEstimator:           return "map"
        case .tripPlanner:                 return "map"
        case .tripLogger:                  return "road.lanes"

        case .annualCostSimulator:         return "calendar"
        case .unitConversion:              return "ruler"
        case .evLoanLeaseOptimizer:        return "percent"
        case .finance:                     return "banknote"
        case .weeklyHealthReport:          return "doc.text.magnifyingglass"

        case .weeklyEVVsGasCost:           return "fuelpump.and.filter"

        case .receiptOCR:                  return "doc.viewfinder"
        case .routeCostCompare:            return "arrow.left.arrow.right"
        case .tcoMonthlyTimeline:          return "calendar.badge.clock"
        case .chargingSafetyChecklist:     return "checklist"
        case .emergencyPackChecklist:      return "backpack"
        case .teslaInvoiceScan:            return "doc.text.magnifyingglass"
        case .libreNav:                    return "map.fill"
        case .routeDiscovery:              return "point.topleft.down.to.point.bottomright.curvepath.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .cheapestChargerShift:        return "Find the lowest-cost window"
        case .superchargerLivePricePredictor: return "Predict tiered pricing from occupancy"
        case .chargingEtiquette:           return "Quick stall courtesy guide"
        case .caughtaKWH:                  return "Catch missing kWh and suspicious rates"
        case .deliveryTracker:             return "Order stages, EDD countdown, VIN and build decode"
        case .deliveryChecklist:           return "Inspect the car before you sign"
        case .deepDepthShift:              return "Energy, cost, miles, and data quality"
        case .chartsBudget:                return "Budgets by month and category"
        case .gasToKWhConverter:           return "Compare gas and electric"
        case .evChargingVsGasTime:         return "Compare charging time vs fueling time"
        case .nearMe:                      return "Nearby chargers"
        case .nhtsaCrashReporting:         return "Federal ADS and Level 2 crash-reporting dataset"
        case .superchargeInfoNearMe:       return "Community Supercharger dataset"
        case .teslaServiceAlerts:          return "Scan and classify service alerts"
        case .teslaEPCPartsCatalog:        return "Search Tesla parts diagrams"
        case .rightToRepair:               return "Why repair access matters for EVs"
        case .lemonLawGuide:              return "NY, CA, FL & WA thresholds with repair tracker"
        case .dataQualityCenter:           return "Find spikes, duplicates, and outliers"
        case .winterDrivingTechniques:     return "Snow, ice, regen, and cold-weather tips"
        case .winterRangeImpactPlanner:    return "Temp, speed, HVAC impact"
        case .forecastDashboard:           return "Predict monthly costs"
        case .forecastWeekly:              return "Rolling 4-week projection"
        case .gridEmissionsForecast:       return "Cleaner local charging windows"
        case .kWhRates:                    return "Your home energy rates"
        case .homeVsPublicSplit:           return "Home vs public cost split"
        case .priceWatchlist:              return "Track manual price updates"
        case .savingsScore:                return "Score + habits to improve"
        case .schedulePlanner:             return "Plan off-peak charging windows"
        case .sessionConfidence:           return "Confidence score for sessions"
        case .duplicateResolver:           return "Resolve imported-session overlaps"
        case .bestValueChargers:           return "Cheapest $/kWh locations"
        case .weeklyCostRollup:            return "This week vs last week"
        case .batteryHealthTimeline:       return "Trend your charging health"
        case .homeChargerOptimizer:        return "Optimize TOU charging"
        case .monthlyBurnDown:             return "Projected month-end spend"
        case .evVsCarComparison:           return "Actual charging spend, gas equivalent, and mileage scenarios"
        case .costPerMileVsGas:            return "EV vs gas cost per mile"
        case .insuranceFinanceTracker:     return "Monthly payments + reminders"
        case .tripBudgetPlanner:           return "Route + lodging + charging cost"
        case .leaseVsBuyAnalyzer:          return "All-in cost comparison"
        case .roadTaxEstimator:            return "EV fee vs gas tax"
        case .stationQualityScore:         return "Crowd-rated reliability"
        case .chargeSpeedProfiler:         return "Speed vs SOC trend"
        case .tireMaintenanceTracker:      return "Tire and service history"
        case .diyServiceVault:             return "Receipts and photos"
        case .maintenanceGuides:           return "Step-by-step DIY procedures & specs"
        case .netCostPerMile:              return "True cost per mile"
        case .monthlyHeatmap:              return "Daily spend or kWh"
        case .shareableReports:            return "Share weekly summaries"
        case .tripCostEstimator:           return "Distance x efficiency x rate"
        case .annualCostSimulator:         return "Weekly averages to annual"
        case .weeklyHealthReport:          return "Best and worst sessions"
        case .garage:                      return "Vehicles, assumptions, presets"
        case .discounts:                   return "Affiliate and referral offers"
        case .evContent:                   return "Curated EV creators"
        case .weeklyEVVsGasCost:           return "Weekly cost using gas price & kWh rate"
        case .receiptOCR:                  return "Scan receipts to auto-fill"
        case .routeCostCompare:            return "Fast vs slow charging"
        case .tcoMonthlyTimeline:          return "Monthly ownership totals"
        case .chargingSafetyChecklist:     return "Quick safety steps"
        case .emergencyPackChecklist:      return "What to keep in your EV"
        case .teslaInvoiceScan:            return "Scan Supercharger invoices"
        case .altitudeCockpit:             return "Elevation profile notes"
        case .weatherCockpit:              return "Forecast details for route planning"
        case .tripCockpit:                 return "Distance, route, speed, and energy"
        case .ticTacToe:                   return "Quick two-player cabin game"
        case .libreNav:                    return "Turn-by-turn nav and charger discovery on open maps"
        case .routeDiscovery:              return "Browse shared driving routes and save favorites"
        default:                           return "Open tool"
        }
    }

}
