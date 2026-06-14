// BrandComponents.swift
// My EV Companion
// Reusable brand-aware UI primitives.
// All components read BrandTheme from the environment and render accordingly.

import SwiftUI

// MARK: - BrandCard

/// Replaces themedCard(). Reads BrandTheme from environment.
public struct BrandCard<Content: View>: View {
    @Environment(\.brandTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let prominent: Bool
    private let padding: CGFloat
    private let content: Content

    public init(prominent: Bool = false, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.prominent = prominent
        self.padding   = padding
        self.content   = content()
    }

    public var body: some View {
        let t = theme.tokens
        let radius = min(t.cornerCard, 20)
        content
            .padding(padding)
            .background(
                Group {
                    if prominent {
                        ZStack {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(t.accent.opacity(0.09))
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(reduceTransparency ? t.cardBG : t.glassOverlay)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(t.cardBG)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        prominent ? t.accent.opacity(0.22) : t.border,
                        lineWidth: 1
                    )
            )
            .shadow(color: t.shadowColor.opacity(0.72), radius: t.shadowRadius * 0.32, x: 0, y: t.shadowY * 0.35)
    }
}

// MARK: - TeslaControlButtonLabel (circular icon control, Tesla-app style)

/// The visual for a Tesla-style round control. Wrap it in a `Button` or
/// `NavigationLink` for behavior, e.g.:
///
///     NavigationLink { ChargingView() } label: {
///         TeslaControlButtonLabel(systemImage: "bolt.fill", title: "Charging")
///     }
///     .buttonStyle(.plain)
public struct TeslaControlButtonLabel: View {
    @Environment(\.brandTheme) private var theme
    private let systemImage: String
    private let title: String
    private let isActive: Bool
    private let diameter: CGFloat

    public init(systemImage: String, title: String, isActive: Bool = false, diameter: CGFloat = 60) {
        self.systemImage = systemImage
        self.title       = title
        self.isActive    = isActive
        self.diameter    = diameter
    }

    public var body: some View {
        let t = theme.tokens
        let fill: Color = isActive
            ? t.accent
            : (theme.isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.045))
        let symbolColor: Color = isActive ? .white : t.textPrimary

        return VStack(spacing: 8) {
            ZStack {
                Circle().fill(fill)
                Circle().strokeBorder(isActive ? Color.clear : t.border, lineWidth: 1)
                Image(systemName: systemImage)
                    .font(.system(size: diameter * 0.34, weight: .medium))
                    .foregroundStyle(symbolColor)
            }
            .frame(width: diameter, height: diameter)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(t.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - BrandStatTile

/// 2-column metric tile: icon + title + value, with optional delta.
public struct BrandStatTile: View {
    @Environment(\.brandTheme) private var theme

    let title: String
    let value: String
    let systemImage: String
    let delta: Double?         // positive = good, negative = bad, nil = no delta
    let deltaUnit: String      // e.g. "%" or " kWh"

    public init(title: String, value: String, systemImage: String, delta: Double? = nil, deltaUnit: String = "") {
        self.title     = title
        self.value     = value
        self.systemImage = systemImage
        self.delta     = delta
        self.deltaUnit = deltaUnit
    }

    public var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(t.accent)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(t.textSecondary)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(t.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let d = delta {
                deltaView(d)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: t.cornerCard - 2, style: .continuous)
                .fill(t.cardBGElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: t.cornerCard - 2, style: .continuous)
                .strokeBorder(t.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func deltaView(_ d: Double) -> some View {
        let t = theme.tokens
        let positive = d >= 0
        let color: Color = positive ? t.success : t.danger
        let arrow = positive ? "arrow.up.right" : "arrow.down.right"
        HStack(spacing: 3) {
            Image(systemName: arrow).font(.caption.weight(.bold))
            Text(String(format: "%.1f\(deltaUnit)", abs(d))).font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }
}

// MARK: - BrandStatGrid

/// 2-column grid of BrandStatTiles
public struct BrandStatGrid: View {
    private let tiles: [AnyView]

    public init(@BrandStatTileBuilder _ content: () -> [AnyView]) {
        self.tiles = content()
    }

    public var body: some View {
        LazyVGrid(
            columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(tiles.indices, id: \.self) { tiles[$0] }
        }
    }
}

@resultBuilder
public struct BrandStatTileBuilder {
    public static func buildBlock(_ components: AnyView...) -> [AnyView] { components }
}

// MARK: - BrandSectionHeader

public struct BrandSectionHeader: View {
    @Environment(\.brandTheme) private var theme
    let title: String
    let systemImage: String?
    let action: (() -> Void)?
    let actionLabel: String

    public init(_ title: String, systemImage: String? = nil, actionLabel: String = "See All", action: (() -> Void)? = nil) {
        self.title       = title
        self.systemImage = systemImage
        self.action      = action
        self.actionLabel = actionLabel
    }

    public var body: some View {
        let t = theme.tokens
        HStack(alignment: .center) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(t.accent)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(t.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            if let action {
                Button(actionLabel, action: action)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(t.accent)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - BrandDivider

public struct BrandDivider: View {
    @Environment(\.brandTheme) private var theme
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(theme.tokens.divider)
            .frame(height: 1)
    }
}

// MARK: - BrandBadge (pill label)

public struct BrandBadge: View {
    @Environment(\.brandTheme) private var theme
    let text: String
    let style: Style

    public enum Style { case accent, success, warning, danger, muted }

    public init(_ text: String, style: Style = .accent) {
        self.text  = text
        self.style = style
    }

    public var body: some View {
        let t = theme.tokens
        let color: Color = {
            switch style {
            case .accent:  return t.accent
            case .success: return t.success
            case .warning: return t.warning
            case .danger:  return t.danger
            case .muted:   return t.textTertiary
            }
        }()
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - BrandPrimaryButton

public struct BrandPrimaryButton: View {
    @Environment(\.brandTheme) private var theme
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title       = title
        self.systemImage = systemImage
        self.isLoading   = isLoading
        self.action      = action
    }

    public var body: some View {
        let t = theme.tokens
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else if let img = systemImage {
                    Image(systemName: img).font(.subheadline.weight(.semibold))
                }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: t.cornerPill, style: .continuous)
                        .fill(t.accent)
                    RoundedRectangle(cornerRadius: t.cornerPill, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
            )
            .shadow(color: t.accentGlow, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - BrandAccentGlow (decorative background gradient)
// Drop behind content for a subtle brand-colored glow effect.

public struct BrandAccentGlow: View {
    @Environment(\.brandTheme) private var theme
    let alignment: Alignment

    public init(alignment: Alignment = .topLeading) {
        self.alignment = alignment
    }

    public var body: some View {
        let t = theme.tokens
        GeometryReader { geo in
            RadialGradient(
                colors: [t.accentGlow, .clear],
                center: .init(x: alignment == .topLeading ? 0 : 1, y: 0),
                startRadius: 0,
                endRadius: geo.size.width * 0.85
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - BrandScreenBackground

public struct BrandScreenBackground: View {
    @Environment(\.brandTheme) private var theme
    public init() {}
    public var body: some View {
        theme.tokens.screenBG.ignoresSafeArea()
    }
}

// MARK: - BrandGlassCard (blurred glass card)

public struct BrandGlassCard<Content: View>: View {
    @Environment(\.brandTheme) private var theme
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let t = theme.tokens
        let radius = min(t.cornerCard, 20)
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(t.glassOverlay, lineWidth: 1)
            )
            .shadow(color: t.shadowColor.opacity(0.72), radius: t.shadowRadius * 0.35, x: 0, y: t.shadowY * 0.45)
    }
}

// MARK: - BrandRowSeparator (thinner, brand-aware row divider for Lists)

public struct BrandListRowModifier: ViewModifier {
    @Environment(\.brandTheme) private var theme
    public func body(content: Content) -> some View {
        content
            .listRowBackground(theme.tokens.cardBG)
            .listRowSeparatorTint(theme.tokens.divider)
    }
}

public extension View {
    func brandListRow() -> some View { modifier(BrandListRowModifier()) }
}

// MARK: - BrandNavigationTitle modifier
// Gives NavigationStack a brand-colored inline appearance

public struct BrandNavTitleModifier: ViewModifier {
    @Environment(\.brandTheme) private var theme
    let title: String
    let subtitle: String?

    public func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(theme.tokens.accent)
    }
}

public extension View {
    func brandNavTitle(_ title: String, subtitle: String? = nil) -> some View {
        modifier(BrandNavTitleModifier(title: title, subtitle: subtitle))
    }
}
