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
    primary = Color(0xFF1E5BFF),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFDCE7FF),
    onPrimaryContainer = Color(0xFF10204B),
    secondary = Color(0xFF28745D),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFD8F3E8),
    onSecondaryContainer = Color(0xFF0E2D23),
    tertiary = Color(0xFFE5484D),
    tertiaryContainer = Color(0xFFFFE1E3),
    onTertiaryContainer = Color(0xFF5E1117),
    background = Color(0xFFF3F6FB),
    onBackground = Color(0xFF10131A),
    surface = Color(0xFFFBFCFF),
    onSurface = Color(0xFF161A22),
    surfaceContainer = Color(0xFFF6F8FD),
    surfaceContainerHigh = Color(0xFFEFF3FA),
    surfaceVariant = Color(0xFFE9EEF8),
    onSurfaceVariant = Color(0xFF536072),
    outline = Color(0xFFC7D1E0),
    outlineVariant = Color(0xFFDCE4F0)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF79A2FF),
    onPrimary = Color(0xFF091329),
    primaryContainer = Color(0xFF1F3B78),
    onPrimaryContainer = Color(0xFFE3EBFF),
    secondary = Color(0xFF7DD9BA),
    onSecondary = Color(0xFF062018),
    secondaryContainer = Color(0xFF184E3F),
    onSecondaryContainer = Color(0xFFD9F7ED),
    tertiary = Color(0xFFFF8B8F),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFF6E2429),
    onTertiaryContainer = Color(0xFFFFE1E3),
    background = Color(0xFF0A1019),
    onBackground = Color(0xFFF2F6FC),
    surface = Color(0xFF111A26),
    onSurface = Color(0xFFF3F7FD),
    surfaceContainer = Color(0xFF141F2D),
    surfaceContainerHigh = Color(0xFF1A2737),
    surfaceVariant = Color(0xFF172231),
    onSurfaceVariant = Color(0xFFB0BED3),
    outline = Color(0xFF2A3950),
    outlineVariant = Color(0xFF1D2A3B)
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
