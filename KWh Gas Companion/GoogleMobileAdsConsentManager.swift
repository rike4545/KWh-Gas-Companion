import Foundation

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

@MainActor
final class GoogleMobileAdsConsentManager {
    static let shared = GoogleMobileAdsConsentManager()

    private init() {}

    var canRequestAds: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.canRequestAds
        #else
        true
        #endif
    }

    var isPrivacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        false
        #endif
    }

    func gatherConsent() async {
        #if canImport(UserMessagingPlatform)
        let parameters = RequestParameters()

        do {
            try await requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            print("Consent gathering failed: \(error.localizedDescription)")
        }
        #endif
    }

    func presentPrivacyOptionsForm() async {
        #if canImport(UserMessagingPlatform)
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("Privacy options form failed to present: \(error.localizedDescription)")
        }
        #endif
    }

    #if canImport(UserMessagingPlatform)
    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    #endif
}
