package com.myevcompanion.app.core

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import com.myevcompanion.app.data.AppAppearance
import com.myevcompanion.app.data.AppStartupCoordinator
import com.myevcompanion.app.data.AppUISettings
import com.myevcompanion.app.data.BudgetStore
import com.myevcompanion.app.data.EntriesStore
import com.myevcompanion.app.data.KWhGasCompanionAppModel
import com.myevcompanion.app.data.ProfileStore
import com.myevcompanion.app.data.SuperchargePricingInfoStore
import com.myevcompanion.app.data.TeslaFiSessionStore
import com.myevcompanion.app.data.TeslaOfficialSuperchargerPricingStore
import com.myevcompanion.app.data.ToolUsageStore

@Immutable
class AppState(
    val profileStore: ProfileStore,
    val entriesStore: EntriesStore,
    val teslaFiStore: TeslaFiSessionStore,
    val budgetStore: BudgetStore,
    val appearance: AppAppearance,
    val toolUsage: ToolUsageStore,
    val uiSettings: AppUISettings,
    val superchargerStore: SuperchargePricingInfoStore,
    val teslaPricingStore: TeslaOfficialSuperchargerPricingStore,
    val appModel: KWhGasCompanionAppModel,
    val startup: AppStartupCoordinator
)

@Composable
fun rememberAppState(): AppState {
    return remember {
        val profile = ProfileStore()
        val entries = EntriesStore()
        val teslaFi = TeslaFiSessionStore()

        val budget = BudgetStore()
        val appearance = AppAppearance()
        val toolUsage = ToolUsageStore()
        val uiSettings = AppUISettings()
        val supercharger = SuperchargePricingInfoStore()
        val teslaPricing = TeslaOfficialSuperchargerPricingStore()
        val appModel = KWhGasCompanionAppModel(
            teslaFiStore = teslaFi,
            profileStore = profile,
            entriesStore = entries
        )

        AppState(
            profileStore = profile,
            entriesStore = entries,
            teslaFiStore = teslaFi,
            budgetStore = budget,
            appearance = appearance,
            toolUsage = toolUsage,
            uiSettings = uiSettings,
            superchargerStore = supercharger,
            teslaPricingStore = teslaPricing,
            appModel = appModel,
            startup = AppStartupCoordinator()
        )
    }
}
