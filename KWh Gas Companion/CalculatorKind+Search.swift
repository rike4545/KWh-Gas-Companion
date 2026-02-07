//
//  CalculatorKind+Search.swift
//  KWh Gas Companion
//
//  Extracted from CalculatorsDashboardView for compile-time improvements.
//

import Foundation

extension CalculatorKind {

    var _calcDashCategory: CalcDashCategory {
        switch self {

        // Featured
        case .cheapestChargerShift, .forecastDashboard, .forecastWeekly, .deepDepthShift, .chartsBudget, .teslaFiCSVImport,
             .superchargeInfoNearMe,
             .teslaEPCPartsCatalog,
             .superchargerLivePricePredictor, .savingsScore:
            return .featured

        // Save Money & Manage Costs
        case .chargingBudgetGuard, .costBreakdownDetail, .costOfOwnershipAnalysis,
             .gasTax, .incentives, .publicIncentiveFinder, .reimbursementGenerator,
             .taxTreatment, .leaseMileage, .quarterlyTaxSummary,
             .superChargerSessionCostCalculator, .businessDeductionReport,
             .evLoanLeaseOptimizer, .finance, .energyCoach,
             .resaleMarketplace, .annualCostSimulator, .homeVsPublicSplit,
             .weeklyCostRollup, .monthlyBurnDown, .insuranceFinanceTracker,
             .tripBudgetPlanner, .leaseVsBuyAnalyzer, .roadTaxEstimator, .netCostPerMile,
             .discounts,
             .tcoMonthlyTimeline:
            return .saveMoney

        // Plan & Forecast
        case .forecastChart, .whatIfForecast, .rangeForecast, .kWhRates,
             .fastVsHomeImpact, .carbonImpactDashboard, .carbonOffset,
             .chargeTime, .superchargerStops, .tripPlanner, .schedulePlanner,
             .homeChargerOptimizer, .winterRangeImpactPlanner, .routeCostCompare:
            return .planAndForecast

        // Charging & Analytics
        case .analyticsCharts, .sessionAnalytics, .sessionEfficiencyScatter,
             .combinedChargeSession, .entriesAnomalies, .sparkPanel,
             .dataQualityCenter,
             .dynamicSuperchargingExplainer, .chargingDataStudio,
             .chargingDataIntegrity, .chargingReconciliation,
             .costPerKWhTrend, .priceWatchlist,
             .chargingEtiquette, .weeklyHealthReport,
             .sessionConfidence, .duplicateResolver, .bestValueChargers, .batteryHealthTimeline,
             .stationQualityScore, .chargeSpeedProfiler, .monthlyHeatmap, .shareableReports:
            return .chargingAndAnalytics

        // Compare & Decide
        case .carsVsEVCalculator, .evVsCarComparison, .evChargingVsGasTime, .tcoTimeline, .mpgeCalculator,
             .gasToKWhConverter, .muscleCarShowdown,
             .costPerMileAndCO2, .tripCostEstimator,
             .weeklyEVVsGasCost, .costPerMileVsGas:
            return .compareAndDecide

        // Data Import / Export
        case .csvChargingWizard, .csvExport, .receiptOCR:
            return .dataImportExport
        case .teslaInvoiceScan:
            return .dataImportExport

        // VIN & Vehicle Tools
        case .rivianVINDecoder, .teslaVINDecoder, .garage,
             .serviceReminders, .recalls, .accessoryTracker, .paymentMethod,
             .productPlateScannerArchive, .unitConversion, .serviceInvoices, .tripLogger,
             .winterDrivingTechniques, .tireMaintenanceTracker, .diyServiceVault,
             .chargingSafetyChecklist, .emergencyPackChecklist,
             .teslaServiceAlerts:
            return .vehicleTools

        // Maps
        case .nearMe:
            return .maps

        // Community
        case .teslaOwnersClub, .teslaOffer, .doGoodDonationShift:
            return .community

        // News & History
        case .evNews, .evContent, .historyOfTeslaAndRivian, .materialsShift, .rightToRepair:
            return .newsAndHistory

        }
    }

