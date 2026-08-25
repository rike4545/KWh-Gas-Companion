package com.myevcompanion.app.ui.screens

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.SectionCard

@Composable
fun ChargingImportHubScreen(
    appState: AppState,
    onOpenTeslaMate: () -> Unit
) {
    val context = LocalContext.current
    val selectedVehicleId by appState.profileStore.selectedVehicleId.collectAsState()
    val sessions by appState.teslaFiStore.sessions.collectAsState()
    val entries by appState.entriesStore.entries.collectAsState()
    val vehicles by appState.profileStore.vehicles.collectAsState()

    var statusMessage by rememberSaveable { mutableStateOf("Import official Tesla Supercharging billing history, or bring in your own generic CSV exports.") }
    var pendingExportText by remember { mutableStateOf<String?>(null) }

    val importTeslaOfficialLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = context.readText(uri)
        val result = appState.appModel.importOfficialTeslaSuperchargingCsv(text)
        statusMessage = when {
            result.importedEntries > 0 -> buildString {
                append("Imported ${result.importedEntries} Tesla Supercharging expense row")
                if (result.importedEntries != 1) append("s")
                append(".")
                if (result.backfilledKwhRows > 0) {
                    append(" Backfilled kWh for ${result.backfilledKwhRows} row")
                    if (result.backfilledKwhRows != 1) append("s")
                    append(".")
                }
                if (result.autoCreatedVehicles > 0) {
                    append(" Created ${result.autoCreatedVehicles} vehicle profile")
                    if (result.autoCreatedVehicles != 1) append("s")
                    append(" from Tesla metadata.")
                }
            }

            result.skippedRows > 0 -> "No Tesla rows were imported. ${result.skippedRows} row${if (result.skippedRows == 1) " was" else "s were"} skipped because they were duplicates or missing required billing fields."
            else -> "No Tesla rows were imported."
        }
    }

    val importEntriesLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = context.readText(uri)
        val imported = appState.entriesStore.importCsv(text, selectedVehicleId)
        statusMessage = if (imported > 0) "Imported $imported expense rows." else "No expense rows were imported."
    }

    val importSessionsLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = context.readText(uri)
        val imported = appState.teslaFiStore.importCsv(text, selectedVehicleId)
        statusMessage = if (imported > 0) "Imported $imported charging sessions." else "No charging rows were imported."
    }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri == null || pendingExportText == null) return@rememberLauncherForActivityResult
        context.writeText(uri, pendingExportText!!)
        statusMessage = "CSV exported successfully."
        pendingExportText = null
    }

    AppScreen(
        title = "Import Center",
        subtitle = "Bring in official Tesla Supercharging billing history or import your own charging and expense CSV files."
    ) {
        item {
            SectionCard(
                title = "Current data",
                subtitle = "Tesla imports can match by VIN or vehicle name and create a garage profile if needed."
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    LabelPill(text = "${vehicles.size} vehicles", color = MaterialTheme.colorScheme.tertiary)
                    LabelPill(text = "${sessions.size} sessions", color = MaterialTheme.colorScheme.primary)
                    LabelPill(text = "${entries.size} entries", color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item {
            SectionCard(
                title = "Official Tesla Supercharging CSV",
                subtitle = "Supports Tesla billing headers like ChargeStartDateTime, QuantityBase, UnitCostBase, Total Inc. VAT, InvoiceNumber, Name, and Vin."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Duplicate rows are skipped, missing kWh can be backfilled from price data, and vehicle matching uses Tesla metadata when present.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Button(
                        onClick = { importTeslaOfficialLauncher.launch(arrayOf("text/*")) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Import official Tesla CSV")
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Charging session CSV",
                subtitle = "Expected columns: stationName, provider, startedAt, endedAt, energyAddedKWh, cost, startSoc, endSoc, maxPowerKw, isSupercharger, vehicleId"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = { importSessionsLauncher.launch(arrayOf("text/*")) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Import charging sessions")
                    }
                    OutlinedButton(
                        onClick = {
                            pendingExportText = appState.teslaFiStore.exportCsv()
                            exportLauncher.launch("kwh-charging-sessions.csv")
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Export charging sessions")
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "TeslaMate",
                subtitle = "Connect your self-hosted TeslaMate API or compatible proxy, review status, charges, drives, and geofence costs, then import fetched charges."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Supports TeslaMateApi-style cars, status, drives, and charges endpoints with bearer or query-string tokens.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Button(
                        onClick = onOpenTeslaMate,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Open TeslaMate connection")
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Expense CSV",
                subtitle = "Expected columns: title, category, amount, energyKWh, date, location, vehicleId, notes"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = { importEntriesLauncher.launch(arrayOf("text/*")) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Import expense entries")
                    }
                    OutlinedButton(
                        onClick = {
                            pendingExportText = appState.entriesStore.exportCsv()
                            exportLauncher.launch("kwh-expense-entries.csv")
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Export expense entries")
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Status",
                subtitle = "Latest import/export result"
            ) {
                Text(
                    text = statusMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

private fun Context.readText(uri: Uri): String {
    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return ""
    return String(bytes, Charsets.UTF_8).takeIf { it.isNotBlank() }
        ?: runCatching { String(bytes, Charsets.UTF_16) }.getOrDefault("")
}

private fun Context.writeText(uri: Uri, text: String) {
    contentResolver.openOutputStream(uri)?.bufferedWriter()?.use { it.write(text) }
}
