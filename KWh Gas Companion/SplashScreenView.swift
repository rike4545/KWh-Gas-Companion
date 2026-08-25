//  SplashScreenView.swift
//  My EV Companion
//
//  Time-of-day photo splash with pulsing aura & Robotaxi-style logo
//  Swift 6 / iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public struct SplashScreenView: View {
    public var onComplete: (() -> Void)?

    public let allowTapToSkip: Bool
    public let pulseDuration: Double
    public let pulseCount: Int
    public let outerPadding: CGFloat
    public let hapticOnSkip: Bool
    public let autoDismiss: Bool
    public let minimumVisibleTime: Double
    public let fadeOutDuration: Double
    public let hardTimeout: TimeInterval

    private var boundIsPresented: Binding<Bool>?

    // MARK: - Initializers
    public init(
        onComplete: (() -> Void)? = nil,
        allowTapToSkip: Bool = true,
        pulseDuration: Double = 0.8,
        pulseCount: Int = 3,
        outerPadding: CGFloat = 24,
        hapticOnSkip: Bool = true,
        autoDismiss: Bool = true,
        minimumVisibleTime: Double = 3.0,
        fadeOutDuration: Double = 0.35,
        hardTimeout: TimeInterval = 10.0
    ) {
        self.onComplete = onComplete
        self.allowTapToSkip = allowTapToSkip
        self.pulseDuration = pulseDuration
        self.pulseCount = pulseCount
        self.outerPadding = outerPadding
        self.hapticOnSkip = hapticOnSkip
        self.autoDismiss = autoDismiss
        self.minimumVisibleTime = minimumVisibleTime
        self.fadeOutDuration = fadeOutDuration
        self.hardTimeout = hardTimeout
        self.boundIsPresented = nil
    }

    public init(
        isPresented: Binding<Bool>,
        allowTapToSkip: Bool = true,
        pulseDuration: Double = 0.8,
        pulseCount: Int = 3,
        outerPadding: CGFloat = 24,
        hapticOnSkip: Bool = true,
        autoDismiss: Bool = true,
        minimumVisibleTime: Double = 3.0,
        fadeOutDuration: Double = 0.35,
        hardTimeout: TimeInterval = 10.0
    ) {
        self.onComplete = nil
        self.allowTapToSkip = allowTapToSkip
        self.pulseDuration = pulseDuration
        self.pulseCount = pulseCount
        self.outerPadding = outerPadding
        self.hapticOnSkip = hapticOnSkip
        self.autoDismiss = autoDismiss
        self.minimumVisibleTime = minimumVisibleTime
        self.fadeOutDuration = fadeOutDuration
        self.hardTimeout = hardTimeout
        self.boundIsPresented = isPresented
    }

    // MARK: - Assets
    private let morningAssetNames   = ["SplashDaySunriseA", "SplashDaySunriseB"]
    private let afternoonAssetNames = ["SplashDayCoastWater", "SplashDayCountryRoad2"]
    private let eveningAssetNames   = ["SplashDuskBeach"]
    private let nightAssetNames     = ["SplashDuskBeach"]

    private let lightBackgroundAssetNames: Set<String> = []

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - State
    @State private var pulsing = false
    @State private var finished = false
    @State private var isFadingOut = false

    @State private var selectedBackgroundName: String?
    @State private var hasBackgroundImage: Bool = false

    @State private var launchedAt: Date? = nil
    @State private var minGateOpen: Bool = false
    @State private var announcedReady: Bool = false

    @State private var gateTask: Task<Void, Never>?
    @State private var autoTask: Task<Void, Never>?
    @State private var hardTimeoutTask: Task<Void, Never>?

    #if DEBUG
    public var _debugSkipGate: Bool = false
    #endif

    private var accent: Color {
        switch currentDayPart() {
        case .night:     return Color(hue: 0.33, saturation: 0.75, brightness: 0.90)
        case .evening:   return Color(hue: 0.33, saturation: 0.70, brightness: 0.82)
        case .afternoon: return Color(hue: 0.33, saturation: 0.65, brightness: 0.62)
        case .morning:   return Color(hue: 0.33, saturation: 0.60, brightness: 0.58)
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shortest = max(1.0, min(size.width, size.height))
            let ring   = min(180, max(100, (shortest - (outerPadding * 2)) * 0.45))
            let disc   = ring * 0.80
            let symbol = max(28, ring * 0.33)

            let bgIsLight = lightBackgroundAssetNames.contains(selectedBackgroundName ?? "")
            let op = overlayOpacities(isBrightBG: bgIsLight)

            ZStack {
                if hasBackgroundImage, let name = selectedBackgroundName {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))
                } else {
                    LinearGradient(
                        colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                Rectangle()
                    .fill(LinearGradient(colors: [
                        .black.opacity(op.top),
                        .black.opacity(op.bottom)
                    ], startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea()

                VStack {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .strokeBorder(accent.opacity(scheme == .dark ? 0.30 : 0.28),
                                          lineWidth: ring * 0.044)
                            .frame(width: ring, height: ring)
                            .scaleEffect(pulsing ? 1.08 : 0.92)
                            .opacity(pulsing ? 0.95 : 0.65)

                        Circle()
                            .fill(accent.opacity(scheme == .dark ? 0.16 : 0.12))
                            .frame(width: disc, height: disc)
                            .scaleEffect(pulsing ? 1.02 : 1.0)

                        Image("MyEVCompanionLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: symbol * 2.8)
                            .shadow(color: accent.opacity(0.7), radius: 12)
                            .shadow(color: .black.opacity(0.6), radius: 6, y: 4)
                            .scaleEffect(pulsing ? 1.04 : 0.97)
                    }
                    Spacer(minLength: 0)
                }
                .padding(outerPadding)
            }
        }
        .opacity(isFadingOut ? 0 : 1)
        .animation(.easeInOut(duration: fadeOutDuration), value: isFadingOut)
        .contentShape(Rectangle())
        .allowsHitTesting(isTappable && !isFadingOut)
        .onTapGesture { if isTappable { complete(withHaptic: hapticOnSkip) } }
        .accessibilityAction(named: Text("Continue")) { if isTappable { complete(withHaptic: hapticOnSkip) } }
        .modifier(SensoryFeedbackOnFade(isFadingOut: isFadingOut))
        .onAppear { decideBackground(); start() }
        .onDisappear { cleanupAll(resetLaunch: true) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                cancelTasks()
                stopPulse()
            case .active:
                if !finished {
                    openGateIfNeeded()
                    scheduleAutoDismiss()
                    scheduleHardTimeoutIfNeeded()
                    if !reduceMotion { startPulse() }
                }
            @unknown default: break
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { stopPulse() } else if !finished { startPulse() }
        }
    }

    private var isTappable: Bool {
        (allowTapToSkip || !autoDismiss) && minGateOpen
    }

    // MARK: - Daypart
    private enum DayPart { case morning, afternoon, evening, night }

    private func currentDayPart(date: Date = Date()) -> DayPart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:   return .morning
        case 11..<17:  return .afternoon
        case 17..<20:  return .evening
        default:       return .night
        }
    }

    private func overlayOpacities(isBrightBG: Bool) -> (top: Double, bottom: Double) {
        let scale = reduceTransparency ? 0.65 : 1.0
        let base: (Double, Double)
        switch currentDayPart() {
        case .night:     base = (isBrightBG ? 0.62 : 0.55, isBrightBG ? 0.48 : 0.42)
        case .evening:   base = (isBrightBG ? 0.42 : 0.36, isBrightBG ? 0.30 : 0.24)
        case .afternoon: base = (isBrightBG ? 0.20 : 0.14, isBrightBG ? 0.14 : 0.10)
        case .morning:   base = (isBrightBG ? 0.22 : 0.16, isBrightBG ? 0.16 : 0.12)
        }
        return (base.0 * scale, base.1 * scale)
    }

    // MARK: - Background selection
    private func decideBackground(date: Date = Date()) {
        let part = currentDayPart(date: date)
        let pool: [String]
        switch part {
        case .morning:   pool = morningAssetNames
        case .afternoon: pool = afternoonAssetNames
        case .evening:   pool = eveningAssetNames
        case .night:     pool = nightAssetNames
        }

        #if canImport(UIKit)
        let available = pool.filter { UIImage(named: $0) != nil }
        #else
        let available = pool
        #endif

        let fallbackPool = morningAssetNames + afternoonAssetNames + eveningAssetNames + nightAssetNames
        let chosen = available.randomElement()
            ?? fallbackPool.first(where: {
                #if canImport(UIKit)
                UIImage(named: $0) != nil
                #else
                true
                #endif
            })

        selectedBackgroundName = chosen
        hasBackgroundImage = (chosen != nil)
    }

    // MARK: - Flow / Timing
    private func start() {
        guard !finished else { return }
        if launchedAt == nil { launchedAt = Date() }
        openGateIfNeeded()
        if !reduceMotion { startPulse() }
        scheduleAutoDismiss()
        scheduleHardTimeoutIfNeeded()
    }

    private func openGateIfNeeded() {
        gateTask?.cancel()
        #if DEBUG
        if _debugSkipGate {
            minGateOpen = true
            announceReadyIfNeeded()
            return
        }
        #endif

        let elapsed = launchedAt.map { Date().timeIntervalSince($0) } ?? 0
        if elapsed >= minimumVisibleTime {
            minGateOpen = true
            announceReadyIfNeeded()
            return
        }
        let remain = max(0, minimumVisibleTime - elapsed)
        gateTask = Task { [remain] in
            try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
            if !Task.isCancelled, !finished {
                minGateOpen = true
                announceReadyIfNeeded()
            }
        }
    }

    private func scheduleAutoDismiss() {
        autoTask?.cancel()
        guard autoDismiss, !finished else { return }

        let pulsesTotal = (pulseDuration * 2.0 * Double(pulseCount))
        let required = max(minimumVisibleTime, pulsesTotal)
        let elapsed = launchedAt.map { Date().timeIntervalSince($0) } ?? 0
        let remaining = max(0, required - elapsed) + 0.05

        autoTask = Task { [remaining] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            if !Task.isCancelled { complete() }
        }
    }

    private func scheduleHardTimeoutIfNeeded() {
        hardTimeoutTask?.cancel()
        guard hardTimeout > 0 else { return }
        let startRef = launchedAt ?? Date()
        hardTimeoutTask = Task {
            let remaining = max(0, hardTimeout - Date().timeIntervalSince(startRef))
            guard remaining > 0 else { if !finished { complete() }; return }
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            if !Task.isCancelled, !finished { complete() }
        }
    }

    private func startPulse() {
        pulsing = false
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }

    private func stopPulse() {
        withAnimation(.none) { pulsing = false }
    }

    private func complete(withHaptic: Bool = false) {
        guard !finished else { return }
        finished = true
        cancelTasks()

        if withHaptic {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }

        isFadingOut = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(fadeOutDuration * 1_000_000_000))
            if let bound = boundIsPresented {
                bound.wrappedValue = false
            }
            onComplete?()
        }
    }

    private func announceReadyIfNeeded() {
        #if canImport(UIKit)
        guard isTappable, !announcedReady else { return }
        UIAccessibility.post(notification: .announcement, argument: "Ready. Tap to continue.")
        announcedReady = true
        #endif
    }

    private func cancelTasks() {
        gateTask?.cancel(); gateTask = nil
        autoTask?.cancel(); autoTask = nil
        hardTimeoutTask?.cancel(); hardTimeoutTask = nil
    }

    private func cleanupAll(resetLaunch: Bool) {
        cancelTasks()
        if resetLaunch {
            launchedAt = nil
            minGateOpen = false
            announcedReady = false
        }
    }
}

// MARK: - Sensory feedback
private struct SensoryFeedbackOnFade: ViewModifier {
    let isFadingOut: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.sensoryFeedback(.impact, trigger: isFadingOut)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    SplashScreenView()
}
#endif
