package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun ChargingImportHubScreen(appState: AppState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = "Charging Import Center", style = MaterialTheme.typography.headlineSmall)
        Text(
            text = "Choose how you want to bring charging data into My EV Companion.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
        )

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(text = "Official Tesla Supercharging CSV", style = MaterialTheme.typography.titleMedium)
                Text(
                    text = "Import billed Supercharging sessions into your charging ledger.",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(text = "TeslaFi Monthly Analytics CSV", style = MaterialTheme.typography.titleMedium)
                Text(
                    text = "Import TeslaFi CSV exports for richer analytics sessions.",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        AdBannerCard()
    }
}
