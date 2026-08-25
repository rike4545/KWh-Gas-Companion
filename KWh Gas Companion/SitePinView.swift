//
//  SitePinView.swift
//  KWh Gas Companion
//
//

// SitePinView.swift
import SwiftUI

@MainActor
struct SitePinView: View {
    let color: Color
    var isSelected: Bool = false
    var countBadge: Int? = nil   // optional (e.g., stall count)

    @State private var appear = false

    var body: some View {
        ZStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .shadow(radius: 1, y: 0.5)

            if let countBadge {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                    Text("\(countBadge)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 16, height: 16)
                .offset(x: 12, y: 12)
            }
        }
        .overlay(
            Circle()
                .stroke(color.opacity(isSelected ? 0.8 : 0), lineWidth: 6)
                .blur(radius: 6)
        )
        .scaleEffect(isSelected ? 1.12 : (appear ? 1.0 : 0.86))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appear = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Supercharger")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .contentShape(Rectangle())
    }
}
