//  DockAppearance.swift
//  Unified Dock styling (Liquid Glass / Standard) + UIKit bridge
//
//  Usage:
//    TabView { ... }
//      .appDockStyle(.liquidGlass)   // or .standard
//      .applyDockAppearance()        // applies based on current theme + style
//

import SwiftUI

// MARK: - Public API

public enum DockStyle: Sendable, Equatable {
    case standard
    case liquidGlass
}

// Single environment key for the chosen dock style
private struct DockStyleKey: EnvironmentKey {
    static let defaultValue: DockStyle = .standard
}

public extension EnvironmentValues {
    var dockStyle: DockStyle {
        get { self[DockStyleKey.self] }
        set { self[DockStyleKey.self] = newValue }
    }
}

public extension View {
    /// Choose how the app dock (tab bar) should look.
    func appDockStyle(_ style: DockStyle) -> some View {
        environment(\.dockStyle, style)
    }

    /// Apply the current dock style + theme accent to UITabBar (UIKit bridge).
    func applyDockAppearance() -> some View {
        modifier(_DockAppearanceModifier())
    }
}

// MARK: - Implementation

private struct _DockAppearanceModifier: ViewModifier {
    @Environment(\.dockStyle) private var style
    @Environment(\.appThemeBox) private var themeBox

    func body(content: Content) -> some View {
        content
            .background(_ApplyDockAppearance(style: style,
                                             accent: _accentUIColor()))
            .onChange(of: style) { _reapply() }
            .onChange(of: themeBox.base.accent) { _reapply() }
    }

    private func _accentUIColor() -> UIColor {
        #if canImport(UIKit)
        // Prefer theme accent if available; else default to system tint.
        return UIColor(themeBox.base.accent)
        #else
        return .black
        #endif
    }

    private func _reapply() {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.windows.forEach { $0.setNeedsLayout(); $0.layoutIfNeeded() }
            }
        }
        #endif
    }
}

private struct _ApplyDockAppearance: UIViewRepresentable {
    let style: DockStyle
    let accent: UIColor

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        apply()
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        apply()
    }

    private func apply() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        switch style {
        case .standard:
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            appearance.shadowColor = UIColor.separator.withAlphaComponent(0.20)

        case .liquidGlass:
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
        }

        // Selected colors (icons + titles)
        appearance.stackedLayoutAppearance.selected.iconColor = accent
        appearance.inlineLayoutAppearance.selected.iconColor = accent
        appearance.compactInlineLayoutAppearance.selected.iconColor = accent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        // Optional: dim unselected items when using Liquid Glass
        if case .liquidGlass = style {
            let dim = UIColor.label.withAlphaComponent(0.65)
            appearance.stackedLayoutAppearance.normal.iconColor = dim
            appearance.inlineLayoutAppearance.normal.iconColor = dim
            appearance.compactInlineLayoutAppearance.normal.iconColor = dim
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dim]
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dim]
            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dim]
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = accent
        #endif
    }
}
