package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun FeatureListScreen(
    title: String,
    sections: List<FeatureSection>,
    footer: (@Composable () -> Unit)? = null
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text(text = title, style = MaterialTheme.typography.headlineSmall)
        }
        items(sections) { section ->
            Card {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(text = section.title, style = MaterialTheme.typography.titleMedium)
                    section.items.forEach { item ->
                        Text(text = "• $item", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
        if (footer != null) {
            item {
                footer()
            }
        }
    }
}

data class FeatureSection(
    val title: String,
    val items: List<String>
)
