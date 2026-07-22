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

struct ChargingBehaviorInsights: Sendable {
    struct Factor: Identifiable, Hashable, Sendable {
        let id = UUID()
        let title: String
        let detail: String
        let impactScore: Double
    }

    private struct Sample: Hashable, Sendable {
        let date: Date
        let sourceLabel: String
        let sourceReference: String
        let locationName: String
        let siteKey: String
        let chargingKind: ChargingKind
        let kWh: Double?
        let cost: Double?
        let startSOC: Double?
        let endSOC: Double?
        let outsideTempC: Double?
    }

    struct SiteStat: Hashable, Sendable {
        let siteKey: String
        let displayName: String
        let sessions: Int
        let totalKWh: Double
    }

    let totalSessions: Int
    let dominantLocation: SiteStat?
    let dominantLocationShare: Double
    let dominantChargingKind: ChargingKind
    let dominantChargingKindShare: Double
    let homeShare: Double
    let fastDCShare: Double
    let destinationShare: Double
    let unknownShare: Double
    let highSOC90Share: Double?
    let highSOC95Share: Double?
    let lowStartSOC10Share: Double?
    let hotWeatherShare: Double?
    let averageSessionKWh: Double?
    let averageSOCWindow: Double?
    let factors: [Factor]
    let suggestions: [String]
    let evidence: [AIEvidence]

    var whereAndHowSummary: String {
        guard totalSessions > 0 else {
            return "I do not have enough charging history yet to tell where this owner charges most often."
        }

        var pieces: [String] = []

        if let dominantLocation, dominantLocation.displayName.lowercased() != "unknown" {
            pieces.append("Most charging happens at \(dominantLocation.displayName), with \(dominantLocation.sessions) of \(totalSessions) sessions (\(Self.percentString(dominantLocationShare))).")
        } else {
            pieces.append("I do not have enough reliable location tags to name one primary site yet.")
        }

        pieces.append("The dominant charging style is \(Self.chargingKindPhrase(dominantChargingKind)) at \(Self.percentString(dominantChargingKindShare)) of analyzed sessions.")

        if homeShare > 0 {
            pieces.append("Home charging accounts for \(Self.percentString(homeShare)); fast DC is \(Self.percentString(fastDCShare)).")
        }

        return pieces.joined(separator: " ")
    }

    var batteryHealthSummary: String {
        guard totalSessions > 0 else {
            return "I do not have enough charging history yet to estimate what may be affecting long-term battery health."
        }

        if factors.isEmpty {
            return "Based on the sessions I can analyze, this charging routine looks relatively battery-friendly. I do not see one dominant long-term stress pattern in the saved data."
        }

        let lead = factors.sorted { $0.impactScore > $1.impactScore }
        let top = lead.prefix(2).map { "\($0.title.lowercased()): \($0.detail)" }
        return "The main long-term battery-health factors I see are " + top.joined(separator: " ") 
    }

