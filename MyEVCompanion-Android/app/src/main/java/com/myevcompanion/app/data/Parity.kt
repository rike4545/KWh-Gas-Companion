package com.myevcompanion.app.data

object IosParityCatalog {
    val calculatorTitles: List<String> = listOf(
        "Accessory Cost Tracker",
        "Charging Analytics Charts",
        "Business Deduction Report",
        "Carbon Impact Dashboard",
        "Carbon Offset Calc.",
        "Cars vs EV Calculator",
        "Estimated Charging Time",
        "Charging Budget Guardrails",
        "Charging Data Studio",
        "Charging Data Integrity",
        "Charging Etiquette",
        "Charging Reconciliation",
        "Charts & Budget",
        "Cheapest Charger Finder",
        "Combined Charge Session",
        "Cost Breakdown",
        "Cost of Ownership",
        "Cost per kWh Trend",
        "$/Mile & CO2",
        "CSV Charging Wizard",
        "CSV Export",
        "Deep Analytics",
        "Data Quality Center",
        "Shifting Do Good",
        "Discounts & Referrals",
        "EV Content",
        "Dynamic Supercharging vs TOU",
        "Expense Entry Anomalies",
        "Energy Coach",
        "EV News",
        "EV vs Gas Comparison",
        "EV Charging vs Gas Time",
        "Fast vs Home Impact",
        "Forecast Charts",
        "Forecast Dashboard",
        "Weekly Forecast",
        "Gas Tax",
        "Gas to kWh Converter",
        "Garage & Vehicles",
        "Grid Emissions Forecast",
        "History: Tesla & Rivian",
        "Home vs Public Split",
        "Incentives & Rebates",
        "Energy Rates",
        "Lease Mileage Overage",
        "Lemon Law Guide",
        "MPGe Calculator",
        "EV Materials & Environment",
        "EV vs Muscle Car Showdown",
        "Superchargers Near Me",
        "NHTSA Crash Reporting",
        "Supercharge.info Near Me",
        "Third-Party Charging Plans",
        "Vehicle Incentive Finder",
        "Plate Scanner Archive",
        "Price Watchlist",
        "Quarterly Tax Summary",
        "Range Forecast",
        "Recalls",
        "Reimbursement Generator",
        "Secondary Market",
        "Rivian VIN Decoder",
        "Right to Repair",
        "Savings Score",
        "Smart Charging Planner",
        "Session Confidence",
        "Duplicate Resolver",
        "Best Value Chargers",
        "Weekly Cost Rollup",
        "Battery Health Timeline",
        "Home Charger Optimizer",
        "Monthly Burn-Down",
        "Cost per Mile vs Gas",
        "Insurance & Finance Tracker",
        "Trip Budget Planner",
        "Lease vs Buy Analyzer",
        "EV Road-Tax Estimator",
        "Station Quality Score",
        "Charge Speed Profiler",
        "Tire & Maintenance Tracker",
        "DIY Service Vault",
        "Net Cost per Mile",
        "Monthly Heatmap",
        "Shareable Reports",
        "Service Reminders",
        "Service Invoices (PDF)",
        "Session Analytics",
        "Efficiency Scatter",
        "Spark: AI Summary",
        "Supercharger Cost Calc",
        "Supercharger Live Price Predictor",
        "Plan Supercharger Stops",
        "TCO Timeline",
        "Tax Treatment",
        "Tesla Offers",
        "Tesla Owners Club",
        "Tesla VIN Decoder",
        "Tesla Service Alerts",
        "Tesla EPC Parts Catalog",
        "Altitude Cockpit",
        "Weather Cockpit",
        "Trip Cockpit",
        "Tic Tac Toe",
        "Trip Cost Estimator",
        "Trip Planner",
        "Trip Logger",
        "Unit Conversion",
        "EV Loan/Lease Optimizer",
        "Finance",
        "Annual Cost Simulator",
        "Weekly Health Report",
        "Winter Driving Techniques",
        "Winter Range Impact",
        "What-If Forecast",
        "Weekly EV vs Gas",
        "Receipt Scan (OCR)",
        "Route Cost Compare",
        "TCO Timeline (Monthly)",
        "Charging Safety Checklist",
        "Emergency Pack Checklist",
        "Tesla Invoice Scan"
    )

    val androidParityBridgeTitles: List<String> = listOf(
        "Direct Connection Dashboard",
        "Direct Connection Setup",
        "Widgets & Charge Status",
        "Agent Assistant",
        "Import Hub Onboarding"
    )

    private val aliases = emptyMap<String, String>()

    fun missingCalculatorTitles(androidTools: List<ToolCard> = SampleData.tools): List<String> {
        val androidTitles = androidTools.map { it.title.normalizedParityTitle() }.toSet()
        return calculatorTitles.filter { title ->
            val mapped = aliases[title] ?: title
            mapped.normalizedParityTitle() !in androidTitles
        }
    }

    fun coveredCalculatorCount(androidTools: List<ToolCard> = SampleData.tools): Int =
        calculatorTitles.size - missingCalculatorTitles(androidTools).size

    fun coverageLabel(androidTools: List<ToolCard> = SampleData.tools): String =
        "${coveredCalculatorCount(androidTools)} / ${calculatorTitles.size}"
}

private fun String.normalizedParityTitle(): String =
    lowercase()
        .replace("&", "and")
        .replace(Regex("\\s+"), " ")
        .trim()
