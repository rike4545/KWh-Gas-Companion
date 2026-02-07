// KPIStatCard.swift
import SwiftUI

struct KPIStatCard: View {
    let title: String
    let value: String
    let caption: String?
    var trend: Double? = nil   // +up, -down

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(title)
                .font(DS.Font.label(13))
                .foregroundStyle(DS.Color.subtext)

            Text(value)
                .font(DS.Font.number(28))
                .foregroundStyle(DS.Color.text)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            if let caption {
                HStack(spacing: 6) {
                    if let t = trend {
                        Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(t >= 0 ? DS.Color.bad : DS.Color.good)
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    Text(caption)
                        .font(DS.Font.label(12))
                        .foregroundStyle(DS.Color.subtext)
                }
            }
        }
        .padding(DS.Spacing.l)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .shadow(color: DS.Shadow.card.opacity(0.25), radius: 12, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .stroke(DS.Color.surface2, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
