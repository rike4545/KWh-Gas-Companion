// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  SystemTheme.swift
//  My KWh Companion
//
//  Concrete themes for ThemeCoordinator.
//  Swift 6 • iOS 17+
//

import SwiftUI

private struct ThemeSurfacePalette {
    let darkCard: UIColor
    let lightCard: UIColor
    let darkSeparator: UIColor
    let lightSeparator: UIColor
    let darkStops: [Color]
    let lightStops: [Color]
    let pillDarkOpacity: Double
    let pillLightOpacity: Double
}

private extension ThemeSurfacePalette {
    func cardColor(for scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? darkCard : lightCard)
    }

    func separatorColor(for scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? darkSeparator : lightSeparator)
    }

    func screenStyle(for scheme: ColorScheme) -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: scheme == .dark ? darkStops : lightStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    func pillTint(accent: Color, scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? pillDarkOpacity : pillLightOpacity)
    }
}

public struct ClassicTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(hex: "#FF4D5A"), scheme: ColorScheme = .light) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 18 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 6 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            darkCard: UIColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 1.0),
            lightCard: UIColor(red: 0.992, green: 0.975, blue: 0.978, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.12),
            lightSeparator: UIColor(red: 0.90, green: 0.79, blue: 0.81, alpha: 0.78),
            darkStops: [
                Color(hex: "#0B0C10"),
                Color(hex: "#161920"),
                accent.opacity(0.18)
            ],
            lightStops: [
                Color(hex: "#FFF7F7"),
                Color(hex: "#FCEEEF"),
                accent.opacity(0.10)
            ],
            pillDarkOpacity: 0.26,
            pillLightOpacity: 0.15
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public struct ModernTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(hex: "#C9A84F"), scheme: ColorScheme = .dark) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 16 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 7 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .black }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            darkCard: UIColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1.0),
            lightCard: UIColor(red: 0.955, green: 0.958, blue: 0.965, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.10),
            lightSeparator: UIColor(white: 0.0, alpha: 0.10),
            darkStops: [
                Color(hex: "#0B0D0F"),
                Color(hex: "#171A1E"),
                Color(hex: "#23262D")
            ],
            lightStops: [
                Color(hex: "#F6F5F1"),
                Color(hex: "#EEECE5"),
                accent.opacity(0.10)
            ],
            pillDarkOpacity: 0.24,
            pillLightOpacity: 0.14
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public struct OrangeTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(hex: "#F07A45"), scheme: ColorScheme = .light) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 16 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 6 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            darkCard: UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1.0),
            lightCard: UIColor(red: 1.0, green: 0.995, blue: 0.992, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.12),
            lightSeparator: UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 0.90),
            darkStops: [
                Color(hex: "#15110F"),
                Color(hex: "#231B17"),
                accent.opacity(0.20)
            ],
            lightStops: [
                Color(hex: "#FFF7F2"),
                Color(hex: "#F7F1EB"),
                accent.opacity(0.10)
            ],
            pillDarkOpacity: 0.22,
            pillLightOpacity: 0.16
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public struct SystemTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = .accentColor, scheme: ColorScheme = .light) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 18 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 6 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    public var cardBackground: Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor.secondarySystemBackground.resolvedColor(with: traits)
            let overlay = UIColor(accentColor).resolvedColor(with: traits)
            return base.blended(with: overlay, alpha: traits.userInterfaceStyle == .dark ? 0.12 : 0.06)
        })
    }

    public var separator: Color {
        Color(uiColor: UIColor { traits in
            UIColor.separator
                .resolvedColor(with: traits)
                .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.42 : 0.28)
        })
    }

    public var pillTint: Color { accent.opacity(scheme == .dark ? 0.18 : 0.12) }

    public var screenBackground: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: scheme == .dark
                    ? [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground),
                        accent.opacity(0.12)
                    ]
                    : [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground),
                        accent.opacity(0.08)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

