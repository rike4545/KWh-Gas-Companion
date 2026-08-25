//
//  SectionHeader.swift
//  KWh Gas Companion
//
//

// SectionHeader.swift
import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String?
    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            if let icon { Image(systemName: icon).imageScale(.medium).foregroundStyle(DS.Color.subtext) }
            Text(title)
                .font(DS.Font.title(18))
                .foregroundStyle(DS.Color.subtext)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.m)
        .accessibilityAddTraits(.isHeader)
    }
}
