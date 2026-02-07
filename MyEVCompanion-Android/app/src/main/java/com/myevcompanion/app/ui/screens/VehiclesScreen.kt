package com.myevcompanion.app.ui.screens

import androidx.compose.runtime.Composable
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun VehiclesScreen(appState: AppState) {
    FeatureListScreen(
        title = "Vehicles",
        sections = listOf(
            FeatureSection(
                title = "Garage",
                items = listOf(
                    "Vehicle profiles",
                    "Vehicle avatars",
                    "VIN decoder",
                    "Service reminders"
                )
            ),
            FeatureSection(
                title = "Ownership",
                items = listOf(
                    "Cost of ownership analysis",
                    "Lease and loan calculators",
                    "Depreciation curve",
                    "Resale marketplace"
                )
            )
        ),
        footer = {
            AdBannerCard()
        }
    )
}
