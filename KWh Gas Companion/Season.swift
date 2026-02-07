//
//  Season.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/12/25.
//


// Season.swift
import Foundation

public enum Season: String, CaseIterable, Codable {
    case spring, summer, autumn, winter
    public var displayName: String {
        rawValue.capitalized
    }
}
