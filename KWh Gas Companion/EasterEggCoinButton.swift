//
//  EasterEggCoinButton.swift
//  My KWh Companion / KWh Gas Companion
//
//  Tap the coin to “flip” → randomly shows hingedpic or unhingedpic (Assets).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct EasterEggCoinButton: View {
    let hingedAssetName: String
    let unhingedAssetName: String
    let size: CGFloat

    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    @Environment(\.colorScheme) private var scheme
    @Environment(\.appThemeBox) private var themeBox

    @State private var spin: Double = 0
    @State private var pop: CGFloat = 1.0
    @State private var isPresenting = false
    @State private var selectedAsset: String

    init(
        hingedAssetName: String = "hingedpic",
        unhingedAssetName: String = "unhingedpic",
        size: CGFloat = 38
    ) {
        self.hingedAssetName = hingedAssetName
        self.unhingedAssetName = unhingedAssetName
        self.size = size
        _selectedAsset = State(initialValue: hingedAssetName)
    }

    var body: some View {
        let theme = themeBox.base

        Button { flip() } label: {
            ZStack {
                Circle()
                    .fill(theme.cardBackground)
                Circle()
                    .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.55 : 0.40), lineWidth: 1)

                // Accent haze
                Circle()
                    .fill(theme.accent.opacity(scheme == .dark ? 0.22 : 0.14))
                    .blur(radius: scheme == .dark ? 10 : 12)
                    .padding(2)

                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: size * 0.62, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 3)
            }
            .frame(width: size, height: size)
            .scaleEffect(pop)
            .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
            .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.14), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Easter egg coin")
        .accessibilityHint("Flips a coin and shows a random image.")
        .fullScreenCover(isPresented: $isPresenting) {
            EasterEggMemeViewer(
                assetName: selectedAsset,
                onFlipAgain: {
                    // Flip again from inside the viewer
                    isPresenting = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        flip()
                    }
                }
            )
        }
    }

    private func flip() {
        if hapticsEnabled {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }

        selectedAsset = Bool.random() ? hingedAssetName : unhingedAssetName

        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            spin += 720
            pop = 1.06
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85).delay(0.12)) {
            pop = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isPresenting = true
        }
    }
}

@MainActor
private struct EasterEggMemeViewer: View {
    let assetName: String
    let onFlipAgain: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = themeBox.base

        ZStack {
            // Slightly “premium” black with a theme glow
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.94),
                    theme.accent.opacity(scheme == .dark ? 0.12 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    Button {
                        onFlipAgain()
                    } label: {
                        Label("Flip again", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 8)

                MemeImage(assetName: assetName)
                    .padding(.horizontal, 14)
                    .shadow(color: .black.opacity(0.60), radius: 18, x: 0, y: 10)

                Spacer()

                Text("🐶 wow • much EV • very easter egg")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.footnote)
                    .padding(.bottom, 18)
            }
        }
    }
}

private struct MemeImage: View {
    let assetName: String

    var body: some View {
        #if canImport(UIKit)
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            missing
        }
        #else
        // Non-UIKit platforms / previews fallback
        Image(assetName)
            .resizable()
            .scaledToFit()
        #endif
    }

    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text("Missing asset: \(assetName)")
                .foregroundStyle(.white.opacity(0.85))
            Text("Add it to Assets.xcassets.")
                .foregroundStyle(.white.opacity(0.7))
                .font(.footnote)
        }
        .padding()
    }
}
