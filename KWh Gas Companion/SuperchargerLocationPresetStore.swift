//
//  SuperchargerLocationPresetStore.swift
//  My EV Companion / KWh Gas Companion
//
//  Per-location presets for the Live Price Predictor calculator.
//  Stored locally via @AppStorage as JSON.
//  Swift 6 • iOS 17+
//

import Foundation
import SwiftUI

// MARK: - Base mode

public enum SuperchargerBasePriceMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    /// Base price is exactly what the user entered (no curve multiplier).
    case manual

    /// Apply the daily curve multiplier to the user-entered base (good for “TOU-ish” tuning).
    case curveMultiplier

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: return "Manual"
        case .curveMultiplier: return "Daily Curve Multiplier"
        }
    }
}

// MARK: - Daily curve model

public struct SuperchargerDailyCurveModel: Codable, Hashable, Sendable {

    public enum Kind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
        case flat
        case peakEvening
        case peakAfternoon
        case peakMorning

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .flat: return "Flat"
            case .peakEvening: return "Peak Evening"
            case .peakAfternoon: return "Peak Afternoon"
            case .peakMorning: return "Peak Morning"
            }
        }
    }

    /// If false, multiplier is always 1.0
    public var enabled: Bool

    /// Shape preset
    public var kind: Kind

    /// Multiplier at “peak” hour (>= 1)
    public var peakMultiplier: Double

    /// Multiplier at “off-peak” hour (<= 1)
    public var offPeakMultiplier: Double

    /// Weekend multiplier (optional nudge; 1.0 = no change)
    public var weekendMultiplier: Double

    public init(
        enabled: Bool = false,
        kind: Kind = .flat,
        peakMultiplier: Double = 1.08,
        offPeakMultiplier: Double = 0.96,
        weekendMultiplier: Double = 1.00
    ) {
        self.enabled = enabled
        self.kind = kind
        self.peakMultiplier = max(0.10, peakMultiplier)
        self.offPeakMultiplier = max(0.10, offPeakMultiplier)
        self.weekendMultiplier = max(0.10, weekendMultiplier)
    }

    /// Returns a multiplier for the given local date/time.
    public func multiplier(for date: Date, calendar: Calendar = .current) -> Double {
        guard enabled else { return 1.0 }
        guard kind != .flat else { return weekendAdjusted(1.0, date: date, calendar: calendar) }

        let hour = calendar.component(.hour, from: date)
        let (peakHour, _) = peakAndOffHours(for: kind)

        // Simple smooth-ish curve using a cosine blend between offPeak and peak.
        // Distance is circular (wraps around midnight).
        let d = circularDistance(hour, peakHour)
        let maxD = 12.0 // farthest point in hours on a 24h clock
        let t = max(0.0, min(1.0, 1.0 - (Double(d) / maxD))) // 1 at peak, 0 far away

        // A little easing
        let eased = t * t * (3 - 2 * t)

        // Blend: far from peak -> offPeakMultiplier, near peak -> peakMultiplier
        let m = offPeakMultiplier + (peakMultiplier - offPeakMultiplier) * eased

        return weekendAdjusted(m, date: date, calendar: calendar)
    }

    private func peakAndOffHours(for kind: Kind) -> (peak: Int, off: Int) {
        switch kind {
        case .flat:
            return (18, 3)
        case .peakEvening:
            return (18, 3)
        case .peakAfternoon:
            return (15, 4)
        case .peakMorning:
            return (8, 2)
        }
    }

    private func circularDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b) % 24
        return min(diff, 24 - diff)
    }

    private func weekendAdjusted(_ m: Double, date: Date, calendar: Calendar) -> Double {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = (weekday == 1 /*Sun*/ || weekday == 7 /*Sat*/)
        return isWeekend ? (m * weekendMultiplier) : m
    }
}

// MARK: - Tier offsets

public struct SuperchargerTierOffsets: Codable, Hashable, Sendable {
    /// Added to the effective base for “Low” tier
    public var lowDelta: Double

    /// Added to the effective base for “High” tier
    public var highDelta: Double

    public init(lowDelta: Double = -0.06, highDelta: Double = 0.08) {
        self.lowDelta = lowDelta
        self.highDelta = highDelta
    }
}

// MARK: - Tier thresholds (occupancy → tier)

public struct SuperchargerTierThresholds: Codable, Hashable, Sendable {
    /// If occupied stalls <= this value → LOW tier.
    public var lowMaxOccupiedStalls: Int

    /// If fill fraction >= this value → HIGH tier.
    /// Example: 0.80 means “>= 80% stalls occupied”.
    public var highMinFillFraction: Double

    public init(lowMaxOccupiedStalls: Int = 1, highMinFillFraction: Double = 0.80) {
        self.lowMaxOccupiedStalls = max(0, lowMaxOccupiedStalls)
        self.highMinFillFraction = max(0.0, min(1.0, highMinFillFraction))
    }

