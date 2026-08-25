package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.EntryCategory
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard

@Composable
fun ChargingScreen(
    appState: AppState,
    onOpenImportHub: () -> Unit
) {
    val sessions by appState.teslaFiStore.sessions.collectAsState()
    val entries by appState.entriesStore.entries.collectAsState()
    val pricing by appState.superchargerStore.stations.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
    val recentChargingEntries = chargingEntries.sortedByDescending { it.date }.take(5)

    AppScreen(
        title = "Charging Data",
        subtitle = "Import, reconcile, and review charging history the way the iOS charging hub does."
    ) {
        item {
            HeroCard(
                eyebrow = "Charging Hub",
                title = "Summary, import, and cleanup in one place",
                subtitle = appState.appModel.chargingForecastSummary()
            )
        }
        item {
            SectionCard(
                title = "Summary",
                subtitle = "Quick health signals across imported sessions and charging ledger entries"
            ) {
                if (sessions.isEmpty() && chargingEntries.isEmpty()) {
                    Text(
                        text = "No charging data yet. Import the official Tesla Supercharging CSV to start with billed sessions, or bring in a generic charging-session export.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    MetricFlowRow(
                        items = listOf(
                            "Latest energy" to "${sessions.firstOrNull()?.energyAddedKWh?.oneDecimal() ?: chargingEntries.firstOrNull()?.energyKWh?.oneDecimal() ?: "--"} kWh",
                            "Fast-charge share" to "${(sessions.count { it.isSupercharger } * 100 / sessions.size.coerceAtLeast(1))}%",
                            "Top speed" to "${sessions.maxOfOrNull { it.maxPowerKw } ?: 0} kW",
                            "Charging logs" to (sessions.size + chargingEntries.size).toString()
                        )
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Import and export",
                subtitle = "Keep charging data portable and easy to reconcile"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(onClick = onOpenImportHub, modifier = androidx.compose.ui.Modifier.fillMaxWidth()) {
                        Text("Open charging data hub")
                    }
                    OutlinedButton(onClick = onOpenImportHub, modifier = androidx.compose.ui.Modifier.fillMaxWidth()) {
                        Text("Import Tesla CSV or export current data")
                    }
                    Text(
                        text = "The Android fork now centers charging imports, exports, and ledger cleanup under the same hub structure used on iOS.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Data tools",
                subtitle = "Core charging workflows mirrored from the iOS charging-data area"
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Import hub" to "Tesla CSV",
                        "Reconcile" to "Ledger vs sessions",
                        "Studio" to "History drilldown",
                        "Export" to "CSV backup"
                    )
                )
            }
        }
        item {
            SectionCard(
                title = "Provider price watch",
                subtitle = "A portable version of the pricing panels from iOS"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    pricing.forEach { spot ->
                        Row(
                            modifier = androidx.compose.ui.Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(spot.provider, style = MaterialTheme.typography.titleMedium)
                                Text(
                                    spot.summary,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            LabelPill(
                                text = "${spot.pricePerKwh.asCurrency()}/kWh",
                                color = MaterialTheme.colorScheme.secondary
                            )
                        }
                    }
                }
            }
        }
        if (showAds) {
            item {
                AdBannerCard()
            }
        }
        item {
            SectionCard(
                title = "Recent charging activity",
                subtitle = "Sessions appear first when available, otherwise the view falls back to charging entries from your ledger."
            ) {
                when {
                    sessions.isNotEmpty() -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        sessions.forEach { session ->
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Row(
                                    modifier = androidx.compose.ui.Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(session.stationName, style = MaterialTheme.typography.titleMedium)
                                    Text(session.cost.asCurrency(), style = MaterialTheme.typography.titleMedium)
                                }
                                Text(
                                    "${session.provider} • ${session.startSoc}% to ${session.endSoc}% • ${session.maxPowerKw} kW peak",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    recentChargingEntries.isNotEmpty() -> Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        recentChargingEntries.forEach { entry ->
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Row(
                                    modifier = androidx.compose.ui.Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(entry.location, style = MaterialTheme.typography.titleMedium)
                                    Text(entry.amount.asCurrency(), style = MaterialTheme.typography.titleMedium)
                                }
                                Text(
                                    "${entry.date.format(com.myevcompanion.app.data.entryDateFormatter)} • ${entry.energyKWh?.oneDecimal()?.plus(" kWh") ?: "Energy unavailable"}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    else -> Text(
                        text = "No charging activity yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
