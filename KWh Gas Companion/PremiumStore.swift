//
//  PremiumStore.swift
//  KWh Gas Companion
//
//  TeslaMate Pro subscription entitlement store (StoreKit 2).
//  Product: $7.99/month, no trial.
//

import Foundation
import StoreKit

@MainActor
final class TeslaMateProStore: ObservableObject {
    static let shared = TeslaMateProStore()

    @Published private(set) var isProActive: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseInFlight: Bool = false
    @Published private(set) var lastError: String?

    private static let entitlementKey = "teslamate_pro_active"
    private let productID = "com.my_ev_companion.premium.monthly"

    private var updatesTask: Task<Void, Never>?

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

        isProActive = UserDefaults.standard.bool(forKey: Self.entitlementKey)

        do {
            let products = try await Product.products(for: [productID])
            product = products.first
            if product == nil {
                lastError = "Pro product not found. Check App Store Connect product ID."
            }
            listenForUpdatesIfNeeded()
            await refreshEntitlements()
        } catch {
            lastError = "StoreKit load error: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == productID, tx.revocationDate == nil {
                unlocked = true
                break
            }
        }
        isProActive = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.entitlementKey)
    }

    func purchasePro() async {
        lastError = nil
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            if product == nil {
                let products = try await Product.products(for: [productID])
                product = products.first
            }
            guard let product else {
                lastError = "Pro product not found. Check App Store Connect product ID."
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    var displayPrice: String {
        product?.displayPrice ?? "$7.99"
    }

    private func listenForUpdatesIfNeeded() {
        if updatesTask != nil { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                if tx.productID == self.productID {
                    await self.refreshEntitlements()
                    await tx.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw NSError(domain: "IAP", code: 1)
        }
    }
}

// Back-compat: PremiumStore previously managed Ads Removal.
// Keep the name as an alias so older references remain valid.
typealias PremiumStore = AdsEntitlementStore
