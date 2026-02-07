//
//  NumericField.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/28/25.
//


import SwiftUI

struct NumericField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
