// ChargingDataSource.swift

import Foundation

public enum ChargingDataSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case teslaOfficial
    case teslaFi
    case manual
    case other

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .teslaOfficial: return "Tesla"
        case .teslaFi:       return "TeslaFi"
        case .manual:        return "Manual"
        case .other:         return "Other"
        }
    }

    public var longLabel: String {
        switch self {
        case .teslaOfficial: return "Official Tesla CSV"
        case .teslaFi:       return "TeslaFi Analytics"
        case .manual:        return "Manual Entry"
        case .other:         return "Other Source"
        }
    }

    public var systemImageName: String {
        switch self {
        case .teslaOfficial: return "bolt.car.fill"
        case .teslaFi:       return "chart.line.uptrend.xyaxis"
        case .manual:        return "pencil.circle.fill"
        case .other:         return "questionmark.circle.fill"
        }
    }
}
