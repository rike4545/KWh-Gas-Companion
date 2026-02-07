//
//  CalculatorKind.swift
//  KWh Gas Companion
//
//  Extracted from CalculatorsDashboardView for compile-time improvements.
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

    // H
    case historyOfTeslaAndRivian
    case homeVsPublicSplit

    // I
    case incentives

    // K
    case kWhRates

    // L
    case leaseMileage

    // M
    case mpgeCalculator
    case materialsShift
    case muscleCarShowdown

    // N
    case nearMe
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
    case teslaFiCSVImport
    case teslaOffer
    case teslaOwnersClub
    case teslaVINDecoder
    case teslaServiceAlerts
    case teslaEPCPartsCatalog
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

    // ✅ NEW
    case weeklyEVVsGasCost

    // ✅ NEW FEATURE PACK
    case receiptOCR
    case routeCostCompare
    case tcoMonthlyTimeline
    case chargingSafetyChecklist
    case emergencyPackChecklist
    case teslaInvoiceScan

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessoryTracker: return "Accessory Cost Tracker"
        case .analyticsCharts: return "Charging Analytics Charts"
        case .businessDeductionReport: return "Business Deduction Report"

        case .carbonImpactDashboard: return "Carbon Impact Dashboard"
        case .carbonOffset: return "Carbon Offset Calc."
        case .carsVsEVCalculator: return "Cars vs EV Calculator"
        case .chargeTime: return "Estimated Charging Time"
        case .chargingBudgetGuard: return "Charging Budget Guardrails"
        case .chargingDataStudio: return "Charging Data Studio"
        case .chargingDataIntegrity: return "Charging Data Integrity"
        case .chargingEtiquette: return "Charging Etiquette"
        case .chargingReconciliation: return "Charging Reconciliation"
        case .chartsBudget: return "Charts & Budget"
        case .cheapestChargerShift: return "Cheapest Charger Finder"
        case .combinedChargeSession: return "Combined Charge Session"
        case .costBreakdownDetail: return "Cost Breakdown"
        case .costOfOwnershipAnalysis: return "Cost of Ownership"
        case .costPerKWhTrend: return "Cost per kWh Trend"
        case .costPerMileAndCO2: return "$/Mile & CO₂"
        case .csvChargingWizard: return "CSV Charging Wizard"
        case .csvExport: return "CSV Export"

        case .deepDepthShift: return "Deep Analytics"
        case .dataQualityCenter: return "Data Quality Center"
        case .doGoodDonationShift: return "Shifting Do Good"
        case .discounts: return "Discounts & Referrals"
        case .evContent: return "EV Content"
        case .dynamicSuperchargingExplainer: return "Dynamic Supercharging vs TOU"

        case .entriesAnomalies: return "Expense Entry Anomalies"
        case .energyCoach: return "Energy Coach"
        case .evNews: return "EV News"
        case .evVsCarComparison: return "EV vs Car Cost Compare"
        case .evChargingVsGasTime: return "EV Charging vs Gas Time"

        case .fastVsHomeImpact: return "Fast vs Home Impact"
        case .forecastChart: return "Forecast Charts"
        case .forecastDashboard: return "Forecast Dashboard"
        case .forecastWeekly: return "Weekly Forecast"

        case .gasTax: return "Gas Tax"
        case .gasToKWhConverter: return "Gas → kWh Converter"
        case .garage: return "Garage & Vehicles"

        case .historyOfTeslaAndRivian: return "History: Tesla & Rivian"
        case .homeVsPublicSplit: return "Home vs Public Split"

        case .incentives: return "Incentives & Rebates"

        case .kWhRates: return "Energy Rates"

        case .leaseMileage: return "Lease Mileage Overage"

        case .mpgeCalculator: return "MPGe Calculator"
        case .materialsShift: return "EV Materials & Environment"
        case .muscleCarShowdown: return "EV vs Muscle Car Showdown"

        case .nearMe: return "Superchargers Near Me"
        case .superchargeInfoNearMe: return "Supercharge.info Near Me"

        case .paymentMethod: return "Third-Party Charging Plans"
        case .publicIncentiveFinder: return "Vehicle Incentive Finder"
        case .productPlateScannerArchive: return "Plate Scanner Archive"
        case .priceWatchlist: return "Price Watchlist"

        case .quarterlyTaxSummary: return "Quarterly Tax Summary"

        case .rangeForecast: return "Range Forecast"
        case .recalls: return "Recalls"
        case .reimbursementGenerator: return "Reimbursement Generator"
        case .resaleMarketplace: return "Secondary Market"
        case .rivianVINDecoder: return "Rivian VIN Decoder"
        case .rightToRepair: return "Right to Repair"

        case .savingsScore: return "Savings Score"
        case .schedulePlanner: return "Smart Charging Planner"
        case .sessionConfidence: return "Session Confidence"
        case .duplicateResolver: return "Duplicate Resolver"
        case .bestValueChargers: return "Best Value Chargers"
        case .weeklyCostRollup: return "Weekly Cost Rollup"
        case .batteryHealthTimeline: return "Battery Health Timeline"
        case .homeChargerOptimizer: return "Home Charger Optimizer"
        case .monthlyBurnDown: return "Monthly Burn‑Down"
        case .costPerMileVsGas: return "Cost per Mile vs Gas"
        case .insuranceFinanceTracker: return "Insurance & Finance Tracker"
        case .tripBudgetPlanner: return "Trip Budget Planner"
        case .leaseVsBuyAnalyzer: return "Lease vs Buy Analyzer"
        case .roadTaxEstimator: return "EV Road‑Tax Estimator"
        case .stationQualityScore: return "Station Quality Score"
        case .chargeSpeedProfiler: return "Charge Speed Profiler"
        case .tireMaintenanceTracker: return "Tire & Maintenance Tracker"
        case .diyServiceVault: return "DIY Service Vault"
        case .netCostPerMile: return "Net Cost per Mile"
        case .monthlyHeatmap: return "Monthly Heatmap"
        case .shareableReports: return "Shareable Reports"

        case .serviceReminders: return "Service Reminders"
        case .serviceInvoices: return "Service Invoices (PDF)"
        case .sessionAnalytics: return "Session Analytics"
        case .sessionEfficiencyScatter: return "Efficiency Scatter"
        case .sparkPanel: return "Spark: AI Summary"
        case .superChargerSessionCostCalculator: return "Supercharger Cost Calc"
        case .superchargerLivePricePredictor: return "Supercharger Live Price Predictor"
        case .superchargerStops: return "Plan Supercharger Stops"

        case .tcoTimeline: return "TCO Timeline"
        case .taxTreatment: return "Tax Treatment"
        case .teslaFiCSVImport: return "Import TeslaFi CSV"
        case .teslaOffer: return "Tesla Offers"
        case .teslaOwnersClub: return "Tesla Owners Club"
        case .teslaVINDecoder: return "Tesla VIN Decoder"
        case .teslaServiceAlerts: return "Tesla Service Alerts"
        case .teslaEPCPartsCatalog: return "Tesla EPC Parts Catalog"
        case .tripCostEstimator: return "Trip Cost Estimator"
        case .tripPlanner: return "Trip Planner"
        case .tripLogger: return "Trip Logger"

        case .unitConversion: return "Unit Conversion"
        case .evLoanLeaseOptimizer: return "EV Loan/Lease Optimizer"
        case .finance: return "Finance"
        case .annualCostSimulator: return "Annual Cost Simulator"
        case .weeklyHealthReport: return "Weekly Health Report"

        case .winterDrivingTechniques: return "Winter Driving Techniques"
        case .winterRangeImpactPlanner: return "Winter Range Impact"
        case .whatIfForecast: return "What-If Forecast"

        // ✅ NEW
        case .weeklyEVVsGasCost: return "Weekly EV vs Gas"

        case .receiptOCR: return "Receipt Scan (OCR)"
        case .routeCostCompare: return "Route Cost Compare"
        case .tcoMonthlyTimeline: return "TCO Timeline (Monthly)"
        case .chargingSafetyChecklist: return "Charging Safety Checklist"
        case .emergencyPackChecklist: return "Emergency Pack Checklist"
        case .teslaInvoiceScan: return "Tesla Invoice Scan"
        }
    }

    public var systemImage: String {
        switch self {
        case .accessoryTracker: return "shippingbox"
        case .analyticsCharts: return "chart.pie"
        case .businessDeductionReport: return "doc.text"

        case .carbonImpactDashboard: return "leaf.circle"
        case .carbonOffset: return "leaf.arrow.circlepath"
        case .carsVsEVCalculator: return "car.2"
        case .chargeTime: return "timer"
        case .chargingBudgetGuard: return "shield.lefthalf.filled"
        case .chargingDataStudio: return "tablecells"
        case .chargingDataIntegrity: return "checkmark.shield"
        case .chargingEtiquette: return "hand.raised"
        case .chargingReconciliation: return "arrow.triangle.2.circlepath"
        case .chartsBudget: return "chart.bar.xaxis"
        case .cheapestChargerShift: return "bolt.circle"
        case .combinedChargeSession: return "bolt.circle"
        case .costBreakdownDetail: return "square.grid.2x2"
        case .costOfOwnershipAnalysis: return "wallet.pass"
        case .costPerKWhTrend: return "bolt.fill"
        case .costPerMileAndCO2: return "leaf"
        case .csvChargingWizard: return "tray.and.arrow.down"
        case .csvExport: return "square.and.arrow.up"

        case .deepDepthShift: return "brain"
        case .dataQualityCenter: return "checkmark.shield"
        case .doGoodDonationShift: return "heart"
        case .discounts: return "tag"
        case .evContent: return "play.rectangle"
        case .dynamicSuperchargingExplainer: return "bolt.badge.clock"

        case .entriesAnomalies: return "sparkles"
        case .energyCoach: return "brain.head.profile"
        case .evNews: return "newspaper"
        case .evVsCarComparison: return "arrow.left.arrow.right"
        case .evChargingVsGasTime: return "clock"

        case .fastVsHomeImpact: return "bolt.badge.clock"
        case .forecastChart, .forecastDashboard, .forecastWeekly, .whatIfForecast: return "chart.line.uptrend.xyaxis"
        case .winterDrivingTechniques: return "thermometer.snowflake"
        case .winterRangeImpactPlanner: return "snowflake"

        case .gasTax: return "fuelpump"
        case .gasToKWhConverter: return "arrow.left.arrow.right.circle"
        case .garage: return "car.2.fill"

        case .historyOfTeslaAndRivian: return "book"

        case .incentives, .publicIncentiveFinder: return "creditcard"

        case .kWhRates: return "bolt"

        case .leaseMileage, .mpgeCalculator, .rangeForecast: return "gauge"

        case .materialsShift: return "leaf"
        case .muscleCarShowdown: return "flag.checkered"

        case .nearMe: return "location"
        case .superchargeInfoNearMe: return "map.circle"
        case .homeVsPublicSplit: return "chart.bar"

        case .paymentMethod: return "creditcard"
        case .priceWatchlist: return "tag"
        case .productPlateScannerArchive: return "archivebox"

        case .quarterlyTaxSummary: return "calendar"

        case .recalls: return "exclamationmark.triangle"
        case .reimbursementGenerator: return "dollarsign.circle"
        case .resaleMarketplace: return "cart"
        case .rivianVINDecoder, .teslaVINDecoder: return "textformat.123"
        case .rightToRepair: return "wrench.and.screwdriver.fill"

        case .savingsScore: return "gauge.high"
        case .schedulePlanner: return "clock.badge.checkmark"
        case .sessionConfidence: return "checkmark.seal"
        case .duplicateResolver: return "square.stack.3d.up"
        case .bestValueChargers: return "bolt.circle"
        case .weeklyCostRollup: return "calendar.badge.clock"
        case .batteryHealthTimeline: return "battery.100percent"
        case .homeChargerOptimizer: return "house.and.flag"
        case .monthlyBurnDown: return "chart.bar"
        case .costPerMileVsGas: return "gauge"
        case .insuranceFinanceTracker: return "doc.text"
        case .tripBudgetPlanner: return "suitcase.rolling"
        case .leaseVsBuyAnalyzer: return "scale.3d"
        case .roadTaxEstimator: return "fuelpump"
        case .stationQualityScore: return "star.circle"
        case .chargeSpeedProfiler: return "speedometer"
        case .tireMaintenanceTracker: return "wrench.and.screwdriver"
        case .diyServiceVault: return "photo.on.rectangle"
        case .netCostPerMile: return "chart.bar.doc.horizontal"
        case .monthlyHeatmap: return "calendar"
        case .shareableReports: return "square.and.arrow.up"
        case .serviceReminders: return "wrench.and.screwdriver"
        case .serviceInvoices: return "doc.richtext"

        case .sessionAnalytics, .sessionEfficiencyScatter: return "chart.xyaxis.line"

        case .sparkPanel: return "sparkles"
        case .superChargerSessionCostCalculator: return "bolt.fill"
        case .superchargerLivePricePredictor: return "bolt.badge.clock"
        case .superchargerStops: return "bolt.circle"

        case .tcoTimeline: return "clock.arrow.circlepath"
        case .taxTreatment: return "scalemass"
        case .teslaFiCSVImport: return "tray.and.arrow.down"
        case .teslaOffer: return "gift"
        case .teslaOwnersClub: return "person.3.fill"
        case .teslaServiceAlerts: return "exclamationmark.bubble"
        case .teslaEPCPartsCatalog: return "wrench.adjustable"
        case .tripCostEstimator: return "map"
        case .tripPlanner: return "map"
        case .tripLogger: return "road.lanes"

        case .annualCostSimulator: return "calendar"
        case .unitConversion: return "ruler"
        case .evLoanLeaseOptimizer: return "percent"
        case .finance: return "banknote"
        case .weeklyHealthReport: return "doc.text.magnifyingglass"

        // ✅ NEW
        case .weeklyEVVsGasCost: return "fuelpump.and.filter"

        case .receiptOCR: return "doc.viewfinder"
        case .routeCostCompare: return "arrow.left.arrow.right"
        case .tcoMonthlyTimeline: return "calendar.badge.clock"
        case .chargingSafetyChecklist: return "checklist"
        case .emergencyPackChecklist: return "backpack"
        case .teslaInvoiceScan: return "doc.text.magnifyingglass"
        }
    }

    public var subtitle: String {
        switch self {
        case .cheapestChargerShift: return "Find the lowest-cost window"
        case .superchargerLivePricePredictor: return "Predict tiered pricing from occupancy"
        case .chargingEtiquette: return "Quick stall courtesy guide"
        case .deepDepthShift: return "Energy, cost, miles, and data quality"
        case .chartsBudget: return "Budgets by month and category"
        case .teslaFiCSVImport: return "Import charging sessions"
        case .gasToKWhConverter: return "Compare gas and electric"
        case .evChargingVsGasTime: return "Compare charging time vs fueling time"
        case .nearMe: return "Nearby chargers"
        case .superchargeInfoNearMe: return "Community Supercharger dataset"
        case .teslaServiceAlerts: return "Scan and classify service alerts"
        case .teslaEPCPartsCatalog: return "Search Tesla parts diagrams"
        case .rightToRepair: return "Why repair access matters for EVs"
        case .dataQualityCenter: return "Find spikes, duplicates, and outliers"
        case .winterDrivingTechniques: return "Snow, ice, regen, and cold-weather tips"
        case .winterRangeImpactPlanner: return "Temp, speed, HVAC impact"
        case .forecastDashboard: return "Predict monthly costs"
        case .forecastWeekly: return "Rolling 4-week projection"
        case .kWhRates: return "Your home energy rates"
        case .homeVsPublicSplit: return "Home vs public cost split"
        case .priceWatchlist: return "Track manual price updates"
        case .savingsScore: return "Score + habits to improve"
        case .schedulePlanner: return "Plan off-peak charging windows"
        case .sessionConfidence: return "Confidence score for sessions"
        case .duplicateResolver: return "Resolve TeslaFi vs entry overlaps"
        case .bestValueChargers: return "Cheapest $/kWh locations"
        case .weeklyCostRollup: return "This week vs last week"
        case .batteryHealthTimeline: return "Trend your charging health"
        case .homeChargerOptimizer: return "Optimize TOU charging"
        case .monthlyBurnDown: return "Projected month-end spend"
        case .costPerMileVsGas: return "EV vs gas cost per mile"
        case .insuranceFinanceTracker: return "Monthly payments + reminders"
        case .tripBudgetPlanner: return "Route + lodging + charging cost"
        case .leaseVsBuyAnalyzer: return "All‑in cost comparison"
        case .roadTaxEstimator: return "EV fee vs gas tax"
        case .stationQualityScore: return "Crowd‑rated reliability"
        case .chargeSpeedProfiler: return "Speed vs SOC trend"
        case .tireMaintenanceTracker: return "Tire and service history"
        case .diyServiceVault: return "Receipts and photos"
        case .netCostPerMile: return "True cost per mile"
        case .monthlyHeatmap: return "Daily spend or kWh"
        case .shareableReports: return "Share weekly summaries"
        case .tripCostEstimator: return "Distance × efficiency × rate"
        case .annualCostSimulator: return "Weekly averages to annual"
        case .weeklyHealthReport: return "Best and worst sessions"
        case .garage: return "Vehicles, assumptions, presets"
        case .discounts: return "Affiliate and referral offers"
        case .evContent: return "Curated EV creators"

        // ✅ NEW
        case .weeklyEVVsGasCost: return "Weekly cost using gas price & kWh rate"

        case .receiptOCR: return "Scan receipts to auto-fill"
        case .routeCostCompare: return "Fast vs slow charging"
        case .tcoMonthlyTimeline: return "Monthly ownership totals"
        case .chargingSafetyChecklist: return "Quick safety steps"
        case .emergencyPackChecklist: return "What to keep in your EV"
        case .teslaInvoiceScan: return "Scan Supercharger invoices"

        default: return "Open tool"
        }
    }
}
