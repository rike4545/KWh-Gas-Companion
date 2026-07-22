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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.EntryCategory
import com.myevcompanion.app.data.ExpenseEntry
import com.myevcompanion.app.data.entryDateFormatter
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.ChipSelector
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ExpensesScreen(
    appState: AppState,
    onOpenEditEntry: (String?) -> Unit
) {
    val entries by appState.entriesStore.entries.collectAsState()
    val vehicles by appState.profileStore.vehicles.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    var selectedCategory by rememberSaveable { mutableStateOf("All") }
    var query by rememberSaveable { mutableStateOf("") }
    var sortMode by rememberSaveable { mutableStateOf("Newest") }
    val filteredEntries = entries
        .filter { selectedCategory == "All" || it.category.name == selectedCategory }
        .filter { entry ->
            if (query.isBlank()) {
                true
            } else {
                val vehicleName = vehicles.firstOrNull { it.id == entry.vehicleId }?.name.orEmpty()
                listOf(entry.title, entry.location, entry.notes, vehicleName)
                    .any { it.contains(query, ignoreCase = true) }
            }
        }
        .let { visible ->
            when (sortMode) {
                "Amount" -> visible.sortedByDescending { it.amount }
                "Oldest" -> visible.sortedBy { it.date }
                else -> visible.sortedByDescending { it.date }
            }
        }
    val groupedTotals = EntryCategory.entries.associateWith { category ->
        entries.filter { it.category == category }.sumOf { it.amount }
    }
    val totalSpend = filteredEntries.sumOf { it.amount }
    val totalEnergy = filteredEntries.sumOf { it.energyKWh ?: 0.0 }

    AppScreen(
        title = "Expenses",
        subtitle = "A filterable ledger for charging, ownership, and service costs modeled after the iOS expense tab."
    ) {
        item {
            HeroCard(
                eyebrow = "Ledger",
                title = "Manual and imported expenses together",
                subtitle = "Search, filter, and sort the same ownership story you track on iOS."
            )
        }
        item {
            SectionCard(
                title = "Summary",
                subtitle = if (selectedCategory == "All") "All expense categories" else "Filtered to ${EntryCategory.valueOf(selectedCategory).label}"
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Total" to totalSpend.asCurrency(),
                        "kWh" to totalEnergy.oneDecimal(),
                        "Entries" to filteredEntries.size.toString(),
                        "Vehicles" to filteredEntries.map { it.vehicleId }.filter { it.isNotBlank() }.distinct().size.toString()
                    )
                )
            }
        }
        item {
            SectionCard(
                title = "Search and sort",
                subtitle = "Faster ledger triage, closer to the iOS expense list behavior"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    LabeledField(
                        label = "Search title, notes, location, vehicle",
                        value = query,
                        onValueChange = { query = it }
                    )
                    ChipSelector(
                        label = "Sort",
                        options = listOf("Newest", "Oldest", "Amount"),
                        selected = sortMode,
                        onSelected = { sortMode = it }
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Category totals",
                subtitle = "This month's totals by expense category"
            ) {
                MetricFlowRow(
                    items = groupedTotals.toList().map { (category, total) ->
                        category.label to total.asCurrency()
                    }
                )
            }
        }
        item {
            SectionCard(
                title = "Filter",
                subtitle = "Quick category filtering like the iOS expense list"
            ) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    LabelPill(
                        text = "All",
                        color = if (selectedCategory == "All") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier.clickable { selectedCategory = "All" }
                    )
                    EntryCategory.entries.forEach { category ->
                        LabelPill(
                            text = category.label,
                            color = if (selectedCategory == category.name) category.tint else MaterialTheme.colorScheme.outline,
                            modifier = Modifier.clickable { selectedCategory = category.name }
                        )
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
                title = "Recent entries",
                subtitle = "Filtered, searchable, and easier to scan like the iOS ledger"
            ) {
                if (filteredEntries.isEmpty()) {
                    Text(
                        text = "No expenses match this view yet. Add a manual expense below, change the category filter, or loosen the search.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        filteredEntries.forEach { entry ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onOpenEditEntry(entry.id) },
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(entry.title, style = MaterialTheme.typography.titleMedium)
                                    Text(
                                        expenseSubtitle(entry, vehicles),
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    if (entry.energyKWh != null) {
                                        Text(
                                            "${entry.energyKWh.oneDecimal()} kWh recorded",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
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
        item {
            Button(onClick = { onOpenEditEntry(null) }, modifier = Modifier.fillMaxWidth()) {
                Text("Add manual expense")
            }
        }
    }
}

private fun expenseSubtitle(entry: ExpenseEntry, vehicles: List<com.myevcompanion.app.data.VehicleProfile>): String {
    val vehicleName = vehicles.firstOrNull { it.id == entry.vehicleId }?.name
    return listOfNotNull(
        entry.location.takeIf { it.isNotBlank() },
        entry.date.format(entryDateFormatter),
        vehicleName
    ).joinToString(" • ")
}
