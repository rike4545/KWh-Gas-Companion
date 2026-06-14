// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  ThemeCoordinator.swift
//  My KWh Companion
//
//  Centralized theme selection.
//  Swift 6 • iOS 17+
//

import SwiftUI

public enum ThemeStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case classic
    case tessie
    case tesla
    case rivian
    case modern
    case orange

    public var id: String { rawValue }

    /// The look used for fresh installs and whenever the user hasn't explicitly
    /// picked a theme. Changing this flips the app-wide default in one place.
    /// Users who chose a theme (themePreset.userSet == true) keep their choice.
    public static let appDefault: ThemeStyle = .tesla

    public var title: String {
        switch self {
        case .classic: return "Default"
        case .tessie:  return "Tessie"
        case .tesla:   return "Tesla"
        case .rivian:  return "Rivian"
        case .modern:  return "Modern"
        case .orange:  return "Orange"
        }
    }

    public static func resolve(themePresetRaw: String, legacyUIStyleRaw: String) -> ThemeStyle {
        if let preset = ThemeStyle(rawValue: themePresetRaw.lowercased()) {
            return preset
        }

        // Legacy compatibility: older builds wrote "uiStyle" values.
        let legacy = legacyUIStyleRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch legacy {
        case "rivian":
            return .rivian
        case "tesla", "teslaglass", "glass":
            return .tesla
        case "modern":
            return .modern
        case "orange":
            return .orange
        case "classic", "system", "default":
            return .classic
        default:
            return .classic
        }
    }
}

@MainActor
public enum ThemeCoordinator {

    public static func makeThemeBox(
        style: ThemeStyle,
        accentColor: Color,
        scheme: ColorScheme
    ) -> AppThemeBox {
        switch style {
        case .classic:
            return AppThemeBox(base: ClassicTheme(accentColor: accentColor, scheme: scheme))
        case .tessie:
            return AppThemeBox(base: TessieTheme(accentColor: accentColor, scheme: scheme))
        case .tesla:
            return AppThemeBox(base: TeslaTheme(accentColor: accentColor, scheme: scheme))
        case .rivian:
            return AppThemeBox(base: RivianTheme(accentColor: accentColor, scheme: scheme))
        case .modern:
            return AppThemeBox(base: ModernTheme(accentColor: accentColor, scheme: scheme))
        case .orange:
            return AppThemeBox(base: OrangeTheme(accentColor: accentColor, scheme: scheme))
        }
    }
}
