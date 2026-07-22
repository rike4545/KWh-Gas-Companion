package com.myevcompanion.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.ads.MobileAds
import com.myevcompanion.app.ads.GoogleMobileAdsConsentManager
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private var adsStarted = false
    private var adsPreparing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        lifecycleScope.launch {
            prepareAndStartAdsIfConfigured()
        }
        setContent {
            MyEVCompanionApp()
        }
    }

    override fun onStart() {
        super.onStart()
        lifecycleScope.launch {
            prepareAndStartAdsIfConfigured()
        }
    }

    private suspend fun prepareAndStartAdsIfConfigured() {
        if (adsStarted || adsPreparing || !areAdsEnabled()) return

        adsPreparing = true
        try {
            GoogleMobileAdsConsentManager.gatherConsent(this)
            if (!GoogleMobileAdsConsentManager.canRequestAds(this)) return

            MobileAds.initialize(this)
            adsStarted = true
        } finally {
            adsPreparing = false
        }
    }

    private fun areAdsEnabled(): Boolean =
        getSharedPreferences("ui_settings", MODE_PRIVATE).getBoolean("showAds", true)
}
