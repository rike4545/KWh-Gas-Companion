package com.myevcompanion.app.ui.screens

import android.net.Uri
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.IosParityCatalog
import com.myevcompanion.app.data.SampleData
import com.myevcompanion.app.data.ToolCard
import com.myevcompanion.app.ui.components.AdBannerCard
import com.myevcompanion.app.ui.components.HeroCard
import com.myevcompanion.app.ui.components.ImageShowcaseCard
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard

@Composable
fun ToolsScreen(
    appState: AppState,
    onOpenTool: (String) -> Unit
) {
    var query by rememberSaveable { mutableStateOf("") }
    var selectedGroup by rememberSaveable { mutableStateOf("All") }
    val usage by appState.toolUsage.usage.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val groups = listOf("All") + SampleData.tools.map { it.group }.distinct()
    val visibleTools = SampleData.tools.filter { tool ->
        val matchesQuery = if (query.isBlank()) {
            true
        } else {
            listOf(tool.title, tool.description, tool.group).any { it.contains(query, ignoreCase = true) }
        }
        val matchesGroup = selectedGroup == "All" || tool.group == selectedGroup
        matchesQuery && matchesGroup
    }
    val toolsByGroup = visibleTools.groupBy { it.group }
    val featuredTools = SampleData.tools
        .sortedByDescending { usage[it.title] ?: 0 }
        .take(3)
    val missingIosTools = IosParityCatalog.missingCalculatorTitles()

    AppScreen(
        title = "Calculators",
        subtitle = "A cleaner Android tool browser with stronger scanning, grouping, and quick-open behavior."
    ) {
        item {
            HeroCard(
                eyebrow = "Toolbox",
                title = "Every EV decision gets a helper",
                subtitle = "Top-used tools right now: ${
                    usage.entries.sortedByDescending { it.value }.take(3).joinToString(" • ") { "${it.key} (${it.value})" }
                }",
                imageRes = toolsHeroArtwork
            )
        }
        item {
            SectionCard(
                title = "Explore tools",
                subtitle = "Search by name, then narrow the library by category"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    LabeledField(
                        label = "Search calculators and utilities",
                        value = query,
                        onValueChange = { query = it }
                    )
                    FilterRow(
                        groups = groups,
                        selectedGroup = selectedGroup,
                        onSelect = { selectedGroup = it }
                    )
                    MetricBanner(
                        primaryText = "${visibleTools.size} visible tools",
                        secondaryText = "${toolsByGroup.keys.size} groups in this view • iOS parity ${IosParityCatalog.coverageLabel()}"
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Parity coverage",
                subtitle = "Android catalog coverage against the current iOS calculator registry"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    MetricFlowRow(
                        items = listOf(
                            "iOS calculators" to IosParityCatalog.coverageLabel(),
                            "Missing titles" to missingIosTools.size.toString(),
                            "Bridge hubs" to IosParityCatalog.androidParityBridgeTitles.size.toString()
                        )
                    )
                    Text(
                        text = if (missingIosTools.isEmpty()) {
                            "Android has a matching entry for every iOS calculator, plus bridge hubs for direct connection, widgets, agent context, and onboarding surfaces."
                        } else {
                            "Still missing: ${missingIosTools.joinToString()}"
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        if (featuredTools.isNotEmpty()) {
            item {
                SectionCard(
                    title = "Top picks",
                    subtitle = "Quick-open tools people reach for most inside the fork"
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        featuredTools.forEach { tool ->
                            ToolBrowserCard(
                                tool = tool,
                                usageCount = usage[tool.title] ?: 0,
                                onOpen = {
                                    appState.toolUsage.recordOpen(tool.title)
                                    onOpenTool(Uri.encode(tool.title))
                                }
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
        toolsByGroup.forEach { (group, tools) ->
            item {
                SectionCard(
                    title = group,
                    subtitle = "${tools.size} tools in this category"
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        tools.forEach { tool ->
                            ToolBrowserCard(
                                tool = tool,
                                usageCount = usage[tool.title] ?: 0,
                                onOpen = {
                                    appState.toolUsage.recordOpen(tool.title)
                                    onOpenTool(Uri.encode(tool.title))
                                }
                            )
                        }
                    }
                }
            }
            if (group == "Research") {
                item {
                    ImageShowcaseCard(
                        imageRes = toolsResearchArtwork,
                        title = "Research and discovery",
                        subtitle = "Incentives, policy updates, and EV industry context live alongside the planners and calculators."
                    )
                }
            }
        }
    }
}

@Composable
private fun FilterRow(
    groups: List<String>,
    selectedGroup: String,
    onSelect: (String) -> Unit
) {
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        groups.forEach { group ->
            LabelPill(
                text = group,
                color = if (group == selectedGroup) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                modifier = Modifier.clickable { onSelect(group) }
            )
        }
    }
}

@Composable
private fun MetricBanner(
    primaryText: String,
    secondaryText: String
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
                            MaterialTheme.colorScheme.tertiary.copy(alpha = 0.08f)
                        )
                    )
                )
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(primaryText, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = secondaryText,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ToolBrowserCard(
    tool: ToolCard,
    usageCount: Int,
    onOpen: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = Color.Transparent,
        onClick = onOpen
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            tool.accent.copy(alpha = 0.18f),
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)
                        )
                    )
                )
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .background(tool.accent.copy(alpha = 0.18f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = tool.group.take(1),
                        style = MaterialTheme.typography.titleMedium,
                        color = tool.accent
                    )
                }
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = tool.title,
                        style = MaterialTheme.typography.titleMedium
                    )
                    Text(
                        text = tool.description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ToolLabelRow(tool = tool, usageCount = usageCount)
                Button(
                    onClick = onOpen,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = tool.accent)
                ) {
                    Text("Open")
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ToolLabelRow(
    tool: ToolCard,
    usageCount: Int
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        LabelPill(text = tool.group, color = tool.accent)
        if (usageCount > 0) {
            LabelPill(
                text = "$usageCount opens",
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}
