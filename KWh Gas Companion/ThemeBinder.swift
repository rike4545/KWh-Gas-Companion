//
//  ThemeBinder.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/24/25.
//


//
//  ThemeBinder.swift
//  KWh Gas Companion
//
//  Central theme binding.
//  - Reads SettingsView's persisted UI style ("uiStyle")
//  - Uses an explicit AppAppearance instance (no EnvironmentObject dependency -> no runtime crash)
//  - Injects AppThemeBox into the environment
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
private struct ThemeBinder: ViewModifier {

    @ObservedObject var appearance: AppAppearance
    @Environment(\.colorScheme) private var scheme

    // SettingsView writes this key
    @AppStorage("uiStyle") private var uiStyleRaw: String = "teslaGlass"

    private enum Style { case classic, teslaGlass }

    private var style: Style {
        switch uiStyleRaw.lowercased() {
        case "teslaglass", "glass":
            return .teslaGlass
        default:
            return .classic
        }
    }

    func body(content: Content) -> some View {
        let accent = appearance.accentColor

        let theme: any AppThemeSpec = {
            switch style {
            case .classic:
                return SystemTheme(accentColor: accent, scheme: scheme)
            case .teslaGlass:
                return TeslaGlassTheme(accentColor: accent, scheme: scheme)
            }
        }()

        // NOTE: Intentionally NOT calling `.tint(...)` here to avoid symbol conflicts
        // in projects where a package-defined `tint` shadows SwiftUI’s `tint`.
        return content
            .environment(\.appThemeBox, AppThemeBox(base: theme))
    }
}

public extension View {
    /// Bind app theme using an explicit AppAppearance instance (safe; no missing EnvironmentObject crash).
    func bindAppTheme(using appearance: AppAppearance) -> some View {
        modifier(ThemeBinder(appearance: appearance))
    }
}
