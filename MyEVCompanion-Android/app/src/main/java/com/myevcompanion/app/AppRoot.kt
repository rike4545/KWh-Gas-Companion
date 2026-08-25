package com.myevcompanion.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.navigation.NavType
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.navArgument
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.navigation.TopLevelDestination
import com.myevcompanion.app.ui.navigation.topLevelDestinations
import com.myevcompanion.app.ui.screens.AiCompanionScreen
import com.myevcompanion.app.ui.screens.ChargingScreen
import com.myevcompanion.app.ui.screens.ChargingImportHubScreen
import com.myevcompanion.app.ui.screens.EditEntryScreen
import com.myevcompanion.app.ui.screens.ExpensesScreen
import com.myevcompanion.app.ui.screens.HomeScreen
import com.myevcompanion.app.ui.screens.SettingsScreen
import com.myevcompanion.app.ui.screens.TeslaMateConnectionScreen
import com.myevcompanion.app.ui.screens.ToolDetailScreen
import com.myevcompanion.app.ui.screens.ToolsScreen
import com.myevcompanion.app.ui.screens.VehiclesScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppRoot(appState: AppState) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val destinationMeta = remember(currentRoute) { routeMeta(currentRoute) }
    val isTopLevelRoute = topLevelDestinations.any { it.route == currentRoute }
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.2f

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    if (destinationMeta.showTitle) {
                        Text(
                            text = destinationMeta.title,
                            style = MaterialTheme.typography.titleLarge
                        )
                    }
                },
                navigationIcon = {
                    if (!isTopLevelRoute && currentRoute != null) {
                        IconButton(onClick = { navController.navigateUp() }) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background.copy(alpha = 0.94f),
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                    navigationIconContentColor = MaterialTheme.colorScheme.onBackground,
                    actionIconContentColor = MaterialTheme.colorScheme.onBackground
                ),
                actions = {
                    if (currentRoute != "settings") {
                        IconButton(onClick = { navController.navigate("settings") }) {
                            Icon(Icons.Filled.Settings, contentDescription = "Settings")
                        }
                    }
                }
            )
        },
        bottomBar = {
            if (isTopLevelRoute) {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    shape = RoundedCornerShape(20.dp),
                    color = Color.Transparent,
                    tonalElevation = 0.dp,
                    shadowElevation = 0.dp
                ) {
                    NavigationBar(
                        modifier = Modifier.background(
                            brush = Brush.horizontalGradient(
                                colors = if (isDark) {
                                    listOf(
                                        MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.96f),
                                        MaterialTheme.colorScheme.surface.copy(alpha = 0.92f)
                                    )
                                } else {
                                    listOf(
                                        MaterialTheme.colorScheme.surface.copy(alpha = 0.98f),
                                        MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.96f)
                                    )
                                }
                            ),
                            shape = RoundedCornerShape(20.dp)
                        ),
                        containerColor = Color.Transparent,
                        tonalElevation = 0.dp
                    ) {
                        topLevelDestinations.forEach { destination ->
                            val selected = currentRoute == destination.route
                            NavigationBarItem(
                                selected = selected,
                                onClick = {
                                    navController.navigate(destination.route) {
                                        popUpTo(navController.graph.findStartDestination().id) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = if (isDark) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                                    selectedTextColor = MaterialTheme.colorScheme.onSurface,
                                    indicatorColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isDark) 0.9f else 1f),
                                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                                ),
                                icon = { Icon(destination.icon, contentDescription = destination.label) },
                                label = { Text(destination.label, maxLines = 1) }
                            )
                        }
                    }
                }
            }
        }
    ) { innerPadding ->
        Box(modifier = Modifier.padding(innerPadding)) {
            NavHost(
                navController = navController,
                startDestination = TopLevelDestination.Home.route
            ) {
                composable(TopLevelDestination.Home.route) {
                    HomeScreen(appState = appState)
                }
                composable(TopLevelDestination.Charging.route) {
                    ChargingScreen(
                        appState = appState,
                        onOpenImportHub = { navController.navigate("charging_import_hub") }
                    )
                }
                composable(TopLevelDestination.Expenses.route) {
                    ExpensesScreen(
                        appState = appState,
                        onOpenEditEntry = { entryId ->
                            val route = if (entryId.isNullOrBlank()) {
                                "edit_entry"
                            } else {
                                "edit_entry?entryId=$entryId"
                            }
                            navController.navigate(route)
                        }
                    )
                }
                composable(TopLevelDestination.Vehicles.route) {
                    VehiclesScreen(appState = appState)
                }
                composable(TopLevelDestination.Tools.route) {
                    ToolsScreen(
                        appState = appState,
                        onOpenTool = { encodedTitle -> navController.navigate("tool_detail/$encodedTitle") }
                    )
                }
                composable(TopLevelDestination.AiCompanion.route) {
                    AiCompanionScreen(appState = appState)
                }
                composable("settings") {
                    SettingsScreen(appState = appState)
                }
                composable("charging_import_hub") {
                    ChargingImportHubScreen(
                        appState = appState,
                        onOpenTeslaMate = { navController.navigate("teslamate_connection") }
                    )
                }
                composable("teslamate_connection") {
                    TeslaMateConnectionScreen(appState = appState)
                }
                composable(
                    route = "edit_entry?entryId={entryId}",
                    arguments = listOf(
                        navArgument("entryId") {
                            type = NavType.StringType
                            nullable = true
                            defaultValue = null
                        }
                    )
                ) { backStackEntry ->
                    EditEntryScreen(
                        appState = appState,
                        initialEntryId = backStackEntry.arguments?.getString("entryId")
                    )
                }
                composable(
                    route = "tool_detail/{toolTitle}",
                    arguments = listOf(
                        navArgument("toolTitle") {
                            type = NavType.StringType
                        }
                    )
                ) { backStackEntry ->
                    ToolDetailScreen(
                        appState = appState,
                        toolTitle = backStackEntry.arguments?.getString("toolTitle")?.let(android.net.Uri::decode).orEmpty()
                    )
                }
            }
        }
    }
}

private data class RouteMeta(
    val title: String,
    val showTitle: Boolean = true
)

private fun routeMeta(route: String?): RouteMeta {
    if (route?.startsWith("edit_entry") == true) return RouteMeta("Expense Editor")
    if (route?.startsWith("tool_detail/") == true) return RouteMeta("Tool Detail")

    return when (route) {
        TopLevelDestination.Home.route -> RouteMeta("KWh Gas Companion", showTitle = false)
        TopLevelDestination.Charging.route -> RouteMeta("Charging Data")
        TopLevelDestination.Expenses.route -> RouteMeta("Expenses")
        TopLevelDestination.Vehicles.route -> RouteMeta("Garage")
        TopLevelDestination.Tools.route -> RouteMeta("Calculators")
        TopLevelDestination.AiCompanion.route -> RouteMeta("AI Companion")
        "settings" -> RouteMeta("Settings")
        "charging_import_hub" -> RouteMeta("Charging Data")
        "teslamate_connection" -> RouteMeta("TeslaMate")
        else -> RouteMeta("KWh Gas Companion")
    }
}
