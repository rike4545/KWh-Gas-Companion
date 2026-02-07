import SwiftUI

@MainActor
struct AdBannerCard: View {
    @ObservedObject var adsStore: AdsEntitlementStore
    @Environment(\.adsInlineEnabled) private var adsInlineEnabled
    @State private var refreshTick: Int = 0

    var body: some View {
        if adsInlineEnabled {
            AdBannerCardContent(adsStore: adsStore)
                .onReceive(adsStore.$refreshTick) { tick in
                    refreshTick = tick
                }
                .id(refreshTick)
        }
    }
}

@MainActor
struct AdBannerOverlayCard: View {
    @ObservedObject var adsStore: AdsEntitlementStore

    var body: some View {
        AdBannerCardContent(adsStore: adsStore)
    }
}

@MainActor
private struct AdBannerCardContent: View {
    @ObservedObject var adsStore: AdsEntitlementStore
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var theme: any AppThemeSpec { themeBox.base }
    private var bannerHeight: CGFloat { horizontalSizeClass == .regular ? 60 : 250 }
    private var bannerSize: AdBannerSize {
        horizontalSizeClass == .regular ? AdBannerSizes.fullBanner : AdBannerSizes.mediumRectangle
    }

    var body: some View {
        if adsStore.hasRemovedAds {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Sponsored", systemImage: "megaphone")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await adsStore.purchaseRemoveAds() }
                    } label: {
                        HStack(spacing: 6) {
                            if adsStore.purchaseInFlight {
                                ProgressView().scaleEffect(0.85)
                            }
                            Text(adsStore.purchaseInFlight ? "Processing…" : "Remove Ads \(adsStore.displayPrice)")
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .disabled(adsStore.purchaseInFlight)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.pillTint.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(theme.separator.opacity(0.6), lineWidth: 1)
                        )
                        .frame(height: bannerHeight)

                    Text("Ad space")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    AdMobBannerView(adUnitID: AdsConfig.bannerAdUnitID, adSize: bannerSize)
                        .frame(height: bannerHeight)
                        .frame(maxWidth: .infinity)
                }
            }
            .themedCard()
            .task {
                await adsStore.load()
            }
        }
    }
}
