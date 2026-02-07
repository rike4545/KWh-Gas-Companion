package com.myevcompanion.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CarRental
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.ui.graphics.vector.ImageVector

sealed class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector
) {
    data object Home : TopLevelDestination("home", "Home", Icons.Filled.Home)
    data object Charging : TopLevelDestination("charging", "Charging", Icons.Filled.LocalGasStation)
    data object Expenses : TopLevelDestination("expenses", "Expenses", Icons.Filled.ReceiptLong)
    data object Vehicles : TopLevelDestination("vehicles", "Vehicles", Icons.Filled.CarRental)
    data object Tools : TopLevelDestination("tools", "Tools", Icons.Filled.Build)
}

val topLevelDestinations = listOf(
    TopLevelDestination.Home,
    TopLevelDestination.Charging,
    TopLevelDestination.Expenses,
    TopLevelDestination.Vehicles,
    TopLevelDestination.Tools
)