public struct TeslaTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(hex: "#3E6AE1"), scheme: ColorScheme = .dark) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 13 }
    public var corner: CGFloat { 14 }
    public var smallCorner: CGFloat { 10 }
    public var elevation: CGFloat { 4 }

    public var accent: Color { Color(hex: "#3E6AE1") }
    public var onAccent: Color { .white }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            // Cards sit a touch lighter than the flat-black canvas so they read
            // as distinct surfaces — matching the Tesla app's ~#1C1C1E cards.
            darkCard: UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0),
            lightCard: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.07),
            lightSeparator: UIColor(white: 0.0, alpha: 0.07),
            // Near-flat black background, like the Tesla app (no visible gradient).
            darkStops: [
                Color(hex: "#000000"),
                Color(hex: "#000000"),
                Color(hex: "#0A0A0A")
            ],
            lightStops: [
                Color(hex: "#F4F4F4"),
                Color(hex: "#EDEEEF"),
                Color(hex: "#F9F9F9")
            ],
            pillDarkOpacity: 0.16,
            pillLightOpacity: 0.10
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public struct RivianTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(hex: "#F5B400"), scheme: ColorScheme = .light) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 20 }
    public var smallCorner: CGFloat { 12 }
    public var elevation: CGFloat { 8 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .black }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            darkCard: UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0),
            lightCard: UIColor(red: 0.975, green: 0.976, blue: 0.98, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.10),
            lightSeparator: UIColor(white: 0.0, alpha: 0.10),
            darkStops: [
                Color(hex: "#0B0D10"),
                Color(hex: "#14171B"),
                Color(hex: "#21252B")
            ],
            lightStops: [
                Color(hex: "#F5F3EE"),
                Color(hex: "#EDE9DF"),
                accent.opacity(0.11)
            ],
            pillDarkOpacity: 0.22,
            pillLightOpacity: 0.14
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public struct TessieTheme: AppThemeSpec {
    public let accentColor: Color
    public let scheme: ColorScheme

    public init(accentColor: Color = Color(red: 0.20, green: 0.56, blue: 0.98), scheme: ColorScheme = .dark) {
        self.accentColor = accentColor
        self.scheme = scheme
    }

    public var spacing: CGFloat { 14 }
    public var corner: CGFloat { 16 }
    public var smallCorner: CGFloat { 10 }
    public var elevation: CGFloat { 6 }

    public var accent: Color { accentColor }
    public var onAccent: Color { .white }

    private var palette: ThemeSurfacePalette {
        ThemeSurfacePalette(
            darkCard: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0),
            lightCard: UIColor(red: 0.95, green: 0.975, blue: 1.0, alpha: 1.0),
            darkSeparator: UIColor(white: 1.0, alpha: 0.12),
            lightSeparator: UIColor(white: 0.0, alpha: 0.10),
            darkStops: [
                Color(hex: "#020611"),
                Color(hex: "#0A1322"),
                Color(hex: "#123050")
            ],
            lightStops: [
                Color(hex: "#EFF7FF"),
                Color(hex: "#DCEEFF"),
                accent.opacity(0.12)
            ],
            pillDarkOpacity: 0.22,
            pillLightOpacity: 0.16
        )
    }

    public var cardBackground: Color { palette.cardColor(for: scheme) }
    public var separator: Color { palette.separatorColor(for: scheme) }
    public var pillTint: Color { palette.pillTint(accent: accent, scheme: scheme) }
    public var screenBackground: AnyShapeStyle { palette.screenStyle(for: scheme) }
}

public typealias KWhClassicTheme = ClassicTheme
public typealias KWhTeslaGlassTheme = TeslaTheme
public typealias TeslaGlassTheme = TeslaTheme

private extension UIColor {
    func blended(with overlay: UIColor, alpha: CGFloat) -> UIColor {
        let alphaClamped = max(0, min(1, alpha))
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        overlay.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 + (r2 - r1) * alphaClamped
        let g = g1 + (g2 - g1) * alphaClamped
        let b = b1 + (b2 - b1) * alphaClamped
        let a = a1 + (a2 - a1) * alphaClamped

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
