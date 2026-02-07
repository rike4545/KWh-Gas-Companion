//
//  CSVToast.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/13/25.
//


// MARK: - File: CSVImportShared.swift
import SwiftUI

struct CSVToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}