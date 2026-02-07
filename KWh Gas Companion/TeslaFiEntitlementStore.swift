//
//  TeslaFiEntitlementStore.swift
//  KWh Gas Companion
//
//  One-time unlock for TeslaFi CSV import ($0.99).
//

import Foundation
import StoreKit

@MainActor
final class TeslaFiEntitlementStore: ObservableObject {
    static let shared = TeslaFiEntitlementStore()

    @Published private(set) var hasTeslaFiUnlock: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseInFlight: Bool = false
    @Published private(set) var lastError: String?

    private static let unlockedKey = "teslafi_unlocked"
    private let productID = "com.my_ev_companion.teslafi.unlock"

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

        hasTeslaFiUnlock = UserDefaults.standard.bool(forKey: Self.unlockedKey)

        do {
            let products = try await Product.products(for: [productID])
            product = products.first
            if product == nil {
                lastError = "TeslaFi unlock product not found. Check App Store Connect product ID."
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
            if tx.productID == productID {
                unlocked = true
                break
            }
        }
        hasTeslaFiUnlock = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.unlockedKey)
    }

    func purchaseUnlock() async {
        lastError = nil
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            if product == nil {
                let products = try await Product.products(for: [productID])
                product = products.first
            }
            guard let product else {
                lastError = "TeslaFi unlock product not found. Check App Store Connect product ID."
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
        product?.displayPrice ?? "$0.99"
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
