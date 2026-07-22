// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

import SwiftUI

struct ThemedCardModifier: ViewModifier {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var uiSettings: AppUISettings

    let padding: CGFloat?
    let corner: CGFloat?
    let surface: AnyShapeStyle?
    let prominent: Bool

    func body(content: Content) -> some View {
        let theme = themeBox.base
        let pad = (padding ?? theme.spacing) * uiSettings.spacingMultiplier * uiSettings.cardPaddingMultiplier
        let radius = min((corner ?? theme.corner) * uiSettings.cardCornerMultiplier, 20)
        let surfaceStyle = surface ?? AnyShapeStyle(theme.cardBackground)
        let borderOpacity = (scheme == .dark ? 0.68 : 0.48) * uiSettings.borderOpacity
        let glowOpacity = prominent
            ? (scheme == .dark ? 0.14 : 0.07)
            : (scheme == .dark ? 0.05 : 0.025)

        return content
            .padding(pad)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(surfaceStyle)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(reduceTransparency ? 0.03 : (scheme == .dark ? 0.06 : 0.14)),
                                    .clear,
                                    theme.accent.opacity(glowOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(scheme == .dark ? 0.20 : 0.36),
                                    theme.separator.opacity(borderOpacity * 0.7),
                                    theme.accent.opacity(prominent ? 0.16 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(scheme == .dark ? 0.025 : 0.08),
                        lineWidth: 0.6
                    )
                    .padding(1)
            )
            .shadow(
                color: theme.accent.opacity(glowOpacity),
                radius: prominent ? theme.elevation * 0.8 : theme.elevation * 0.35,
                x: 0,
                y: prominent ? 6 : 3
            )
            .shadow(
                color: theme.separator.opacity(scheme == .dark ? 0.18 : 0.10),
                radius: prominent ? theme.elevation * 0.55 : theme.elevation * 0.3,
                x: 0,
                y: prominent ? 5 : 2
            )
    }
}

extension View {
    func themedCard(
        padding: CGFloat? = nil,
        corner: CGFloat? = nil,
        surface: AnyShapeStyle? = nil,
        prominent: Bool = false
    ) -> some View {
        modifier(ThemedCardModifier(padding: padding, corner: corner, surface: surface, prominent: prominent))
    }
}
