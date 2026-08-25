package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.OutlinedTextField
import androidx.compose.ui.Modifier
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.AiProvider
import com.myevcompanion.app.data.IosParityCatalog
import com.myevcompanion.app.data.ThemeMode
import com.myevcompanion.app.ui.components.ChipSelector
import com.myevcompanion.app.ui.components.LabeledField
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard

@Composable
fun SettingsScreen(appState: AppState) {
    val themeMode by appState.appearance.themeMode.collectAsState()
    val hapticsEnabled by appState.uiSettings.hapticsEnabled.collectAsState()
    val showAds by appState.uiSettings.showAds.collectAsState()
    val aiSettings by appState.aiSettings.settings.collectAsState()
    val missingIosTools = IosParityCatalog.missingCalculatorTitles()

    AppScreen(
        title = "Settings",
        subtitle = "A cleaner control center for theme behavior, tactile feedback, and monetization toggles."
    ) {
        item {
            SectionCard(
                title = "Appearance",
                subtitle = "Material 3 theming with a custom palette inspired by the app's EV and road-trip feel"
            ) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    LabelPill(
                        text = "Light",
                        color = if (themeMode == ThemeMode.LIGHT) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier.clickable { appState.appearance.setThemeMode(ThemeMode.LIGHT) }
                    )
                    LabelPill(
                        text = "Dark",
                        color = if (themeMode == ThemeMode.DARK) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier.clickable { appState.appearance.setThemeMode(ThemeMode.DARK) }
                    )
                    LabelPill(
                        text = "System",
                        color = if (themeMode == ThemeMode.SYSTEM) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        modifier = Modifier.clickable { appState.appearance.setThemeMode(ThemeMode.SYSTEM) }
                    )
                }
                Text(
                    text = "Theme mode is currently ${themeMode.displayName()}. Your selection is saved locally and applied immediately.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        item {
            SectionCard(
                title = "AI companion",
                subtitle = "Choose the provider the bot uses and save your own API keys on this device"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    ChipSelector(
                        label = "Provider",
                        options = AiProvider.entries.map { it.displayName },
                        selected = aiSettings.provider.displayName,
                        onSelected = { selected ->
                            AiProvider.entries.firstOrNull { it.displayName == selected }
                                ?.let(appState.aiSettings::setProvider)
                        }
                    )
                    MetricFlowRow(
                        items = listOf(
                            "Active" to aiSettings.provider.displayName,
                            "OpenAI key" to if (aiSettings.openAiApiKey.isBlank()) "Not set" else "Saved",
                            "Claude key" to if (aiSettings.anthropicApiKey.isBlank()) "Not set" else "Saved"
                        )
                    )
                    OutlinedTextField(
                        value = aiSettings.openAiApiKey,
                        onValueChange = appState.aiSettings::setOpenAiApiKey,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("OpenAI API key") },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        supportingText = { Text("Used when OpenAI is selected.") }
                    )
                    LabeledField(
                        label = "OpenAI model",
                        value = aiSettings.openAiModel,
                        onValueChange = appState.aiSettings::setOpenAiModel,
                        supportingText = "Default: gpt-4.1-mini"
                    )
                    OutlinedTextField(
                        value = aiSettings.anthropicApiKey,
                        onValueChange = appState.aiSettings::setAnthropicApiKey,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Claude API key") },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        supportingText = { Text("Used when Claude is selected.") }
                    )
                    LabeledField(
                        label = "Claude model",
                        value = aiSettings.claudeModel,
                        onValueChange = appState.aiSettings::setClaudeModel,
                        supportingText = "Default: claude-3-5-haiku-20241022"
                    )
                    Text(
                        text = "Keys are saved locally on this device and are sent only to the provider you select.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "iOS parity",
                subtitle = "Calculator and fork coverage checked against the iOS catalog"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    MetricFlowRow(
                        items = listOf(
                            "iOS calculators" to IosParityCatalog.coverageLabel(),
                            "Missing" to missingIosTools.size.toString(),
                            "Android bridge hubs" to IosParityCatalog.androidParityBridgeTitles.size.toString()
                        )
                    )
                    Text(
                        text = if (missingIosTools.isEmpty()) {
                            "Every iOS calculator title is represented in Android. Bridge hubs cover iOS-only areas such as direct connection, widgets, agent context, and import onboarding."
                        } else {
                            "Missing from Android: ${missingIosTools.joinToString()}"
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Behavior",
                subtitle = "Simple runtime toggles"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Haptics", style = MaterialTheme.typography.titleMedium)
                        Switch(
                            checked = hapticsEnabled,
                            onCheckedChange = appState.uiSettings::setHapticsEnabled
                        )
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Show ads", style = MaterialTheme.typography.titleMedium)
                        Switch(
                            checked = showAds,
                            onCheckedChange = appState.uiSettings::setShowAds
                        )
                    }
                    Text(
                        text = "Ads appear in dedicated cards on browse-heavy screens so they stay visually separate from navigation, forms, and primary actions.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

private fun ThemeMode.displayName(): String {
    val raw = name.lowercase()
    return raw.replaceFirstChar { char ->
        if (char.isLowerCase()) char.titlecase() else char.toString()
    }
}
