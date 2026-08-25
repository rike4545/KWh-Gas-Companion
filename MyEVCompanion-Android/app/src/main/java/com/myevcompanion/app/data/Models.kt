package com.myevcompanion.app.data

import androidx.compose.ui.graphics.Color
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.UUID

enum class ThemeMode {
    LIGHT,
    DARK,
    SYSTEM
}

enum class EntryCategory(
    val label: String,
    val tint: Color
) {
    Charging("Charging", Color(0xFF00C48C)),
    Insurance("Insurance", Color(0xFF2D7FF9)),
    Maintenance("Maintenance", Color(0xFFFF8A3D)),
    Lease("Lease", Color(0xFFFFC145)),
    Accessories("Accessories", Color(0xFF8A7CFF)),
    Registration("Registration", Color(0xFFEF5350)),
    Tires("Tires", Color(0xFF8D6E63)),
    Parking("Parking", Color(0xFF26A69A)),
    Tolls("Tolls", Color(0xFF5C6BC0)),
    Other("Other", Color(0xFF90A4AE))
}

data class VehicleProfile(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val make: String,
    val model: String,
    val year: Int,
    val vin: String,
    val plateOrMarker: String,
    val isEv: Boolean,
    val batteryCapacityKWh: Double,
    val efficiencyWhPerMile: Double,
    val estimatedRangeMiles: Double,
    val accent: Color,
    val notes: String = ""
)

data class ExpenseEntry(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val category: EntryCategory,
    val amount: Double,
    val energyKWh: Double? = null,
    val date: LocalDate,
    val location: String,
    val vehicleId: String,
    val notes: String = ""
)

data class ChargingSession(
    val id: String = UUID.randomUUID().toString(),
    val vehicleId: String,
    val stationName: String,
    val provider: String,
    val startedAt: LocalDateTime,
    val endedAt: LocalDateTime,
    val energyAddedKWh: Double,
    val cost: Double,
    val startSoc: Int,
    val endSoc: Int,
    val maxPowerKw: Int,
    val isSupercharger: Boolean
)

data class ToolCard(
    val title: String,
    val description: String,
    val group: String,
    val accent: Color
)

data class PricingSpotlight(
    val provider: String,
    val pricePerKwh: Double,
    val summary: String
)

data class DashboardInsight(
    val title: String,
    val body: String,
    val scoreLabel: String
)

data class ChargingMlInsight(
    val summary: String,
    val confidenceLabel: String,
    val sampleCount: Int,
    val trendLabel: String,
    val nextSessionCost: Double?,
    val nextSessionEnergyKwh: Double?,
    val typicalCostPerKwh: Double?,
    val priciestProvider: String,
    val anomalyLabel: String,
    val strongestSignals: List<Pair<String, String>>,
    val providerForecasts: List<Pair<String, String>>,
    val anomalyCandidates: List<Pair<String, String>>
)

data class MonthlyBudget(
    val monthlyLimit: Double,
    val targetKwh: Double,
    val targetSessions: Int
)

data class DashboardSnapshot(
    val totalSpend: Double,
    val energyThisMonth: Double,
    val avgCostPerKwh: Double,
    val sessionCount: Int,
    val topProvider: String,
    val activeVehicle: VehicleProfile?,
    val recentSessions: List<ChargingSession>,
    val recentEntries: List<ExpenseEntry>,
    val insights: List<DashboardInsight>,
    val chargingMlInsight: ChargingMlInsight
)

internal object SampleData {
    val vehicles = listOf(
        VehicleProfile(
            name = "Midnight Model Y",
            make = "Tesla",
            model = "Model Y Long Range",
            year = 2024,
            vin = "7SAYGDEE7RF123456",
            plateOrMarker = "KWH 247",
            isEv = true,
            batteryCapacityKWh = 81.0,
            efficiencyWhPerMile = 257.0,
            estimatedRangeMiles = 308.0,
            accent = Color(0xFF16C79A),
            notes = "Primary family EV with home charging and occasional Supercharger runs."
        ),
        VehicleProfile(
            name = "Hudson R1T",
            make = "Rivian",
            model = "R1T Adventure",
            year = 2023,
            vin = "7FCTGAAA1PN765432",
            plateOrMarker = "RIV 845",
            isEv = true,
            batteryCapacityKWh = 135.0,
            efficiencyWhPerMile = 452.0,
            estimatedRangeMiles = 315.0,
            accent = Color(0xFFFFB84D),
            notes = "Weekend hauler with a bigger battery and higher road-trip costs."
        )
    )

