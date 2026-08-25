//  ChargingMergeReviewView.swift
//  My KWh Companion
//
//  Review canonical merges and block future merges.
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct ChargingMergeReviewView: View {

    @EnvironmentObject private var teslaFi: TeslaFiSessionStore

    private var mergedCanonicals: [TeslaFiSession] {
        teslaFi.canonicalSessions
            .filter { (teslaFi.integrityMergeMap[$0.id]?.count ?? 1) > 1 }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            Section {
                Text("Canonical sessions are built by merging near-duplicate imported rows. If a merge looks wrong, block it and rebuild.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Merged sessions") {
                if mergedCanonicals.isEmpty {
                    Text("No merges detected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mergedCanonicals) { canonical in
                        NavigationLink {
                            CanonicalMergeDetailView(canonical: canonical)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(canonical.displayLocation)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text("\(canonical.startDate.formatted(date: .abbreviated, time: .shortened)) • \(canonical.energyAddedKWh, specifier: "%.1f") kWh")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(teslaFi.integrityMergeMap[canonical.id]?.count ?? 1)x")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Section("Maintenance") {
                Button(role: .destructive) {
                    teslaFi.clearAllMergeBlocks()
                } label: {
                    Label("Clear all merge blocks", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Review Merges")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { teslaFi.rebuildCanonicalSessions() }
    }
}

@MainActor
fileprivate struct CanonicalMergeDetailView: View {

    @EnvironmentObject private var teslaFi: TeslaFiSessionStore
    let canonical: TeslaFiSession

    private var raw: [TeslaFiSession] {
        teslaFi.rawSessions(forCanonical: canonical.id)
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(canonical.displayLocation).font(.headline)
                    Text("Canonical: \(canonical.startDate.formatted(date: .abbreviated, time: .shortened)) → \(canonical.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Raw sessions merged (\(raw.count))") {
                ForEach(raw) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(s.startDate.formatted(date: .abbreviated, time: .shortened)) → \(s.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline.weight(.semibold))

                        Text("\(s.energyAddedKWh, specifier: "%.3f") kWh • \(s.displayLocation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            if let c = s.cost {
                                Text(String(format: "$%.2f", c))
                                    .font(.caption.weight(.semibold))
                            } else {
                                Text("Missing cost")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }

                            Spacer()

                            Menu("Block merge") {
                                // Block this raw session vs the first raw session (anchor).
                                if let anchor = raw.first, anchor.id != s.id {
                                    Button("Block anchor ↔︎ this session", systemImage: "nosign") {
                                        teslaFi.blockMergeBetween(anchor, and: s)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Merge Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
