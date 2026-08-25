package com.myevcompanion.app.core

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import com.myevcompanion.app.data.AppAppearance
import com.myevcompanion.app.data.AppStartupCoordinator
import com.myevcompanion.app.data.AppUISettings
import com.myevcompanion.app.data.AiSettingsStore
import com.myevcompanion.app.data.BudgetStore
import com.myevcompanion.app.data.DiscountFavoritesStore
import com.myevcompanion.app.data.EntriesStore
import com.myevcompanion.app.data.KWhGasCompanionAppModel
import com.myevcompanion.app.data.ProfileStore
import com.myevcompanion.app.data.SuperchargePricingInfoStore
import com.myevcompanion.app.data.TeslaFiSessionStore
import com.myevcompanion.app.data.TeslaMateConnectionStore
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
    val discountFavorites: DiscountFavoritesStore,
    val uiSettings: AppUISettings,
    val aiSettings: AiSettingsStore,
    val superchargerStore: SuperchargePricingInfoStore,
    val teslaMateStore: TeslaMateConnectionStore,
    val teslaPricingStore: TeslaOfficialSuperchargerPricingStore,
    val appModel: KWhGasCompanionAppModel,
    val startup: AppStartupCoordinator
)

@Composable
fun rememberAppState(context: Context): AppState {
    return remember(context) {
        val profile = ProfileStore(context)
        val entries = EntriesStore(context)
        val teslaFi = TeslaFiSessionStore(context)

        val budget = BudgetStore()
        val appearance = AppAppearance(context)
        val toolUsage = ToolUsageStore()
        val discountFavorites = DiscountFavoritesStore(context)
        val uiSettings = AppUISettings(context)
        val aiSettings = AiSettingsStore(context)
        val supercharger = SuperchargePricingInfoStore()
        val teslaMate = TeslaMateConnectionStore(context)
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
            discountFavorites = discountFavorites,
            uiSettings = uiSettings,
            aiSettings = aiSettings,
            superchargerStore = supercharger,
            teslaMateStore = teslaMate,
            teslaPricingStore = teslaPricing,
            appModel = appModel,
            startup = AppStartupCoordinator()
        )
    }
}
