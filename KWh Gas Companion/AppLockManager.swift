//
//  AppLockManager.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  AppLockManager.swift
//  My KWh Companion
//
//  Simple FaceID/Passcode gate.
//  Swift 6 • iOS 17+
//

import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {

    @AppStorage("appLockEnabled") var isEnabled: Bool = false
    @Published var isUnlocked: Bool = true
    @Published var lastError: String?

    func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }

    func unlock() async {
        guard isEnabled else {
            isUnlocked = true
            return
        }

        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"

        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            lastError = "Authentication not available."
            isUnlocked = true
            return
        }

        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                localizedReason: "Unlock My EV Companion")
            isUnlocked = ok
            if !ok { lastError = "Not authorized." }
        } catch {
            lastError = error.localizedDescription
            isUnlocked = false
        }
    }
}

@MainActor
struct AppLockGate<Content: View>: View {
    @EnvironmentObject private var lock: AppLockManager
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content
                .blur(radius: (lock.isEnabled && !lock.isUnlocked) ? 18 : 0)
                .allowsHitTesting(!(lock.isEnabled && !lock.isUnlocked))

            if lock.isEnabled && !lock.isUnlocked {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill").font(.system(size: 40, weight: .semibold))
                    Text("Locked").font(.title2.weight(.semibold))
                    if let err = lock.lastError {
                        Text(err).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Text("Unlock")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if lock.isEnabled { lock.lock() }
        }
    }
}
