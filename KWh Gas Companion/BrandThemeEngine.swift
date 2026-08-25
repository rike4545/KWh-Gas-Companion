// BrandThemeEngine.swift
// My EV Companion
// Auto-switches UI theme based on active vehicle make.
// Tessie-style (dark glass, red) for Tesla · Rivian-style (earthy green) for Rivian · neutral for others.

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Brand

public enum VehicleBrand: String, Equatable, Sendable {
    case tesla
    case rivian
    case other
}

// MARK: - Brand detection (reuses VehicleProfile from your codebase)

public extension VehicleProfile {
    var detectedBrand: VehicleBrand {
        let make = self.make.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let v    = self.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if make.contains("tesla") || v.hasPrefix("5YJ") || v.hasPrefix("7SA") || v.hasPrefix("LRW") {
            return .tesla
        }
        if make.contains("rivian") || v.hasPrefix("7FC") || v.hasPrefix("7PD") {
            return .rivian
        }
        return .other
    }
}

// MARK: - Tokens (Brand-specific)

public struct BrandTokens: Sendable {
    // Core palette
    public let accent: Color
    public let accentSecondary: Color
    public let accentGlow: Color          // For halos / ring effects

    // Surfaces
    public let screenBG: Color
    public let cardBG: Color
    public let cardBGElevated: Color
    public let glassOverlay: Color       // Semi-transparent card fill

    // Text
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color

    // Borders
    public let border: Color
    public let divider: Color

    // Status
    public let success: Color
    public let warning: Color
    public let danger: Color

    // Geometry
    public let cornerCard: CGFloat
    public let cornerPill: CGFloat
    public let spacingUnit: CGFloat

    // Shadow
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowY: CGFloat
}

// MARK: - Tesla brand tokens (Tessie aesthetic)
// Deep black/charcoal glass, Tesla Red accent, cool neutrals.

