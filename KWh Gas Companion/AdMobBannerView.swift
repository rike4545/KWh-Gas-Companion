import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds

public typealias AdBannerSize = AdSize
public enum AdBannerSizes {
    static let banner: AdBannerSize = AdSizeBanner
    static let mediumRectangle: AdBannerSize = AdSizeMediumRectangle
    static let fullBanner: AdBannerSize = AdSizeFullBanner
}

struct AdMobBannerView: View {
    let adUnitID: String
    let adSize: AdBannerSize
    @State private var loadState: BannerLoadState = .loading

    var body: some View {
        if isConfigured {
            ZStack {
                if loadState != .loaded {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.secondary.opacity(0.12))
                        .overlay {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.75)
                                Text(loadState == .failed ? "Ad unavailable" : "Loading ad…")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                BannerRepresentable(
                    adUnitID: adUnitID,
                    adSize: adSize,
                    loadState: $loadState
                )
                .opacity(loadState == .loaded ? 1 : 0.02)
            }
        } else {
            EmptyView()
        }
    }

    private var isConfigured: Bool {
        guard adUnitID.contains("ca-app-pub-") else { return false }
        let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        return (appId?.isEmpty == false) && GoogleMobileAdsConsentManager.shared.canRequestAds
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdBannerSize
    @Binding var loadState: BannerLoadState

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        context.coordinator.configure(
            banner,
            adUnitID: adUnitID,
            adSize: adSize,
            rootViewController: rootViewController()
        )
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        context.coordinator.configure(
            uiView,
            adUnitID: adUnitID,
            adSize: adSize,
            rootViewController: rootViewController()
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(loadState: $loadState)
    }

    private func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return scene.windows.first { $0.isKeyWindow }?.rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var loadState: BannerLoadState
        private var lastLoadedAdUnitID: String?
        private var lastLoadedSize: AdBannerSize?

        init(loadState: Binding<BannerLoadState>) {
            _loadState = loadState
        }

        func configure(
            _ banner: BannerView,
            adUnitID: String,
            adSize: AdBannerSize,
            rootViewController: UIViewController?
        ) {
            banner.delegate = self

            if banner.adUnitID != adUnitID {
                banner.adUnitID = adUnitID
            }

            if !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) {
                banner.adSize = adSize
            }

            banner.rootViewController = rootViewController

            let shouldLoad =
                rootViewController != nil &&
                (lastLoadedAdUnitID != adUnitID || lastLoadedSize.map { !isAdSizeEqualToSize(size1: $0, size2: adSize) } ?? true)

            guard shouldLoad else { return }

            loadState = .loading
            lastLoadedAdUnitID = adUnitID
            lastLoadedSize = adSize
            banner.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loadState = .loaded
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loadState = .failed
            lastLoadedAdUnitID = nil
            lastLoadedSize = nil
        }
    }
}

private enum BannerLoadState: Equatable {
    case loading
    case loaded
    case failed
}

#else

public typealias AdBannerSize = Any
public enum AdBannerSizes {
    static let banner: AdBannerSize = 0
    static let mediumRectangle: AdBannerSize = 0
    static let fullBanner: AdBannerSize = 0
}

struct AdMobBannerView: View {
    let adUnitID: String
    let adSize: AdBannerSize
    var body: some View { EmptyView() }
}

#endif

enum AdsConfig {
    static let bannerAdUnitID = "ca-app-pub-9917450718827221/8551932804"
}
