//
//  DriveSession.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/24/25.
//

import SwiftUI
import Foundation

/// Represents a single drive session between two odometer readings
struct DriveSession: Identifiable, Hashable {
    /// String ID so we can derive it from UUID/String entry identifiers reliably.
    let id: String
    let date: Date
    let distance: Double // miles
    let energyUsed: Double // kWh

    var efficiencyMiPerKWh: Double? {
        guard energyUsed > 0 else { return nil }
        return distance / energyUsed
    }
}

@MainActor
struct HyperDriveAnalyticsView: View {
    @EnvironmentObject private var entriesStore: EntriesStore
    @EnvironmentObject private var profileStore: ProfileStore

    /// Builds drive sessions by pairing sequential odometer entries for the selected vehicle
    private var sessions: [DriveSession] {
        guard let vehicleKey = key(from: profileStore.selectedVehicleID) else { return [] }

        // Pull into locals to keep the type-checker happy
        let allEntries = entriesStore.entries

        // Filter for vehicle + odometer present
        let candidates = allEntries.filter { e in
            guard let eVehicleKey = key(from: e.vehicleID) else { return false }
            return eVehicleKey == vehicleKey && e.odometer != nil
        }

        // Sort ascending
        let sorted = candidates.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return [] }

        // Build sessions in a simple loop (compiler-friendly)
        var out: [DriveSession] = []
        out.reserveCapacity(sorted.count - 1)

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let next = sorted[i]

            guard let prevOdo = prev.odometer, let nextOdo = next.odometer else { continue }

            let delta = nextOdo - prevOdo
            guard delta >= 0 else { continue } // ignore resets / bad data

            let distance = delta.rounded()
            let energy = next.energyKWh ?? 0

            // Prefer entry id as session id; fall back to date-based key
            let sid = key(from: next.id) ?? "drive-\(Int(next.date.timeIntervalSince1970))"

            out.append(
                DriveSession(
                    id: sid,
                    date: next.date,
                    distance: distance,
                    energyUsed: energy
                )
            )
        }

        return out
    }

    private var recentSessions: [DriveSession] {
        // Force concrete Array type so ForEach is never ambiguous
        Array(sessions.suffix(5).reversed())
    }

    private var totalMiles: Double {
        sessions.reduce(0) { $0 + $1.distance }
    }

    private var totalEnergy: Double {
        sessions.reduce(0) { $0 + $1.energyUsed }
    }

    private var averageEfficiencyText: String {
        guard totalEnergy > 0 else { return "—" }
        let avg = totalMiles / totalEnergy
        return String(format: "%.2f mi/kWh", avg)
    }

    var body: some View {
        Form {
            if profileStore.selectedVehicleID == nil {
                ContentUnavailableView(
                    "No Vehicle Selected",
                    systemImage: "car",
                    description: Text("Select a current vehicle in Garage to see driving analytics.")
                )
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "Not Enough Data Yet",
                    systemImage: "speedometer",
                    description: Text("Add at least two entries with odometer readings for the current vehicle to generate drive sessions.")
                )
            } else {
                Section(header: Text("Driving Efficiency")) {
                    statRow(title: "Avg. Efficiency", value: averageEfficiencyText)
                    statRow(title: "Total Sessions", value: "\(sessions.count)")
                    statRow(title: "Total Miles", value: String(format: "%.0f mi", totalMiles))
                    statRow(title: "Total Energy", value: String(format: "%.1f kWh", totalEnergy))
                }

                Section(header: Text("Recent Drives")) {
                    ForEach(recentSessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.date, style: .date)

                            let summary = String(format: "%.1f mi, %.1f kWh", session.distance, session.energyUsed)
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let eff = session.efficiencyMiPerKWh {
                                Text(String(format: "%.2f mi/kWh", eff))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Driving Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - ID normalization

    /// Returns a stable string key for UUID/UUID?/String/String? and unwraps Optionals boxed as Any.
    private func key(from value: Any?) -> String? {
        guard let value else { return nil }

        // Unwrap Optional<Wrapped> that arrives boxed as Any
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return key(from: child.value)
            } else {
                return nil
            }
        }

        if let uuid = value as? UUID {
            return uuid.uuidString.lowercased()
        }

        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let u = UUID(uuidString: trimmed) {
                return u.uuidString.lowercased()
            }
            return trimmed
        }

        if let h = value as? AnyHashable {
            // Try UUID-ish normalization if the description is a UUID
            let d = String(describing: h)
            if let u = UUID(uuidString: d) {
                return u.uuidString.lowercased()
            }
            return d
        }

        // Last resort: stable-ish textual key
        return String(describing: value)
    }
}
