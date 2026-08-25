package com.myevcompanion.app.ads

import android.app.Activity
import android.content.Context

object AppOpenAdManager {
    suspend fun handleAppForegrounded(activity: Activity) = Unit

    suspend fun loadAd(context: Context) = Unit
}
