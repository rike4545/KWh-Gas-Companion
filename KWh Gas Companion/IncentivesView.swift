/// IncentivesView.swift
// MyKwH Companion
// Created by Bryan on 7/15/25.

import SwiftUI

/// View providing a direct link to comprehensive EV incentives listing
struct IncentivesView: View {
    private let incentivesURL = URL(string: "https://www.electricforall.org/rebates-incentives/")!

    var body: some View {
        NavigationStack {
            List {
                Link(destination: incentivesURL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EV Rebates & Incentives")
                            .font(.headline)
                        Text("Comprehensive listing of federal, state, and local EV incentives")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("EV Incentives")
        }
    }
}

// MARK: - Preview
#if DEBUG
struct IncentivesView_Previews: PreviewProvider {
    static var previews: some View {
        IncentivesView()
    }
}
#endif
