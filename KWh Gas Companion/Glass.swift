//
//  Glass.swift
//  KWh Gas Companion
//
//  Minimal glassmorphism helpers for SwiftUI (iOS 17+), with accessibility fallbacks.
//  - Respects Reduce Transparency (falls back to a soft solid surface)
//  - Tunable radius, stroke, shadow, padding
//  - Light/dark aware border gradient
//

import SwiftUI

// MARK: - Glass Modifier (safer type name)

public struct GlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public var radius: CGFloat = 16
    public var material: Material = .ultraThinMaterial
    public var materialOpacity: Double = 1.0
    public var strokeWidth: CGFloat = 1
    public var padding: CGFloat = 10
    public var addShadow: Bool = true

    /// Optional tint that subtly biases the glass toward your brand color.
    /// Keep nil for “neutral Apple-glass”.
    public var tint: Color? = nil
    public var tintOpacity: Double = 0.10

    public init(
        radius: CGFloat = 16,
        material: Material = .ultraThinMaterial,
        materialOpacity: Double = 1.0,
        strokeWidth: CGFloat = 1,
        padding: CGFloat = 10,
        addShadow: Bool = true,
        tint: Color? = nil,
        tintOpacity: Double = 0.10
    ) {
        self.radius = radius
        self.material = material
        self.materialOpacity = materialOpacity
        self.strokeWidth = strokeWidth
        self.padding = padding
        self.addShadow = addShadow
        self.tint = tint
        self.tintOpacity = tintOpacity
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content
            .padding(padding)
            .background(backgroundStyle, in: shape)
            .overlay(borderOverlay(in: shape))
            .shadow(
                color: Color.black.opacity(addShadow ? (colorScheme == .dark ? 0.28 : 0.12) : 0),
                radius: addShadow ? (colorScheme == .dark ? 18 : 16) : 0,
                x: 0,
                y: addShadow ? 8 : 0
            )
            .contentShape(shape)
    }

    private var backgroundStyle: AnyShapeStyle {
        if reduceTransparency {
            // Solid fallback with a “frosted” feel (but accessible)
            let fill = (colorScheme == .dark
                        ? Color.white.opacity(0.07)
                        : Color.white.opacity(0.72))
            return AnyShapeStyle(fill)
        } else {
            // Material base, with optional tint overlay baked into the style
            // (tint overlay is applied via .overlay below, not in ShapeStyle itself)
            return AnyShapeStyle(material.opacity(materialOpacity))
        }
    }

    private func borderOverlay(in shape: RoundedRectangle) -> some View {
        // Slightly stronger highlight in light mode, softer in dark
        let hi = colorScheme == .dark ? 0.34 : 0.48
        let lo = colorScheme == .dark ? 0.10 : 0.18

        return ZStack {
            // Optional tint haze to make it feel “brand glass”
            if let tint, !reduceTransparency {
                shape
                    .fill(tint.opacity(colorScheme == .dark ? tintOpacity : (tintOpacity * 0.75)))
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }

            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(hi),
                            .white.opacity(lo),
                            .white.opacity(hi)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: strokeWidth
                )
                .allowsHitTesting(false)
        }
    }
}

public extension View {
    /// Glassmorphism container with sensible defaults and accessibility fallback.
    func glass(
        radius: CGFloat = 16,
        material: Material = .ultraThinMaterial,
        opacity: Double = 1.0,
        strokeWidth: CGFloat = 1,
        padding: CGFloat = 10,
        addShadow: Bool = true,
        tint: Color? = nil,
        tintOpacity: Double = 0.10
    ) -> some View {
        modifier(
            GlassModifier(
                radius: radius,
                material: material,
                materialOpacity: opacity,
                strokeWidth: strokeWidth,
                padding: padding,
                addShadow: addShadow,
                tint: tint,
                tintOpacity: tintOpacity
            )
        )
    }
}

// MARK: - Glass Icon Button

public struct GlassCircleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public var padding: CGFloat = 10
    public var material: Material = .thinMaterial
    public var borderWidth: CGFloat = 0.75
    public var addShadow: Bool = true

    public init(
        padding: CGFloat = 10,
        material: Material = .thinMaterial,
        borderWidth: CGFloat = 0.75,
        addShadow: Bool = true
    ) {
        self.padding = padding
        self.material = material
        self.borderWidth = borderWidth
        self.addShadow = addShadow
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(padding)
            .background(circleBackground(isPressed: configuration.isPressed))
            .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))
            .shadow(
                color: Color.black.opacity(addShadow ? (configuration.isPressed ? 0.08 : (colorScheme == .dark ? 0.18 : 0.15)) : 0),
                radius: addShadow ? (configuration.isPressed ? 4 : 12) : 0,
                x: 0,
                y: addShadow ? (configuration.isPressed ? 2 : 8) : 0
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
            .contentShape(Circle())
    }

    private var borderColor: Color {
        .white.opacity(colorScheme == .dark ? 0.33 : 0.45)
    }

    @ViewBuilder
    private func circleBackground(isPressed: Bool) -> some View {
        if reduceTransparency {
            Circle().fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.75))
        } else {
            Circle().fill(material)
        }
    }
}

// MARK: - Small Glass Capsule (labels / chips)

public struct GlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public var addShadow: Bool = true

    public init(addShadow: Bool = true) {
        self.addShadow = addShadow
    }

    public func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundStyle, in: Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 0.75))
            .shadow(
                color: Color.black.opacity(addShadow ? (colorScheme == .dark ? 0.18 : 0.10) : 0),
                radius: addShadow ? 8 : 0,
                x: 0,
                y: addShadow ? 4 : 0
            )
            .minimumScaleFactor(0.9)
    }

    private var backgroundStyle: AnyShapeStyle {
        if reduceTransparency {
            let fill = (colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.white.opacity(0.75))
            return AnyShapeStyle(fill)
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var borderColor: Color {
        .white.opacity(colorScheme == .dark ? 0.33 : 0.45)
    }
}

public extension View {
    func glassCapsule(addShadow: Bool = true) -> some View {
        modifier(GlassCapsuleModifier(addShadow: addShadow))
    }
}
