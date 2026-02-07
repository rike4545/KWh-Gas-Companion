//
//  ExpenseSection.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/27/25.
//


//
//  ExpenseSection.swift
//  MyKwH Companion – 2025-07-29
//  Models a group of ExpenseEntry items for a single day.

import Foundation

struct ExpenseSection: Identifiable {
    let id: Date            // Start of day for grouping
    let entries: [ExpenseEntry]
}