    val entries = listOf(
        ExpenseEntry(
            title = "Home charging top-up",
            category = EntryCategory.Charging,
            amount = 18.60,
            energyKWh = 42.0,
            date = LocalDate.now().minusDays(1),
            location = "Brooklyn garage",
            vehicleId = vehicles[0].id,
            notes = "Overnight off-peak window."
        ),
        ExpenseEntry(
            title = "Supercharger in Newark",
            category = EntryCategory.Charging,
            amount = 24.15,
            energyKWh = 38.5,
            date = LocalDate.now().minusDays(3),
            location = "Newark V3",
            vehicleId = vehicles[0].id,
            notes = "Road-trip fast charge."
        ),
        ExpenseEntry(
            title = "Tire rotation",
            category = EntryCategory.Maintenance,
            amount = 69.00,
            date = LocalDate.now().minusDays(9),
            location = "Queens service center",
            vehicleId = vehicles[0].id
        ),
        ExpenseEntry(
            title = "Insurance payment",
            category = EntryCategory.Insurance,
            amount = 182.42,
            date = LocalDate.now().minusDays(12),
            location = "Policy autopay",
            vehicleId = vehicles[1].id
        ),
        ExpenseEntry(
            title = "Bed rack accessories",
            category = EntryCategory.Accessories,
            amount = 249.99,
            date = LocalDate.now().minusDays(18),
            location = "Adventure shop",
            vehicleId = vehicles[1].id
        )
    )

    val sessions = listOf(
        ChargingSession(
            vehicleId = vehicles[0].id,
            stationName = "Brooklyn Garage",
            provider = "Home",
            startedAt = LocalDateTime.of(LocalDate.now().minusDays(1), LocalTime.of(22, 20)),
            endedAt = LocalDateTime.of(LocalDate.now(), LocalTime.of(5, 48)),
            energyAddedKWh = 42.0,
            cost = 18.60,
            startSoc = 22,
            endSoc = 79,
            maxPowerKw = 11,
            isSupercharger = false
        ),
        ChargingSession(
            vehicleId = vehicles[0].id,
            stationName = "Newark V3",
            provider = "Tesla Supercharger",
            startedAt = LocalDateTime.of(LocalDate.now().minusDays(3), LocalTime.of(17, 5)),
            endedAt = LocalDateTime.of(LocalDate.now().minusDays(3), LocalTime.of(17, 41)),
            energyAddedKWh = 38.5,
            cost = 24.15,
            startSoc = 18,
            endSoc = 71,
            maxPowerKw = 250,
            isSupercharger = true
        ),
        ChargingSession(
            vehicleId = vehicles[1].id,
            stationName = "Kingston Rivian Waypoint",
            provider = "Rivian Adventure",
            startedAt = LocalDateTime.of(LocalDate.now().minusDays(6), LocalTime.of(14, 10)),
            endedAt = LocalDateTime.of(LocalDate.now().minusDays(6), LocalTime.of(16, 5)),
            energyAddedKWh = 52.2,
            cost = 27.41,
            startSoc = 31,
            endSoc = 74,
            maxPowerKw = 125,
            isSupercharger = false
        )
    )

