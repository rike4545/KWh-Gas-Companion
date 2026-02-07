//
//  RatesStore.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/12/25.
//


// RatesStore.swift
import Foundation

final class RatesStore: ObservableObject {
    @Published var residentialRate: Double = UserDefaults.standard.double(forKey: "resRate")
    @Published var commercialRate: Double = UserDefaults.standard.double(forKey: "comRate")

    init() {
        if residentialRate == 0 { residentialRate = 0.15 }
        if commercialRate == 0 { commercialRate = 0.12 }
    }

    func save() {
        UserDefaults.standard.set(residentialRate, forKey: "resRate")
        UserDefaults.standard.set(commercialRate, forKey: "comRate")
    }
}
