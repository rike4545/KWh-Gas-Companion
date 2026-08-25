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
        AdBannerOverlayCompactContent(adsStore: adsStore)
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
                    Label("Sponsored", systemImage: "megaphone.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    Spacer()
                    Text("Ad-supported")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.pillTint.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(theme.separator.opacity(0.6), lineWidth: 1)
                        )
                        .frame(height: bannerHeight)

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

@MainActor
private struct AdBannerOverlayCompactContent: View {
    @ObservedObject var adsStore: AdsEntitlementStore
    @Environment(\.appThemeBox) private var themeBox

    private var theme: any AppThemeSpec { themeBox.base }
    private let bannerHeight: CGFloat = 50

    var body: some View {
        if adsStore.hasRemovedAds {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("Sponsored")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Ad-supported")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }

                ZStack {
                    AdMobBannerView(adUnitID: AdsConfig.bannerAdUnitID, adSize: AdBannerSizes.banner)
                        .frame(height: bannerHeight)
                        .frame(maxWidth: .infinity)
                }
            }
            .task {
                await adsStore.load()
            }
        }
    }
}
