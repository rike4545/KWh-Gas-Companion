//
//  EnergyModel.swift
//  KWh Gas Companion
//
//  Created by Bryan on 10/19/25.
//


//
//  EnergyModel.swift
//  My EV Companion
//
//  Simple consumption model influenced by temp, speed, wind, elevation.
//  Swift 6 / iOS 17+
//

import Foundation

struct EnergyModel {
    /// Estimate Wh/mi given baseline and environment.
    /// This is a pragmatic model: speed^2 aero curve, linear temp penalty, small wind, elevation energy.
    static func whPerMile(
        baselineWhPerMile: Double,
        cruiseMPH: Double,
        tempF: Double,
        windDeltaMPH: Double
    ) -> Double {
        // Aero: ~quadratic with speed; normalize to 65 mph baseline.
        let v = max(cruiseMPH + windDeltaMPH, 20)
        let aero = pow(v / 65.0, 2.0)
        
        // Temperature penalty vs. 65°F baseline (~0.5%/°F below 65, 0.15%/°F above 75 for HVAC/chemistry)
        let coldPenalty = tempF < 65 ? (65 - tempF) * 0.005 : 0
        let hotPenalty  = tempF > 75 ? (tempF - 75) * 0.0015 : 0
        let tempFactor = 1.0 + coldPenalty + hotPenalty
        
        return baselineWhPerMile * aero * tempFactor
    }
    
    /// Elevation energy (kWh) for a given net climb (m). ~9.8 m/s^2 * mass; use proxy 0.02 kWh per 10 m per 2000 kg
    /// We avoid mass input; use a typical EV proxy. Negative means regen (clamped).
    static func kWhForElevation(netGainMeters: Double) -> Double {
        // Approx 0.02 kWh per 10 m climbed for a mid-size EV; regen recovers ~60% on descent.
        if netGainMeters >= 0 {
            return (netGainMeters / 10.0) * 0.02
        } else {
            // Regen efficiency ~60%; negative gain means descent => credit back 0.012 kWh per 10 m
            return (netGainMeters / 10.0) * 0.012
        }
    }
}
