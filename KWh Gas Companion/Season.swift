//
//  Season.swift
//  KWh Gas Companion
//
//

// Season.swift
import Foundation

public enum Season: String, CaseIterable, Codable {
    case spring, summer, autumn, winter
    public var displayName: String {
        rawValue.capitalized
    }
}
