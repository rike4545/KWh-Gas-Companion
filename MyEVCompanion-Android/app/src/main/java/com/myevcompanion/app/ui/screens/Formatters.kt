package com.myevcompanion.app.ui.screens

import java.util.Locale

fun Double.asCurrency(): String = "$" + String.format(Locale.US, "%.2f", this)

fun Double.oneDecimal(): String = String.format(Locale.US, "%.1f", this)