private extension BrandTokens {
    static func classic(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#FF4D5A"),
            accentSecondary:  Color(hex: "#FF7B85"),
            accentGlow:       Color(hex: "#FF4D5A").opacity(dark ? 0.28 : 0.20),
            screenBG:         dark ? Color(hex: "#101114") : Color(hex: "#F8F3F3"),
            cardBG:           dark ? Color(hex: "#181A20") : Color(hex: "#FFFFFF"),
            cardBGElevated:   dark ? Color(hex: "#202330") : Color(hex: "#FFF7F7"),
            glassOverlay:     dark ? Color.white.opacity(0.05) : Color.white.opacity(0.82),
            textPrimary:      dark ? Color(hex: "#F2F2F3") : Color(hex: "#19191C"),
            textSecondary:    dark ? Color(hex: "#8F96A6") : Color(hex: "#70737B"),
            textTertiary:     dark ? Color(hex: "#596070") : Color(hex: "#B3B6BE"),
            border:           dark ? Color.white.opacity(0.09) : Color.black.opacity(0.07),
            divider:          dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06),
            success:          Color(hex: "#34C759"),
            warning:          Color(hex: "#FFD60A"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       16,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.42 : 0.08),
            shadowRadius:     dark ? 16 : 8,
            shadowY:          dark ? 6 : 3
        )
    }

    static func modern(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#C9A84F"),
            accentSecondary:  Color(hex: "#E1C677"),
            accentGlow:       Color(hex: "#C9A84F").opacity(dark ? 0.28 : 0.20),
            screenBG:         dark ? Color(hex: "#0D0F12") : Color(hex: "#F4F4F2"),
            cardBG:           dark ? Color(hex: "#1B1E22") : Color(hex: "#FFFFFF"),
            cardBGElevated:   dark ? Color(hex: "#23272D") : Color(hex: "#F0F1F3"),
            glassOverlay:     dark ? Color.white.opacity(0.045) : Color.white.opacity(0.8),
            textPrimary:      dark ? Color(hex: "#F0F0EE") : Color(hex: "#1D1F22"),
            textSecondary:    dark ? Color(hex: "#A3A6AD") : Color(hex: "#6D7076"),
            textTertiary:     dark ? Color(hex: "#5B616D") : Color(hex: "#B4B7BD"),
            border:           dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08),
            divider:          dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06),
            success:          Color(hex: "#34C759"),
            warning:          Color(hex: "#D6AF4D"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       16,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.5 : 0.08),
            shadowRadius:     dark ? 18 : 8,
            shadowY:          dark ? 7 : 3
        )
    }

    static func orange(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#F07A45"),
            accentSecondary:  Color(hex: "#FFA676"),
            accentGlow:       Color(hex: "#F07A45").opacity(dark ? 0.25 : 0.20),
            screenBG:         dark ? Color(hex: "#12100F") : Color(hex: "#F3F4F6"),
            cardBG:           dark ? Color(hex: "#1D1A18") : Color(hex: "#FFFFFF"),
            cardBGElevated:   dark ? Color(hex: "#292421") : Color(hex: "#F7F8FA"),
            glassOverlay:     dark ? Color.white.opacity(0.05) : Color.white.opacity(0.82),
            textPrimary:      dark ? Color(hex: "#F3F1EF") : Color(hex: "#1D1D20"),
            textSecondary:    dark ? Color(hex: "#B0A79F") : Color(hex: "#767A84"),
            textTertiary:     dark ? Color(hex: "#6A635D") : Color(hex: "#B8BBC4"),
            border:           dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08),
            divider:          dark ? Color.white.opacity(0.07) : Color(hex: "#E8E9ED"),
            success:          Color(hex: "#34C759"),
            warning:          Color(hex: "#F5B400"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       16,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.45 : 0.08),
            shadowRadius:     dark ? 16 : 8,
            shadowY:          dark ? 6 : 3
        )
    }

    static func tessie(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#62B9FF"),
            accentSecondary:  Color(hex: "#4BA6FF"),
            accentGlow:       Color(hex: "#62B9FF").opacity(0.24),
            screenBG:         dark ? Color(hex: "#090F1E") : Color(hex: "#EEF4FF"),
            cardBG:           dark ? Color(hex: "#111B31") : Color(hex: "#F7FAFF"),
            cardBGElevated:   dark ? Color(hex: "#15223D") : Color(hex: "#EEF4FF"),
            glassOverlay:     dark ? Color.white.opacity(0.05) : Color.white.opacity(0.82),
            textPrimary:      dark ? Color(hex: "#EEF4FF") : Color(hex: "#16253D"),
            textSecondary:    dark ? Color(hex: "#9AA8C0") : Color(hex: "#647894"),
            textTertiary:     dark ? Color(hex: "#5D6F8C") : Color(hex: "#A3B3C8"),
            border:           dark ? Color.white.opacity(0.09) : Color.black.opacity(0.07),
            divider:          dark ? Color(hex: "#1B2742") : Color.black.opacity(0.06),
            success:          Color(hex: "#30D158"),
            warning:          Color(hex: "#FFD60A"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       16,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.48 : 0.08),
            shadowRadius:     dark ? 18 : 8,
            shadowY:          dark ? 7 : 3
        )
    }

    static func tesla(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#3E6AE1"),
            accentSecondary:  Color(hex: "#5F7FE8"),
            accentGlow:       Color(hex: "#3E6AE1").opacity(dark ? 0.18 : 0.12),
            screenBG:         dark ? Color(hex: "#000000") : Color(hex: "#F4F4F4"),
            cardBG:           dark ? Color(hex: "#171717") : Color(hex: "#FFFFFF"),
            cardBGElevated:   dark ? Color(hex: "#202020") : Color(hex: "#ECECEC"),
            glassOverlay:     dark ? Color.white.opacity(0.035) : Color.white.opacity(0.88),
            textPrimary:      dark ? Color(hex: "#F6F6F6") : Color(hex: "#171A20"),
            textSecondary:    dark ? Color(hex: "#A2A3A5") : Color(hex: "#5C5E62"),
            textTertiary:     dark ? Color(hex: "#6B6D70") : Color(hex: "#8E9095"),
            border:           dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
            divider:          dark ? Color(hex: "#2A2A2A") : Color(hex: "#DDDFE4"),
            success:          Color(hex: "#30D158"),
            warning:          Color(hex: "#FFD60A"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       14,
            cornerPill:       100,
            spacingUnit:      14,
            shadowColor:      Color.black.opacity(dark ? 0.28 : 0.06),
            shadowRadius:     dark ? 8 : 6,
            shadowY:          dark ? 3 : 2
        )
    }
}

// MARK: - Rivian brand tokens
// Clean light surfaces with dark typography and Rivian-style yellow actions.

