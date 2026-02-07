// DDSessionDTO.swift
import Foundation

public struct DDSessionDTO: Sendable, Hashable {
    public var start: Date
    public var end: Date
    public var energyKWh: Double
    public var cost: Double
    public var miles: Double
    public var isSupercharging: Bool

    public init(
        start: Date,
        end: Date,
        energyKWh: Double,
        cost: Double,
        miles: Double,
        isSupercharging: Bool
    ) {
        self.start = start
        self.end = end
        self.energyKWh = energyKWh
        self.cost = cost
        self.miles = miles
        self.isSupercharging = isSupercharging
    }
}
