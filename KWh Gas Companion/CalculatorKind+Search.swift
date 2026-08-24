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
        case .cheapestChargerShift, .forecastDashboard, .forecastWeekly, .gridEmissionsForecast, .deepDepthShift, .chartsBudget,
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
             .homeChargerOptimizer, .winterRangeImpactPlanner, .routeCostCompare,
             .libreNav, .routeDiscovery:
            return .planAndForecast

        // Charging & Analytics
        case .analyticsCharts, .sessionAnalytics, .sessionEfficiencyScatter,
             .combinedChargeSession, .entriesAnomalies, .sparkPanel,
             .dataQualityCenter,
             .dynamicSuperchargingExplainer, .chargingDataStudio,
             .chargingDataIntegrity, .chargingReconciliation,
             .caughtaKWH, .costPerKWhTrend, .priceWatchlist,
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
             .maintenanceGuides,
             .deliveryTracker, .deliveryChecklist,
             .chargingSafetyChecklist, .emergencyPackChecklist,
             .teslaServiceAlerts, .altitudeCockpit, .weatherCockpit, .tripCockpit, .ticTacToe:
            return .vehicleTools

        // Maps
        case .nearMe:
            return .maps

        // Community
        case .teslaOwnersClub, .teslaOffer, .doGoodDonationShift:
            return .community

        // News & History
        case .evNews, .evContent, .historyOfTeslaAndRivian, .materialsShift,
             .rightToRepair, .lemonLawGuide, .nhtsaCrashReporting:
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
        case .routeDiscovery:
            extra = "route discovery shared routes drives scenic backroads community favorites saved trips explore browse road trip"
        case .libreNav:
            extra = "librenav navigation navigate turn by turn directions route map openstreetmap osm gps guidance trip planner waypoints chargers discovery voice eta"
        case .nearMe:
            extra = "nearby map chargers supercharger stations location"
        case .superchargeInfoNearMe:
            extra = "supercharge.info community dataset map sites stalls open construction permit"
        case .nhtsaCrashReporting:
            extra = "nhtsa crash reporting standing general order sgo ads level 2 adas autonomous autopilot crash data federal investigation reporting limitations comparison caveats"
        case .teslaServiceAlerts:
            extra = "tesla service alerts warning code severity scanner ocr vision screenshot"
        case .dataQualityCenter:
            extra = "data quality duplicates outliers anomalies cleanup integrity spikes"
        case .caughtaKWH:
            extra = "caught kwh catch missing energy high rate suspicious charging rows cost per kwh anomaly cleanup outlier data quality"
        case .teslaEPCPartsCatalog:
            extra = "tesla epc parts catalog part number pn oem diagrams exploded view assembly"
        case .rightToRepair:
            extra = "right to repair repairability independent repair parts tools diagnostics software pairing rich rebuilds"
        case .lemonLawGuide:
            extra = "lemon law defective vehicle repair refund replacement ny new york ca california fl florida wa washington arbitration attorney consumer protection warranty qualifying repairs days out of service threshold buyback repurchase dealer manufacturer state rights"
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
        case .gridEmissionsForecast:
            extra = "grid emissions forecast watttime marginal emissions moer co2 clean charging green red carbon heavy flexible load laundry home battery project clean grid"
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
        case .maintenanceGuides:
            extra = "diy maintenance guides how to tutorial step by step tire rotation pattern directional staggered square lug nut torque 129 lb ft 175 nm 21mm star pattern jack pads lift pucks cabin air filter swap t20 torx trim tool footwell glovebox airflow arrow frunk filter housing ten screws radiator cleaning debris shop vac fins 10mm needle nose service mode red border diagnostics tpms low voltage high voltage thermal hvac alerts home charging setup schedule weekday weekend off peak time of use rates charge stats wheel torque reference juniper 18 19 20 21 inch"
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
        case .deliveryTracker:
            extra = "delivery status tracker tesla order rn reference number edd estimated delivery date window countdown vin assigned assignment production built factory in transit shipping delivery center appointment handover order status booked routing location odometer mktoptions option codes build sheet spec viewer change log history waiting queue"
        case .deliveryChecklist:
            extra = "delivery day checklist inspection inspect new car acceptance panel gap paint defect walk around punch list due bill exterior interior functionality software charging documentation test drive extras photos notes pdf export advisor sign paperwork vin match handover"
        case .chargingSafetyChecklist:
            extra = "charging safety checklist"
        case .emergencyPackChecklist:
            extra = "emergency pack checklist"
        case .teslaInvoiceScan:
            extra = "tesla invoice scan supercharger receipt pdf"
        case .altitudeCockpit:
            extra = "tes app altitude cockpit elevation profile mountain route grade height record"
        case .weatherCockpit:
            extra = "tes app weather forecast humidity wind temperature rain route"
        case .tripCockpit:
            extra = "tes app trip cockpit record route distance average speed energy stops"
        case .ticTacToe:
            extra = "tes app game tic tac toe cabin parked charging two player"
        case .evVsCarComparison:
            extra = "compare comparison gas fuel gasoline current total charging spend actual logged distance preset miles 1500 5000 15000 20000 25000 custom miles annual yearly weekly budget co2 cost per mile"
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
