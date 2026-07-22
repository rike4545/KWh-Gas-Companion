import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Charts)
import Charts
#endif

#if canImport(UIKit)
@MainActor
private enum AppScrollTuning {
    private static var hasApplied = false

    static func applyIfNeeded() {
        guard !hasApplied else { return }
        hasApplied = true

        let scrollView = UIScrollView.appearance()
        scrollView.decelerationRate = .normal
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.keyboardDismissMode = .interactive

        UITableView.appearance().isPrefetchingEnabled = true
        UICollectionView.appearance().isPrefetchingEnabled = true
    }
}
#endif

/// Global polish that applies motion + scroll behavior consistently.
struct AppPolishModifier: ViewModifier {
    @EnvironmentObject private var uiSettings: AppUISettings

    func body(content: Content) -> some View {
        content
            .onAppear {
                #if canImport(UIKit)
                AppScrollTuning.applyIfNeeded()
                #endif
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .transaction { tx in
                switch uiSettings.motion {
                case .none:
                    tx.animation = nil
                    tx.disablesAnimations = true
                case .reduced:
                    tx.animation = nil
                    tx.disablesAnimations = true
                case .full:
                    tx.animation = .snappy(duration: 0.24, extraBounce: 0.05)
                    tx.disablesAnimations = false
                }
            }
    }
}

extension View {
    func appPolish() -> some View {
        modifier(AppPolishModifier())
    }
}

#if canImport(Charts)
/// Shared chart behavior for smoother, more interactive data visualizations.
private struct KWhChartSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .chartPlotStyle { plot in
                plot
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.vertical, 2)
    }
}

private struct KWhChartScrubbingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrubX: CGFloat?

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let anchor = proxy.plotFrame {
                        let frame = geo[anchor]
                        ZStack(alignment: .topLeading) {
                            if let scrubX {
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.22))
                                    .frame(width: 2, height: frame.height)
                                    .offset(x: frame.minX + scrubX - 1, y: frame.minY)
                                    .allowsHitTesting(false)
                            }

                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.minX, y: frame.minY)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let relativeX = value.location.x - frame.minX
                                            guard frame.width > 0 else { return }
                                            scrubX = min(max(0, relativeX), frame.width)
                                        }
                                        .onEnded { _ in
                                            if reduceMotion {
                                                scrubX = nil
                                            } else {
                                                withAnimation(.easeOut(duration: 0.18)) {
                                                    scrubX = nil
                                                }
                                            }
                                        }
                                )
                        }
                    }
                }
            }
            .transaction { tx in
                if !reduceMotion {
                    tx.animation = .interactiveSpring(response: 0.28, dampingFraction: 0.84, blendDuration: 0.16)
                }
            }
    }
}

extension View {
    func kwhInteractiveChartSurface() -> some View {
        modifier(KWhChartSurfaceModifier())
    }

    func kwhInteractiveDataViz() -> some View {
        modifier(KWhChartSurfaceModifier())
            .modifier(KWhChartScrubbingModifier())
    }
}
#endif
