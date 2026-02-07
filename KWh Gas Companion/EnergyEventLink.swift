//
//  EnergyEventLink.swift
//  KWh Gas Companion
//
//  Created by Bryan on 12/17/25.
//


//
//  EnergyEventBuilder.swift
//  My KWh Companion
//
//  Builds EnergyEvent stream + optionally matches TeslaFi ↔︎ Ledger.
//  Swift 6 • iOS 17+
//

import Foundation

struct EnergyEventLink: Identifiable, Hashable, Sendable {
    let ledgerID: String
    let teslaFiID: String
    let confidence: Double

    var id: String { "link|\(ledgerID)|\(teslaFiID)" }
}

enum EnergyEventBuilder {

    static func build(
        teslaFi: [TeslaFiSession],
        ledger: [ExpenseEntry]
    ) -> (events: [EnergyEvent], links: [EnergyEventLink]) {

        let tfEvents = teslaFi.map { s -> EnergyEvent in
            let loc = ChargingLocationNormalizer.cleanedName(s.location)
            return EnergyEvent(
                sourceKind: .teslaFi,
                sourceID: s.sessionHash,
                startDate: s.startDate,
                endDate: s.endDate,
                kWh: s.energyAddedKWh,
                amountGross: s.cost,
                amountNet: s.cost,
                currencyCode: nil,
                locationName: loc,
                siteKey: ChargingLocationNormalizer.siteKey(from: loc),
                latitude: nil,
                longitude: nil,
                chargingKind: ChargingClassifier.classify(session: s),
                vehicleName: nil,
                vin: nil,
                notes: nil
            )
        }

        let ledgerEnergy = ledger.filter { $0.isEnergyEffective }
        let ledgerEvents = ledgerEnergy.map { e -> EnergyEvent in
            let start = e.charging?.startDate ?? e.date
            let end = e.charging?.endDate
            let loc = e.charging?.siteName ?? e.location
            return EnergyEvent(
                sourceKind: .ledger,
                sourceID: e.id.uuidString,
                startDate: start,
                endDate: end,
                kWh: e.energyAddedKWh,
                amountGross: e.amount,
                amountNet: e.amountExVAT,
                currencyCode: e.currencyCode,
                locationName: ChargingLocationNormalizer.cleanedName(loc),
                siteKey: ChargingLocationNormalizer.siteKey(from: loc),
                latitude: e.charging?.latitude,
                longitude: e.charging?.longitude,
                chargingKind: ChargingClassifier.classify(entry: e),
                vehicleName: e.charging?.vehicleName ?? e.vehicleName,
                vin: e.charging?.vin ?? e.vin,
                notes: e.charging?.notes ?? e.notes
            )
        }

        let links = matchLedgerToTeslaFi(ledgerEvents: ledgerEvents, teslaFiEvents: tfEvents)
        let all = (tfEvents + ledgerEvents).sorted { $0.startDate > $1.startDate }
        return (all, links)
    }

    /// Matches by:
    /// - same siteKey
    /// - start time within ±8 minutes
    /// - kWh within ±0.3 (when both have kWh)
    private static func matchLedgerToTeslaFi(
        ledgerEvents: [EnergyEvent],
        teslaFiEvents: [EnergyEvent]
    ) -> [EnergyEventLink] {

        let tfBySite = Dictionary(grouping: teslaFiEvents, by: \.siteKey)
        var usedTF = Set<String>()
        var links: [EnergyEventLink] = []

        for le in ledgerEvents {
            guard let candidates = tfBySite[le.siteKey], !candidates.isEmpty else { continue }

            let best = candidates
                .filter { !usedTF.contains($0.id) }
                .map { tf -> (EnergyEvent, Double) in
                    let dt = abs(tf.startDate.timeIntervalSince(le.startDate))
                    let timeScore = max(0, 1.0 - (dt / (8.0 * 60.0))) // 1 at 0 min, 0 at 8 min

                    let kwhScore: Double = {
                        guard let a = le.kWh, let b = tf.kWh, a > 0, b > 0 else { return 0.55 } // neutral
                        let diff = abs(a - b)
                        return diff <= 0.3 ? 1.0 : max(0, 1.0 - (diff / 2.0))
                    }()

                    // Weighted
                    let score = (0.65 * timeScore) + (0.35 * kwhScore)
                    return (tf, score)
                }
                .filter { $0.1 > 0.55 } // avoid junk matches
                .sorted(by: { $0.1 > $1.1 })
                .first

            if let (tf, score) = best {
                usedTF.insert(tf.id)
                links.append(EnergyEventLink(
                    ledgerID: le.id,
                    teslaFiID: tf.id,
                    confidence: score
                ))
            }
        }

        return links.sorted { $0.confidence > $1.confidence }
    }
}
