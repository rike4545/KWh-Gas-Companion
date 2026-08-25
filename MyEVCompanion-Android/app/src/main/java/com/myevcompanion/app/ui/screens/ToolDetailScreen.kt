package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import android.net.Uri
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.EntryCategory
import com.myevcompanion.app.data.SampleData
import com.myevcompanion.app.data.ToolCard
import com.myevcompanion.app.data.sessionDateTimeFormatter
import com.myevcompanion.app.ui.screens.asCurrency
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard
import java.time.Duration
import kotlin.math.max
import kotlin.math.roundToInt

@Composable
fun ToolDetailScreen(
    appState: AppState,
    toolTitle: String
) {
    val tool = SampleData.tools.firstOrNull { it.title == toolTitle }
    val entries by appState.entriesStore.entries.collectAsState()
    val vehicles by appState.profileStore.vehicles.collectAsState()
    val sessions by appState.teslaFiStore.sessions.collectAsState()
    val budget by appState.budgetStore.budget.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val discountFavorites by appState.discountFavorites.favorites.collectAsState()
    val mlInsight = appState.appModel.chargingMlInsight()
    val uriHandler = LocalUriHandler.current

    val resolvedTool = tool ?: ToolCard(
        title = toolTitle,
        description = "Use this workspace to review the data and context tied to this tool.",
        group = "Tool",
        accent = MaterialTheme.colorScheme.primary
    )

    AppScreen(
        title = resolvedTool.title,
        subtitle = resolvedTool.description
    ) {
        item {
            HeroCard(
                eyebrow = resolvedTool.group,
                title = resolvedTool.title,
                subtitle = toolHeroSubtitle(resolvedTool),
                imageRes = resolvedTool.detailArtworkRes()
            )
        }
        if (showAds) {
            item {
                AdBannerCard()
            }
        }
        when (resolvedTool.title) {
            "Charging Budget Guard" -> {
                val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
                val chargingSpend = chargingEntries.sumOf { it.amount }
                val chargingEnergy = chargingEntries.sumOf { it.energyKWh ?: 0.0 }
                val remainingBudget = budget.monthlyLimit - chargingSpend
                item {
                    SectionCard(
                        title = "Budget status",
                        subtitle = "Live numbers from your saved charging ledger"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Budget" to budget.monthlyLimit.asCurrency(),
                                "Spent" to chargingSpend.asCurrency(),
                                "Remaining" to remainingBudget.asCurrency(),
                                "kWh tracked" to chargingEnergy.oneDecimal()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Guardrail insight",
                        subtitle = "A quick read on how current charging spend compares with your target"
                    ) {
                        Text(
                            text = when {
                                chargingEntries.isEmpty() -> "No charging entries yet. Import Tesla history or add manual charging expenses to activate monthly guardrails."
                                remainingBudget >= 0 -> "You are ${remainingBudget.asCurrency()} under the current monthly charging budget. At this pace, the budget is still healthy."
                                else -> "You are ${kotlin.math.abs(remainingBudget).asCurrency()} over the current monthly charging budget, so this is a good point to review fast-charging frequency and price windows."
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Quarterly Tax Summary" -> {
                val currentYear = java.time.LocalDate.now().year
                val quarterTotals = (1..4).associateWith { quarter ->
                    entries.filter { entry ->
                        entry.date.year == currentYear && ((entry.date.monthValue - 1) / 3 + 1) == quarter
                    }.sumOf { it.amount }
                }
                item {
                    SectionCard(
                        title = "Quarterly totals",
                        subtitle = "Year-to-date ownership and charging totals grouped by quarter"
                    ) {
                        MetricFlowRow(
                            items = quarterTotals.map { (quarter, total) ->
                                "Q$quarter" to total.asCurrency()
                            }
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Tax-ready context",
                        subtitle = "A quarter view that keeps year-to-date costs easier to review"
                    ) {
                        Text(
                            text = "Saved entries this year: ${entries.count { it.date.year == currentYear }}. Charging, parking, tolls, service, and other ownership costs all roll into this quarter view.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Cost of Ownership" -> {
                val totals = EntryCategory.entries.associateWith { category ->
                    entries.filter { it.category == category }.sumOf { it.amount }
                }
                item {
                    SectionCard(
                        title = "Ownership totals",
                        subtitle = "A single view of charging, maintenance, insurance, and other ownership costs"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Total spend" to entries.sumOf { it.amount }.asCurrency(),
                                "Charging" to (totals[EntryCategory.Charging] ?: 0.0).asCurrency(),
                                "Insurance" to (totals[EntryCategory.Insurance] ?: 0.0).asCurrency(),
                                "Maintenance" to (totals[EntryCategory.Maintenance] ?: 0.0).asCurrency()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Top categories",
                        subtitle = "Highest-spend buckets from your current ledger"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            totals.entries.sortedByDescending { it.value }.take(5).forEach { (category, total) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    LabelPill(text = category.label, color = category.tint)
                                    Text(total.asCurrency(), style = MaterialTheme.typography.titleMedium)
                                }
                            }
                        }
                    }
                }
            }

            "Tesla VIN Decoder" -> {
                val teslaVehicle = vehicles.firstOrNull {
                    it.make.contains("tesla", ignoreCase = true) && it.vin.length >= 11
                }
                val vin = teslaVehicle?.vin.orEmpty()
                item {
                    SectionCard(
                        title = "VIN decode",
                        subtitle = "Read key Tesla identifiers from the VIN saved in your garage"
                    ) {
                        if (vin.length < 11) {
                            Text(
                                text = "Add a Tesla vehicle with a VIN in the Garage tab to activate this decoder.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            MetricFlowRow(
                                items = listOf(
                                    "Model hint" to decodeTeslaModel(vin),
                                    "Drive unit" to decodeTeslaDrive(vin),
                                    "Battery" to decodeTeslaBattery(vin),
                                    "Year code" to vin[9].toString()
                                )
                            )
                        }
                    }
                }
                teslaVehicle?.let { vehicle ->
                    item {
                        SectionCard(
                            title = "Garage link",
                            subtitle = "Currently decoding ${vehicle.name}"
                        ) {
                            Text(
                                text = vehicle.vin,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            "Trip Budget Planner" -> {
                val activeVehicle = appState.profileStore.activeVehicle()
                val avgChargingCostPerKwh = entries
                    .filter { it.category == EntryCategory.Charging && (it.energyKWh ?: 0.0) > 0.0 }
                    .takeIf { it.isNotEmpty() }
                    ?.let { chargingEntries -> chargingEntries.sumOf { it.amount } / chargingEntries.sumOf { it.energyKWh ?: 0.0 } }
                    ?: 0.41
                val estimatedTripKwh = activeVehicle?.batteryCapacityKWh?.let { battery -> max(battery * 1.4, 45.0) } ?: 60.0
                val estimatedTripCost = estimatedTripKwh * avgChargingCostPerKwh
                item {
                    SectionCard(
                        title = "Starter trip budget",
                        subtitle = "Live estimate from your vehicle profile and charging history"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Vehicle" to (activeVehicle?.name ?: "Not set"),
                                "Energy plan" to "${estimatedTripKwh.oneDecimal()} kWh",
                                "Avg rate" to "${avgChargingCostPerKwh.asCurrency()}/kWh",
                                "Charge cost" to estimatedTripCost.asCurrency()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Planner note",
                        subtitle = "A quick estimate built from your saved vehicle profile and charging history"
                    ) {
                        Text(
                            text = "This screen uses your saved charging costs as the baseline for a simple road-trip estimate so you can frame distance, energy, and charging spend before you leave.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Altitude Cockpit" -> {
                val activeVehicle = appState.profileStore.activeVehicle()
                val elevationGain = (sessions.sumOf { max(0, it.endSoc - it.startSoc) } * 18).coerceAtLeast(620)
                item {
                    SectionCard(
                        title = "Altitude profile",
                        subtitle = "A no-login route snapshot for elevation-aware drives"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Vehicle" to (activeVehicle?.name ?: "Garage vehicle"),
                                "Current altitude" to "412 ft",
                                "Route high" to "${elevationGain} ft",
                                "Grade note" to "Rolling terrain"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Recording checklist",
                        subtitle = "Modeled after Tes.app's altitude cockpit"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "Start a profile before a mountain or bridge-heavy route.",
                                "Mark the route high point so the return leg has better range context.",
                                "Pair altitude notes with efficiency and charging sessions after the drive."
                            ).forEach { note ->
                                Text(note, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            "Weather Cockpit" -> {
                item {
                    SectionCard(
                        title = "Route weather",
                        subtitle = "Trip-friendly forecast details without account access"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Temperature" to "64 F",
                                "Wind" to "12 mph NW",
                                "Humidity" to "58%",
                                "Rain risk" to "20%"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "EV impact",
                        subtitle = "How weather can change the next drive"
                    ) {
                        Text(
                            text = "Headwinds, heavy rain, and cold cabin preconditioning can move real-world efficiency more than the route distance alone. Keep this cockpit next to trip planning when the forecast looks unsettled.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Trip Cockpit" -> {
                val activeVehicle = appState.profileStore.activeVehicle()
                val recentTripEnergy = sessions.take(3).sumOf { it.energyAddedKWh }.coerceAtLeast(38.0)
                val estimatedMiles = activeVehicle?.efficiencyWhPerMile?.let { (recentTripEnergy * 1000.0 / it).roundToInt() } ?: 148
                item {
                    SectionCard(
                        title = "Trip recorder",
                        subtitle = "Route, distance, speed, energy, and stop context"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Distance" to "$estimatedMiles mi",
                                "Energy" to "${recentTripEnergy.oneDecimal()} kWh",
                                "Avg speed" to "48 mph",
                                "Stops" to sessions.take(3).size.toString()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Route notes",
                        subtitle = "A simple cockpit for the next saved trip"
                    ) {
                        Text(
                            text = "Use this as a lightweight trip profile: record the route, charging stops, average speed, and post-drive energy so later forecasts have better assumptions.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "TeslaFi Mobile Dashboard" -> {
                val sessionCount = sessions.size
                val energy = sessions.sumOf { it.energyAddedKWh }
                val cost = sessions.sumOf { it.cost }
                val activeVehicle = appState.profileStore.activeVehicle()
                val estimatedMiles = activeVehicle?.efficiencyWhPerMile?.takeIf { it > 0 }?.let {
                    energy * 1000.0 / it
                } ?: sessions.sumOf { max(0, it.endSoc - it.startSoc).toDouble() * 2.8 }
                val gasEquivalentCost = estimatedMiles / 28.0 * 3.65
                val savings = gasEquivalentCost - cost
                item {
                    SectionCard(
                        title = "TeslaFi-style mobile summary",
                        subtitle = "Drive and charge metrics from imported session history"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Sessions" to sessionCount.toString(),
                                "Energy" to "${energy.oneDecimal()} kWh",
                                "Cost" to cost.asCurrency(),
                                "Distance" to "${estimatedMiles.roundToInt()} mi",
                                "Gas savings" to savings.asCurrency(),
                                "Avg rate" to if (energy > 0) "${(cost / energy).asCurrency()}/kWh" else "Unknown"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Recent charges",
                        subtitle = "Charge rate, energy, and cost details"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            sessions.take(6).forEach { session ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column {
                                        Text(session.stationName, style = MaterialTheme.typography.bodyMedium)
                                        Text(
                                            text = session.startedAt.format(sessionDateTimeFormatter),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    Text(
                                        text = "${session.energyAddedKWh.oneDecimal()} kWh · ${session.cost.asCurrency()}",
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Privacy posture",
                        subtitle = "Modeled after Fido's local-token approach"
                    ) {
                        Text(
                            text = "Use a TeslaFi API token only with TeslaFi-compatible endpoints you trust. Imported data stays on this device in the Android app, and Tesla Owner API OAuth tokens are a separate credential flow from TeslaFi API tokens.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "TeslaMate Mobile Dashboard" -> {
                val sessionCount = sessions.size
                val latest = sessions.maxByOrNull { it.startedAt }
                val energy = sessions.sumOf { it.energyAddedKWh }
                val cost = sessions.sumOf { it.cost }
                val averagePower = sessions.map { it.maxPowerKw }.average().takeIf { !it.isNaN() }
                val chargeGain = sessions.sumOf { max(0, it.endSoc - it.startSoc) }
                item {
                    SectionCard(
                        title = "TesLog-style mobile summary",
                        subtitle = "Vehicle, battery, and charging context from saved history"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Vehicle state" to if (latest == null) "Unknown" else "Parked",
                                "Battery now" to (latest?.endSoc?.let { "$it%" } ?: "Unknown"),
                                "Sessions" to sessionCount.toString(),
                                "Energy" to "${energy.oneDecimal()} kWh",
                                "Charge gain" to "$chargeGain%",
                                "Peak power" to (latest?.maxPowerKw?.let { "$it kW" } ?: "Unknown"),
                                "Avg power" to (averagePower?.roundToInt()?.let { "$it kW" } ?: "Unknown"),
                                "Charge cost" to cost.asCurrency()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Vehicle details",
                        subtitle = "Fields TesLog-style dashboards commonly surface"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Locked" to "Unknown",
                                "Sentry" to "Unknown",
                                "Climate" to "Unknown",
                                "Software" to "Connected endpoint needed"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "TeslaMate fit",
                        subtitle = "What this Android panel needs for full parity"
                    ) {
                        Text(
                            text = "For deeper TesLog-style parity, the Android app should add a real TeslaMate-compatible API connection with live status, tire pressure, battery-health trend data, multi-car switching, and charge-progress polling. Right now this panel infers what it can from imported charging history.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Tic Tac Toe" -> {
                item {
                    SectionCard(
                        title = "Cabin game",
                        subtitle = "Two-player quick game for parked downtime"
                    ) {
                        TicTacToeBoard()
                    }
                }
                item {
                    SectionCard(
                        title = "Safety note",
                        subtitle = "Designed for charging stops and parked moments"
                    ) {
                        Text(
                            text = "This mini app is intentionally local and account-free. Keep games for when the vehicle is parked, just like a browser dashboard activity.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "ML Charge Forecast" -> {
                item {
                    SectionCard(
                        title = "On-device forecast",
                        subtitle = "A tiny neural net trained directly on your saved charging history"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Confidence" to mlInsight.confidenceLabel,
                                "Samples" to mlInsight.sampleCount.toString(),
                                "Next cost" to (mlInsight.nextSessionCost?.asCurrency() ?: "Learning"),
                                "Next kWh" to (mlInsight.nextSessionEnergyKwh?.let { "${it.oneDecimal()} kWh" } ?: "Learning")
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Signals",
                        subtitle = "Forecast, fit, trend, and anomaly signals coming out of the first ML layer"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Trend" to mlInsight.trendLabel,
                                "Typical rate" to (mlInsight.typicalCostPerKwh?.let { "${it.asCurrency()}/kWh" } ?: "Unknown"),
                                "Priciest provider" to mlInsight.priciestProvider,
                                "Outlier" to mlInsight.anomalyLabel
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Model notes",
                        subtitle = "What this first pass does and does not try to do"
                    ) {
                        Text(
                            text = mlInsight.summary,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Signal breakdown",
                        subtitle = "The main behavior patterns the current model is leaning on"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            mlInsight.strongestSignals.forEach { (label, value) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
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
                        title = "Provider baseline cards",
                        subtitle = "Typical rates and session sizes by provider from the current training history"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            mlInsight.providerForecasts.forEach { (provider, summary) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = provider,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                    Text(
                                        text = summary,
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
                        title = "Anomaly candidates",
                        subtitle = "The sessions or providers with the biggest price deviation from baseline"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            mlInsight.anomalyCandidates.forEach { (provider, summary) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = provider,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                    Text(
                                        text = summary,
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
                        title = "Next step for this layer",
                        subtitle = "Where we can make it smarter after this first integration"
                    ) {
                        Text(
                            text = "The next strong upgrade would be feeding this neural net with temperature, charger type, route class, battery size, and home-versus-public context so the forecast can move beyond timeline and provider patterns alone.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "CaughtaKWH" -> {
                val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
                val ratedEntries = chargingEntries
                    .mapNotNull { entry ->
                        val energy = entry.energyKWh ?: return@mapNotNull null
                        if (energy <= 0.0) return@mapNotNull null
                        entry to (entry.amount / energy)
                    }
                val ratedSessions = sessions
                    .filter { it.energyAddedKWh > 0.0 }
                    .map { session -> session to (session.cost / session.energyAddedKWh) }
                val allRates = ratedEntries.map { it.second } + ratedSessions.map { it.second }
                val baselineRate = allRates.average().takeIf { !it.isNaN() && it > 0.0 } ?: 0.0
                val highRateThreshold = max(0.55, baselineRate * 1.35)
                val missingEnergyEntries = chargingEntries.filter { (it.energyKWh ?: 0.0) <= 0.0 }
                val highRateEntries = ratedEntries.filter { it.second >= highRateThreshold }
                val highRateSessions = ratedSessions.filter { it.second >= highRateThreshold }
                val caughtCount = missingEnergyEntries.size + highRateEntries.size + highRateSessions.size
                val cleanRows = (chargingEntries.size + sessions.size - caughtCount).coerceAtLeast(0)
                val worstEntry = highRateEntries.maxByOrNull { it.second }
                val worstSession = highRateSessions.maxByOrNull { it.second }
                val worstRate = listOfNotNull(worstEntry?.second, worstSession?.second).maxOrNull()
                item {
                    SectionCard(
                        title = "CaughtaKWH sweep",
                        subtitle = "A quick pass over charging rows that could distort cost, kWh, or provider trends"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Caught" to caughtCount.toString(),
                                "Clean rows" to cleanRows.toString(),
                                "Baseline" to if (baselineRate > 0.0) "${baselineRate.asCurrency()}/kWh" else "Learning",
                                "Worst rate" to (worstRate?.let { "${it.asCurrency()}/kWh" } ?: "None")
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Caught signals",
                        subtitle = "The issues most likely to need a second look"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            CaughtaKwhRow(
                                label = "Missing kWh",
                                value = missingEnergyEntries.size.toString(),
                                detail = "Charging expenses that have cost but no usable energy value."
                            )
                            CaughtaKwhRow(
                                label = "High-rate entries",
                                value = highRateEntries.size.toString(),
                                detail = "Manual ledger rows at or above ${highRateThreshold.asCurrency()}/kWh."
                            )
                            CaughtaKwhRow(
                                label = "High-rate sessions",
                                value = highRateSessions.size.toString(),
                                detail = "Imported sessions at or above ${highRateThreshold.asCurrency()}/kWh."
                            )
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Biggest catch",
                        subtitle = "The row CaughtaKWH would review first"
                    ) {
                        val body = when {
                            worstEntry != null -> "${worstEntry.first.title} is running at ${worstEntry.second.asCurrency()}/kWh. Check the energy value, taxes, idle fees, and whether the row should be split."
                            worstSession != null -> "${worstSession.first.stationName} is running at ${worstSession.second.asCurrency()}/kWh. Check imported cost, energy, idle fees, and provider pricing."
                            missingEnergyEntries.isNotEmpty() -> "${missingEnergyEntries.first().title} is missing kWh. Add energy so cost per kWh, forecasts, and budget guardrails can use it."
                            else -> "No charging rows are standing out right now. Keep importing sessions and logging energy so CaughtaKWH has more signal to inspect."
                        }
                        Text(
                            text = body,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Next cleanup move",
                        subtitle = "What improves the catch rate fastest"
                    ) {
                        Text(
                            text = if (missingEnergyEntries.isNotEmpty()) {
                                "Start by filling missing kWh on charging expenses. That one field unlocks price-per-kWh trend checks, anomaly detection, budget pacing, and more reliable forecasts."
                            } else {
                                "Review unusually high-rate rows first, then keep provider names consistent so the app can separate real pricing changes from messy labels."
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Safety Score Predictor" -> {
                val estimate = estimateSafetyScore(sessions)
                item {
                    SectionCard(
                        title = "Estimated safety score",
                        subtitle = "A cautious proxy built from the data this app actually stores"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Estimate" to estimate.scoreLabel,
                                "Confidence" to estimate.confidenceLabel,
                                "Sessions used" to estimate.sessionsUsed.toString(),
                                "Late-night" to estimate.lateNightLabel
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "How this estimate works",
                        subtitle = "Known signals are weighted lightly, unknown Tesla factors stay neutral"
                    ) {
                        Text(
                            text = estimate.summary,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Factor coverage",
                        subtitle = "What the app can and cannot infer today"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            estimate.factorRows.forEach { (label, value) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
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
                        title = "What would improve it",
                        subtitle = "More telemetry would make the estimate much more believable"
                    ) {
                        Text(
                            text = "To get closer to Tesla's real Safety Score, the app would need trip-level driving data such as hard braking, aggressive turning, following distance, speeding time, seatbelt state, Autopilot/FSD disengagements, and actual trip miles or minutes.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "NHTSA Crash Reporting" -> {
                item {
                    SectionCard(
                        title = "Standing General Order",
                        subtitle = "Official NHTSA reporting page for ADS and Level 2 ADAS crash data"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = "This page tracks crash reports submitted under NHTSA's Standing General Order for vehicles equipped with automated driving systems or certain Level 2 driver-assistance features. It is a research reference, not a simple brand safety ranking.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Button(
                                onClick = { uriHandler.openUri(nhtsaCrashReportingUrl) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open official NHTSA page")
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "What the data covers",
                        subtitle = "High-level scope from the federal reporting rule"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "ADS reports" to "Automated driving systems in use or recently disengaged",
                                "Level 2 reports" to "Specified ADAS features like lane centering + ACC",
                                "Trigger" to "Certain crashes meeting SGO reporting thresholds",
                                "Source" to "Manufacturer and operator submissions"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Why comparisons can mislead",
                        subtitle = "Key caveats NHTSA calls out on the same page"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "The page is not intended for apples-to-apples comparisons across manufacturers.",
                                "Crash counts are not normalized by miles driven, vehicles in operation, or feature usage rates.",
                                "Manufacturers may differ in fleet size, ODD, sensing capability, and reporting maturity.",
                                "A single crash event can appear in more than one report as investigations evolve."
                            ).forEach { note ->
                                Text(
                                    text = "• $note",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "How to use it well",
                        subtitle = "Best fit for owners, researchers, and policy-following users"
                    ) {
                        Text(
                            text = "Use this tile to monitor reporting transparency, understand what incidents are entering the federal record, and keep the dataset in context alongside recalls, owner reports, and official safety investigations. Treat it as a reporting feed and regulatory reference, not a complete or normalized crash leaderboard.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Grid Emissions Forecast" -> {
                val forecast = sampleGridEmissionForecast()
                val best = forecast.minBy { it.index }
                val worst = forecast.maxBy { it.index }
                item {
                    SectionCard(
                        title = "24-hour emissions forecast",
                        subtitle = "Green windows are better for flexible electricity use"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            MetricFlowRow(
                                items = listOf(
                                    "Current index" to "${forecast.first().index}/100",
                                    "Best hour" to best.hourLabel,
                                    "Heaviest hour" to worst.hourLabel,
                                    "Data shape" to "WattTime MOER"
                                )
                            )
                            GridEmissionStrip(forecast)
                            Text(
                                text = "This tile is structured for WattTime real-time and forecast data. Lower index values mean a cleaner marginal grid, so flexible loads can move toward green windows and away from red windows.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Compare locations",
                        subtitle = "U.S. grids can have very different clean windows"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            sampleGridLocationComparisons().forEach { location ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(location.city, style = MaterialTheme.typography.titleMedium)
                                        Text(
                                            text = "${location.region} - ${location.note}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    LabelPill(
                                        text = "${location.currentIndex}/100",
                                        color = emissionIndexColor(location.currentIndex)
                                    )
                                }
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "WattTime integration",
                        subtitle = "Ready path for live data once credentials are configured"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            MetricFlowRow(
                                items = listOf(
                                    "Locate grid" to "/v3/region-from-loc",
                                    "Forecast" to "/v3/forecast",
                                    "Real-time" to "/v3/signal-index",
                                    "Signal" to "co2_moer"
                                )
                            )
                            Text(
                                text = "WattTime requires registration and bearer-token auth. The app should store credentials outside the UI, refresh tokens before polling, and re-check region boundaries at least monthly because grid regions can change.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Button(
                                onClick = { uriHandler.openUri(wattTimeDocsUrl) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open WattTime docs")
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Flexible-load ideas",
                        subtitle = "Best fits for cleaner timing"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "Start EV charging during the cleanest forecast block when the car does not need to leave immediately.",
                                "Run laundry, dishwasher, and water-heating cycles in green windows.",
                                "Charge or discharge home batteries around the local grid's high- and low-emission periods.",
                                "Use location comparison before travel or when choosing where to schedule charging."
                            ).forEach { note ->
                                Text(note, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            "Tesla Service Alerts" -> {
                item {
                    var alertQuery by rememberSaveable { mutableStateOf("") }
                    val decodedAlerts = teslaAlertDecoderRows.filter { alert ->
                        alertQuery.isBlank() ||
                            listOf(alert.codePattern, alert.plainEnglish, alert.ownerAction, alert.system)
                                .any { it.contains(alertQuery, ignoreCase = true) }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        SectionCard(
                            title = "Plain-English alert decoder",
                            subtitle = "High-signal patterns from Tessie and MyTeslaMate alert catalogs"
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                LabeledField(
                                    label = "Search code, system, or symptom",
                                    value = alertQuery,
                                    onValueChange = { alertQuery = it }
                                )
                                MetricFlowRow(
                                    items = listOf(
                                        "Catalog scope" to "17k+ signals",
                                        "Decoded groups" to teslaAlertDecoderRows.size.toString(),
                                        "Sources" to "Tessie + MyTeslaMate",
                                        "Mode" to "Owner triage"
                                    )
                                )
                                Text(
                                    text = "Paste the stable part of a Tesla alert code, such as VCSEC, BMS, PCS, GTW, CP, TPMS, DAS, APP, or UI. The decoder maps it to likely impact, urgency, and the next practical owner action.",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        SectionCard(
                            title = "Decoded alert groups",
                            subtitle = "${decodedAlerts.size} matching groups"
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                                decodedAlerts.forEach { alert ->
                                    TeslaAlertDecoderCard(alert)
                                }
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Source lookups",
                        subtitle = "Open the live catalogs for exact raw code details"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Button(
                                onClick = { uriHandler.openUri(tessieAlertsUrl) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open Tessie alert explorer")
                            }
                            OutlinedButton(
                                onClick = { uriHandler.openUri(myTeslaMateAlertsUrl) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open MyTeslaMate alerts")
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Triage rules",
                        subtitle = "How to read repeated or severe errors"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "Red: stop, reduce driving, or book service if the car also shows a warning, limits charging, limits power, or repeats after sleep/reboot.",
                                "Orange: document the exact code, software version, and conditions, then watch for repeat behavior.",
                                "Yellow: usually informational or intermittent, but keep the code if a symptom appears.",
                                "Any HV battery, charge-port, brake, steering, restraint, thermal, or repeated communication alert deserves more caution than an infotainment-only alert."
                            ).forEach { note ->
                                Text(note, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            "Tesla Excess Wear Guide" -> {
                item {
                    SectionCard(
                        title = "Official Tesla guide",
                        subtitle = "Lease-return self-inspection reference for normal versus excessive wear"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = "Use this before lease return or repair decisions to review Tesla's current guidance for mileage, tires, wheels, glass, interior wear, exterior damage, missing parts, and aftermarket changes.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Button(
                                onClick = { uriHandler.openUri(teslaExcessWearGuideUrl) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open official Tesla guide")
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Quick checks",
                        subtitle = "High-level items to review before returning a leased vehicle"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Tires" to "4/32 in or greater",
                                "Wheel marks" to "Under 6 in per wheel",
                                "Glass" to "No driver-view damage",
                                "Equipment" to "Return all included items"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Best use",
                        subtitle = "Pair the guide with your vehicle records"
                    ) {
                        Text(
                            text = "Save repair receipts, service invoices, accessory removals, and final mileage in the app so lease-return decisions stay connected to the rest of your ownership history.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Direct Connection Dashboard" -> {
                val latest = sessions.maxByOrNull { it.startedAt }
                item {
                    SectionCard(
                        title = "Connection overview",
                        subtitle = "Android mirror of the iOS direct-connection home"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Endpoint" to "Not configured",
                                "Token mode" to "Local only",
                                "Latest charge" to (latest?.stationName ?: "No sessions"),
                                "Vehicle" to (vehicles.firstOrNull()?.name ?: "No garage profile")
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Data surfaces",
                        subtitle = "The iOS dashboard areas represented here"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Overview" to "Charge + drive summary",
                                "Activities" to "${sessions.size} saved sessions",
                                "Geofence costs" to "Provider/site rollup",
                                "Charge status" to "Widget-ready"
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Parity note",
                        subtitle = "What Android can safely expose today"
                    ) {
                        Text(
                            text = "This Android surface keeps the iOS direct-connection workflow discoverable without pretending a live TeslaMate endpoint is configured. Once endpoint storage and polling are added, this panel can use the same sections for real charge, drive, geofence, and widget data.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Direct Connection Setup" -> {
                item {
                    SectionCard(
                        title = "Setup checklist",
                        subtitle = "Android companion to the iOS setup wizard"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "Choose a trusted TeslaMate-style host or proxy.",
                                "Confirm whether the token travels in a header or query parameter.",
                                "Test read-only charge and drive endpoints before enabling background refresh.",
                                "Keep tokens local and rotate them if a proxy or phone is replaced."
                            ).forEach { step ->
                                Text(step, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Readiness",
                        subtitle = "The pieces Android needs for full live-data parity"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Endpoint URL" to "Needed",
                                "API token" to "Needed",
                                "Charge polling" to "Planned",
                                "Drive summaries" to "Planned"
                            )
                        )
                    }
                }
            }

            "Widgets & Charge Status" -> {
                val latest = sessions.maxByOrNull { it.startedAt }
                item {
                    SectionCard(
                        title = "Charge status card",
                        subtitle = "Android counterpart for iOS widgets and Live Activities"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "State" to if (latest == null) "Waiting for data" else "Recently charged",
                                "Battery" to (latest?.endSoc?.let { "$it%" } ?: "Unknown"),
                                "Energy" to (latest?.energyAddedKWh?.let { "${it.oneDecimal()} kWh" } ?: "Unknown"),
                                "Cost" to (latest?.cost?.asCurrency() ?: "Unknown")
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Widget parity",
                        subtitle = "How this maps from iOS to Android"
                    ) {
                        Text(
                            text = "iOS uses Widgets and Live Activities for glanceable charge status. Android should map that intent to home-screen widgets, notifications, and a foreground-friendly charge-status card using the same charge summary fields.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Agent Assistant" -> {
                val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
                item {
                    SectionCard(
                        title = "Agent context",
                        subtitle = "The same high-level inputs the iOS agent workspace collects"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Vehicles" to vehicles.size.toString(),
                                "Entries" to entries.size.toString(),
                                "Charging rows" to chargingEntries.size.toString(),
                                "Sessions" to sessions.size.toString()
                            )
                        )
                    }
                }
                item {
                    SectionCard(
                        title = "Suggested brief",
                        subtitle = "A local summary ready for an assistant workflow"
                    ) {
                        Text(
                            text = "Summarize monthly charging spend, flag price outliers, recommend the next import or cleanup task, and point the owner toward the most relevant tool based on the current garage and ledger state.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            "Import Hub Onboarding" -> {
                item {
                    SectionCard(
                        title = "First import path",
                        subtitle = "The Android version of iOS import-hub onboarding"
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            listOf(
                                "Start with the official Tesla Supercharging CSV when available.",
                                "Use generic charging-session CSVs for non-Tesla providers or prior exports.",
                                "Import expense CSVs for insurance, maintenance, tolls, parking, and accessories.",
                                "Review duplicates and missing energy values before trusting long-term trends."
                            ).forEach { step ->
                                Text(step, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item {
                    SectionCard(
                        title = "Current import state",
                        subtitle = "What the onboarding flow can detect now"
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Vehicles" to vehicles.size.toString(),
                                "Expenses" to entries.size.toString(),
                                "Sessions" to sessions.size.toString(),
                                "Ready" to if (vehicles.isNotEmpty() || entries.isNotEmpty() || sessions.isNotEmpty()) "In progress" else "Fresh start"
                            )
                        )
                    }
                }
            }

            "Discounts & Referrals" -> {
                val favoriteLinks = iosDiscountLinks.filter { it.url in discountFavorites }
                item {
                    SectionCard(
                        title = "Discount hub",
                        subtitle = "Affiliate and referral offers from the iOS app, grouped the same way on Android."
                    ) {
                        MetricFlowRow(
                            items = listOf(
                                "Links" to iosDiscountLinks.size.toString(),
                                "Favorites" to favoriteLinks.size.toString(),
                                "Referrals" to iosDiscountLinks.count { it.category == "Referrals" }.toString(),
                                "Accessories" to iosDiscountLinks.count { it.category == "Accessories" }.toString()
                            )
                        )
                    }
                }
                if (favoriteLinks.isNotEmpty()) {
                    item {
                        SectionCard(
                            title = "Saved favorites",
                            subtitle = "Quick access to the discount and referral links you want to revisit."
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                                favoriteLinks.forEach { link ->
                                    DiscountLinkCard(
                                        link = link,
                                        isFavorite = true,
                                        onOpenLink = { uriHandler.openUri(link.safeUrl) },
                                        onToggleFavorite = { appState.discountFavorites.toggleFavorite(link.url) }
                                    )
                                }
                            }
                        }
                    }
                }
                iosDiscountLinks
                    .groupBy { it.category }
                    .forEach { (category, links) ->
                        item {
                            SectionCard(
                                title = category,
                                subtitle = when (category) {
                                    "Referrals" -> "Referral and general discount links carried over from the iOS view."
                                    else -> "Accessory and shop links carried over from the iOS view."
                                }
                            ) {
                                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                                    links.forEach { link ->
                                        DiscountLinkCard(
                                            link = link,
                                            isFavorite = link.url in discountFavorites,
                                            onOpenLink = { uriHandler.openUri(link.safeUrl) },
                                            onToggleFavorite = { appState.discountFavorites.toggleFavorite(link.url) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                item {
                    SectionCard(
                        title = "Offer notice",
                        subtitle = "Matches the caution included on iOS"
                    ) {
                        Text(
                            text = "Some links may be affiliate or referral URLs. Always verify deals, terms, and availability. Offers can change without notice.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            else -> {
                val detail = dynamicToolDetail(
                    tool = resolvedTool,
                    entries = entries,
                    vehicles = vehicles,
                    sessions = sessions,
                    budget = budget
                )
                item {
                    SectionCard(
                        title = detail.summaryTitle,
                        subtitle = detail.summarySubtitle
                    ) {
                        Text(
                            text = detail.summaryBody,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                item {
                    SectionCard(
                        title = detail.metricTitle,
                        subtitle = detail.metricSubtitle
                    ) {
                        MetricFlowRow(
                            items = detail.metrics
                        )
                    }
                }
                item {
                    SectionCard(
                        title = detail.actionTitle,
                        subtitle = detail.actionSubtitle
                    ) {
                        Text(
                            text = detail.actionBody,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DiscountLinkCard(
    link: DiscountLinkItem,
    isFavorite: Boolean,
    onOpenLink: () -> Unit,
    onToggleFavorite: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = link.name,
            style = MaterialTheme.typography.titleMedium
        )
        Text(
            text = link.hostLabel,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Button(
            onClick = onOpenLink,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Open link")
        }
        OutlinedButton(
            onClick = onToggleFavorite,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (isFavorite) "Remove favorite" else "Save favorite")
        }
    }
}

private data class DiscountLinkItem(
    val name: String,
    val url: String,
    val category: String
) {
    val hostLabel: String
        get() = runCatching { android.net.Uri.parse(url).host.orEmpty() }
            .getOrDefault("")
            .ifBlank { url }

    val safeUrl: String
        get() = url.withoutAdClickIds()
}

private val blockedAdClickQueryNames = setOf(
    "gclid",
    "msclkid",
    "gbraid",
    "wbraid",
    "yclid",
    "fbclid"
)

private fun String.withoutAdClickIds(): String {
    val uri = runCatching { Uri.parse(this) }.getOrNull() ?: return this
    val queryNames = uri.queryParameterNames
    if (queryNames.none { it.lowercase() in blockedAdClickQueryNames }) return this

    val builder = uri.buildUpon().clearQuery()
    queryNames
        .filterNot { it.lowercase() in blockedAdClickQueryNames }
        .forEach { name ->
            uri.getQueryParameters(name).forEach { value ->
                builder.appendQueryParameter(name, value)
            }
        }
    return builder.build().toString()
}

@Composable
private fun CaughtaKwhRow(
    label: String,
    value: String,
    detail: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        LabelPill(text = value, color = Color(0xFFEF476F))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(label, style = MaterialTheme.typography.titleSmall)
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private val iosDiscountLinks = listOf(
    // BEGIN SHARED DISCOUNT LINKS
    DiscountLinkItem("Misc Discounts", "https://linktr.ee/teslafi", "Referrals"),
    DiscountLinkItem("Comfrt Discount", "https://comfrt.com/KLAIRE11", "Referrals"),
    DiscountLinkItem("Accessories – EV Base", "https://www.evbase.com?sca_ref=9481743.pPgJrlY92f", "Accessories"),
    DiscountLinkItem("One Free Month of Starlink", "https://starlink.com/residential?referral=RC-4509047-46429-69", "Accessories"),
    DiscountLinkItem("Accessories – Lectron EV Adapters", "https://www.awin1.com/cread.php?awinmid=91891&awinaffid=2625306", "Accessories"),
    DiscountLinkItem("Accessories – Aftermarket (T Sportline)", "https://tsportline.com?sca_ref=9830647.pqBEvt1iTi8Kekf&utm_source=uppa&utm_medium=0&utm_campaign=0", "Accessories"),
    DiscountLinkItem("Accessories – Unplugged Performance", "https://unpluggedperformance.com/?_br=bryan69F1", "Accessories"),
    DiscountLinkItem("Accessories – DIY Wrap Club (TESBROS)", "https://www.diywrapclub.com/SFP6WB4X", "Accessories"),
    DiscountLinkItem("Accessories – EVDance", "https://www.awin1.com/cread.php?awinmid=67740&awinaffid=2625306", "Accessories"),
    DiscountLinkItem("Accessories – Oedro Parts", "https://www.awin1.com/cread.php?awinmid=28349&awinaffid=2625306", "Accessories"),
    DiscountLinkItem("Save $2000 off a Tesla", "https://www.tesla.com/referral/bryan627261", "Accessories"),
    DiscountLinkItem("Amazon: Up to $30 OFF Tesla floor liners | 3W Floormats", "https://amzn.to/4r4Pp7q", "Accessories")
    // END SHARED DISCOUNT LINKS
)

private const val nhtsaCrashReportingUrl =
    "https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting#data"
private const val wattTimeDocsUrl = "https://docs.watttime.org/"
private const val tessieAlertsUrl = "https://stats.tessie.com/alerts"
private const val myTeslaMateAlertsUrl = "https://app.myteslamate.com/alerts"
private const val teslaExcessWearGuideUrl = "https://www.tesla.com/support/excess-wear-use-guide"

@Composable
private fun GridEmissionStrip(forecast: List<GridEmissionPoint>) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            forecast.forEach { point ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height((28 + (100 - point.index) * 0.36).dp)
                        .clip(RoundedCornerShape(5.dp))
                        .background(point.color)
                )
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(forecast.first().hourLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(forecast[forecast.size / 2].hourLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(forecast.last().hourLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private fun emissionIndexColor(index: Int): Color = when {
    index <= 35 -> Color(0xFF2EAD67)
    index <= 55 -> Color(0xFFB18B00)
    index <= 72 -> Color(0xFFC56A20)
    else -> Color(0xFFD64545)
}

@Composable
private fun TeslaAlertDecoderCard(alert: TeslaAlertDecoderRow) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.7f))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(alert.codePattern, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = alert.system,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            LabelPill(text = alert.severity, color = alert.severityColor)
        }
        Text(alert.plainEnglish, style = MaterialTheme.typography.bodyMedium)
        Text(
            text = "Owner action: ${alert.ownerAction}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "Examples: ${alert.examples.joinToString()}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

private data class TeslaAlertDecoderRow(
    val codePattern: String,
    val system: String,
    val severity: String,
    val plainEnglish: String,
    val ownerAction: String,
    val examples: List<String>
) {
    val severityColor: Color
        get() = when (severity) {
            "Red" -> Color(0xFFD64545)
            "Orange" -> Color(0xFFC56A20)
            "Yellow" -> Color(0xFFB18B00)
            else -> Color(0xFF2EAD67)
        }
}

private val teslaAlertDecoderRows = listOf(
    TeslaAlertDecoderRow(
        codePattern = "BMS_* / BATT_*",
        system = "High-voltage battery and pack management",
        severity = "Red",
        plainEnglish = "The battery-management system is reporting a pack, isolation, contactor, thermal, sensor, or charge-limit condition.",
        ownerAction = "Avoid deep discharge, avoid repeated fast charging until understood, capture the exact code, and book service if range, charging, or power is limited.",
        examples = listOf("BMS_a", "BATT_a", "battery isolation", "contactor")
    ),
    TeslaAlertDecoderRow(
        codePattern = "PCS_* / CP_* / CHG_*",
        system = "Charging hardware, onboard charger, and charge port",
        severity = "Orange",
        plainEnglish = "The car is unhappy with AC/DC charging, charge-port latch/sensor state, onboard charger behavior, or the connected supply.",
        ownerAction = "Try a known-good charger, inspect the port and cable, lower current for AC charging, and service it if the same code repeats across chargers.",
        examples = listOf("PCS_a", "CP_a", "CHG_w", "charge port")
    ),
    TeslaAlertDecoderRow(
        codePattern = "VCSEC_* TPMS / closure / key",
        system = "Vehicle security, tire pressure sensors, closures, keys",
        severity = "Yellow",
        plainEnglish = "A body/security controller is seeing tire-pressure sensor faults, mismatched TPMS configuration, key/authentication issues, or closure sensor disagreement.",
        ownerAction = "For TPMS, verify tire pressures and sensor IDs after tire work. For keys or closures, retry after sleep/reboot and service if locks, doors, or alerts misbehave.",
        examples = listOf("VCSEC_a225_TPMSFaultSensor2", "VCSEC_a259_TPMSDeterminedTypeMismatch")
    ),
    TeslaAlertDecoderRow(
        codePattern = "PM_* / GTW_* / CAN data bus",
        system = "Pedal monitor, gateway, and network communication",
        severity = "Orange",
        plainEnglish = "One controller is missing, intermittent, or failing a CAN communication integrity check.",
        ownerAction = "If it appears once with no symptoms, document it. If power, braking, steering, drive readiness, or repeated MIA messages appear, schedule service.",
        examples = listOf("PM_a012_canDataBusA", "PM_a075_canDataBusD", "GTW_*")
    ),
    TeslaAlertDecoderRow(
        codePattern = "DI_* / DRIVE_* / INV_*",
        system = "Drive inverter, motor, traction, and power delivery",
        severity = "Red",
        plainEnglish = "A drive-unit or inverter alert can mean reduced power, traction limits, motor control faults, or a propulsion system protection event.",
        ownerAction = "Do not ignore if acceleration, regen, or drive readiness changes. Pull over safely for active warnings and open a service request.",
        examples = listOf("DI_a", "DIR_a", "INV_a", "power reduced")
    ),
    TeslaAlertDecoderRow(
        codePattern = "ESP_* / ABS_* / EPB_* / IBST_*",
        system = "Brakes, stability control, parking brake, and brake booster",
        severity = "Red",
        plainEnglish = "A braking or stability system is reporting degraded capability, unavailable assistance, or a sensor/control fault.",
        ownerAction = "Treat as safety-relevant. Reduce driving and request service if any brake, ABS, stability, or parking-brake warning is shown.",
        examples = listOf("ESP_a", "ABS_w", "EPB_a", "IBST_a")
    ),
    TeslaAlertDecoderRow(
        codePattern = "DAS_* / APP_* / AP_* camera/radar",
        system = "Autopilot, driver-assistance sensors, cameras, and compute",
        severity = "Yellow",
        plainEnglish = "Driver-assistance features may be blocked, degraded, calibrating, or unavailable because a camera, radar, ultrasonic, compute, or software path is unhappy.",
        ownerAction = "Clean cameras, wait for calibration if recently serviced, and drive manually. Service it if warnings persist in clear weather after reboot/sleep.",
        examples = listOf("DAS_*", "APP_w", "camera blocked", "adaptive headlights unavailable")
    ),
    TeslaAlertDecoderRow(
        codePattern = "UI_* / MCU_* / IC_* / ADSP_*",
        system = "Infotainment, display, audio, and user interface",
        severity = "Yellow",
        plainEnglish = "The center display, instrument cluster, audio processor, or infotainment software reported an error or unavailable subsystem.",
        ownerAction = "Reboot if the screen or audio is affected. Escalate if the display blanks repeatedly, loses critical vehicle controls, or returns after software updates.",
        examples = listOf("UI_a147_ASILStatusError", "ADSP_w053_audioSystemUnavailable")
    ),
    TeslaAlertDecoderRow(
        codePattern = "VCFRONT_* / VCRIGHT_* / VCRIGHTS_* lighting",
        system = "Body controller, lighting, headlights, and local IO",
        severity = "Yellow",
        plainEnglish = "A body controller sees a local electrical, lighting, adaptive-headlight, or sensor problem.",
        ownerAction = "Check whether the affected light or feature actually works. If visibility or legal lighting is affected, schedule service promptly.",
        examples = listOf("VCRIGHTS_a004_adaptiveHeadlightsUnavailable", "VCFRONT_*")
    ),
    TeslaAlertDecoderRow(
        codePattern = "VCSEAT* / HVAC_* / THERM_*",
        system = "Seats, cabin climate, and thermal management",
        severity = "Yellow",
        plainEnglish = "Comfort or thermal subsystems are seeing motor stalls, actuator limits, refrigerant/valve issues, or temperature-control faults.",
        ownerAction = "If it is a seat motor stall with normal movement, monitor it. If cabin heat, battery conditioning, or defrost is impaired, service it.",
        examples = listOf("VCSEATD_a220_seatCurrStallTrack", "HVAC_*", "THERM_*")
    ),
    TeslaAlertDecoderRow(
        codePattern = "SRS_* / RCM_* / restraint",
        system = "Airbags, restraints, and occupant safety",
        severity = "Red",
        plainEnglish = "A restraint-system alert may affect airbags, seatbelt pretensioners, occupant classification, or crash-safety readiness.",
        ownerAction = "Book service quickly and avoid carrying passengers in affected seats if the car displays a restraint or airbag warning.",
        examples = listOf("SRS_*", "RCM_*", "airbag warning")
    )
)

private data class DynamicToolDetail(
    val summaryTitle: String,
    val summarySubtitle: String,
    val summaryBody: String,
    val metricTitle: String,
    val metricSubtitle: String,
    val metrics: List<Pair<String, String>>,
    val actionTitle: String,
    val actionSubtitle: String,
    val actionBody: String
)

private data class SafetyScoreEstimate(
    val score: Int?,
    val confidenceLabel: String,
    val sessionsUsed: Int,
    val lateNightLabel: String,
    val summary: String,
    val factorRows: List<Pair<String, String>>
) {
    val scoreLabel: String
        get() = score?.toString() ?: "N/A"
}

private fun dynamicToolDetail(
    tool: ToolCard,
    entries: List<com.myevcompanion.app.data.ExpenseEntry>,
    vehicles: List<com.myevcompanion.app.data.VehicleProfile>,
    sessions: List<com.myevcompanion.app.data.ChargingSession>,
    budget: com.myevcompanion.app.data.MonthlyBudget
): DynamicToolDetail {
    val chargingEntries = entries.filter { it.category == EntryCategory.Charging }
    val totalSpend = entries.sumOf { it.amount }
    val chargingSpend = chargingEntries.sumOf { it.amount }
    val totalEnergy = chargingEntries.sumOf { it.energyKWh ?: 0.0 }
    val avgRate = if (totalEnergy > 0.0) chargingSpend / totalEnergy else 0.0
    val activeVehicleName = vehicles.firstOrNull()?.name ?: "No vehicle saved"

    val metrics = when (tool.group) {
        "Planning" -> listOf(
            "Vehicle" to activeVehicleName,
            "Sessions" to sessions.size.toString(),
            "Avg rate" to if (avgRate > 0.0) "${avgRate.asCurrency()}/kWh" else "No rate yet",
            "Range context" to vehicles.firstOrNull()?.estimatedRangeMiles?.toInt()?.let { "$it mi" }.orEmpty().ifBlank { "Not set" }
        )

        "Charging Intelligence" -> listOf(
            "Charging rows" to chargingEntries.size.toString(),
            "Sessions" to sessions.size.toString(),
            "Energy" to "${totalEnergy.oneDecimal()} kWh",
            "Avg rate" to if (avgRate > 0.0) "${avgRate.asCurrency()}/kWh" else "No rate yet"
        )

        "Finance" -> listOf(
            "Total spend" to totalSpend.asCurrency(),
            "Charging" to chargingSpend.asCurrency(),
            "Budget left" to (budget.monthlyLimit - chargingSpend).asCurrency(),
            "Entries" to entries.size.toString()
        )

        "Vehicle Intelligence" -> listOf(
            "Vehicles" to vehicles.size.toString(),
            "Active" to activeVehicleName,
            "VIN-ready" to vehicles.count { it.vin.isNotBlank() }.toString(),
            "Sessions" to sessions.size.toString()
        )

        "Maintenance" -> listOf(
            "Vehicles" to vehicles.size.toString(),
            "Maintenance" to entries.count { it.category == EntryCategory.Maintenance }.toString(),
            "Accessories" to entries.count { it.category == EntryCategory.Accessories }.toString(),
            "Spend" to totalSpend.asCurrency()
        )

        "Reporting" -> listOf(
            "Entries" to entries.size.toString(),
            "Sessions" to sessions.size.toString(),
            "Categories" to EntryCategory.entries.size.toString(),
            "Spend" to totalSpend.asCurrency()
        )

        "Research" -> listOf(
            "Vehicles" to vehicles.size.toString(),
            "Focus" to tool.group,
            "Garage" to activeVehicleName,
            "Saved entries" to entries.size.toString()
        )

        "Connected Vehicle" -> listOf(
            "Endpoint" to "Not configured",
            "Vehicles" to vehicles.size.toString(),
            "Sessions" to sessions.size.toString(),
            "Charge status" to (sessions.maxByOrNull { it.startedAt }?.endSoc?.let { "$it%" } ?: "Waiting")
        )

        else -> listOf(
            "Vehicles" to vehicles.size.toString(),
            "Entries" to entries.size.toString(),
            "Sessions" to sessions.size.toString(),
            "Group" to tool.group
        )
    }

    val actionSubtitle = when (tool.group) {
        "Planning" -> "Best when your garage and charging history are reasonably complete"
        "Charging Intelligence" -> "Most useful after importing charging history or Tesla billing data"
        "Finance" -> "Becomes more accurate as you add manual expenses and charging costs"
        "Vehicle Intelligence" -> "Works best after saving detailed vehicle profiles"
        "Maintenance" -> "Gets stronger as receipts, services, and upkeep costs are logged"
        "Reporting" -> "Improves as your saved history grows across months and categories"
        "Research" -> "Pairs best with your current garage and ownership questions"
        "Connected Vehicle" -> "Ready for endpoint, token, live charge, drive, and widget data once those feeds are configured"
        else -> "This tool is ready to build from the data already saved in the app"
    }

    val actionBody = when (tool.title) {
        "Tesla Offers" -> "Use this tool to keep official Tesla promotions, referral opportunities, and model-specific offers in one place before you order."
        "Tesla Owners Club" -> "Use this screen to keep owner community resources close by when you want local groups, discussions, and club references."
        "Vehicle Incentive Finder" -> "Start with your saved vehicle and location details, then compare likely rebates, credits, and utility programs."
        "Incentives & Rebates" -> "Use this view to keep public incentives, utility discounts, and local rebate programs organized before a purchase or charger install."
        "Receipt Scan (OCR)" -> "The next step for this tool is turning service and charging receipts into structured ledger entries with less manual typing."
        "Service Invoices (PDF)" -> "Use this workspace to keep invoice files, service notes, and maintenance totals aligned with the garage history."
        "CSV Export" -> "Open this tool when you need a clean export of charging or expense history for backup, auditing, or deeper analysis elsewhere."
        else -> "${tool.title} is ready to work from your current garage, charging, and expense history. As you add more real records, this view can surface sharper insights for ${tool.description.lowercase()}".replace("..", ".")
    }

    return DynamicToolDetail(
        summaryTitle = tool.title,
        summarySubtitle = tool.description,
        summaryBody = summaryBody(tool),
        metricTitle = metricTitle(tool.group),
        metricSubtitle = metricSubtitle(tool.group),
        metrics = metrics,
        actionTitle = actionTitle(tool.group),
        actionSubtitle = actionSubtitle,
        actionBody = actionBody
    )
}

private fun summaryBody(tool: ToolCard): String = when (tool.group) {
    "Planning" -> "${tool.title} focuses on route, timing, energy, and stop-planning decisions using the charging and vehicle details you have already saved."
    "Charging Intelligence" -> "${tool.title} is designed to inspect pricing, site behavior, imports, and charging performance so you can spot cost and session patterns faster."
    "Finance" -> "${tool.title} turns your ledger into a more decision-ready cost view, using charging, maintenance, insurance, and other ownership records together."
    "Vehicle Intelligence" -> "${tool.title} uses your garage details, saved specs, and ownership history to answer vehicle-specific questions more quickly."
    "Maintenance" -> "${tool.title} keeps service, parts, and upkeep records organized so vehicle care stays tied to the rest of your ownership data."
    "Reporting" -> "${tool.title} summarizes saved history into clearer rollups, quality checks, and patterns you can review at a glance."
    "Research" -> "${tool.title} keeps the relevant references, offers, or brand-specific context close to the garage and ledger data you already use."
    "Connected Vehicle" -> "${tool.title} keeps live-data setup, charge state, and endpoint readiness aligned with the iOS connected-vehicle surfaces."
    else -> "${tool.title} opens as a focused workspace connected to your saved vehicles, entries, and charging history."
}

private fun metricTitle(group: String): String = when (group) {
    "Planning" -> "Planning inputs"
    "Charging Intelligence" -> "Charging context"
    "Finance" -> "Cost context"
    "Vehicle Intelligence" -> "Garage context"
    "Maintenance" -> "Service context"
    "Reporting" -> "Reporting inputs"
    "Research" -> "Reference context"
    "Connected Vehicle" -> "Connection context"
    else -> "Current context"
}

private fun metricSubtitle(group: String): String = when (group) {
    "Planning" -> "Saved values that can shape forecasts, routes, and trip assumptions"
    "Charging Intelligence" -> "Current charging history available to analyze"
    "Finance" -> "Saved spending data available to roll up and compare"
    "Vehicle Intelligence" -> "Vehicle records and specs currently available"
    "Maintenance" -> "Saved upkeep and ownership records this tool can draw from"
    "Reporting" -> "The current record set available for summaries and rollups"
    "Research" -> "Personal garage context available alongside reference material"
    "Connected Vehicle" -> "Current readiness for live vehicle status and charge-summary surfaces"
    else -> "The current records this tool can use"
}

private fun actionTitle(group: String): String = when (group) {
    "Planning" -> "How to use it"
    "Charging Intelligence" -> "Where it helps"
    "Finance" -> "Best next step"
    "Vehicle Intelligence" -> "What to do next"
    "Maintenance" -> "Best next step"
    "Reporting" -> "How to improve it"
    "Research" -> "What to use it for"
    "Connected Vehicle" -> "Connection path"
    else -> "Next step"
}

private fun toolHeroSubtitle(tool: ToolCard): String {
    return when (tool.title) {
        "Charging Budget Guard" -> "Monthly charging guardrails built from your saved spend and energy history."
        "CaughtaKWH" -> "A charging-data catcher for missing kWh, high rates, and suspicious rows."
        "ML Charge Forecast" -> "A first on-device ML layer that forecasts the next charge and spots pricing outliers."
        "Quarterly Tax Summary" -> "Quarter-based rollups for charging and ownership costs throughout the year."
        "Cost of Ownership" -> "One place to see what ownership is really costing across categories."
        "EV vs Gas Comparison" -> "Actual charging spend, gas-equivalent cost, and mileage comparison in one place."
        "Safety Score Predictor" -> "A low-confidence estimate that uses the limited timing clues already saved in your charging history."
        "Tesla VIN Decoder" -> "Decode Tesla identity details directly from the garage workflow."
        "Tesla Excess Wear Guide" -> "Official Tesla lease-return wear guidance with quick owner checks before self-inspection."
        "Trip Budget Planner" -> "Use your saved energy history to frame a smarter trip budget."
        "TeslaFi Mobile Dashboard" -> "A Fido-inspired mobile view of imported TeslaFi charging and drive metrics."
        "TeslaMate Mobile Dashboard" -> "A TesLog-inspired mobile view of battery, status, and charging summaries."
        "Altitude Cockpit" -> "Elevation snapshots and profile notes for hilly drives."
        "Weather Cockpit" -> "Weather details tuned for range, comfort, and charging decisions."
        "Trip Cockpit" -> "A lightweight trip recorder for distance, route, speed, energy, and stops."
        "Tic Tac Toe" -> "A simple local cabin game that does not touch account or vehicle controls."
        "Direct Connection Dashboard" -> "Endpoint, charge, drive, geofence, widget, and live-status parity from the iOS connected-vehicle area."
        "Direct Connection Setup" -> "A setup checklist for live vehicle data that keeps tokens and proxy choices explicit."
        "Widgets & Charge Status" -> "The Android counterpart to iOS widgets and Live Activities for charging progress."
        "Agent Assistant" -> "A local context summary shaped like the iOS agent workspace."
        "Import Hub Onboarding" -> "The import-first path from iOS, adapted for Android CSV pickers and local stores."
        else -> "Open a focused workspace for this tool with your current garage, charging, and expense data."
    }
}

@Composable
private fun TicTacToeBoard() {
    var cells by rememberSaveable { mutableStateOf(List(9) { "" }) }
    var currentPlayer by rememberSaveable { mutableStateOf("X") }
    val winner = ticTacToeWinner(cells)
    val status = when {
        winner != null -> "$winner wins"
        cells.all { it.isNotBlank() } -> "Draw"
        else -> "$currentPlayer turn"
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(status, style = MaterialTheme.typography.titleMedium)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (0..2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    (0..2).forEach { column ->
                        val index = row * 3 + column
                        OutlinedButton(
                            onClick = {
                                if (cells[index].isBlank() && winner == null) {
                                    cells = cells.toMutableList().also { it[index] = currentPlayer }
                                    currentPlayer = if (currentPlayer == "X") "O" else "X"
                                }
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(
                                text = cells[index].ifBlank { " " },
                                style = MaterialTheme.typography.headlineMedium
                            )
                        }
                    }
                }
            }
        }
        Button(
            onClick = {
                cells = List(9) { "" }
                currentPlayer = "X"
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Reset game")
        }
    }
}

private fun ticTacToeWinner(cells: List<String>): String? {
    val wins = listOf(
        listOf(0, 1, 2), listOf(3, 4, 5), listOf(6, 7, 8),
        listOf(0, 3, 6), listOf(1, 4, 7), listOf(2, 5, 8),
        listOf(0, 4, 8), listOf(2, 4, 6)
    )
    return wins.firstNotNullOfOrNull { line ->
        val mark = cells[line.first()]
        mark.takeIf { it.isNotBlank() && line.all { index -> cells[index] == mark } }
    }
}

private fun estimateSafetyScore(
    sessions: List<com.myevcompanion.app.data.ChargingSession>
): SafetyScoreEstimate {
    if (sessions.isEmpty()) {
        return SafetyScoreEstimate(
            score = null,
            confidenceLabel = "No data",
            sessionsUsed = 0,
            lateNightLabel = "Unknown",
            summary = "There are no saved charging sessions yet, so the app cannot estimate even a rough safety score. Once session history exists, this view can at least infer whether your recent charging pattern points to more late-night driving exposure.",
            factorRows = listOf(
                "Hard Braking" to "Unavailable",
                "Aggressive Turning" to "Unavailable",
                "Unsafe Following" to "Unavailable",
                "FSD Disengagement" to "Unavailable",
                "Late-Night Driving" to "Unavailable",
                "Excessive Speeding" to "Unavailable",
                "Unbuckled Driving" to "Unavailable"
            )
        )
    }

    val observedSessions = sessions.take(20)
    val lateNightSessions = observedSessions.count { session ->
        val hour = session.startedAt.hour
        hour >= 22 || hour < 4
    }
    val lateNightSuperchargerSessions = observedSessions.count { session ->
        session.isSupercharger && (session.startedAt.hour >= 22 || session.startedAt.hour < 4)
    }
    val deepDepletionSessions = observedSessions.count { session -> session.startSoc in 1..12 }
    val shortTurnSessions = observedSessions.count { session ->
        Duration.between(session.startedAt, session.endedAt).toMinutes() in 1..20
    }

    val lateNightRatio = lateNightSessions.toDouble() / observedSessions.size
    val lateNightSuperchargerRatio = lateNightSuperchargerSessions.toDouble() / observedSessions.size
    val deepDepletionRatio = deepDepletionSessions.toDouble() / observedSessions.size
    val shortTurnRatio = shortTurnSessions.toDouble() / observedSessions.size

    val penalty = (lateNightRatio * 14.0) +
        (lateNightSuperchargerRatio * 8.0) +
        (deepDepletionRatio * 4.0) +
        (shortTurnRatio * 2.0)

    val score = (100.0 - penalty).roundToInt().coerceIn(76, 100)
    val confidenceLabel = when {
        observedSessions.size >= 10 -> "Low-medium"
        observedSessions.size >= 5 -> "Low"
        else -> "Very low"
    }
    val lateNightLabel = "${(lateNightRatio * 100).roundToInt()}%"

    val summary = buildString {
        append("This estimate stays conservative because the app does not store Tesla's main driving-risk signals. ")
        append("It only nudges the score down when saved charging sessions suggest more late-night driving exposure, deeper low-battery runs, or short high-turnaround stops that can loosely correlate with more intense driving days. ")
        append("Most official Safety Score factors remain neutral here, so this should be treated as a rough directional estimate, not a Tesla-equivalent score.")
    }

    return SafetyScoreEstimate(
        score = score,
        confidenceLabel = confidenceLabel,
        sessionsUsed = observedSessions.size,
        lateNightLabel = lateNightLabel,
        summary = summary,
        factorRows = listOf(
            "Hard Braking" to "Neutral placeholder",
            "Aggressive Turning" to "Neutral placeholder",
            "Unsafe Following" to "Neutral placeholder",
            "FSD Disengagement" to "Neutral placeholder",
            "Late-Night Driving" to "${lateNightSessions}/${observedSessions.size} observed sessions",
            "Excessive Speeding" to "Unavailable",
            "Unbuckled Driving" to "Unavailable"
        )
    )
}

private fun decodeTeslaModel(vin: String): String = when (vin.getOrNull(3)) {
    '3' -> "Model 3"
    'Y' -> "Model Y"
    'S' -> "Model S"
    'X' -> "Model X"
    'C' -> "Cybertruck"
    else -> "Tesla"
}

private fun decodeTeslaDrive(vin: String): String = when (vin.getOrNull(7)) {
    'A', 'B', 'C', 'D' -> "Dual motor"
    'E', 'F' -> "Performance"
    'G', 'H' -> "AWD"
    else -> "Unknown drive"
}

private fun decodeTeslaBattery(vin: String): String = when (vin.getOrNull(6)) {
    'E', 'F' -> "Long Range / large pack"
    'A', 'B', 'C' -> "Standard pack"
    'P' -> "Performance pack"
    else -> "Battery code unavailable"
}
