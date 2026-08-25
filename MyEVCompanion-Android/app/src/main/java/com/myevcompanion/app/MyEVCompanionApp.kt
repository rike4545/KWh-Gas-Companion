package com.myevcompanion.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.myevcompanion.app.core.rememberAppState
import com.myevcompanion.app.ui.theme.MyEVCompanionTheme

@Composable
fun MyEVCompanionApp() {
    val context = LocalContext.current.applicationContext
    val appState = rememberAppState(context)

    MyEVCompanionTheme(appState = appState) {
        Surface(color = MaterialTheme.colorScheme.background) {
            AppRoot(appState = appState)
        }
    }
}
