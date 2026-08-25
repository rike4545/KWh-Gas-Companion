//
//  ForecastHeaderView 2.swift
//  KWh Gas Companion
//
//

// ForecastHeaderView.swift
// My KWh Companion

import SwiftUI

struct ForecastHeaderView: View {
    @Binding var selectedRange: ForecastRange

    var body: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(ForecastRange.allCases) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
    }
}
