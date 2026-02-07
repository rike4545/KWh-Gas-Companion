package com.myevcompanion.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.myevcompanion.app.core.AppState
import com.myevcompanion.app.ui.navigation.TopLevelDestination
import com.myevcompanion.app.ui.navigation.topLevelDestinations
import com.myevcompanion.app.ui.screens.ChargingScreen
import com.myevcompanion.app.ui.screens.ChargingImportHubScreen
import com.myevcompanion.app.ui.screens.EditEntryScreen
import com.myevcompanion.app.ui.screens.ExpensesScreen
import com.myevcompanion.app.ui.screens.HomeScreen
import com.myevcompanion.app.ui.screens.SettingsScreen
import com.myevcompanion.app.ui.screens.ToolsScreen
import com.myevcompanion.app.ui.screens.VehiclesScreen
@Composable
fun AppRoot(appState: AppState) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(text = "My EV Companion") },
                actions = {
                    IconButton(onClick = { navController.navigate("settings") }) {
                        Icon(Icons.Filled.Settings, contentDescription = "Settings")
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
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
                        icon = { Icon(destination.icon, contentDescription = destination.label) },
                        label = { Text(destination.label) }
                    )
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
                        onOpenEditEntry = { navController.navigate("edit_entry") }
                    )
                }
                composable(TopLevelDestination.Vehicles.route) {
                    VehiclesScreen(appState = appState)
                }
                composable(TopLevelDestination.Tools.route) {
                    ToolsScreen(appState = appState)
                }
                composable("settings") {
                    SettingsScreen(appState = appState)
                }
                composable("charging_import_hub") {
                    ChargingImportHubScreen(appState = appState)
                }
                composable("edit_entry") {
                    EditEntryScreen(appState = appState)
                }
            }
        }
    }
}
