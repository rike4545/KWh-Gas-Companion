package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.EntryCategory
import com.myevcompanion.app.data.entryDateFormatter
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.DecorativeBadge
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.ImageShowcaseCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard

@Composable
fun HomeScreen(appState: AppState) {
    val entries by appState.entriesStore.entries.collectAsState()
    val sessions by appState.teslaFiStore.sessions.collectAsState()
    val selectedVehicleId by appState.profileStore.selectedVehicleId.collectAsState()
    val vehicles by appState.profileStore.vehicles.collectAsState()
    val budget by appState.budgetStore.budget.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val snapshot = remember(entries, sessions, selectedVehicleId) {
        appState.appModel.dashboardSnapshot()
    }
    val mlInsight = snapshot.chargingMlInsight
    val now = java.time.LocalDate.now()
    val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
    val monthlyChargingSpend = chargingEntries
        .filter { it.date.year == now.year && it.date.month == now.month }
        .sumOf { it.amount }
    val monthlyChargingEnergy = chargingEntries
        .filter { it.date.year == now.year && it.date.month == now.month }
        .sumOf { it.energyKWh ?: 0.0 }
    val remainingBudget = budget.monthlyLimit - monthlyChargingSpend
    val daysElapsed = now.dayOfMonth.coerceAtLeast(1)
    val daysInMonth = now.lengthOfMonth()
    val projectedMonthlyChargingSpend = monthlyChargingSpend / daysElapsed * daysInMonth
    val projectedWeeklyChargingSpend = monthlyChargingSpend / daysElapsed * 7.0
    val projectedWeeklyKwh = monthlyChargingEnergy / daysElapsed * 7.0
    val actionItems = remember(entries, sessions, vehicles, remainingBudget) {
        buildList {
            if (vehicles.isEmpty()) {
                add("Add your first vehicle so imports, forecasts, and expense entries can attach to a real garage profile.")
            }
            if (entries.isEmpty() && sessions.isEmpty()) {
                add("Import Tesla Supercharging history or add a manual expense to start building dashboard insights.")
            }
            if (remainingBudget < 0) {
                add("Charging spend is over budget this month. Review fast-charging use and rate windows.")
            } else if (projectedMonthlyChargingSpend > budget.monthlyLimit) {
                add("Charging is on pace to exceed the monthly target. Shifting more sessions home could help.")
            }
            if (sessions.isEmpty() && chargingEntries.isNotEmpty()) {
                add("You already have charging expenses saved. Import session history next to unlock deeper charging analysis.")
            }
            if (isEmpty()) {
                add("Your dashboard inputs are in good shape. The next high-value move is keeping charging and ownership entries current.")
            }
        }
    }

    AppScreen(
        title = "Drive smarter.",
        subtitle = "Track charging costs, vehicle efficiency, and ownership insights from one dashboard."
    ) {
        item {
            HeroCard(
                eyebrow = "Android Dashboard",
                title = "Your charging life in one glance",
                subtitle = "Spend, sessions, efficiency, and the next action item all live in a calmer home surface.",
                imageRes = homeHeroArtwork
            )
        }
        item {
            DecorativeBadge(text = "Top provider: ${snapshot.topProvider}")
        }
        item {
            DashboardPulseCard(
                spend = monthlyChargingSpend.asCurrency(),
                pace = projectedMonthlyChargingSpend.asCurrency(),
                remaining = remainingBudget.asCurrency(),
                provider = snapshot.topProvider
            )
        }
        item {
            SectionCard(
                title = "Action center",
                subtitle = "Quick next steps inspired by the iOS dashboard"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    actionItems.take(3).forEachIndexed { index, itemText ->
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            LabelPill(
                                text = "Action ${index + 1}",
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = itemText,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "This month",
                subtitle = "Live rollup from charging sessions and expense entries"
            ) {
                if (entries.isEmpty() && sessions.isEmpty()) {
                    Text(
                        text = "No driving or charging activity yet. Add a vehicle, log an expense, or import the official Tesla Supercharging CSV to start building real totals.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    MetricFlowRow(
                        items = listOf(
                            "Spend" to snapshot.totalSpend.asCurrency(),
                            "Energy" to "${snapshot.energyThisMonth.oneDecimal()} kWh",
                            "Avg cost" to "${snapshot.avgCostPerKwh.asCurrency()}/kWh",
                            "Sessions" to snapshot.sessionCount.toString()
                        )
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Weekly forecast",
                subtitle = "A compact forecast layer modeled after the iOS dashboard cards"
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Projected cost" to projectedWeeklyChargingSpend.asCurrency(),
                        "Projected kWh" to "${projectedWeeklyKwh.oneDecimal()} kWh",
                        "Month pace" to projectedMonthlyChargingSpend.asCurrency(),
                        "Avg rate" to if (snapshot.avgCostPerKwh > 0.0) "${snapshot.avgCostPerKwh.asCurrency()}/kWh" else "No rate yet"
                    )
                )
            }
        }
        item {
            GridEmissionsForecastCard()
        }
        item {
            SectionCard(
                title = "ML charging layer",
                subtitle = "A lightweight on-device model built from your own charging history"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    MetricFlowRow(
                        items = listOf(
                            "Confidence" to mlInsight.confidenceLabel,
                            "Samples" to mlInsight.sampleCount.toString(),
                            "Next cost" to (mlInsight.nextSessionCost?.asCurrency() ?: "Learning"),
                            "Next kWh" to (mlInsight.nextSessionEnergyKwh?.let { "${it.oneDecimal()} kWh" } ?: "Learning")
                        )
                    )
                    MetricFlowRow(
                        items = listOf(
                            "Trend" to mlInsight.trendLabel,
                            "Typical rate" to (mlInsight.typicalCostPerKwh?.let { "${it.asCurrency()}/kWh" } ?: "Unknown"),
                            "Price hotspot" to mlInsight.priciestProvider,
                            "Outlier" to mlInsight.anomalyLabel
                        )
                    )
                    Text(
                        text = mlInsight.summary,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "ML signal breakdown",
                subtitle = "The strongest inputs currently shaping the forecast"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    mlInsight.strongestSignals.forEach { (label, value) ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(text = label, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                text = value,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Budget",
                subtitle = "Charging spend versus the current monthly target"
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Monthly target" to budget.monthlyLimit.asCurrency(),
                        "Spent" to monthlyChargingSpend.asCurrency(),
                        "Remaining" to remainingBudget.asCurrency(),
                        "Target sessions" to budget.targetSessions.toString()
                    )
                )
            }
        }
        item {
            SectionCard(
                title = snapshot.activeVehicle?.name ?: "Active vehicle",
                subtitle = snapshot.activeVehicle?.notes ?: "Select a vehicle in the garage tab to personalize the dashboard."
            ) {
                snapshot.activeVehicle?.let { vehicle ->
                    MetricFlowRow(
                        items = listOf(
                            "Range" to "${vehicle.estimatedRangeMiles.toInt()} mi",
                            "Battery" to "${vehicle.batteryCapacityKWh.toInt()} kWh",
                            "Efficiency" to "${vehicle.efficiencyWhPerMile.toInt()} Wh/mi"
                        )
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Data sources",
                subtitle = "The same dashboard idea the iOS app uses to show where current insights come from"
            ) {
                MetricFlowRow(
                    items = listOf(
                        "Garage" to vehicles.size.toString(),
                        "Expense entries" to entries.size.toString(),
                        "Charging sessions" to sessions.size.toString(),
                        "Imported charging rows" to chargingEntries.size.toString()
                    )
                )
            }
        }
        snapshot.activeVehicle?.let { vehicle ->
            item {
                ImageShowcaseCard(
                    imageRes = vehicle.artworkRes(),
                    title = "${vehicle.make} ${vehicle.model}",
                    subtitle = "The Android dashboard now reuses the imported iOS garage artwork for the active vehicle."
                )
            }
        }
        item {
            SectionCard(
                title = "Recent charging",
                subtitle = "Your latest charging sessions at a glance"
            ) {
                if (snapshot.recentSessions.isEmpty()) {
                    Text(
                        text = "No charging sessions have been imported yet. Tesla Supercharging CSV imports still land in your expense ledger, so you can start with billing history even before session feeds are connected.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        snapshot.recentSessions.forEach { session ->
                            ActivityRow(
                                title = session.stationName,
                                subtitle = "${session.provider} • ${session.startedAt.format(com.myevcompanion.app.data.sessionDateTimeFormatter)}",
                                meta = session.cost.asCurrency(),
                                badgeText = "${session.energyAddedKWh.oneDecimal()} kWh",
                                badgeColor = if (session.isSupercharger) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Recent expenses",
                subtitle = "Charging and ownership costs stay together, like the iOS app"
            ) {
                if (snapshot.recentEntries.isEmpty()) {
                    Text(
                        text = "No expense entries yet. Manual entries and official Tesla Supercharging imports will both appear here.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        snapshot.recentEntries.forEach { entry ->
                            ActivityRow(
                                title = entry.title,
                                subtitle = "${entry.location} • ${entry.date.format(entryDateFormatter)}",
                                meta = entry.amount.asCurrency(),
                                badgeText = entry.category.label,
                                badgeColor = entry.category.tint
                            )
                        }
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Insights",
                subtitle = "Smart nudges inspired by the original app's recommendations"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    snapshot.insights.forEach { insight ->
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(insight.title, style = MaterialTheme.typography.titleMedium)
                                LabelPill(text = insight.scoreLabel, color = MaterialTheme.colorScheme.primary)
                            }
                            Text(
                                text = insight.body,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
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
    }
}

@Composable
private fun GridEmissionsForecastCard() {
    val forecast = sampleGridEmissionForecast()
    val best = forecast.minBy { it.index }
    val dirtiest = forecast.maxBy { it.index }
    val current = forecast.first()
    val reduction = (dirtiest.index - best.index).coerceAtLeast(0)

    SectionCard(
        title = "Grid emissions forecast",
        subtitle = "A weather-style clean charging window for the next 24 hours"
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            MetricFlowRow(
                items = listOf(
                    "Now" to "${current.index}/100 ${current.label}",
                    "Best window" to best.hourLabel,
                    "Avoid" to dirtiest.hourLabel,
                    "Shift upside" to "$reduction pts cleaner"
                )
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                forecast.forEach { point ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height((26 + (100 - point.index) * 0.38).dp)
                            .clip(RoundedCornerShape(5.dp))
                            .background(point.color)
                    )
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Green = cleaner", style = MaterialTheme.typography.labelMedium, color = Color(0xFF2F7D4F))
                Text("Red = carbon-heavy", style = MaterialTheme.typography.labelMedium, color = Color(0xFFB23A3A))
            }
            Text(
                text = "Uses the same idea as Project Clean Grid: WattTime marginal emissions data can point flexible loads like EV charging, laundry, and home batteries toward cleaner hours.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun DashboardPulseCard(
    spend: String,
    pace: String,
    remaining: String,
    provider: String
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = Color.Transparent
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
                            MaterialTheme.colorScheme.tertiary.copy(alpha = 0.08f)
                        )
                    )
                )
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            MetricFlowRow(
                items = listOf(
                    "Charging spend" to spend,
                    "Month pace" to pace,
                    "Remaining" to remaining,
                    "Top provider" to provider
                )
            )
        }
    }
}

@Composable
private fun ActivityRow(
    title: String,
    subtitle: String,
    meta: String,
    badgeText: String,
    badgeColor: Color
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(badgeColor, CircleShape)
                )
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Column(
                modifier = Modifier.padding(start = 12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                horizontalAlignment = Alignment.End
            ) {
                LabelPill(text = badgeText, color = badgeColor)
                Text(meta, style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}