    var suggestionsSummary: String {
        guard !suggestions.isEmpty else {
            return "Keep logging sessions with location and SOC so I can give more specific battery-care suggestions."
        }

        return suggestions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    static func build(
        entries: [ExpenseEntry],
        teslaFiSessions: [TeslaFiSession]
    ) -> ChargingBehaviorInsights {
        let energyEntries = entries.filter { $0.isEnergyEffective }
        let bundle = EnergyEventBuilder.build(teslaFi: teslaFiSessions, ledger: energyEntries)
        let linkedTeslaFiIDs = Set(bundle.links.map(\.teslaFiID))

        var samples: [Sample] = energyEntries.map { entry in
            let loc = ChargingLocationNormalizer.cleanedName(entry.charging?.siteName ?? entry.location)
            return Sample(
                date: entry.charging?.startDate ?? entry.date,
                sourceLabel: "EntriesStore",
                sourceReference: entry.id.uuidString,
                locationName: loc,
                siteKey: ChargingLocationNormalizer.siteKey(from: loc),
                chargingKind: ChargingClassifier.classify(entry: entry),
                kWh: entry.energyAddedKWh,
                cost: entry.amount,
                startSOC: entry.charging?.startSOC,
                endSOC: entry.charging?.endSOC ?? entry.stateOfCharge,
                outsideTempC: entry.charging?.outsideTempC
            )
        }

        let unlinkedTeslaFi = bundle.events
            .filter { $0.sourceKind == .teslaFi }
            .filter { !linkedTeslaFiIDs.contains($0.id) }

        samples.append(contentsOf: unlinkedTeslaFi.map { event in
            Sample(
                date: event.startDate,
                sourceLabel: "ImportedSessionStore",
                sourceReference: event.sourceID,
                locationName: ChargingLocationNormalizer.cleanedName(event.locationName),
                siteKey: event.siteKey,
                chargingKind: event.chargingKind,
                kWh: event.kWh,
                cost: event.amountGross,
                startSOC: nil,
                endSOC: nil,
                outsideTempC: nil
            )
        })

        samples.sort { $0.date > $1.date }

        guard !samples.isEmpty else {
            return ChargingBehaviorInsights(
                totalSessions: 0,
                dominantLocation: nil,
                dominantLocationShare: 0,
                dominantChargingKind: .unknown,
                dominantChargingKindShare: 0,
                homeShare: 0,
                fastDCShare: 0,
                destinationShare: 0,
                unknownShare: 0,
                highSOC90Share: nil,
                highSOC95Share: nil,
                lowStartSOC10Share: nil,
                hotWeatherShare: nil,
                averageSessionKWh: nil,
                averageSOCWindow: nil,
                factors: [],
                suggestions: [],
                evidence: []
            )
        }

        let groupedSites = Dictionary(grouping: samples, by: \.siteKey)
        let siteStats = groupedSites.map { key, rows in
            SiteStat(
                siteKey: key,
                displayName: ChargingLocationNormalizer.preferredDisplayName(from: rows.map(\.locationName)),
                sessions: rows.count,
                totalKWh: rows.compactMap(\.kWh).reduce(0, +)
            )
        }
        .sorted {
            if $0.sessions == $1.sessions {
                return $0.totalKWh > $1.totalKWh
            }
            return $0.sessions > $1.sessions
        }

        let kindCounts = Dictionary(grouping: samples, by: \.chargingKind).mapValues(\.count)
        let dominantKind = kindCounts.max { lhs, rhs in lhs.value < rhs.value }?.key ?? .unknown
        let total = Double(samples.count)
        let homeShare = Double(kindCounts[.home] ?? 0) / total
        let fastDCShare = Double(kindCounts[.fastDC] ?? 0) / total
        let destinationShare = Double(kindCounts[.destination] ?? 0) / total
        let unknownShare = Double(kindCounts[.unknown] ?? 0) / total

        let socRows = samples.filter { $0.startSOC != nil || $0.endSOC != nil }
        let completedSOCRows = samples.filter { $0.startSOC != nil && $0.endSOC != nil }
        let high90 = ratio(count: socRows.filter { ($0.endSOC ?? -1) >= 90 }.count, total: socRows.count)
        let high95 = ratio(count: socRows.filter { ($0.endSOC ?? -1) >= 95 }.count, total: socRows.count)
        let low10 = ratio(count: completedSOCRows.filter { ($0.startSOC ?? 101) <= 10 }.count, total: completedSOCRows.count)
        let hotWeather = ratio(count: samples.filter { ($0.outsideTempC ?? -.greatestFiniteMagnitude) >= 32 }.count, total: samples.filter { $0.outsideTempC != nil }.count)

        let avgKWh = average(samples.compactMap(\.kWh))
        let avgSOCWindow = average(completedSOCRows.compactMap { sample in
            guard let start = sample.startSOC, let end = sample.endSOC else { return nil }
            return max(0, end - start)
        })

        var factors: [Factor] = []
        var suggestions: [String] = []

        if fastDCShare >= 0.35 {
            factors.append(Factor(
                title: "Heavy fast-charging share",
                detail: "Fast DC makes up \(percentString(fastDCShare)) of sessions, which can add long-term stress when it is the default rather than the exception.",
                impactScore: fastDCShare
            ))
            suggestions.append("Move more weekly charging to slower home or destination charging when you can, and save fast DC for travel days or genuinely time-sensitive sessions.")
        }

        if let high95, high95 >= 0.20 {
            factors.append(Factor(
                title: "Frequent very high charge ceilings",
                detail: "\(percentString(high95)) of SOC-tagged sessions finish at 95% or above, which keeps the pack near the top of its range more often than ideal for daily use.",
                impactScore: high95 + 0.1
            ))
            suggestions.append("Use 95-100% mainly for trip prep. For normal days, set a lower routine charge limit and finish high only when the extra range will be used soon.")
        } else if let high90, high90 >= 0.45 {
            factors.append(Factor(
                title: "Regular charging above 90%",
                detail: "\(percentString(high90)) of SOC-tagged sessions end at 90% or higher, which may raise long-term wear if that is the everyday pattern.",
                impactScore: high90
            ))
            suggestions.append("If this vehicle is usually parked after charging, consider a lower daily target and reserve 90%+ sessions for colder weather, long drives, or limited charging access.")
        }

        if let low10, low10 >= 0.25 {
            factors.append(Factor(
                title: "Frequent deep discharge starts",
                detail: "\(percentString(low10)) of complete SOC sessions begin at 10% or lower, suggesting the battery is often run very low before charging.",
                impactScore: low10
            ))
            suggestions.append("Plug in a bit earlier when possible so the car spends less time in very low SOC ranges.")
        }

        if let hotWeather, hotWeather >= 0.25 {
            factors.append(Factor(
                title: "Charging in hotter conditions",
                detail: "\(percentString(hotWeather)) of temperature-tagged sessions were logged above 32 C, where repeated high-SOC or fast charging can compound thermal stress.",
                impactScore: hotWeather
            ))
            suggestions.append("On hotter days, avoid leaving the vehicle sitting at a very high SOC after charging if you can help it.")
        }

        if factors.isEmpty {
            suggestions.append("The logged routine already looks fairly balanced. The biggest win now is consistency: keep most routine charging moderate and use high limits or fast charging when the trip really calls for it.")
        }

        if unknownShare >= 0.30 {
            suggestions.append("Add or clean up charging locations for more precise guidance about where home, work, and public charging are happening most often.")
        }

        let evidence = buildEvidence(from: samples, siteStats: siteStats, dominantKind: dominantKind, dominantKindShare: Double(kindCounts[dominantKind] ?? 0) / total, fastDCShare: fastDCShare, high90: high90, high95: high95)

        return ChargingBehaviorInsights(
            totalSessions: samples.count,
            dominantLocation: siteStats.first,
            dominantLocationShare: siteStats.first.map { Double($0.sessions) / total } ?? 0,
            dominantChargingKind: dominantKind,
            dominantChargingKindShare: Double(kindCounts[dominantKind] ?? 0) / total,
            homeShare: homeShare,
            fastDCShare: fastDCShare,
            destinationShare: destinationShare,
            unknownShare: unknownShare,
            highSOC90Share: high90,
            highSOC95Share: high95,
            lowStartSOC10Share: low10,
            hotWeatherShare: hotWeather,
            averageSessionKWh: avgKWh,
            averageSOCWindow: avgSOCWindow,
            factors: factors.sorted { $0.impactScore > $1.impactScore },
            suggestions: Array(suggestions.prefix(4)),
            evidence: evidence
        )
    }

    private static func buildEvidence(
        from samples: [Sample],
        siteStats: [SiteStat],
        dominantKind: ChargingKind,
        dominantKindShare: Double,
        fastDCShare: Double,
        high90: Double?,
        high95: Double?
    ) -> [AIEvidence] {
        var evidence: [AIEvidence] = []

        if let topSite = siteStats.first {
            evidence.append(AIEvidence(
                source: "ChargingBehaviorInsights",
                reference: topSite.displayName,
                summary: "\(topSite.displayName) appears in \(topSite.sessions) session(s) and \(String(format: "%.1f", topSite.totalKWh)) kWh."
            ))
        }

        evidence.append(AIEvidence(
            source: "ChargingBehaviorInsights",
            reference: "charging-kind",
            summary: "Dominant charging style is \(chargingKindPhrase(dominantKind)) at \(percentString(dominantKindShare)); fast DC share is \(percentString(fastDCShare))."
        ))

        if let high90 {
            evidence.append(AIEvidence(
                source: "ChargingBehaviorInsights",
                reference: "high-soc",
                summary: "SOC-tagged sessions ending at 90%+ account for \(percentString(high90)); 95%+ account for \(percentString(high95 ?? 0))."
            ))
        }

        for sample in samples.prefix(3) {
            let energyText: String = {
                guard let kWh = sample.kWh else { return "kWh unknown" }
                return String(format: "%.1f kWh", kWh)
            }()
            evidence.append(AIEvidence(
                source: sample.sourceLabel,
                reference: sample.sourceReference,
                summary: "\(shortDate(sample.date)) at \(sample.locationName) • \(chargingKindPhrase(sample.chargingKind)) • \(energyText)"
            ))
        }

        return evidence
    }

    private static func ratio(count: Int, total: Int) -> Double? {
        guard total > 0 else { return nil }
        return Double(count) / Double(total)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func percentString(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func chargingKindPhrase(_ kind: ChargingKind) -> String {
        switch kind {
        case .home: return "home charging"
        case .fastDC: return "fast DC charging"
        case .destination: return "destination charging"
        case .unknown: return "unknown charging"
        }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
