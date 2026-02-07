// LaunchGateRoot.swift
import SwiftUI

@MainActor
struct LaunchGateRoot: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var gate = LaunchGate(minDuration: 1.0, timeout: 4.0)

    var body: some View {
        Group {
            if gate.ready {
                MainTabView()
                    .environmentObject(entriesStore)
                    .environmentObject(profileStore)
            } else {
                // NOTE: matches the new SplashScreenView API
                SplashScreenView(
                    onComplete: { gate.forceReady() },
                    allowTapToSkip: false,
                    autoDismiss: false  // gate controls dismissal
                )
                .ignoresSafeArea()
                .task {
                    await gate.boot {
                        // Replace with real boot steps if you have them:
                        // await entriesStore.loadFromDisk()
                        // await profileStore.loadFromDisk()
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }
        }
    }
}

@MainActor
final class LaunchGate: ObservableObject {
    @AppStorage("app.hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @Published private(set) var ready = false

    private let minDuration: TimeInterval
    private let timeout: TimeInterval
    private var started = false
    private var bootFinished = false

    init(minDuration: TimeInterval = 0.9, timeout: TimeInterval = 4.0) {
        self.minDuration = max(0.1, minDuration)
        self.timeout = max(self.minDuration, timeout)
    }

    /// Run boot tasks, enforce a min splash time, and a hard timeout.
    func boot(_ work: @escaping () async -> Void) async {
        guard !started else { return }
        started = true
        let t0 = Date()

        Task {
            await work()
            await MainActor.run { self.bootFinished = true }
        }

        // Minimum visible time
        try? await Task.sleep(nanoseconds: UInt64(minDuration * 1_000_000_000))

        // Wait for work or timeout, whichever comes first
        if !bootFinished {
            let deadline = t0.addingTimeInterval(timeout)
            while !bootFinished && Date() < deadline {
                try? await Task.sleep(nanoseconds: 60_000_000) // ~60ms
            }
        }

        if !hasLaunchedBefore { hasLaunchedBefore = true }
        ready = true
    }

    func forceReady() { ready = true }
}
