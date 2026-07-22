//
//  TeslaFiEntitlementStore.swift
//  KWh Gas Companion
//
//  TeslaFi CSV import is now available to everyone.
//

import Foundation

@MainActor
final class TeslaFiEntitlementStore: ObservableObject {
    static let shared = TeslaFiEntitlementStore()

    @Published private(set) var hasTeslaFiUnlock: Bool = true
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
        hasTeslaFiUnlock = true
    }

    func refreshEntitlements() async {
        hasTeslaFiUnlock = true
    }

    func purchaseUnlock() async {
        hasTeslaFiUnlock = true
    }

    func restore() async {
        hasTeslaFiUnlock = true
    }

    var displayPrice: String {
        "Free"
    }
}
