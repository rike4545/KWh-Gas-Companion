package com.myevcompanion.app.ui.screens

import androidx.compose.ui.graphics.Color
import java.time.LocalTime

data class GridEmissionPoint(
    val hour: Int,
    val index: Int,
    val region: String,
    val label: String
) {
    val hourLabel: String
        get() {
            val time = LocalTime.of(hour % 24, 0)
            val suffix = if (time.hour < 12) "AM" else "PM"
            val displayHour = when (val raw = time.hour % 12) {
                0 -> 12
                else -> raw
            }
            return "$displayHour $suffix"
        }

    val color: Color
        get() = when {
            index <= 35 -> Color(0xFF2EAD67)
            index <= 55 -> Color(0xFFF2C94C)
            index <= 72 -> Color(0xFFF2994A)
            else -> Color(0xFFD64545)
        }
}

data class GridLocationComparison(
    val city: String,
    val region: String,
    val currentIndex: Int,
    val bestWindow: String,
    val note: String
)

fun sampleGridEmissionForecast(): List<GridEmissionPoint> {
    val now = LocalTime.now().hour
    val shape = listOf(64, 61, 58, 52, 45, 38, 31, 28, 34, 43, 51, 62, 73, 82, 86, 79, 67, 54, 42, 36, 33, 40, 49, 57)
    return shape.mapIndexed { offset, index ->
        GridEmissionPoint(
            hour = (now + offset) % 24,
            index = index,
            region = "Local grid",
            label = when {
                index <= 35 -> "Clean"
                index <= 55 -> "Moderate"
                index <= 72 -> "Elevated"
                else -> "Carbon-heavy"
            }
        )
    }
}

fun sampleGridLocationComparisons(): List<GridLocationComparison> = listOf(
    GridLocationComparison("San Jose, CA", "CAISO_NORTH", 32, "1 PM - 4 PM", "Solar-heavy midday window"),
    GridLocationComparison("Austin, TX", "ERCOT", 48, "11 PM - 2 AM", "Wind often improves overnight"),
    GridLocationComparison("Chicago, IL", "MISO", 66, "3 AM - 6 AM", "Cleaner before morning ramp"),
    GridLocationComparison("New York, NY", "NYISO_NYC", 58, "10 AM - 1 PM", "Moderate daytime window")
)
