//
//  FilterMenu 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/29/25.
//


// FilterMenu.swift
// MyKwH Companion

import SwiftUI

/// Menu for filtering expenses by category
struct FilterMenu: View {
    @Binding var filter: ExpenseFilter

    var body: some View {
        Menu {
            ForEach(ExpenseFilter.allCases) { option in
                Button(option.rawValue) {
                    filter = option
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}
