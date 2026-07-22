//
//  TileButton.swift
//  KWh Gas Companion
//
//

// TileButton.swift
import SwiftUI

struct TileButton: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Color.surface2)
                        .frame(width: 42, height: 42)
                    Image(systemName: icon).imageScale(.large).foregroundStyle(DS.Color.text)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.Font.title(16)).foregroundStyle(DS.Color.text)
                    if let subtitle {
                        Text(subtitle).font(DS.Font.label(12)).foregroundStyle(DS.Color.subtext)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(DS.Color.subtext)
            }
            .padding(DS.Spacing.l)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(subtitle ?? "")
    }
}
