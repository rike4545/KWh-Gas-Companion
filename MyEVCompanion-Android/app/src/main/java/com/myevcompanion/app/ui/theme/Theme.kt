package com.myevcompanion.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.data.ThemeMode

private val LightColors = lightColorScheme(
    primary = Color(0xFF00C389),
    onPrimary = Color(0xFF0B1D1B),
    secondary = Color(0xFF2B8CFF),
    onSecondary = Color.White,
    background = Color(0xFFF6F7F8),
    onBackground = Color(0xFF101820),
    surface = Color.White,
    onSurface = Color(0xFF101820)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF00C389),
    onPrimary = Color(0xFF0B1D1B),
    secondary = Color(0xFF2B8CFF),
    onSecondary = Color.Black,
    background = Color(0xFF0B1116),
    onBackground = Color(0xFFE6ECF2),
    surface = Color(0xFF111820),
    onSurface = Color(0xFFE6ECF2)
)

@Composable
fun MyEVCompanionTheme(
    appState: AppState,
    content: @Composable () -> Unit
) {
    val themeMode by appState.appearance.themeMode.collectAsState()
    val systemDark = isSystemInDarkTheme()
    val useDark = when (themeMode) {
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
        ThemeMode.SYSTEM -> systemDark
    }

    MaterialTheme(
        colorScheme = if (useDark) DarkColors else LightColors,
        typography = Typography,
        content = content
    )
}
