//
//  ToolCardSection.swift
//  KWh Gas Companion
//
//
import SwiftUI

struct ToolCardSection: View {
    var body: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: TeslaVINDecoderView()) {
                ToolTile(icon: "barcode.viewfinder", title: "VIN Decoder")
            }
            NavigationLink(destination: TripLoggerView()) {
                ToolTile(icon: "car.fill", title: "Trip Log")
            }
        }
        .padding(.horizontal)
    }

    struct ToolTile: View {
        var icon: String
        var title: String
        @Environment(\.appThemeBox) private var themeBox

        var body: some View {
            let theme = themeBox.base
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .themedCard(padding: 14, corner: min(theme.corner, 14))
        }
    }
}