    var _calcDashSearchBlob: String {
        let extra: String
        switch self {
        case .cheapestChargerShift:
            extra = "cheap cheapest price pricing cost supercharger fast charge offpeak peak"
        case .superchargerLivePricePredictor:
            extra = "live price predictor occupancy stalls congestion tier low normal high idle fees"
        case .chargingEtiquette:
            extra = "etiquette tips courtesy queue move when done unplug idle fees busy station safety stall cable"
        case .gasToKWhConverter:
            extra = "gas gasoline mpg miles per gallon kwh electricity equivalence"
        case .evChargingVsGasTime:
            extra = "time compare charging vs gas fueling pump minutes hours stop duration"
        case .winterDrivingTechniques:
            extra = "winter snow ice cold driving tips traction braking regen preheat precondition tires chains defog black ice safe distance"
        case .teslaFiCSVImport:
            extra = "teslafi import csv sessions charging logs"
        case .nearMe:
            extra = "nearby map chargers supercharger stations location"
        case .superchargeInfoNearMe:
            extra = "supercharge.info community dataset map sites stalls open construction permit"
        case .teslaServiceAlerts:
            extra = "tesla service alerts warning code severity scanner ocr vision screenshot"
        case .dataQualityCenter:
            extra = "data quality duplicates outliers anomalies cleanup integrity spikes"
        case .teslaEPCPartsCatalog:
            extra = "tesla epc parts catalog part number pn oem diagrams exploded view assembly"
        case .rightToRepair:
            extra = "right to repair repairability independent repair parts tools diagnostics software pairing rich rebuilds"
        case .evContent:
            extra = "ev content youtube creators channels videos builds conversions mods reviews"
        case .discounts:
            extra = "discount discounts deals affiliate referral referrals accessories offers promo"
        case .serviceInvoices:
            extra = "pdf invoice receipt receipts documents"
        case .garage:
            extra = "vehicles vehicle profiles assumptions presets fleet"
        case .kWhRates:
            extra = "rates electric electricity tou time of use utility delivery supply"
        case .forecastDashboard, .whatIfForecast, .forecastChart:
            extra = "predict projection estimate model scenario planning"
        case .forecastWeekly:
            extra = "weekly forecast projection cost kwh trend"
        case .winterRangeImpactPlanner:
            extra = "winter range impact planner temperature speed hvac"
        case .teslaVINDecoder, .rivianVINDecoder:
            extra = "vin vehicle identification number decode wmi"
        case .homeVsPublicSplit:
            extra = "home public split cost share supercharger fast charging"
        case .priceWatchlist:
            extra = "watchlist price tracking charger favorite alerts"
        case .savingsScore:
            extra = "score savings habits cost efficiency"
        case .schedulePlanner:
            extra = "plan schedule off-peak time window utility rates"
        case .sessionConfidence:
            extra = "confidence score session quality completeness kwh cost location"
        case .duplicateResolver:
            extra = "duplicate resolver teslafi entries merge overlap cleanup"
        case .bestValueChargers:
            extra = "best value cheapest cost per kwh charger"
        case .weeklyCostRollup:
            extra = "weekly rollup week over week alerts threshold"
        case .batteryHealthTimeline:
            extra = "battery health timeline trend degradation estimate"
        case .homeChargerOptimizer:
            extra = "home charger optimizer tou rates offpeak peak schedule"
        case .monthlyBurnDown:
            extra = "monthly burn down projection budget pacing"
        case .costPerMileVsGas:
            extra = "cost per mile gas vs ev compare"
        case .insuranceFinanceTracker:
            extra = "insurance finance tracker loan lease payment monthly"
        case .tripBudgetPlanner:
            extra = "trip budget planner lodging nights charging total cost"
        case .leaseVsBuyAnalyzer:
            extra = "lease vs buy analyzer comparison resale apr payment"
        case .roadTaxEstimator:
            extra = "ev road tax gas tax fee state"
        case .stationQualityScore:
            extra = "station quality score reliability uptime rating"
        case .chargeSpeedProfiler:
            extra = "charge speed profiler soc kW peak average"
        case .tireMaintenanceTracker:
            extra = "tire maintenance tracker service history reminders"
        case .diyServiceVault:
            extra = "diy service vault receipts photos"
        case .netCostPerMile:
            extra = "net cost per mile depreciation insurance energy"
        case .monthlyHeatmap:
            extra = "monthly heatmap spend kwh calendar"
        case .shareableReports:
            extra = "shareable reports weekly health cost summary"
        case .receiptOCR:
            extra = "receipt scan ocr merchant amount date"
        case .routeCostCompare:
            extra = "route cost compare fast slow charging rate time"
        case .tcoMonthlyTimeline:
            extra = "tco timeline monthly ownership cost"
        case .chargingSafetyChecklist:
            extra = "charging safety checklist"
        case .emergencyPackChecklist:
            extra = "emergency pack checklist"
        case .teslaInvoiceScan:
            extra = "tesla invoice scan supercharger receipt pdf"
        case .tripCostEstimator:
            extra = "trip cost estimate distance efficiency rate"
        case .annualCostSimulator:
            extra = "annual cost simulate projection weekly average"
        case .weeklyHealthReport:
            extra = "weekly health report best worst sessions"
        case .weeklyEVVsGasCost:
            extra = "weekly cost gas price per gallon mpg miles kwh rate electricity compare savings"
        default:
            extra = ""
        }
        return "\(title) \(subtitle) \(rawValue) \(extra)"
    }
}
