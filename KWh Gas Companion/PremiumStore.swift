//
//  PremiumStore.swift
//  KWh Gas Companion
//
//  Direct connection access is available to everyone.
//

import Foundation

@MainActor
final class DirectConnectionAccessStore: ObservableObject {
    static let shared = DirectConnectionAccessStore()

    @Published private(set) var isProActive: Bool = true
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseInFlight: Bool = false
    @Published private(set) var lastError: String?

    private init() {
        Task { [weak self] in
            await self?.load()
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        isProActive = true
    }

    func refreshEntitlements() async {
        isProActive = true
    }

    func purchasePro() async {
        isProActive = true
    }

    func restore() async {
        isProActive = true
    }

    var displayPrice: String {
        "Included"
    }
}

// Back-compat: PremiumStore previously managed Ads Removal.
// Keep the name as an alias so older references remain valid.
typealias PremiumStore = AdsEntitlementStore
