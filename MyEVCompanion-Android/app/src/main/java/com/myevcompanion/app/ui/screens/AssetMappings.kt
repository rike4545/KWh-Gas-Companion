package com.myevcompanion.app.ui.screens

import com.myevcompanion.app.R
import com.myevcompanion.app.data.ToolCard
import com.myevcompanion.app.data.VehicleProfile

fun VehicleProfile.artworkRes(): Int {
    val key = "${make.lowercase()} ${model.lowercase()} ${name.lowercase()}"
    return when {
        "model 3" in key -> R.drawable.model_3
        "model y" in key -> R.drawable.model_y
        "model s" in key -> R.drawable.model_s
        "model x" in key -> R.drawable.model_x
        "cybertruck" in key -> R.drawable.cybertruck
        "roadster" in key -> R.drawable.roadster
        "r1t" in key -> R.drawable.rivianr1t
        "r1s" in key -> R.drawable.rivianr1s
        "r2" in key -> R.drawable.rivianr2
        "r3" in key -> R.drawable.rivianr3
        else -> R.drawable.myevsplash
    }
}

val homeHeroArtwork = R.drawable.splashdayroad
val toolsHeroArtwork = R.drawable.splashdayabstract
val toolsResearchArtwork = R.drawable.splashnightcosmic

fun ToolCard.detailArtworkRes(): Int {
    return when (title) {
        "Cars vs EV Calculator",
        "EV vs Gas Comparison",
        "EV vs Car Cost Compare",
        "Cost per Mile vs Gas",
        "Weekly EV vs Gas",
        "Gas to kWh Converter",
        "Gas to kWh" -> R.drawable.splashdayroad

        "Trip Planner",
        "Trip Budget Planner",
        "Trip Cost Estimator",
        "Route Cost Compare",
        "Trip Logger",
        "Weekly Forecast",
        "What-If Forecast",
        "Grid Emissions Forecast",
        "Winter Range Impact",
        "Forecast Dashboard",
        "Forecast Charts",
        "Range Forecast",
        "Estimated Charging Time",
        "Smart Charging Planner",
        "Superchargers Near Me",
        "Supercharge.info Near Me",
        "Plan Supercharger Stops" -> R.drawable.splashdaycoastwater

        "Tesla VIN Decoder",
        "Tesla Invoice Scan",
        "Tesla EPC Parts Catalog",
        "Tesla Excess Wear Guide",
        "Tesla Service Alerts" -> R.drawable.model_y

        "Rivian VIN Decoder" -> R.drawable.rivianr1t

        "Garage & Vehicles",
        "Battery Health Timeline",
        "Home Charger Optimizer",
        "MPGe Calculator",
        "Winter Driving Techniques" -> R.drawable.myevsplash

        else -> when (group) {
            "Research" -> R.drawable.splashnightcosmic
            "Planning" -> R.drawable.splashdaycoastwater
            "Vehicle Intelligence" -> R.drawable.myevsplash
            "Everyday" -> R.drawable.splashdayroad
            "Charging Intelligence" -> R.drawable.splashdaysunrisea
            "Maintenance" -> R.drawable.splashduskbeach
            "Finance" -> R.drawable.splashdayabstract
            "Reporting" -> R.drawable.splashdaysunriseb
            else -> toolsHeroArtwork
        }
    }
}