private extension BrandTokens {
    static func rivian(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#F5B400"),
            accentSecondary:  Color(hex: "#FFD24D"),
            accentGlow:       Color(hex: "#F5B400").opacity(dark ? 0.26 : 0.22),
            screenBG:         dark ? Color(hex: "#121317") : Color(hex: "#ECEDEF"),
            cardBG:           dark ? Color(hex: "#1A1D23") : Color(hex: "#F8F8F9"),
            cardBGElevated:   dark ? Color(hex: "#22262E") : Color(hex: "#FFFFFF"),
            glassOverlay:     dark ? Color.white.opacity(0.045) : Color.white.opacity(0.86),
            textPrimary:      dark ? Color(hex: "#F4F5F7") : Color(hex: "#21252B"),
            textSecondary:    dark ? Color(hex: "#A7ACB4") : Color(hex: "#666C75"),
            textTertiary:     dark ? Color(hex: "#7A808A") : Color(hex: "#9EA4AE"),
            border:           dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08),
            divider:          dark ? Color(hex: "#2F343D") : Color(hex: "#DEE1E7"),
            success:          Color(hex: "#7AD95D"),
            warning:          Color(hex: "#F5B400"),
            danger:           Color(hex: "#E35B52"),
            cornerCard:       18,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.48 : 0.08),
            shadowRadius:     dark ? 16 : 8,
            shadowY:          dark ? 6 : 3
        )
    }
}

// MARK: - Neutral brand tokens (other makes)

private extension BrandTokens {
    static func neutral(scheme: ColorScheme) -> BrandTokens {
        let dark = scheme == .dark
        return BrandTokens(
            accent:           Color(hex: "#0A84FF"),
            accentSecondary:  Color(hex: "#40A8FF"),
            accentGlow:       Color(hex: "#0A84FF").opacity(0.22),
            screenBG:         dark ? Color(hex: "#0C0C0F") : Color(hex: "#F2F2F7"),
            cardBG:           dark ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF"),
            cardBGElevated:   dark ? Color(hex: "#252528") : Color(hex: "#F5F5F9"),
            glassOverlay:     dark ? Color.white.opacity(0.055) : Color.white.opacity(0.78),
            textPrimary:      dark ? Color(hex: "#F2F2F2") : Color(hex: "#0D0D0D"),
            textSecondary:    dark ? Color(hex: "#8E8E93") : Color(hex: "#6C6C70"),
            textTertiary:     dark ? Color(hex: "#48484A") : Color(hex: "#AEAEB2"),
            border:           dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
            divider:          dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05),
            success:          Color(hex: "#30D158"),
            warning:          Color(hex: "#FFD60A"),
            danger:           Color(hex: "#FF453A"),
            cornerCard:       16,
            cornerPill:       100,
            spacingUnit:      16,
            shadowColor:      Color.black.opacity(dark ? 0.5 : 0.09),
            shadowRadius:     dark ? 20 : 10,
            shadowY:          dark ? 7 : 4
        )
    }
}

// MARK: - BrandTheme (resolved tokens)

public struct BrandTheme: Equatable, Sendable {
    public let brand: VehicleBrand
    public let style: ThemeStyle
    public let isDark: Bool
    public let tokens: BrandTokens

    public static func == (lhs: BrandTheme, rhs: BrandTheme) -> Bool {
        lhs.brand == rhs.brand
            && lhs.style == rhs.style
            && lhs.isDark == rhs.isDark
    }

    public static func resolve(brand: VehicleBrand, scheme: ColorScheme) -> BrandTheme {
        let tokens: BrandTokens
        let style: ThemeStyle
        switch brand {
        case .tesla:
            tokens = .tesla(scheme: scheme)
            style = .tesla
        case .rivian:
            tokens = .rivian(scheme: scheme)
            style = .rivian
        case .other:
            tokens = .neutral(scheme: scheme)
            style = .classic
        }
        return BrandTheme(brand: brand, style: style, isDark: scheme == .dark, tokens: tokens)
    }

    public static func resolve(
        style: ThemeStyle,
        detectedBrand: VehicleBrand,
        scheme: ColorScheme
    ) -> BrandTheme {
        if style == .classic, detectedBrand != .other {
            return resolve(brand: detectedBrand, scheme: scheme)
        }

        let brand: VehicleBrand
        let tokens: BrandTokens

        switch style {
        case .tesla:
            brand = .tesla
            tokens = .tesla(scheme: scheme)
        case .rivian:
            brand = .rivian
            tokens = .rivian(scheme: scheme)
        case .tessie:
            brand = .other
            tokens = .tessie(scheme: scheme)
        case .modern:
            brand = .other
            tokens = .modern(scheme: scheme)
        case .orange:
            brand = .other
            tokens = .orange(scheme: scheme)
        case .classic:
            brand = .other
            tokens = .classic(scheme: scheme)
        }

        return BrandTheme(brand: brand, style: style, isDark: scheme == .dark, tokens: tokens)
    }
}

// MARK: - BrandThemeManager (ObservableObject, drives the whole app)

@MainActor
public final class BrandThemeManager: ObservableObject {
    public static let shared = BrandThemeManager()

