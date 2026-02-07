package com.myevcompanion.app.ui.screens

import androidx.compose.runtime.Composable
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun ToolsScreen(appState: AppState) {
    FeatureListScreen(
        title = "Tools",
        sections = listOf(
            FeatureSection(
                title = "Calculators",
                items = listOf(
                    "MPGe calculator",
                    "Gas to kWh converter",
                    "EV vs gas cost",
                    "Fast vs home impact"
                )
            ),
            FeatureSection(
                title = "Planning",
                items = listOf(
                    "Trip planner",
                    "Route probe",
                    "Charging ledger",
                    "Charging etiquette"
                )
            ),
            FeatureSection(
                title = "Research",
                items = listOf(
                    "EV news",
                    "Public incentives",
                    "Right to repair",
                    "Tesla EPC parts search"
                )
            )
        ),
        footer = {
            AdBannerCard()
        }
    )
}
