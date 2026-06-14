// Copyright Bryan Carroll. Made with Love in New York. All rights reserved. 2026.

//
//  ThemeBinder.swift
//  KWh Gas Companion
//
//  Central theme binding.
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
private struct ThemeBinder: ViewModifier {

    @ObservedObject var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    @AppStorage("themePreset") private var themePresetRaw: String = ThemeStyle.appDefault.rawValue
    @AppStorage("uiStyle") private var legacyUIStyleRaw: String = "classic"

    private var style: ThemeStyle {
        ThemeStyle.resolve(themePresetRaw: themePresetRaw, legacyUIStyleRaw: legacyUIStyleRaw)
    }

    func body(content: Content) -> some View {
        let box = ThemeCoordinator.makeThemeBox(style: style, accentColor: appearance.accentColor, scheme: scheme)
        return content.environment(\.appThemeBox, box)
    }
}

public extension View {
    func bindAppTheme(using appearance: AppAppearance) -> some View {
        modifier(ThemeBinder(appearance: appearance))
    }
}