    val tools = listOf(
        ToolCard("Trip Planner", "Balance range, charge stops, and overnight cost.", "Planning", Color(0xFF16C79A)),
        ToolCard("Gas to kWh", "Translate legacy gas spend into EV energy terms.", "Everyday", Color(0xFF2D7FF9)),
        ToolCard("MPGe Lens", "Estimate efficiency and compare across vehicles.", "Everyday", Color(0xFFFF8A3D)),
        ToolCard("Lease vs Buy", "Model ownership tradeoffs over time.", "Finance", Color(0xFFFFC145)),
        ToolCard("Battery Health", "Track charging behavior and long-term degradation signals.", "Diagnostics", Color(0xFF8A7CFF)),
        ToolCard("Public Incentives", "Keep a shortlist of rebates and policy wins.", "Research", Color(0xFF00A6A6)),
        ToolCard("Trip Budget Planner", "Estimate lodging, charging, tolls, and total road-trip cost before you leave.", "Planning", Color(0xFF35B36E)),
        ToolCard("Trip Cost Estimator", "Compare route energy spend across weather, speeds, and charging strategies.", "Planning", Color(0xFF1FA187)),
        ToolCard("Range Forecast", "Project usable range from your recent efficiency and charging behavior.", "Planning", Color(0xFF2A9D8F)),
        ToolCard("Forecast Dashboard", "See weekly and monthly charging forecasts built from your saved history.", "Planning", Color(0xFF3C9AFF)),
        ToolCard("Grid Emissions Forecast", "Find cleaner local charging windows with WattTime-style real-time and 24-hour grid emissions signals.", "Planning", Color(0xFF1B998B)),
        ToolCard("Charging Data Studio", "Explore imported charging history with more analyst-style summaries and drilldowns.", "Charging Intelligence", Color(0xFF4CC9F0)),
        ToolCard("TeslaFi Mobile Dashboard", "Review TeslaFi-style drive and charge summaries from imported sessions.", "Charging Intelligence", Color(0xFF118AB2)),
        ToolCard("TeslaMate Mobile Dashboard", "Review TesLog-style live status, battery, and charging summaries from imported or connected data.", "Charging Intelligence", Color(0xFF2C7DA0)),
        ToolCard("ML Charge Forecast", "Use a tiny on-device neural net to forecast the next charge and catch pricing outliers.", "Charging Intelligence", Color(0xFF3F8EFC)),
        ToolCard("Charging Reconciliation", "Compare ledger entries against imported charging feeds and catch mismatches.", "Charging Intelligence", Color(0xFF4895EF)),
        ToolCard("CaughtaKWH", "Catch missing kWh, high-rate sessions, and suspicious charging rows before they skew your totals.", "Charging Intelligence", Color(0xFFEF476F)),
        ToolCard("Cost per kWh Trend", "Track how your effective energy price shifts over time and provider.", "Charging Intelligence", Color(0xFF4361EE)),
        ToolCard("Best Value Chargers", "Surface the sites and providers that delivered the best cost efficiency.", "Charging Intelligence", Color(0xFF3A86FF)),
        ToolCard("Session Analytics", "Review charging session patterns, energy curves, and spend concentration.", "Charging Intelligence", Color(0xFF577590)),
        ToolCard("Price Watchlist", "Track noteworthy charging prices and manual spot checks across providers.", "Charging Intelligence", Color(0xFF277DA1)),
        ToolCard("Charging Budget Guard", "Set guardrails for monthly charging spend and session targets.", "Finance", Color(0xFFF4A261)),
        ToolCard("Quarterly Tax Summary", "Roll up expenses into a quarter-by-quarter tax-friendly ownership snapshot.", "Finance", Color(0xFFE9C46A)),
        ToolCard("Reimbursement Generator", "Prepare charging and business-use reimbursement summaries from saved entries.", "Finance", Color(0xFFE76F51)),
        ToolCard("Insurance & Finance Tracker", "Keep financing, insurance, and recurring vehicle costs in one lens.", "Finance", Color(0xFFF28482)),
        ToolCard("Cost of Ownership", "Blend charging, maintenance, insurance, and extras into one ownership view.", "Finance", Color(0xFFF6BD60)),
        ToolCard("Battery Health Timeline", "Watch battery-related trends across months instead of isolated sessions.", "Vehicle Intelligence", Color(0xFF9B5DE5)),
        ToolCard("Home Charger Optimizer", "Compare home charging assumptions, rates, and hardware scenarios.", "Vehicle Intelligence", Color(0xFFB565D9)),
        ToolCard("Safety Score Predictor", "Estimate a rough driver-safety score from the limited trip-timing signals currently stored in the app.", "Vehicle Intelligence", Color(0xFFA06CD5)),
        ToolCard("Tesla VIN Decoder", "Decode Tesla VIN details quickly from the garage workflow.", "Vehicle Intelligence", Color(0xFF7B2CBF)),
        ToolCard("Rivian VIN Decoder", "Mirror the iOS VIN utilities for Rivian profiles too.", "Vehicle Intelligence", Color(0xFF6A4C93)),
        ToolCard("Altitude Cockpit", "Record elevation snapshots and altitude profile context for mountain drives.", "Tesla Display Apps", Color(0xFF3A86FF)),
        ToolCard("Weather Cockpit", "Review route-weather details like temperature, wind, humidity, and charging impact.", "Tesla Display Apps", Color(0xFF00B4D8)),
        ToolCard("Trip Cockpit", "Capture route, distance, average speed, energy, and stop notes in one trip view.", "Tesla Display Apps", Color(0xFF06D6A0)),
        ToolCard("Tic Tac Toe", "Play a quick no-login cabin game inspired by browser apps for Tesla displays.", "Tesla Display Apps", Color(0xFFFFBE0B)),
        ToolCard("Direct Connection Dashboard", "Mirror the iOS direct-connection dashboard with endpoint, token, charge, drive, and geofence context.", "Connected Vehicle", Color(0xFF0A84FF)),
        ToolCard("Direct Connection Setup", "Keep the iOS setup-guide flow discoverable on Android for TeslaMate-style endpoints and proxy tokens.", "Connected Vehicle", Color(0xFF5E5CE6)),
        ToolCard("Widgets & Charge Status", "Track the Android counterpart for iOS widgets and Live Activities around current charge state.", "Connected Vehicle", Color(0xFF34C759)),
        ToolCard("Agent Assistant", "Surface the iOS agent workspace as an Android summary, action, and diagnostics companion.", "Reporting", Color(0xFFAF52DE)),
        ToolCard("Import Hub Onboarding", "Explain the same iOS import-first onboarding path for Tesla billing, charging, and expense CSVs.", "Reporting", Color(0xFFFF9F0A)),
        ToolCard("History: Tesla & Rivian", "Browse brand history context alongside ownership and comparison tools.", "Research", Color(0xFF0081A7)),
        ToolCard("EV News", "Keep current EV news and market context close to the planning tools.", "Research", Color(0xFF00AFB9)),
        ToolCard("NHTSA Crash Reporting", "Review the federal Standing General Order crash-reporting dataset and its limitations.", "Research", Color(0xFF2C7DA0)),
        ToolCard("Recalls", "Check recall-oriented research utilities from the iOS tool lineup.", "Research", Color(0xFF118AB2)),
        ToolCard("Right to Repair", "Surface repair-rights context and policy tools from the iOS app.", "Research", Color(0xFF0EAD69)),
        ToolCard("Lemon Law Guide", "Keep the consumer-protection guidance tools discoverable on Android too.", "Research", Color(0xFF06D6A0)),
        ToolCard("Service Reminders", "Track recurring maintenance and service touchpoints from the same garage context.", "Maintenance", Color(0xFFBC6C25)),
        ToolCard("Service Invoices", "Organize service invoice workflows alongside manual expense tracking.", "Maintenance", Color(0xFFD4A373)),
        ToolCard("Tire & Maintenance Tracker", "Track tires, rotations, and recurring maintenance costs over time.", "Maintenance", Color(0xFFB08968)),
        ToolCard("DIY Service Vault", "Keep self-service records and related costs together with the ownership ledger.", "Maintenance", Color(0xFF9C6644)),
        ToolCard("Shareable Reports", "Prepare cleaner summaries from saved charging and expense history.", "Reporting", Color(0xFF5E60CE)),
        ToolCard("Weekly Cost Rollup", "Summarize recent spend in a compact weekly reporting view.", "Reporting", Color(0xFF64DFDF)),
        ToolCard("Monthly Burn-Down", "Watch how spending moves against targets as the month unfolds.", "Reporting", Color(0xFF56CFE1)),
        ToolCard("Spark: AI Summary", "Summarize charging, spending, and outliers in one quick weekly brief.", "Reporting", Color(0xFF4EA8DE)),
        catalogTool("$/Mile & CO2", "Finance", Color(0xFFF4A261)),
        catalogTool("Accessory Cost Tracker", "Finance", Color(0xFFF4A261)),
        catalogTool("Annual Cost Simulator", "Finance", Color(0xFFF4A261)),
        catalogTool("Business Deduction Report", "Finance", Color(0xFFF4A261)),
        catalogTool("CSV Charging Wizard", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("CSV Export", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Carbon Impact Dashboard", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Carbon Offset Calc.", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Cars vs EV Calculator", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Charge Speed Profiler", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charging Analytics Charts", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charging Budget Guardrails", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charging Data Integrity", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charging Etiquette", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charging Safety Checklist", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Charts & Budget", "Finance", Color(0xFFF4A261)),
        catalogTool("Cheapest Charger Finder", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Combined Charge Session", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Cost Breakdown", "Finance", Color(0xFFF4A261)),
        catalogTool("Cost per Mile vs Gas", "Finance", Color(0xFFF4A261)),
        catalogTool("Data Quality Center", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Deep Analytics", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Discounts & Referrals", "Research", Color(0xFF00AFB9)),
        catalogTool("Duplicate Resolver", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Dynamic Supercharging vs TOU", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("EV Charging vs Gas Time", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("EV Content", "Research", Color(0xFF00AFB9)),
        catalogTool("EV Loan/Lease Optimizer", "Finance", Color(0xFFF4A261)),
        catalogTool("EV Materials & Environment", "Research", Color(0xFF00AFB9)),
        catalogTool("EV Road-Tax Estimator", "Finance", Color(0xFFF4A261)),
        catalogTool("EV vs Gas Comparison", "Finance", Color(0xFFF4A261)),
        catalogTool("EV vs Car Cost Compare", "Finance", Color(0xFFF4A261)),
        catalogTool("EV vs Muscle Car Showdown", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Efficiency Scatter", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Emergency Pack Checklist", "Maintenance", Color(0xFFB08968)),
        catalogTool("Energy Coach", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Energy Rates", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Estimated Charging Time", "Planning", Color(0xFF35B36E)),
        catalogTool("Expense Entry Anomalies", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Fast vs Home Impact", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Finance", "Finance", Color(0xFFF4A261)),
        catalogTool("Forecast Charts", "Planning", Color(0xFF35B36E)),
        catalogTool("Garage & Vehicles", "Vehicle Intelligence", Color(0xFF9B5DE5)),
        catalogTool("Gas Tax", "Finance", Color(0xFFF4A261)),
        catalogTool("Gas to kWh Converter", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Home vs Public Split", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Incentives & Rebates", "Research", Color(0xFF00AFB9)),
        catalogTool("Lease Mileage Overage", "Finance", Color(0xFFF4A261)),
        catalogTool("Lease vs Buy Analyzer", "Finance", Color(0xFFF4A261)),
        catalogTool("MPGe Calculator", "Vehicle Intelligence", Color(0xFF9B5DE5)),
        catalogTool("Monthly Heatmap", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Net Cost per Mile", "Finance", Color(0xFFF4A261)),
        catalogTool("Plan Supercharger Stops", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Plate Scanner Archive", "Maintenance", Color(0xFFB08968)),
        catalogTool("Receipt Scan (OCR)", "Maintenance", Color(0xFFB08968)),
        catalogTool("Route Cost Compare", "Planning", Color(0xFF35B36E)),
        catalogTool("Savings Score", "Finance", Color(0xFFF4A261)),
        catalogTool("Secondary Market", "Research", Color(0xFF00AFB9)),
        catalogTool("Service Invoices (PDF)", "Maintenance", Color(0xFFB08968)),
        catalogTool("Session Confidence", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Shifting Do Good", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Smart Charging Planner", "Planning", Color(0xFF35B36E)),
        catalogTool("Station Quality Score", "Reporting", Color(0xFF5E60CE)),
        catalogTool("Supercharge.info Near Me", "Planning", Color(0xFF35B36E)),
        catalogTool("Supercharger Cost Calc", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Supercharger Live Price Predictor", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Superchargers Near Me", "Planning", Color(0xFF35B36E)),
        catalogTool("TCO Timeline", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("TCO Timeline (Monthly)", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Tax Treatment", "Finance", Color(0xFFF4A261)),
        catalogTool("Tesla EPC Parts Catalog", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Tesla Excess Wear Guide", "Maintenance", Color(0xFFB08968)),
        catalogTool("Tesla Invoice Scan", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Tesla Offers", "Research", Color(0xFF00AFB9)),
        catalogTool("Tesla Owners Club", "Research", Color(0xFF00AFB9)),
        catalogTool("Tesla Service Alerts", "Maintenance", Color(0xFFB08968)),
        catalogTool("Third-Party Charging Plans", "Charging Intelligence", Color(0xFF4895EF)),
        catalogTool("Trip Logger", "Planning", Color(0xFF35B36E)),
        catalogTool("Unit Conversion", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Vehicle Incentive Finder", "Research", Color(0xFF00AFB9)),
        catalogTool("Weekly EV vs Gas", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("Weekly Forecast", "Planning", Color(0xFF35B36E)),
        catalogTool("Weekly Health Report", "Everyday", Color(0xFF2D7FF9)),
        catalogTool("What-If Forecast", "Planning", Color(0xFF35B36E)),
        catalogTool("Winter Driving Techniques", "Vehicle Intelligence", Color(0xFF9B5DE5)),
        catalogTool("Winter Range Impact", "Planning", Color(0xFF35B36E))
    )

    val pricing = listOf(
        PricingSpotlight("Tesla Supercharger", 0.41, "Cheapest after 9 PM, strong site reliability."),
        PricingSpotlight("EVgo", 0.49, "Good metro coverage, weaker late-night value."),
        PricingSpotlight("Home utility", 0.17, "Best cost profile, especially during off-peak windows.")
    )

    fun dashboardInsights(activeVehicle: VehicleProfile?): List<DashboardInsight> {
        val vehicleName = activeVehicle?.name ?: "your EV"
        return listOf(
            DashboardInsight(
                title = "Home charging is winning",
                body = "$vehicleName is averaging materially lower cost per kWh at home than on fast charging this month.",
                scoreLabel = "84 / 100"
            ),
            DashboardInsight(
                title = "Peak-hour drift",
                body = "Two recent sessions landed in higher-rate windows. Sliding those after 9 PM would trim this month's spend.",
                scoreLabel = "Watch"
            ),
            DashboardInsight(
                title = "Battery rhythm looks healthy",
                body = "Most sessions started below 30% and ended below 85%, which is a clean fast-charge pattern for long-term health.",
                scoreLabel = "Strong"
            )
        )
    }
}

private fun catalogTool(title: String, group: String, accent: Color): ToolCard =
    ToolCard(title, toolDescription(title, group), group, accent)

private fun toolDescription(title: String, group: String): String {
    return when (title) {
        "$/Mile & CO2" -> "Estimate operating cost and emissions impact in one side-by-side view."
        "Accessory Cost Tracker" -> "Track upgrades, add-ons, and accessories without losing the full ownership picture."
        "Annual Cost Simulator" -> "Project a full year of charging and ownership costs from your current trends."
        "Business Deduction Report" -> "Summarize eligible business-use costs and mileage-related expense context."
        "CSV Charging Wizard" -> "Guide charging-history imports with clear column checks and format help."
        "CSV Export" -> "Export saved charging and expense records for backup, sharing, or deeper analysis."
        "Carbon Impact Dashboard" -> "Turn your usage history into a simple view of emissions and energy impact."
        "Carbon Offset Calc." -> "Estimate what it would take to offset your vehicle-related energy footprint."
        "Cars vs EV Calculator" -> "Compare conventional vehicle costs against your EV ownership profile."
        "Charge Speed Profiler" -> "Review how charging speed changes by site, session, and state of charge."
        "Charging Analytics Charts" -> "Visualize charging sessions, rates, spend, and energy trends over time."
        "Charging Budget Guardrails" -> "Set spend boundaries and spot early signs that charging costs are drifting."
        "Charging Data Integrity" -> "Catch missing values, suspicious totals, and mismatched charging records."
        "Charging Etiquette" -> "Keep quick reminders for charging best practices and station courtesy."
        "Charts & Budget" -> "Blend budget tracking with quick charts for a clearer spending snapshot."
        "Cheapest Charger Finder" -> "Highlight the lowest-cost charging options across your saved providers and stops."
        "Combined Charge Session" -> "Merge related charging records into a cleaner session-level timeline."
        "Cost Breakdown" -> "Split ownership costs into clear buckets so the biggest drivers stand out fast."
        "Cost per Mile vs Gas" -> "Compare EV running costs against gas ownership on a per-mile basis."
        "Data Quality Center" -> "Review record health, duplicates, and import issues from one quality dashboard."
        "Deep Analytics" -> "Open a denser reporting view for trends, anomalies, and historical patterns."
        "Discounts & Referrals" -> "Keep charging offers, referral links, and savings opportunities in one place."
        "Duplicate Resolver" -> "Find overlapping entries and clean up duplicate charging or expense records."
        "Dynamic Supercharging vs TOU" -> "Compare Tesla fast-charging prices against home time-of-use windows."
        "EV Charging vs Gas Time" -> "Balance time spent charging against the fuel-stop habits of gas ownership."
        "EV Content" -> "Save useful EV articles, explainers, and media worth revisiting later."
        "EV Loan/Lease Optimizer" -> "Model financing and lease structures to see which option fits best."
        "EV Materials & Environment" -> "Explore battery materials, sustainability context, and environmental references."
        "NHTSA Crash Reporting" -> "Track the official federal crash-reporting dataset for ADS and Level 2 ADAS, along with its major caveats."
        "EV Road-Tax Estimator" -> "Estimate road-use taxes and fees that may apply to EV ownership."
        "EV vs Gas Comparison" -> "Compare actual EV charging spend, gas equivalents, and mileage scenarios."
        "EV vs Car Cost Compare" -> "Put total EV ownership costs next to a traditional vehicle scenario."
        "EV vs Muscle Car Showdown" -> "Compare performance-minded ownership costs through an EV-versus-gas lens."
        "Efficiency Scatter" -> "Spot efficiency clusters and outliers across vehicles, routes, or charging behavior."
        "Emergency Pack Checklist" -> "Keep a ready-to-go checklist for road trips, winter driving, and emergencies."
        "Energy Coach" -> "Turn recent charging and driving patterns into practical efficiency suggestions."
        "Energy Rates" -> "Track rate assumptions across home, public, and fast-charging providers."
        "Estimated Charging Time" -> "Estimate session length from battery size, power level, and charge target."
        "Expense Entry Anomalies" -> "Surface entries that look unusually high, low, or incomplete."
        "Fast vs Home Impact" -> "Compare fast charging and home charging across cost, convenience, and battery habits."
        "Finance" -> "Open a broad financial lens on charging, ownership, and recurring vehicle costs."
        "Forecast Charts" -> "Review projected spend and energy use in chart-friendly planning views."
        "Grid Emissions Forecast" -> "Find cleaner local charging windows with WattTime-style real-time and 24-hour grid emissions signals."
        "Garage & Vehicles" -> "Keep vehicle profiles, key specs, and garage context organized together."
        "Gas Tax" -> "Estimate fuel-tax equivalents and compare them with EV-related fees."
        "Gas to kWh Converter" -> "Translate gas usage and spending into familiar EV energy units."
        "Home vs Public Split" -> "Measure how much of your charging happens at home versus on the road."
        "Incentives & Rebates" -> "Track purchase incentives, local rebates, and utility savings opportunities."
        "Lease Mileage Overage" -> "Model mileage overages before they become an end-of-lease surprise."
        "Lease vs Buy Analyzer" -> "Compare the long-term tradeoffs between leasing and buying."
        "MPGe Calculator" -> "Estimate MPGe and compare overall efficiency across vehicle types."
        "Monthly Heatmap" -> "See which days and weeks drove the most activity, charging, or spend."
        "Net Cost per Mile" -> "Calculate a fuller per-mile cost after charging, upkeep, and recurring expenses."
        "Plan Supercharger Stops" -> "Outline likely Tesla charging stops for longer routes."
        "Plate Scanner Archive" -> "Store plate scans and related vehicle records for quick lookup."
        "Receipt Scan (OCR)" -> "Extract expense details from receipts and feed them into the ledger faster."
        "Route Cost Compare" -> "Compare route choices by charging cost, distance, and efficiency impact."
        "Safety Score Predictor" -> "Estimate a rough safety score from charging-session timing and other limited signals already saved in the app."
        "Savings Score" -> "Summarize how well current usage patterns are protecting your budget."
        "Secondary Market" -> "Keep tabs on used EV pricing, resale trends, and market context."
        "Service Invoices (PDF)" -> "Collect service PDFs and keep them tied to vehicle history."
        "Session Confidence" -> "Score how complete and trustworthy each charging session record looks."
        "Shifting Do Good" -> "Explore how cleaner charging windows can improve cost and grid impact."
        "Smart Charging Planner" -> "Plan charging around rates, schedules, and trip needs."
        "Station Quality Score" -> "Rank sites by reliability, pricing, and overall charging experience."
        "Supercharge.info Near Me" -> "Check nearby Supercharger coverage when planning a stop."
        "Supercharger Cost Calc" -> "Estimate Tesla fast-charging cost before you plug in."
        "Supercharger Live Price Predictor" -> "Model likely live Supercharger pricing from recent trends and timing."
        "Superchargers Near Me" -> "Browse nearby Tesla charging options when you need a quick stop."
        "TCO Timeline" -> "Follow how total cost of ownership changes over the life of the vehicle."
        "TCO Timeline (Monthly)" -> "View total cost of ownership on a month-by-month timeline."
        "Tax Treatment" -> "Review ownership expenses in a more tax-aware context."
        "Tesla EPC Parts Catalog" -> "Keep factory parts references close to maintenance planning."
        "Tesla Excess Wear Guide" -> "Open Tesla's lease return wear-and-use reference before self-inspection."
        "Tesla Invoice Scan" -> "Capture Tesla invoice details quickly and turn them into saved records."
        "TeslaFi Mobile Dashboard" -> "Review imported TeslaFi-style session history, charge costs, efficiency, and gas-savings context."
        "TeslaMate Mobile Dashboard" -> "Review TesLog-style vehicle status, battery context, and charging summaries in a mobile-friendly layout."
        "Altitude Cockpit" -> "Record elevation snapshots and keep an altitude profile for hilly drives and mountain routes."
        "Weather Cockpit" -> "Check trip-friendly forecast signals such as wind, humidity, temperature, and rain risk."
        "Trip Cockpit" -> "Log route distance, average speed, energy, and trip notes without needing a Tesla login."
        "Tic Tac Toe" -> "Open a quick two-player cabin game for downtime while parked or charging."
        "Direct Connection Dashboard" -> "Review endpoint, token, charge, drive, geofence, widget, and live-status readiness in one connected-vehicle view."
        "Direct Connection Setup" -> "Walk through the proxy, endpoint, token, and privacy decisions needed before live vehicle data is enabled."
        "Widgets & Charge Status" -> "Prepare an Android charge-status surface that mirrors the iOS widget and Live Activity intent."
        "Agent Assistant" -> "Summarize garage, charging, spending, and tool context the way the iOS agent panel does."
        "Import Hub Onboarding" -> "Guide first-run import choices so Tesla billing, generic charging, and expense CSVs land in the right places."
        "Tesla Offers" -> "Track Tesla promotions, offers, and limited-time owner programs."
        "Tesla Owners Club" -> "Keep community resources and owner discussions easy to revisit."
        "Tesla Service Alerts" -> "Decode Tesla firmware alerts into plain-English severity, impact, and owner action."
        "Third-Party Charging Plans" -> "Compare subscription plans and network options beyond Tesla."
        "Trip Logger" -> "Keep a cleaner log of trips, charging stops, and notable route events."
        "Unit Conversion" -> "Convert common charging, energy, and distance values without leaving the app."
        "Vehicle Incentive Finder" -> "Search for incentives that match your vehicle and location."
        "Weekly EV vs Gas" -> "Compare a week of EV costs with an equivalent gas-driving week."
        "Weekly Forecast" -> "Project the next week of charging needs and expected spend."
        "Weekly Health Report" -> "Summarize recent efficiency, charging rhythm, and cost signals."
        "What-If Forecast" -> "Model how schedule, weather, or pricing changes could affect future costs."
        "Winter Driving Techniques" -> "Keep winter driving tips and cold-weather habits close at hand."
        "Winter Range Impact" -> "Estimate how colder temperatures may change usable range and charging needs."
        else -> when (group) {
            "Finance" -> "Explore the financial side of ownership with focused cost and budget tools."
            "Charging Intelligence" -> "Analyze charging sessions, pricing, and station behavior with more detail."
            "Everyday" -> "Use quick everyday helpers for conversions, comparisons, and daily EV decisions."
            "Reporting" -> "Turn saved history into clearer reports, rollups, and quality checks."
            "Research" -> "Keep useful EV policy, market, and community references close by."
            "Maintenance" -> "Track service, repairs, and upkeep alongside the rest of your garage."
            "Planning" -> "Plan routes, charging stops, and forecasts from your own vehicle context."
            "Tesla Display Apps" -> "Open no-login mini apps inspired by Tesla browser dashboards."
            "Vehicle Intelligence" -> "Use garage details and vehicle specs to answer ownership questions faster."
            else -> "Use this tool to explore a focused part of your vehicle and charging history."
        }
    }
}

val entryDateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d")
val sessionDateTimeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d, h:mm a")
