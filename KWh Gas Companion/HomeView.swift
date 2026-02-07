//
//  HomeView.swift
//  KWh Gas Companion
//
//  Home hub — smooth + data-aware
//  Uses TeslaFiSessionManager via @EnvironmentObject (NOT dynamic member lookup)
//

import SwiftUI

@MainActor
struct HomeView: View {

    @EnvironmentObject private var teslaFiManager: TeslaFiSessionManager
    @EnvironmentObject private var entriesStore: EntriesStore   // if you have it; if not, remove these 2 lines + sections that reference it

    @State private var showSessionAnalytics = false
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                nextUpCard

                teslaFiCard

                entriesCard
            }
            .padding()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showImport = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            NavigationStack {
                TeslaFiCSVImportView()
            }
        }
        .sheet(isPresented: $showSessionAnalytics) {
            NavigationStack {
                SessionAnalyticsView()
                    .environmentObject(teslaFiManager) // SessionAnalyticsView expects TeslaFiSessionStore by default; if you used init(sessions:) you can adjust
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KWh Gas Companion")
                .font(.title2.weight(.semibold))
            Text("Charging + costs, with quick insights and clean data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Next Up (sentience)

    private var nextUpCard: some View {
        let sessionCount = teslaFiManager.sessions.count
        let missingCost = teslaFiManager.missingCostCount

        let suggested: [String] = {
            var out: [String] = []

            if sessionCount == 0 {
                out.append("Import TeslaFi sessions to unlock analytics and trends.")
            } else {
                out.append("You have \(sessionCount) session(s) loaded.")
            }

            if missingCost > 0 {
                out.append("Add missing costs to \(missingCost) session(s) to improve accuracy.")
            }

            // EntriesStore (optional)
            if let snapshot = entriesSnapshot, snapshot.count == 0, sessionCount > 0 {
                out.append("You have TeslaFi data, but no saved charging entries yet — consider converting sessions to entries.")
            }

            return out
        }()

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Next Up")
                        .font(.headline)
                    Spacer()
                    Text("Smart hints")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if suggested.isEmpty {
                    Label("Everything looks good.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(suggested, id: \.self) { s in
                        Label(s, systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - TeslaFi

    private var teslaFiCard: some View {
        let count = teslaFiManager.sessions.count
        let totalKWh = teslaFiManager.totalEnergyAddedKWh
        let totalCost = teslaFiManager.totalCostUSD

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("TeslaFi Sessions", systemImage: "bolt.car")
                        .font(.headline)
                    Spacer()
                    Text("\(count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if count == 0 {
                    Text("No sessions imported yet.")
                        .foregroundStyle(.secondary)

                    Button {
                        showImport = true
                    } label: {
                        Label("Import TeslaFi CSV", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    HStack(spacing: 12) {
                        stat("Energy", "\(fmtNumber(totalKWh, digits: 1)) kWh")
                        stat("Cost", fmtCurrency(totalCost))
                    }

                    Button {
                        // If your SessionAnalyticsView uses init(sessions:), use that instead of sheet env injection.
                        showSessionAnalytics = true
                    } label: {
                        Label("View Analytics", systemImage: "chart.bar.xaxis")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Entries (optional)

    private var entriesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Saved Entries", systemImage: "tray.full")
                        .font(.headline)
                    Spacer()
                    Text("\(entriesSnapshot?.count ?? 0)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let snap = entriesSnapshot, snap.count > 0 {
                    HStack(spacing: 12) {
                        stat("Energy", "\(fmtNumber(snap.energyKWh, digits: 1)) kWh")
                        stat("Cost", fmtCurrency(snap.cost))
                    }
                } else {
                    Text("No saved entries yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var entriesSnapshot: (count: Int, energyKWh: Double, cost: Double)? {
        // If your EntriesStore differs, adapt this.
        // The key idea: do NOT use reflection; read the typed store.
        let items = entriesStore.entries
        let charging = items.filter { $0.isEnergyEffective }
        let energy = charging.reduce(into: 0.0) { $0 += max(0, $1.energyAddedKWh ?? 0) }
        let cost = charging.reduce(into: 0.0) { $0 += max(0, $1.amount) }
        return (charging.count, energy, cost)
    }

    // MARK: - Small UI helpers

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmtNumber(_ v: Double, digits: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func fmtCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }
}
