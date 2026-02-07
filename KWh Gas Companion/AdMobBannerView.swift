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

    var body: some View {
        if isConfigured {
            BannerRepresentable(adUnitID: adUnitID, adSize: adSize)
        } else {
            EmptyView()
        }
    }

    private var isConfigured: Bool {
        guard adUnitID.contains("ca-app-pub-") else { return false }
        let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        return (appId?.isEmpty == false)
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdBannerSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = rootViewController()
    }

    private func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return scene.windows.first { $0.isKeyWindow }?.rootViewController
    }
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
