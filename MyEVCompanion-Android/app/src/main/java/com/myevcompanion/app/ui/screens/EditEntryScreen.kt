package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.EntryCategory
import com.myevcompanion.app.data.ExpenseEntry
import com.myevcompanion.app.data.VehicleProfile
import com.myevcompanion.app.data.entryDateFormatter
import com.myevcompanion.app.ui.components.ChipSelector
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.SectionCard
import java.time.LocalDate
import java.util.UUID

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EditEntryScreen(
    appState: AppState,
    initialEntryId: String? = null
) {
    val entries by appState.entriesStore.entries.collectAsState()
    val vehicles by appState.profileStore.vehicles.collectAsState()
    val activeVehicleId by appState.profileStore.selectedVehicleId.collectAsState()
    val activeVehicle = appState.profileStore.activeVehicle()

    var editingId by rememberSaveable { mutableStateOf<String?>(null) }
    var title by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("") }
    var energy by rememberSaveable { mutableStateOf("") }
    var date by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var location by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var selectedCategory by rememberSaveable { mutableStateOf(EntryCategory.Charging.name) }
    var selectedVehicleId by rememberSaveable { mutableStateOf("") }
    var statusMessage by rememberSaveable { mutableStateOf("") }
    val selectedVehicle = remember(selectedVehicleId, vehicles) {
        vehicles.firstOrNull { it.id == selectedVehicleId }
    }

    fun loadEntry(entry: ExpenseEntry?) {
        editingId = entry?.id
        title = entry?.title.orEmpty()
        amount = entry?.amount?.toString().orEmpty()
        energy = entry?.energyKWh?.toString().orEmpty()
        date = entry?.date?.toString() ?: LocalDate.now().toString()
        location = entry?.location.orEmpty()
        notes = entry?.notes.orEmpty()
        selectedCategory = entry?.category?.name ?: EntryCategory.Charging.name
        selectedVehicleId = entry?.vehicleId ?: activeVehicleId
    }

    LaunchedEffect(initialEntryId, entries) {
        if (initialEntryId.isNullOrBlank()) return@LaunchedEffect
        if (editingId == initialEntryId) return@LaunchedEffect
        entries.firstOrNull { it.id == initialEntryId }?.let(::loadEntry)
    }

    LaunchedEffect(activeVehicleId) {
        if (editingId == null && selectedVehicleId.isBlank()) {
            selectedVehicleId = activeVehicleId
        }
        if (editingId == null && location.isBlank()) {
            location = activeVehicle?.name?.let { "$it logbook" } ?: ""
        }
    }

    val isChargingCategory = selectedCategory == EntryCategory.Charging.name

    AppScreen(
        title = "Expense Editor",
        subtitle = "Add manual ownership costs, charging expenses, and general ledger entries with a more complete iOS-style form."
    ) {
        item {
            SectionCard(
                title = "Vehicle assignment",
                subtitle = selectedVehicle?.displayNameForAndroid() ?: "Choose a vehicle below or leave this expense unattached."
            ) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    LabelPill(
                        text = "No vehicle",
                        color = if (selectedVehicleId.isBlank()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier.clickable { selectedVehicleId = "" }
                    )
                    vehicles.forEach { vehicle ->
                        LabelPill(
                            text = vehicle.name,
                            color = if (selectedVehicleId == vehicle.id) vehicle.accent else MaterialTheme.colorScheme.outline,
                            modifier = Modifier.clickable { selectedVehicleId = vehicle.id }
                        )
                    }
                }
            }
        }
        item {
            SectionCard(
                title = if (editingId == null) "New entry" else "Edit entry",
                subtitle = "Entries are persisted immediately to local storage and support both charging and non-charging expenses."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    LabeledField(label = "Title", value = title, onValueChange = { title = it })
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        LabeledField(
                            label = "Amount",
                            value = amount,
                            onValueChange = { amount = it },
                            modifier = Modifier.weight(1f)
                        )
                        LabeledField(
                            label = "Energy kWh",
                            value = energy,
                            onValueChange = { energy = it },
                            modifier = Modifier.weight(1f),
                            supportingText = if (isChargingCategory) "Optional, but useful for charging imports and cost per kWh." else "Usually leave blank for non-charging expenses."
                        )
                    }
                    LabeledField(label = "Date", value = date, onValueChange = { date = it })
                    LabeledField(label = "Location", value = location, onValueChange = { location = it })
                    LabeledField(
                        label = "Notes",
                        value = notes,
                        onValueChange = { notes = it },
                        singleLine = false,
                        supportingText = "Short notes show up in export too."
                    )
                    ChipSelector(
                        label = "Category",
                        options = EntryCategory.entries.map { it.name },
                        selected = selectedCategory,
                        onSelected = {
                            selectedCategory = it
                            if (it != EntryCategory.Charging.name) energy = ""
                        }
                    )
                    Text(
                        text = "Dates use ISO format like 2026-03-27 so imports, exports, and manual expenses stay consistent.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = {
                                val parsedAmount = amount.toDoubleOrNull()
                                val parsedDate = runCatching { LocalDate.parse(date) }.getOrNull()
                                if (title.isBlank() || parsedAmount == null || parsedDate == null) {
                                    statusMessage = "Fill in title, amount, and a valid date first."
                                } else {
                                    val entry = ExpenseEntry(
                                        id = editingId ?: UUID.randomUUID().toString(),
                                        title = title,
                                        category = EntryCategory.valueOf(selectedCategory),
                                        amount = parsedAmount,
                                        energyKWh = if (isChargingCategory) energy.toDoubleOrNull() else null,
                                        date = parsedDate,
                                        location = location.ifBlank { "Manual entry" },
                                        vehicleId = selectedVehicleId,
                                        notes = notes
                                    )
                                    appState.entriesStore.saveEntry(entry)
                                    statusMessage = if (editingId == null) "Manual expense saved." else "Expense updated."
                                    loadEntry(null)
                                }
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (editingId == null) "Save expense" else "Update expense")
                        }
                        OutlinedButton(
                            onClick = {
                                if (editingId != null) {
                                    appState.entriesStore.deleteEntry(editingId!!)
                                    statusMessage = "Expense deleted."
                                }
                                loadEntry(null)
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (editingId == null) "Clear form" else "Delete")
                        }
                    }
                    if (statusMessage.isNotBlank()) {
                        Text(statusMessage, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Recent entries",
                subtitle = "Tap any item to load it into the form above."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    entries.take(8).forEach { entry ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { loadEntry(entry) },
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(entry.title, style = MaterialTheme.typography.titleMedium)
                                Text(
                                    buildEntrySubtitle(entry, vehicles),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                LabelPill(text = entry.category.label, color = entry.category.tint)
                                Text(entry.amount.asCurrency(), style = MaterialTheme.typography.titleMedium)
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun com.myevcompanion.app.data.VehicleProfile.displayNameForAndroid(): String {
    return "$year $make $model"
}

private fun buildEntrySubtitle(
    entry: ExpenseEntry,
    vehicles: List<VehicleProfile>
): String {
    val vehicleName = vehicles.firstOrNull { it.id == entry.vehicleId }?.name
    return listOfNotNull(
        entry.date.format(entryDateFormatter),
        entry.location.takeIf { it.isNotBlank() },
        vehicleName
    ).joinToString(" • ")
}
