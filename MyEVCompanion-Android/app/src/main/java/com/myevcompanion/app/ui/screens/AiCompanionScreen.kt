package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.AiChatMessage
import com.myevcompanion.app.data.AiChatRole
import com.myevcompanion.app.data.AiCompanionClient
import com.myevcompanion.app.data.buildAiCompanionContext
import com.myevcompanion.app.ui.components.LabelPill
import com.myevcompanion.app.ui.components.MetricFlowRow
import com.myevcompanion.app.ui.components.SectionCard
import kotlinx.coroutines.launch

@Composable
fun AiCompanionScreen(appState: AppState) {
    val settings by appState.aiSettings.settings.collectAsState()
    val messages = remember {
        mutableStateListOf(
            AiChatMessage(
                role = AiChatRole.Assistant,
                content = "Ask me about your next charging move, trip cost, monthly pace, garage setup, or an expense decision."
            )
        )
    }
    var draft by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var isSending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val client = remember { AiCompanionClient() }

    fun send(text: String) {
        val prompt = text.trim()
        if (prompt.isBlank() || isSending) return
        if (!settings.isConfigured) {
            error = "Add a ${settings.provider.displayName} API key and model in Settings first."
            return
        }

        error = null
        draft = ""
        messages += AiChatMessage(AiChatRole.User, prompt)
        isSending = true
        scope.launch {
            runCatching {
                client.sendMessage(
                    settings = settings,
                    contextText = buildAiCompanionContext(appState.appModel),
                    history = messages.dropLast(1),
                    message = prompt
                )
            }.onSuccess { reply ->
                messages += AiChatMessage(AiChatRole.Assistant, reply)
            }.onFailure { failure ->
                error = failure.message ?: "The AI provider could not complete the request."
            }
            isSending = false
        }
    }

    AppScreen(
        title = "AI companion",
        subtitle = "A real LLM bot that reads the app's charging, expense, garage, and forecast context before it answers."
    ) {
        item {
            SectionCard(
                title = "Provider",
                subtitle = "The active provider and model come from Settings"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    MetricFlowRow(
                        items = listOf(
                            "Provider" to settings.provider.displayName,
                            "Model" to settings.activeModel.ifBlank { "Not set" },
                            "Status" to if (settings.isConfigured) "Ready" else "Needs key"
                        )
                    )
                    Text(
                        text = "The bot sends a compact app-context packet with each message so it can reason from your real local activity data.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item {
            SectionCard(
                title = "Starter prompts"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    listOf(
                        "What should I do next to lower this month's charging cost?",
                        "Summarize my recent charging activity and call out anything unusual.",
                        "Help me decide whether the next trip should use home charging or fast charging."
                    ).forEach { prompt ->
                        OutlinedButton(
                            onClick = { send(prompt) },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isSending
                        ) {
                            Text(prompt)
                        }
                    }
                }
            }
        }
        item {
            SectionCard(
                title = "Conversation"
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    messages.forEach { message ->
                        ChatBubble(message)
                    }
                    if (isSending) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp))
                            Text(
                                text = "${settings.provider.displayName} is thinking...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    error?.let { text ->
                        Text(
                            text = text,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                    OutlinedTextField(
                        value = draft,
                        onValueChange = { draft = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 112.dp),
                        label = { Text("Ask the companion") },
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                        minLines = 3
                    )
                    Button(
                        onClick = { send(draft) },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = draft.isNotBlank() && !isSending
                    ) {
                        Text("Send")
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatBubble(message: AiChatMessage) {
    val isUser = message.role == AiChatRole.User
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 340.dp),
            shape = RoundedCornerShape(
                topStart = 18.dp,
                topEnd = 18.dp,
                bottomStart = if (isUser) 18.dp else 6.dp,
                bottomEnd = if (isUser) 6.dp else 18.dp
            ),
            color = if (isUser) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surfaceContainerHigh
            }
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                LabelPill(
                    text = if (isUser) "You" else "Companion",
                    color = if (isUser) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
                )
                Text(
                    text = message.content,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isUser) {
                        MaterialTheme.colorScheme.onPrimaryContainer
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
                )
            }
        }
    }
}
