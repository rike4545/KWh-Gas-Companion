//
//  ThemeCoordinator.swift
//  My KWh Companion
//
//  Small helper used by any legacy code that wants to build an AppThemeBox
//  without importing ThemeBinder.
//
//  Swift 6 • iOS 17+
//

import SwiftUI

public enum ThemeStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case classic
    case teslaGlass

    public var id: String { rawValue }

    public static func resolve(from raw: String) -> ThemeStyle {
        switch raw {
        case "teslaGlass", "glass":
            return .teslaGlass
        default:
            return .classic
        }
    }
}

@MainActor
public enum ThemeCoordinator {

    public static func makeThemeBox(
        uiStyleRaw: String,
        accentColor: Color,
        scheme: ColorScheme
    ) -> AppThemeBox {
        switch ThemeStyle.resolve(from: uiStyleRaw) {
        case .classic:
            return AppThemeBox(base: SystemTheme(accentColor: accentColor, scheme: scheme))
        case .teslaGlass:
            return AppThemeBox(base: TeslaGlassTheme(accentColor: accentColor, scheme: scheme))
        }
    }
}
