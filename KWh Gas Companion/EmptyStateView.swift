//  EmptyStateView.swift
//  MyKwH Companion – 2025-07-29
//  Displays a placeholder when there are no expense entries.

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No entries match your filters.")
                .font(.headline)
            Text("Adjust filters or search to view expenses.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
