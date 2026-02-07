package com.myevcompanion.app

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.core.rememberAppState
import com.myevcompanion.app.ui.theme.MyEVCompanionTheme

@Composable
fun MyEVCompanionApp() {
    val appState = rememberAppState()

    MyEVCompanionTheme(appState = appState) {
        Surface(color = MaterialTheme.colorScheme.background) {
            AppRoot(appState = appState)
        }
    }
}