    private static func initialScheme() -> ColorScheme {
        #if canImport(UIKit)
        return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        #else
        return .light
        #endif
    }

    private static func initialStyle(defaults: UserDefaults = .standard) -> ThemeStyle {
        let presetRaw = defaults.string(forKey: "themePreset") ?? ThemeStyle.appDefault.rawValue
        let legacyRaw = defaults.string(forKey: "uiStyle") ?? ThemeStyle.classic.rawValue
        return ThemeStyle.resolve(themePresetRaw: presetRaw, legacyUIStyleRaw: legacyRaw)
    }

    @Published public private(set) var theme: BrandTheme = .resolve(
        style: BrandThemeManager.initialStyle(),
        detectedBrand: .other,
        scheme: BrandThemeManager.initialScheme()
    )
    @Published public private(set) var brand: VehicleBrand = .other

    private var scheme: ColorScheme = BrandThemeManager.initialScheme()

    public func update(vehicle: VehicleProfile?, scheme: ColorScheme, style: ThemeStyle) {
        self.scheme = scheme
        let detectedBrand = vehicle?.detectedBrand ?? .other
        let newTheme = BrandTheme.resolve(style: style, detectedBrand: detectedBrand, scheme: scheme)
        let newBrand = newTheme.brand
        if newTheme != theme || newBrand != brand {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.brand  = newBrand
                self.theme  = newTheme
            }
        }
    }
}

// MARK: - Environment key

private struct BrandThemeKey: EnvironmentKey {
    static let defaultValue: BrandTheme = .resolve(style: .classic, detectedBrand: .other, scheme: .light)
}

public extension EnvironmentValues {
    var brandTheme: BrandTheme {
        get { self[BrandThemeKey.self] }
        set { self[BrandThemeKey.self] = newValue }
    }
}

// Convenience shorthand on View
public extension View {
    func brandThemeEnvironment(_ theme: BrandTheme) -> some View {
        environment(\.brandTheme, theme)
    }
}

// MARK: - BrandThemeModifier (attach to root)
// Usage: .modifier(BrandThemeModifier(profileStore: profileStore))

public struct BrandThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var profileStore: ProfileStore
    @AppStorage("themePreset") private var themePresetRaw: String = ThemeStyle.appDefault.rawValue
    @AppStorage("uiStyle") private var legacyUIStyleRaw: String = "classic"
    @StateObject private var manager = BrandThemeManager.shared

    private var style: ThemeStyle {
        ThemeStyle.resolve(themePresetRaw: themePresetRaw, legacyUIStyleRaw: legacyUIStyleRaw)
    }

    private var selectedVehicle: VehicleProfile? {
        profileStore.selectedVehicle
    }

    public func body(content: Content) -> some View {
        content
            .environmentObject(manager)
            .environment(\.brandTheme, manager.theme)
            .onChange(of: scheme) { _, newScheme in
                manager.update(vehicle: selectedVehicle, scheme: newScheme, style: style)
            }
            .onChange(of: themePresetRaw) { _, _ in
                manager.update(vehicle: selectedVehicle, scheme: scheme, style: style)
            }
            .onChange(of: legacyUIStyleRaw) { _, _ in
                manager.update(vehicle: selectedVehicle, scheme: scheme, style: style)
            }
            .onChange(of: profileStore.selectedVehicleID) { _, _ in
                manager.update(vehicle: selectedVehicle, scheme: scheme, style: style)
            }
            .onChange(of: profileStore.vehicles) { _, _ in
                manager.update(vehicle: selectedVehicle, scheme: scheme, style: style)
            }
            .onAppear {
                manager.update(vehicle: selectedVehicle, scheme: scheme, style: style)
            }
    }
}

// MARK: - Color(hex:) helper
// Removed — your project already defines Color(hex:) elsewhere.
// If you see "use of unresolved identifier 'init(hex:)'", add ONE definition
// anywhere in your project (e.g. a new file ColorHex.swift):
//
//   public extension Color {
//       init(hex: String) {
//           let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
//           var val: UInt64 = 0
//           Scanner(string: h).scanHexInt64(&val)
//           let len = h.count
//           let r = Double((val >> (len == 8 ? 24 : 16)) & 0xFF) / 255
//           let g = Double((val >> (len == 8 ? 16 :  8)) & 0xFF) / 255
//           let b = Double((val >> (len == 8 ?  8 :  0)) & 0xFF) / 255
//           let a = len == 8 ? Double(val & 0xFF) / 255 : 1.0
//           self.init(red: r, green: g, blue: b, opacity: a)
//       }
//   }
