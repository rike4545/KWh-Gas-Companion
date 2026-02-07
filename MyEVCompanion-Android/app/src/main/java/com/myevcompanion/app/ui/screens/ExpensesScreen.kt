package com.myevcompanion.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.components.AdBannerCard

@Composable
fun ExpensesScreen(
    appState: AppState,
    onOpenEditEntry: () -> Unit
) {
    FeatureListScreen(
        title = "Expenses",
        sections = listOf(
            FeatureSection(
                title = "Logging",
                items = listOf(
                    "Expense editor",
                    "Expense categories",
                    "CSV import/export",
                    "Receipt attachment" 
                )
            ),
            FeatureSection(
                title = "Reports",
                items = listOf(
                    "Quarterly tax summary",
                    "Business deduction report",
                    "Reimbursement generator",
                    "Cost breakdown detail"
                )
            )
        ),
        footer = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = onOpenEditEntry,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Add / Edit Entry")
                }
                AdBannerCard()
            }
        }
    )
}
