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
        ZStack {
            Rectangle()
                .fill(box.base.screenBackground)
                .ignoresSafeArea()

            RadialGradient(
                colors: [box.base.accent.opacity(scheme == .dark ? 0.22 : 0.16), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .blur(radius: 30)
            .ignoresSafeArea()

            RadialGradient(
                colors: [box.base.accent.opacity(scheme == .dark ? 0.14 : 0.10), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 620
            )
            .blur(radius: 34)
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}