    public func tier(occupiedStalls: Int, totalStalls: Int) -> SuperchargerPriceTier {
        let total = max(1, totalStalls)
        let occ = max(0, min(total, occupiedStalls))

        if occ <= lowMaxOccupiedStalls { return .low }

        let fill = Double(occ) / Double(total)
        if fill >= highMinFillFraction { return .high }

        return .normal
    }
}

public enum SuperchargerPriceTier: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case low
    case normal
    case high

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}

// MARK: - Preset model

public struct SuperchargerLocationPreset: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String

    public var totalStalls: Int

    /// “Normal tier” baseline. Often the price you see when not quiet / not near-full.
    public var basePriceNormal: Double

    /// Per-location tuning
    public var baseMode: SuperchargerBasePriceMode
    public var curve: SuperchargerDailyCurveModel
    public var offsets: SuperchargerTierOffsets
    public var thresholds: SuperchargerTierThresholds

    public init(
        id: UUID = UUID(),
        name: String,
        totalStalls: Int,
        basePriceNormal: Double,
        baseMode: SuperchargerBasePriceMode = .manual,
        curve: SuperchargerDailyCurveModel = .init(),
        offsets: SuperchargerTierOffsets = .init(),
        thresholds: SuperchargerTierThresholds = .init()
    ) {
        self.id = id
        self.name = name
        self.totalStalls = max(1, totalStalls)
        self.basePriceNormal = max(0, basePriceNormal)
        self.baseMode = baseMode
        self.curve = curve
        self.offsets = offsets
        self.thresholds = thresholds
    }

    // Backward-compatible decoding defaults (prevents “Corrupt JSON” nuking presets after schema changes)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Unnamed"
        self.totalStalls = max(1, (try? c.decode(Int.self, forKey: .totalStalls)) ?? 12)
        self.basePriceNormal = max(0, (try? c.decode(Double.self, forKey: .basePriceNormal)) ?? 0.0)

        self.baseMode = (try? c.decode(SuperchargerBasePriceMode.self, forKey: .baseMode)) ?? .manual
        self.curve = (try? c.decode(SuperchargerDailyCurveModel.self, forKey: .curve)) ?? .init()
        self.offsets = (try? c.decode(SuperchargerTierOffsets.self, forKey: .offsets)) ?? .init()
        self.thresholds = (try? c.decode(SuperchargerTierThresholds.self, forKey: .thresholds)) ?? .init()
    }

    /// Compute an estimated price for a given occupancy and time.
    public func predictedPrice(occupiedStalls: Int, at date: Date, calendar: Calendar = .current) -> Double {
        let tier = thresholds.tier(occupiedStalls: occupiedStalls, totalStalls: totalStalls)

        let base: Double = {
            switch baseMode {
            case .manual:
                return basePriceNormal
            case .curveMultiplier:
                return basePriceNormal * curve.multiplier(for: date, calendar: calendar)
            }
        }()

        let raw: Double
        switch tier {
        case .low: raw = base + offsets.lowDelta
        case .normal: raw = base
        case .high: raw = base + offsets.highDelta
        }
        return max(0, raw)
    }
}

// MARK: - Store

@MainActor
public final class SuperchargerLocationPresetStore: ObservableObject {

    @Published public private(set) var presets: [SuperchargerLocationPreset] = []

    @AppStorage("evc_supercharger_location_presets_v1")
    private var presetsJSON: String = ""

    public init(seedDefaultsIfEmpty: Bool = true) {
        load()
        if seedDefaultsIfEmpty, presets.isEmpty {
            presets = [
                SuperchargerLocationPreset(
                    name: "Lake Grove, NY (example)",
                    totalStalls: 12,
                    basePriceNormal: 0.37,
                    baseMode: .manual,
                    curve: .init(enabled: false, kind: .peakEvening),
                    offsets: .init(lowDelta: -0.06, highDelta: 0.10),
                    thresholds: .init(lowMaxOccupiedStalls: 1, highMinFillFraction: 0.80)
                )
            ]
            persist()
        }
    }

    public func load() {
        guard !presetsJSON.isEmpty,
              let data = presetsJSON.data(using: .utf8)
        else {
            presets = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([SuperchargerLocationPreset].self, from: data)
            presets = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            // Corrupt JSON? Reset safely.
            presets = []
        }
    }

    public func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            presetsJSON = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // If encoding fails, don’t clobber previous value.
        }
    }

    public func upsert(_ preset: SuperchargerLocationPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        presets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
    }

    public func delete(_ preset: SuperchargerLocationPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    public func preset(id: UUID?) -> SuperchargerLocationPreset? {
        guard let id else { return nil }
        return presets.first(where: { $0.id == id })
    }
}
