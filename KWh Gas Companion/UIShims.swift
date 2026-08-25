//
//  AppCard.swift
//  KWh Gas Companion
//
//

// UIShims.swift
// Minimal shared UI bits used across screens.
// iOS 17+ / Swift 6

import SwiftUI

// MARK: - AppCard

public struct AppCard<Content: View>: View {
    @Environment(\.appThemeBox) private var theme
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .padding(12)
            .background(theme.base.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: theme.base.corner, style: .continuous)
                    .stroke(theme.base.separator, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.base.corner, style: .continuous))
    }
}

// MARK: - AppSectionHeader

public struct AppSectionHeader: View {
    @Environment(\.appThemeBox) private var theme
    public let title: String
    public var subtitle: String? = nil
    public var systemImage: String? = nil

    public init(_ title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let s = systemImage { Image(systemName: s).foregroundStyle(theme.base.accent) }
            Text(title)
                .font(.headline.weight(.semibold))
            if let sub = subtitle {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - TagPill

public struct TagPill: View {
    @Environment(\.appThemeBox) private var theme
    public let text: String
    public init(text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.base.pillTint)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.base.separator, lineWidth: 0.7))
    }
}

// MARK: - Button Styles

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.appThemeBox) private var theme
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(theme.base.accent.opacity(configuration.isPressed ? 0.85 : 1.0))
            .foregroundStyle(theme.base.onAccent)
            .clipShape(RoundedRectangle(cornerRadius: theme.base.corner, style: .continuous))
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.appThemeBox) private var theme
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(theme.base.cardBackground)
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: theme.base.corner, style: .continuous)
                    .stroke(theme.base.separator, lineWidth: 0.9)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: theme.base.corner, style: .continuous))
    }
}

// MARK: - Screen Background (theme-driven)

public extension View {
    /// Applies the themed screen background and hides list backgrounds by default.
    func appScreenBackground() -> some View { modifier(_AppScreenBackground()) }
}

private struct _AppScreenBackground: ViewModifier {
    @Environment(\.appThemeBox) private var theme
    func body(content: Content) -> some View {
        content
            .background(theme.base.screenBackground, ignoresSafeAreaEdges: .all)
            .scrollContentBackground(.hidden)
    }
}
