//
//  DesignTokens.swift
//  My KWh Companion
//
//  Safe typography/spacing/radius/color tokens for Swift 6 / iOS 17+
//  - Uses SwiftUI text styles (no Font.system(size:) pitfalls)
//  - No dependency on .ultraThinMaterial (glass uses Color fallback)
//  - Namespaced to avoid symbol collisions
//

import SwiftUI

// MARK: - Namespace

enum DesignTokens {

    // MARK: - Typography

    enum FontRole {
        case title       // section/page titles
        case label       // card/list labels
        case body        // standard body text
        case caption     // small/secondary text
        case number      // numeric emphasis (monospaced)
        case footnote    // extra small
    }

    /// Returns a SwiftUI.Font using style-based APIs (no CGFloat sizes).
    static func font(_ role: FontRole) -> SwiftUI.Font {
        switch role {
        case .title:    return SwiftUI.Font.title3.weight(.semibold)
        case .label:    return SwiftUI.Font.subheadline.weight(.medium)
        case .body:     return SwiftUI.Font.body
        case .caption:  return SwiftUI.Font.caption
        case .number:   return SwiftUI.Font.title2.monospacedDigit()
        case .footnote: return SwiftUI.Font.footnote
        }
    }

    // Convenience accessors if you prefer static vars
    static var titleFont: SwiftUI.Font   { font(.title) }
    static var labelFont: SwiftUI.Font   { font(.label) }
    static var bodyFont: SwiftUI.Font    { font(.body) }
    static var captionFont: SwiftUI.Font { font(.caption) }
    static var numberFont: SwiftUI.Font  { font(.number) }
    static var footnoteFont: SwiftUI.Font{ font(.footnote) }

    // MARK: - Spacing

    enum Space: CGFloat, CaseIterable {
        case xs = 6
        case sm = 10
        case md = 14
        case lg = 18
        case xl = 24
    }
    static func space(_ s: Space) -> CGFloat { s.rawValue }

    // MARK: - Radius

    enum Radius: CGFloat, CaseIterable {
        case sm = 10
        case md = 16
        case lg = 22
    }
    static func radius(_ r: Radius) -> CGFloat { r.rawValue }

    // MARK: - Colors

    struct Palette {
        // Base neutrals (tune to taste)
        static let background = Color(.sRGB, red: 0.07, green: 0.07, blue: 0.09, opacity: 1)
        static let surface    = Color(.sRGB, red: 0.12, green: 0.12, blue: 0.15, opacity: 1)
        static let border     = Color.white.opacity(0.10)
        static let borderSoft = Color.white.opacity(0.06)

        // Accents
        static let accent     = Color.red
        static let positive   = Color.green
        static let warning    = Color.orange
        static let negative   = Color.red

        // Text roles
        static let primaryText   = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText  = Color.secondary.opacity(0.7)
    }

    // MARK: - “Glass” background (Material-free)

    /// A subtle “glass-like” fill that works without .ultraThinMaterial.
    static func glassBackground() -> Color {
        Color.white.opacity(0.07)
    }

    /// A reusable “glass” card container (material-free).
    @ViewBuilder
    static func glassCard<Content: View>(
        corner: CGFloat = DesignTokens.radius(.md),
        pad: CGFloat = DesignTokens.space(.md),
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(pad)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(glassBackground())
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(Palette.border)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    // MARK: - Currency / Number formatters

    static func money(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    static func fmt0(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    static func fmt1(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

// MARK: - Examples (remove in production if desired)

#if DEBUG
struct _DesignTokensPreview: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Title Font").font(DesignTokens.titleFont)
                Text("Label Font").font(DesignTokens.labelFont)
                Text("Body Font").font(DesignTokens.bodyFont)
                Text("Caption Font").font(DesignTokens.captionFont)
                Text("Number 123,456").font(DesignTokens.numberFont)

                DesignTokens.glassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Glass Card")
                            .font(DesignTokens.labelFont)
                        Text("This card uses a Color-based glass background (no Material).")
                            .font(DesignTokens.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(DesignTokens.Palette.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
