package com.myevcompanion.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CarRental
import androidx.compose.material.icons.filled.ElectricBolt
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.ui.graphics.vector.ImageVector

sealed class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector
) {
    data object Home : TopLevelDestination("home", "Home", Icons.Filled.Home)
    data object Charging : TopLevelDestination("charging", "Charging", Icons.Filled.ElectricBolt)
    data object Expenses : TopLevelDestination("expenses", "Expenses", Icons.AutoMirrored.Filled.ReceiptLong)
    data object Vehicles : TopLevelDestination("vehicles", "Garage", Icons.Filled.CarRental)
    data object Tools : TopLevelDestination("tools", "Tools", Icons.Filled.Build)
    data object AiCompanion : TopLevelDestination("ai_companion", "AI", Icons.Filled.AutoAwesome)
}

val topLevelDestinations = listOf(
    TopLevelDestination.Home,
    TopLevelDestination.Charging,
    TopLevelDestination.Expenses,
    TopLevelDestination.Vehicles,
    TopLevelDestination.Tools,
    TopLevelDestination.AiCompanion
)
