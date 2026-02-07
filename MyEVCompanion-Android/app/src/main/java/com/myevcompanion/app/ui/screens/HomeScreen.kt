package com.myevcompanion.app.ui.screens

import androidx.compose.runtime.Composable
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun HomeScreen(appState: AppState) {
    FeatureListScreen(
        title = "Home",
        sections = listOf(
            FeatureSection(
                title = "Dashboards",
                items = listOf(
                    "Summary cards",
                    "Forecast header + breakdown",
                    "Monthly charging change",
                    "Energy mix and carbon impact",
                    "Cost per kWh trends",
                    "Range forecast"
                )
            ),
            FeatureSection(
                title = "Insights",
                items = listOf(
                    "Anomaly detection",
                    "Session efficiency scatter",
                    "Peak window heatmap",
                    "Charging etiquette tips"
                )
            )
        ),
        footer = {
            AdBannerCard()
        }
    )
}
