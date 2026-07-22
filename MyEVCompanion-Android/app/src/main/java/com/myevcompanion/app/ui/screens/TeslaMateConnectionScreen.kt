package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.TeslaMateConnectionConfig
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.SectionCard

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TeslaMateConnectionScreen(appState: AppState) {
    val config by appState.teslaMateStore.config.collectAsState()
    val snapshot by appState.teslaMateStore.snapshot.collectAsState()
    val isLoading by appState.teslaMateStore.isLoading.collectAsState()
    val message by appState.teslaMateStore.message.collectAsState()
    val selectedVehicleId by appState.profileStore.selectedVehicleId.collectAsState()
    val savedSessions by appState.teslaFiStore.sessions.collectAsState()

    var baseUrl by remember(config.baseUrl) { mutableStateOf(config.baseUrl) }
    var token by remember(config.token) { mutableStateOf(config.token) }
    var useQueryToken by remember(config.useQueryToken) { mutableStateOf(config.useQueryToken) }

    AppScreen(
        title = "TeslaMate",
        subtitle = "Connect your self-hosted TeslaMate API or compatible proxy, inspect live data, and import fetched charging sessions."
    ) {
        item {
            SectionCard(
                title = "Connection",
                subtitle = "Use a read-only TeslaMateApi endpoint over HTTPS, LAN, or VPN."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = baseUrl,
                        onValueChange = { baseUrl = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Base URL") },
                        singleLine = true,
                        supportingText = { Text("Example: https://teslamate-api.example.com") }
                    )
                    OutlinedTextField(
                        value = token,
                        onValueChange = { token = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Access token / API key") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation()
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text("Pass token in query string", style = MaterialTheme.typography.titleSmall)
                            Text(
                                "Use only if your proxy expects ?token=.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(checked = useQueryToken, onCheckedChange = { useQueryToken = it })
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = {
                                appState.teslaMateStore.save(
                                    TeslaMateConnectionConfig(
                                        baseUrl = baseUrl,
                                        token = token,
                                        useQueryToken = useQueryToken,
                                        selectedCarId = config.selectedCarId
                                    )
                                )
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Save")
                        }
                        OutlinedButton(
                            onClick = { appState.teslaMateStore.clear() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Clear")
                        }
                    }
                    Button(
                        onClick = {
                            appState.teslaMateStore.save(
                                TeslaMateConnectionConfig(
                                    baseUrl = baseUrl,
                                    token = token,
                                    useQueryToken = useQueryToken,
                                    selectedCarId = config.selectedCarId
                                )
                            )
                            appState.teslaMateStore.refresh()
                        },
                        enabled = !isLoading,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(if (isLoading) "Testing..." else "Test connection")
                    }
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        if (snapshot.cars.isNotEmpty()) {
            item {
                SectionCard(
                    title = "Vehicle",
                    subtitle = "Select which TeslaMate vehicle the dashboard should read."
                ) {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        snapshot.cars.forEach { car ->
                            FilterChip(
                                selected = config.selectedCarId == car.id,
                                onClick = {
                                    appState.teslaMateStore.save(config.copy(selectedCarId = car.id))
                                    appState.teslaMateStore.refresh()
                                },
                                label = { Text(car.name) }
                            )
                        }
                    }
                }
            }
        }

        item {
            SectionCard(
                title = "Status",
                subtitle = "Live TeslaMate status fields when your endpoint provides them."
            ) {
                val status = snapshot.status
                MetricGrid(
                    items = listOf(
                        "Battery" to (status?.batteryLevel?.let { "$it%" } ?: "Unknown"),
                        "Usable" to (status?.usableBatteryLevel?.let { "$it%" } ?: "Unknown"),
                        "Charging" to (status?.chargingState ?: "Unknown"),
                        "State" to (status?.vehicleState ?: "Unknown"),
                        "Rated range" to (status?.ratedRange?.let { "${it.oneDecimal()} mi" } ?: "Unknown"),
                        "Ideal range" to (status?.idealRange?.let { "${it.oneDecimal()} mi" } ?: "Unknown"),
                        "Locked" to (status?.locked?.yesNo() ?: "Unknown"),
                        "Sentry" to (status?.sentryMode?.onOff() ?: "Unknown"),
                        "Climate" to (status?.climateOn?.onOff() ?: "Unknown"),
                        "Software" to (status?.softwareVersion ?: "Unknown")
                    )
                )
            }
        }

        item {
            SectionCard(
                title = "Import fetched charges",
                subtitle = "Fetched TeslaMate charges import into the same charging-session history used by Android dashboards."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        LabelPill(text = "${snapshot.charges.size} fetched", color = MaterialTheme.colorScheme.primary)
                        LabelPill(text = "${savedSessions.size} saved", color = MaterialTheme.colorScheme.tertiary)
                    }
                    Button(
                        onClick = {
                            appState.teslaMateStore.importFetchedCharges(
                                sessionStore = appState.teslaFiStore,
                                defaultVehicleId = selectedVehicleId
                            )
                            baseUrl = config.baseUrl
                            token = config.token
                            useQueryToken = config.useQueryToken
                        },
                        enabled = snapshot.charges.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Import fetched TeslaMate charges")
                    }
                }
            }
        }

        item {
            SectionCard(
                title = "Recent charges",
                subtitle = "Energy, cost, site, power, and battery movement."
            ) {
                if (snapshot.charges.isEmpty()) {
                    Text("No charges loaded yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        snapshot.charges.take(8).forEach { charge ->
                            DetailRow(
                                title = charge.location ?: charge.startedAt ?: "TeslaMate charge",
                                value = charge.energyKwh?.let { "${it.oneDecimal()} kWh" } ?: "Unknown",
                                detail = listOfNotNull(
                                    charge.cost?.asCurrency(),
                                    charge.powerKw?.let { "${it.oneDecimal()} kW" },
                                    if (charge.startSoc != null && charge.endSoc != null) "${charge.startSoc}% to ${charge.endSoc}%" else null
                                ).joinToString(" · ")
                            )
                        }
                    }
                }
            }
        }

        item {
            SectionCard(
                title = "Recent drives",
                subtitle = "Distance, energy, cost, and efficiency from TeslaMate."
            ) {
                if (snapshot.drives.isEmpty()) {
                    Text("No drives loaded yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        snapshot.drives.take(8).forEach { drive ->
                            DetailRow(
                                title = drive.startedAt ?: "TeslaMate drive",
                                value = drive.distance?.let { "${it.oneDecimal()} mi" } ?: "Unknown",
                                detail = listOfNotNull(
                                    drive.energyKwh?.let { "${it.oneDecimal()} kWh" },
                                    drive.cost?.asCurrency(),
                                    drive.efficiencyWhPerMile?.let { "${it.oneDecimal()} Wh/mi" }
                                ).joinToString(" · ")
                            )
                        }
                    }
                }
            }
        }

        item {
            SectionCard(
                title = "Geofence costs",
                subtitle = "Rollup by TeslaMate geofence or charge location."
            ) {
                val grouped = snapshot.charges.groupBy { it.location ?: "Unknown" }
                if (grouped.isEmpty()) {
                    Text("No geofence charge data loaded yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        grouped.toSortedMap().forEach { (location, charges) ->
                            val energy = charges.sumOf { it.energyKwh ?: 0.0 }
                            val cost = charges.sumOf { it.cost ?: 0.0 }
                            DetailRow(
                                title = location,
                                value = cost.asCurrency(),
                                detail = "${energy.oneDecimal()} kWh · ${charges.size} charge${if (charges.size == 1) "" else "s"}"
                            )
                        }
                    }
                }
            }
        }

        item {
            SectionCard(
                title = "Setup checklist",
                subtitle = "Self-hosted TeslaMate support mirrors the iOS workflow."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        "Deploy TeslaMate and expose TeslaMateApi or a compatible read-only API.",
                        "Keep PostgreSQL and MQTT private unless you run your own backend in front of them.",
                        "Use HTTPS, LAN, or a trusted VPN from this Android device.",
                        "Paste the base URL and token here, test the connection, then import charges into analytics."
                    ).forEach {
                        Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun MetricGrid(items: List<Pair<String, String>>) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items.forEach { (label, value) ->
            LabelPill(text = "$label: $value", color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun DetailRow(title: String, value: String, detail: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            if (detail.isNotBlank()) {
                Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Text(value, style = MaterialTheme.typography.titleMedium)
    }
}

private fun Boolean.yesNo(): String = if (this) "Yes" else "No"

private fun Boolean.onOff(): String = if (this) "On" else "Off"
