//  SubscriptionManager.swift
//  My KWh Companion
//
//  StoreKit 2 subscription manager for the "Tesla API Sync" upgrade.
//  - Loads products
//  - Purchases & restores
//  - Listens to Transaction.updates without blocking load()
//  - Verifies receipts and updates `entitlementsActive`
//  - Provides a simple singleton for easy injection
//
//  iOS 16+
//
//  Usage:
//  @StateObject var iap = SubscriptionManager.shared
//  .environmentObject(iap)
//  if iap.entitlementsActive { /* show paid feature */ } else { /* PaywallView() */ }

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    // MARK: - Singleton
    static let shared = SubscriptionManager()

    // MARK: - Configuration
    // Replace with your real product id(s)
    private let productIDs: Set<String> = [
        "com.yourbundle.teslaapi.monthly"
    ]

    // MARK: - Published State
    @Published private(set) var products: [Product] = []
    @Published private(set) var entitlementsActive: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?

    // MARK: - Private
    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Public API

    /// Load products and start listening for subscription state changes.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch products once
            products = try await Product.products(for: Array(productIDs))

            // Start background listener (non-blocking)
            listenForTransactionUpdates()

            // Compute current entitlement state
            entitlementsActive = await isSubscribed()
        } catch {
            lastError = "StoreKit load error: \(error.localizedDescription)"
            #if DEBUG
            print("StoreKit load error:", error)
            #endif
        }
    }

    /// Purchase a specific product.
    func purchase(_ product: Product) async throws {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let _ = try check(verification) as Transaction
                // After a successful verified purchase, recompute entitlements.
                entitlementsActive = await isSubscribed()
            case .userCancelled, .pending:
                // No-op: UI can reflect pending or allow retry.
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }

    /// Restore previous purchases.
    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            entitlementsActive = await isSubscribed()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
            #if DEBUG
            print("Restore failed:", error)
            #endif
        }
    }

    /// Convenience: call to refresh entitlement state manually (e.g., on app foreground).
    func refreshEntitlements() async {
        entitlementsActive = await isSubscribed()
    }

    // MARK: - Transaction Listening (NEW)

    /// Non-blocking listener for transaction updates (renewals, refunds, revocations).
    private func listenForTransactionUpdates() {
        // Avoid starting multiple listeners
        if updatesTask != nil { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(transaction: result)
            }
        }
    }

    /// Handles a single transaction update, verifies it, and updates entitlement state.
    private func handle(transaction result: VerificationResult<Transaction>) async {
        do {
            let tx: Transaction = try check(result)
            // Consider only our product group; ignore others
            if productIDs.contains(tx.productID) {
                // Verified transaction, not revoked -> entitlement may be active
                entitlementsActive = await isSubscribed()
            }
            // Always finish verified transactions
            await tx.finish()
        } catch {
            // Unverified or other error
            #if DEBUG
            print("Transaction not verified / failed: \(error)")
            #endif
        }
    }

    // MARK: - Verification & Entitlement

    /// Verifies a StoreKit 2 `VerificationResult` and returns the signed value.
    private func check<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }

    /// Computes whether any active entitlement exists for our products.
    private func isSubscribed() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let tx) = entitlement,
               productIDs.contains(tx.productID),
               tx.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
