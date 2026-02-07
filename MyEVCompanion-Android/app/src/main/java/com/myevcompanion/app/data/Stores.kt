package com.myevcompanion.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class ProfileStore {
    private val _profiles = MutableStateFlow(emptyList<String>())
    val profiles: StateFlow<List<String>> = _profiles
}

class EntriesStore {
    private val _entries = MutableStateFlow(emptyList<String>())
    val entries: StateFlow<List<String>> = _entries
}

class TeslaFiSessionStore {
    private val _sessions = MutableStateFlow(emptyList<String>())
    val sessions: StateFlow<List<String>> = _sessions
}

class BudgetStore {
    private val _budgets = MutableStateFlow(emptyList<String>())
    val budgets: StateFlow<List<String>> = _budgets
}

class AppAppearance {
    private val _accentHex = MutableStateFlow("#00C389")
    val accentHex: StateFlow<String> = _accentHex

    private val _themeMode = MutableStateFlow(ThemeMode.SYSTEM)
    val themeMode: StateFlow<ThemeMode> = _themeMode
}

enum class ThemeMode {
    LIGHT,
    DARK,
    SYSTEM
}

class ToolUsageStore {
    private val _usage = MutableStateFlow(emptyMap<String, Int>())
    val usage: StateFlow<Map<String, Int>> = _usage
}

class AppUISettings {
    private val _hapticsEnabled = MutableStateFlow(true)
    val hapticsEnabled: StateFlow<Boolean> = _hapticsEnabled
}

class SuperchargePricingInfoStore {
    private val _stations = MutableStateFlow(emptyList<String>())
    val stations: StateFlow<List<String>> = _stations
}

class TeslaOfficialSuperchargerPricingStore {
    private val _prices = MutableStateFlow(emptyList<String>())
    val prices: StateFlow<List<String>> = _prices
}

class KWhGasCompanionAppModel(
    val teslaFiStore: TeslaFiSessionStore,
    val profileStore: ProfileStore,
    val entriesStore: EntriesStore
)

class AppStartupCoordinator {
    private val _didWarmup = MutableStateFlow(false)
    val didWarmup: StateFlow<Boolean> = _didWarmup
}
