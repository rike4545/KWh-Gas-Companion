// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  ThemeBackground.swift
//  KWh Gas Companion
//
//  Root theme background surface.
//  Swift 6 / iOS 17+
//

import SwiftUI

public struct ThemeBackground: View {
    @Environment(\.appThemeBox) private var box
    @Environment(\.colorScheme) private var scheme
    public init() {}

    public var body: some View {
        let theme = box.base

        ZStack {
            Rectangle()
                .fill(theme.screenBackground)

            LinearGradient(
                colors: [
                    theme.accent.opacity(scheme == .dark ? 0.08 : 0.05),
                    Color.white.opacity(scheme == .dark ? 0.02 : 0.12),
                    .clear,
                    theme.pillTint.opacity(scheme == .dark ? 0.10 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(scheme == .dark ? .screen : .softLight)
        }
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(scheme == .dark ? 0.10 : 0.025),
                            .clear,
                            Color.black.opacity(scheme == .dark ? 0.16 : 0.055)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
                .opacity(scheme == .dark ? 1 : 0.55)
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
