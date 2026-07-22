//  UXKit.swift
//  My KWh Companion
//
//  Lightweight UX helpers: load phases, skeletons, and safe wrappers.
//  Zero dependency on your models.

import SwiftUI

// MARK: - Load phase

enum LoadPhase<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Skeleton

struct SkeletonRow: View {
    var height: CGFloat = 64
    var corner: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .frame(height: height)
            .redacted(reason: .placeholder)
            .shimmer() // see modifier below
    }
}

extension View {
    /// Simple shimmer using an animating gradient mask.
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

private struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if !active { return AnyView(content) }
        let gradient = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.15), location: 0.25),
                .init(color: .white.opacity(0.45), location: 0.5),
                .init(color: .white.opacity(0.15), location: 0.75),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        return AnyView(
            content
                .mask(
                    Rectangle()
                        .fill(gradient)
                        .rotationEffect(.degrees(20))
                        .offset(x: -200 + phase, y: -200 + phase)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
        )
    }
}

// MARK: - Inline empty state

struct InlineEmptyState: View {
    let title: String
    let message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.car")
                .font(.system(size: 36, weight: .semibold))
                .opacity(0.7)
            Text(title).font(.headline)
            if let message { Text(message).font(.subheadline).opacity(0.7) }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 24)
    }
}
