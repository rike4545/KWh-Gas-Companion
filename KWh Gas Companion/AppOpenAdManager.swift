import Foundation

@MainActor
final class AppOpenAdManager {
    static let shared = AppOpenAdManager()

    private init() {}

    func handleAppForegrounded() async {}

    func loadAd() async {}
}
