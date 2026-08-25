package com.myevcompanion.app.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

enum class AiProvider(
    val displayName: String
) {
    OpenAI("OpenAI"),
    Claude("Claude")
}

data class AiCompanionSettings(
    val provider: AiProvider,
    val openAiApiKey: String,
    val anthropicApiKey: String,
    val openAiModel: String,
    val claudeModel: String
) {
    val activeModel: String
        get() = when (provider) {
            AiProvider.OpenAI -> openAiModel
            AiProvider.Claude -> claudeModel
        }

    val activeApiKey: String
        get() = when (provider) {
            AiProvider.OpenAI -> openAiApiKey
            AiProvider.Claude -> anthropicApiKey
        }

    val isConfigured: Boolean
        get() = activeApiKey.isNotBlank() && activeModel.isNotBlank()
}

class AiSettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences("ai_companion_settings", Context.MODE_PRIVATE)
    private val _settings = kotlinx.coroutines.flow.MutableStateFlow(readSettings())
    val settings: kotlinx.coroutines.flow.StateFlow<AiCompanionSettings> = _settings

    fun setProvider(provider: AiProvider) {
        update { copy(provider = provider) }
    }

    fun setOpenAiApiKey(apiKey: String) {
        update { copy(openAiApiKey = apiKey.trim()) }
    }

    fun setAnthropicApiKey(apiKey: String) {
        update { copy(anthropicApiKey = apiKey.trim()) }
    }

    fun setOpenAiModel(model: String) {
        update { copy(openAiModel = model.trim()) }
    }

    fun setClaudeModel(model: String) {
        update { copy(claudeModel = model.trim()) }
    }

    private fun update(block: AiCompanionSettings.() -> AiCompanionSettings) {
        val next = _settings.value.block()
        _settings.value = next
        prefs.edit()
            .putString("provider", next.provider.name)
            .putString("openAiApiKey", next.openAiApiKey)
            .putString("anthropicApiKey", next.anthropicApiKey)
            .putString("openAiModel", next.openAiModel)
            .putString("claudeModel", next.claudeModel)
            .apply()
    }

    private fun readSettings(): AiCompanionSettings {
        val provider = runCatching {
            AiProvider.valueOf(prefs.getString("provider", AiProvider.OpenAI.name) ?: AiProvider.OpenAI.name)
        }.getOrDefault(AiProvider.OpenAI)
        return AiCompanionSettings(
            provider = provider,
            openAiApiKey = prefs.getString("openAiApiKey", "").orEmpty(),
            anthropicApiKey = prefs.getString("anthropicApiKey", "").orEmpty(),
            openAiModel = prefs.getString("openAiModel", "gpt-4.1-mini").orEmpty(),
            claudeModel = prefs.getString("claudeModel", "claude-3-5-haiku-20241022").orEmpty()
        )
    }
}

data class AiChatMessage(
    val role: AiChatRole,
    val content: String
)

enum class AiChatRole {
    User,
    Assistant
}

class AiCompanionClient {
    suspend fun sendMessage(
        settings: AiCompanionSettings,
        contextText: String,
        history: List<AiChatMessage>,
        message: String
    ): String = withContext(Dispatchers.IO) {
        require(settings.isConfigured) { "Add an API key and model in Settings before sending a message." }
        when (settings.provider) {
            AiProvider.OpenAI -> callOpenAi(settings, contextText, history, message)
            AiProvider.Claude -> callClaude(settings, contextText, history, message)
        }
    }

    private fun callOpenAi(
        settings: AiCompanionSettings,
        contextText: String,
        history: List<AiChatMessage>,
        message: String
    ): String {
        val input = JSONArray()
            .put(JSONObject().put("role", "system").put("content", systemPrompt(contextText)))
        history.takeLast(8).forEach { chat ->
            input.put(
                JSONObject()
                    .put("role", if (chat.role == AiChatRole.User) "user" else "assistant")
                    .put("content", chat.content)
            )
        }
        input.put(JSONObject().put("role", "user").put("content", message))

        val payload = JSONObject()
            .put("model", settings.openAiModel)
            .put("input", input)
            .put("max_output_tokens", 700)

        val response = postJson(
            endpoint = "https://api.openai.com/v1/responses",
            headers = mapOf("Authorization" to "Bearer ${settings.openAiApiKey}"),
            payload = payload
        )
        val outputText = response.optString("output_text")
        if (outputText.isNotBlank()) return outputText.trim()

        val output = response.optJSONArray("output") ?: return "I received an empty response from OpenAI."
        for (index in 0 until output.length()) {
            val item = output.optJSONObject(index) ?: continue
            val content = item.optJSONArray("content") ?: continue
            for (contentIndex in 0 until content.length()) {
                val part = content.optJSONObject(contentIndex) ?: continue
                val text = part.optString("text").ifBlank { part.optString("output_text") }
                if (text.isNotBlank()) return text.trim()
            }
        }
        return "I received an OpenAI response, but it did not include readable text."
    }

