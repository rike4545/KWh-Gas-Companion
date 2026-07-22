package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.VehicleProfile
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.ImageShowcaseCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard
import java.util.UUID

@Composable
fun VehiclesScreen(appState: AppState) {
    val vehicles by appState.profileStore.vehicles.collectAsState()
    val selectedId by appState.profileStore.selectedVehicleId.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val selected = vehicles.firstOrNull { it.id == selectedId }

    var editingId by rememberSaveable { mutableStateOf<String?>(null) }
    var name by rememberSaveable { mutableStateOf("") }
    var make by rememberSaveable { mutableStateOf("") }
    var model by rememberSaveable { mutableStateOf("") }
    var year by rememberSaveable { mutableStateOf("") }
    var plate by rememberSaveable { mutableStateOf("") }
    var vin by rememberSaveable { mutableStateOf("") }
    var battery by rememberSaveable { mutableStateOf("") }
    var range by rememberSaveable { mutableStateOf("") }
    var efficiency by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var statusMessage by rememberSaveable { mutableStateOf("") }

    fun loadVehicle(vehicle: VehicleProfile?) {
        editingId = vehicle?.id
        name = vehicle?.name.orEmpty()
        make = vehicle?.make.orEmpty()
        model = vehicle?.model.orEmpty()
        year = vehicle?.year?.toString().orEmpty()
        plate = vehicle?.plateOrMarker.orEmpty()
        vin = vehicle?.vin.orEmpty()
        battery = vehicle?.batteryCapacityKWh?.toString().orEmpty()
        range = vehicle?.estimatedRangeMiles?.toString().orEmpty()
        efficiency = vehicle?.efficiencyWhPerMile?.toString().orEmpty()
        notes = vehicle?.notes.orEmpty()
    }

    LaunchedEffect(selectedId) {
        loadVehicle(selected)
    }

    AppScreen(
        title = "Garage",
        subtitle = "A garage-first home for vehicle profiles, care workflows, and import-ready details."
    ) {
        item {
            HeroCard(
                eyebrow = "Vehicles",
                title = selected?.name ?: "Your EV garage",
                subtitle = selected?.notes ?: "Add your first vehicle below so charging imports and manual entries attach to real garage data.",
                imageRes = selected?.artworkRes() ?: homeHeroArtwork
            )
        }
        item {
            SectionCard(
                title = "Story and care",
                subtitle = "The iOS garage mixes profiles with service-aware shortcuts, so Android now starts there too."
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Story timeline" to "Coming next",
                        "DIY service" to "Vault-ready",
                        "Reminders" to "Recurring care",
                        "Import / export" to "Charging hub"
                    )
                )
            }
        }
        item {
            SectionCard(
                title = "Garage lineup",
                subtitle = "Tap a vehicle to make it current and load it into the editor below"
            ) {
                if (vehicles.isEmpty()) {
                    Text(
                        text = "No vehicles yet. Save your first one below, or import the official Tesla Supercharging CSV and let the app create a starter profile from Tesla metadata.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        vehicles.forEach { vehicle ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        appState.profileStore.selectVehicle(vehicle.id)
                                        loadVehicle(vehicle)
                                        statusMessage = "${vehicle.name} loaded into the editor."
                                    },
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(vehicle.name, style = MaterialTheme.typography.titleMedium)
                                    Text(
                                        "${vehicle.year} ${vehicle.make} ${vehicle.model}",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                LabelPill(
                                    text = if (vehicle.id == selectedId) "Current" else "Load",
                                    color = vehicle.accent
                                )
                            }
                        }
                    }
                }
            }
        }
        selected?.let { vehicle ->
            item {
                SectionCard(
                    title = "Selected vehicle",
                    subtitle = "Live stats from the active profile"
                ) {
                    MetricFlowRow(
                        items = listOf(
                            "Battery" to "${vehicle.batteryCapacityKWh.toInt()} kWh",
                            "Range" to "${vehicle.estimatedRangeMiles.toInt()} mi",
                            "Efficiency" to "${vehicle.efficiencyWhPerMile.toInt()} Wh/mi",
                            "Plate" to vehicle.plateOrMarker
                        )
                    )
                }
            }
            item {
                ImageShowcaseCard(
                    imageRes = vehicle.artworkRes(),
                    title = "${vehicle.year} ${vehicle.make} ${vehicle.model}",
                    subtitle = "Imported iOS vehicle artwork is now visible directly in the garage experience."
                )
            }
        }
        if (showAds) {
            item {
                AdBannerCard()
            }
        }
        item {
            SectionCard(
                title = if (editingId == null) "New vehicle" else "Edit vehicle",
                subtitle = "Changes are saved locally on-device and used across imports, entries, calculators, and dashboard summaries."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    LabeledField(label = "Name", value = name, onValueChange = { name = it })
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        LabeledField(label = "Make", value = make, onValueChange = { make = it }, modifier = Modifier.weight(1f))
                        LabeledField(label = "Model", value = model, onValueChange = { model = it }, modifier = Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        LabeledField(label = "Year", value = year, onValueChange = { year = it }, modifier = Modifier.weight(1f))
                        LabeledField(label = "Plate", value = plate, onValueChange = { plate = it }, modifier = Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        LabeledField(label = "Battery kWh", value = battery, onValueChange = { battery = it }, modifier = Modifier.weight(1f))
                        LabeledField(label = "Range miles", value = range, onValueChange = { range = it }, modifier = Modifier.weight(1f))
                    }
                    LabeledField(label = "Efficiency Wh/mi", value = efficiency, onValueChange = { efficiency = it })
                    LabeledField(label = "VIN", value = vin, onValueChange = { vin = it })
                    LabeledField(label = "Notes", value = notes, onValueChange = { notes = it }, singleLine = false)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = {
                                val parsedYear = year.toIntOrNull()
                                val parsedBattery = battery.toDoubleOrNull()
                                val parsedRange = range.toDoubleOrNull()
                                val parsedEfficiency = efficiency.toDoubleOrNull()
                                if (name.isBlank() || make.isBlank() || model.isBlank() || parsedYear == null || parsedBattery == null || parsedRange == null || parsedEfficiency == null) {
                                    statusMessage = "Fill in the main vehicle fields before saving."
                                } else {
                                    appState.profileStore.saveVehicle(
                                        VehicleProfile(
                                            id = editingId ?: UUID.randomUUID().toString(),
                                            name = name,
                                            make = make,
                                            model = model,
                                            year = parsedYear,
                                            vin = vin,
                                            plateOrMarker = plate,
                                            isEv = true,
                                            batteryCapacityKWh = parsedBattery,
                                            efficiencyWhPerMile = parsedEfficiency,
                                            estimatedRangeMiles = parsedRange,
                                            accent = selected?.accent ?: androidx.compose.ui.graphics.Color(0xFF16C79A),
                                            notes = notes
                                        )
                                    )
                                    statusMessage = if (editingId == null) "Vehicle added." else "Vehicle updated."
                                }
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (editingId == null) "Save vehicle" else "Update vehicle")
                        }
                        OutlinedButton(
                            onClick = {
                                editingId = null
                                name = ""
                                make = ""
                                model = ""
                                year = ""
                                plate = ""
                                vin = ""
                                battery = ""
                                range = ""
                                efficiency = ""
                                notes = ""
                                statusMessage = "Ready for a new vehicle."
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("New profile")
                        }
                    }
                    if (editingId != null && vehicles.size > 1) {
                        OutlinedButton(
                            onClick = {
                                appState.profileStore.deleteSelectedVehicle()
                                statusMessage = "Vehicle removed."
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Delete selected vehicle")
                        }
                    }
                    if (statusMessage.isNotBlank()) {
                        Text(statusMessage, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}
