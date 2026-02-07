import SwiftUI

struct ThemedCardModifier: ViewModifier {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var uiSettings: AppUISettings

    let padding: CGFloat?
    let corner: CGFloat?
    let surface: AnyShapeStyle?
    let prominent: Bool

    func body(content: Content) -> some View {
        let theme = themeBox.base
        let pad = (padding ?? theme.spacing) * uiSettings.spacingMultiplier * uiSettings.cardPaddingMultiplier
        let radius = (corner ?? theme.corner) * uiSettings.cardCornerMultiplier
        let surfaceStyle = surface ?? {
            switch uiSettings.cardStyle {
            case .glass:
                return AnyShapeStyle(.thinMaterial)
            default:
                return AnyShapeStyle(theme.cardBackground)
            }
        }()
        let borderOpacity = (scheme == .dark ? 0.78 : 0.60) * uiSettings.borderOpacity
        let liteEffects = uiSettings.motion != .full
        let shadowOpacity = (scheme == .dark ? 0.28 : 0.18) * uiSettings.shadowMultiplier * (liteEffects ? 0.0 : 1.0)
        let lift = (prominent ? 6.0 : 3.0) * (liteEffects ? 0.0 : 1.0)
        let shadowRadius = (prominent ? theme.elevation + 10 : theme.elevation + 4) * (liteEffects ? 0.0 : 1.0)

        return content
            .padding(pad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(surfaceStyle)
                    .overlay {
                        if !liteEffects {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(scheme == .dark ? 0.10 : 0.32),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.screen)
                                .opacity(scheme == .dark ? 0.30 : 0.18)
                        }
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.separator.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(
                color: theme.separator.opacity(shadowOpacity),
                radius: shadowRadius * uiSettings.shadowMultiplier,
                x: 0,
                y: lift
            )
    }
}

extension View {
    func themedCard(
        padding: CGFloat? = nil,
        corner: CGFloat? = nil,
        surface: AnyShapeStyle? = nil,
        prominent: Bool = false
    ) -> some View {
        modifier(ThemedCardModifier(padding: padding, corner: corner, surface: surface, prominent: prominent))
    }
}