    private fun callClaude(
        settings: AiCompanionSettings,
        contextText: String,
        history: List<AiChatMessage>,
        message: String
    ): String {
        val messages = JSONArray()
        history.takeLast(8).forEach { chat ->
            messages.put(
                JSONObject()
                    .put("role", if (chat.role == AiChatRole.User) "user" else "assistant")
                    .put("content", chat.content)
            )
        }
        messages.put(JSONObject().put("role", "user").put("content", message))

        val payload = JSONObject()
            .put("model", settings.claudeModel)
            .put("system", systemPrompt(contextText))
            .put("max_tokens", 700)
            .put("messages", messages)

        val response = postJson(
            endpoint = "https://api.anthropic.com/v1/messages",
            headers = mapOf(
                "x-api-key" to settings.anthropicApiKey,
                "anthropic-version" to "2023-06-01"
            ),
            payload = payload
        )
        val content = response.optJSONArray("content") ?: return "I received an empty response from Claude."
        val parts = buildList {
            for (index in 0 until content.length()) {
                val item = content.optJSONObject(index) ?: continue
                val text = item.optString("text")
                if (text.isNotBlank()) add(text)
            }
        }
        return parts.joinToString("\n\n").ifBlank { "I received a Claude response, but it did not include readable text." }.trim()
    }

    private fun postJson(
        endpoint: String,
        headers: Map<String, String>,
        payload: JSONObject
    ): JSONObject {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 45_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            headers.forEach { (key, value) -> setRequestProperty(key, value) }
        }

        OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
            writer.write(payload.toString())
        }

        val status = connection.responseCode
        val body = if (status in 200..299) {
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } else {
            connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        }
        connection.disconnect()

        if (status !in 200..299) {
            val message = runCatching {
                val json = JSONObject(body)
                json.optJSONObject("error")?.optString("message").orEmpty()
                    .ifBlank { json.optString("message") }
            }.getOrDefault("").ifBlank { "HTTP $status" }
            throw IllegalStateException(message)
        }
        return JSONObject(body)
    }

    private fun systemPrompt(contextText: String): String {
        return """
            You are the KWh Gas Companion AI bot inside an EV ownership app.
            Help the user with charging, cost, trip, budget, garage, expense, and activity decisions.
            Use the app context below as trusted function output from the app's local data.
            Be concise, practical, and specific. If data is missing, say what to add in the app.

            App function context:
            $contextText
        """.trimIndent()
    }
}

fun buildAiCompanionContext(appModel: KWhGasCompanionAppModel): String {
    val snapshot = appModel.dashboardSnapshot()
    val vehicle = snapshot.activeVehicle
    val recentSessions = snapshot.recentSessions.joinToString("\n") { session ->
        "- ${session.provider.ifBlank { session.stationName }} at ${session.stationName}: ${session.energyAddedKWh.formatOne()} kWh, ${session.cost.formatCurrency()}, ${session.startSoc}% to ${session.endSoc}%"
    }.ifBlank { "- No recent charging sessions." }
    val recentEntries = snapshot.recentEntries.joinToString("\n") { entry ->
        "- ${entry.title}: ${entry.amount.formatCurrency()}, ${entry.category.label}, ${entry.date}, ${entry.location}"
    }.ifBlank { "- No recent expense entries." }
    val insights = snapshot.insights.joinToString("\n") { insight ->
        "- ${insight.title}: ${insight.body} (${insight.scoreLabel})"
    }.ifBlank { "- No dashboard insights yet." }
    val ml = snapshot.chargingMlInsight

    return """
        function dashboardSnapshot:
        - Total spend: ${snapshot.totalSpend.formatCurrency()}
        - Energy this month: ${snapshot.energyThisMonth.formatOne()} kWh
        - Average cost per kWh: ${snapshot.avgCostPerKwh.formatCurrency()}/kWh
        - Charging sessions: ${snapshot.sessionCount}
        - Top provider: ${snapshot.topProvider}

        function activeVehicle:
        - Name: ${vehicle?.name ?: "No active vehicle"}
        - Vehicle: ${vehicle?.let { "${it.year} ${it.make} ${it.model}" } ?: "Unknown"}
        - Range: ${vehicle?.estimatedRangeMiles?.formatOne() ?: "Unknown"} miles
        - Battery: ${vehicle?.batteryCapacityKWh?.formatOne() ?: "Unknown"} kWh
        - Efficiency: ${vehicle?.efficiencyWhPerMile?.formatOne() ?: "Unknown"} Wh/mi

        function chargingMlInsight:
        - Summary: ${ml.summary}
        - Confidence: ${ml.confidenceLabel}
        - Trend: ${ml.trendLabel}
        - Next session cost: ${ml.nextSessionCost?.formatCurrency() ?: "Learning"}
        - Next session energy: ${ml.nextSessionEnergyKwh?.formatOne() ?: "Learning"} kWh
        - Typical rate: ${ml.typicalCostPerKwh?.formatCurrency() ?: "Unknown"}/kWh
        - Price hotspot: ${ml.priciestProvider}
        - Outlier: ${ml.anomalyLabel}

        function recentChargingSessions:
        $recentSessions

        function recentExpenseEntries:
        $recentEntries

        function dashboardInsights:
        $insights
    """.trimIndent()
}

private fun Double.formatCurrency(): String = "$" + String.format(Locale.US, "%.2f", this)

private fun Double.formatOne(): String = String.format(Locale.US, "%.1f", this)
