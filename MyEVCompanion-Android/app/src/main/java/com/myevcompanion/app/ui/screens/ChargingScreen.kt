package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun ChargingScreen(
    appState: AppState,
    onOpenImportHub: () -> Unit
) {
    FeatureListScreen(
        title = "Charging",
        sections = listOf(
            FeatureSection(
                title = "Charging Logs",
                items = listOf(
                    "Charge session history",
                    "Edit charge entries",
                    "Charging reconciliation",
                    "Charging data integrity"
                )
            ),
            FeatureSection(
                title = "Supercharger",
                items = listOf(
                    "Live price calculator",
                    "Price prediction engine",
                    "Station explorer",
                    "Near me view"
                )
            ),
            FeatureSection(
                title = "Forecasting",
                items = listOf(
                    "Charging budget guardrails",
                    "Monthly forecast",
                    "Range forecast",
                    "Cost per kWh strategy"
                )
            )
        ),
        footer = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = onOpenImportHub,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Open Charging Import Center")
                }
                AdBannerCard()
            }
        }
    )
}
