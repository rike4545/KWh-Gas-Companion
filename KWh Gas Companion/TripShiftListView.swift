//
//  TripShiftListView.swift
//  My KWh Companion
//
//  Complete replacement — smoother filtering/sorting for large session lists,
//  and a more "sentient" summary strip (missing-cost detection + avg price).
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct TripShiftListView: View {

    /// Charging sessions (TeslaFi import sessions, etc.)
    var sessions: [TeslaFiSession]

    /// Optional row tap callback
    var onSelect: ((TeslaFiSession) -> Void)? = nil

    /// When embedded inside another screen (e.g., HomeView), keep this false to avoid
    /// clobbering the parent Navigation title.
    var showsNavigationTitle: Bool = false

    // UI
    @State private var search: String = ""
    @State private var sortNewestFirst: Bool = true
    @State private var onlyMissingCost: Bool = false

    // Computed (memoized)
    @State private var computed: [TeslaFiSession] = []
    @State private var metrics: Metrics = .empty
    @State private var computeTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?
    @StateObject private var adsStore = AdsEntitlementStore.shared

    var body: some View {
        if showsNavigationTitle {
            content
                .navigationTitle("Charging Sessions")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            header
            controls

            if computed.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .onAppear { scheduleRecompute(debounce: false) }
        .onChange(of: sessions) { _, _ in scheduleRecompute(debounce: false) }
        .onChange(of: sortNewestFirst) { _, _ in scheduleRecompute(debounce: false) }
        .onChange(of: onlyMissingCost) { _, _ in scheduleRecompute(debounce: false) }
        .onChange(of: search) { _, _ in scheduleRecompute(debounce: true) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Charging Sessions")
                    .font(.title3).bold()

                Spacer()

                Text("\(metrics.shownCount)/\(metrics.totalCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                summaryPill(title: "Energy", value: fmt0(metrics.energyShown) + " kWh")
                summaryPill(title: "Cost", value: money(metrics.costKnownShown))
                summaryPill(title: "Missing cost", value: "\(metrics.missingCostShown)")
                if let avg = metrics.avgPricePerKWhShown {
                    summaryPill(title: "Avg $/kWh", value: avg.formatted(.number.precision(.fractionLength(3))))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).bold().monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search location…", text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)

                if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )

            HStack(spacing: 14) {
                Toggle(isOn: $onlyMissingCost) {
                    Text("Missing cost only")
                        .font(.footnote)
                }
                .toggleStyle(.switch)

                Spacer()

                Button {
                    sortNewestFirst.toggle()
                } label: {
                    Label(sortNewestFirst ? "Newest" : "Oldest",
                          systemImage: sortNewestFirst ? "arrow.down" : "arrow.up")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(computed, id: \.id) { s in
                    Button {
                        onSelect?(s)
                    } label: {
                        SessionRow(session: s)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                        .padding(.top, 8)
                }
            }
            .padding(.top, 4)
        }
        .task { await adsStore.load() }
    }

    private struct SessionRow: View {
        let session: TeslaFiSession

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(locationText(session))
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(energyText(session))
                        .font(.subheadline)
                        .monospacedDigit()
                }

                HStack(spacing: 10) {
                    Text(timeRangeText(session))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("• \(durationText(session))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let cost = session.cost {
                        Text(cost.formatted(.currency(code: currencyCode)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        Text("Cost unknown")
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.12))
                            )
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
        }

        private static var currencyCode: String {
            Locale.current.currency?.identifier ?? "USD"
        }
        private var currencyCode: String { Self.currencyCode }

        private func locationText(_ s: TeslaFiSession) -> String {
            let trimmed = (s.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unknown location" : trimmed
        }

        private func energyText(_ s: TeslaFiSession) -> String {
            "\(s.energyAddedKWh.formatted(.number.precision(.fractionLength(1)))) kWh"
        }

        private func timeRangeText(_ s: TeslaFiSession) -> String {
            // Short + readable: Dec 14, 9:12–10:01
            let start = s.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            let end = s.endDate.formatted(.dateTime.hour().minute())
            return "\(start)–\(end)"
        }

        private func durationText(_ s: TeslaFiSession) -> String {
            let sec = max(0, s.endDate.timeIntervalSince(s.startDate))
            let minutes = Int((sec / 60).rounded())
            if minutes >= 60 {
                let h = minutes / 60
                let m = minutes % 60
                return "\(h)h \(m)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.car")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No sessions match your filters.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text("Import Tesla CSV or charging-session history to populate this list.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Compute (debounced + off-main)

    private func scheduleRecompute(debounce: Bool) {
        debounceTask?.cancel()
        if debounce {
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                recomputeNow()
            }
        } else {
            recomputeNow()
        }
    }

    private func recomputeNow() {
        computeTask?.cancel()

        let all = sessions
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortNewest = sortNewestFirst
        let missingOnly = onlyMissingCost

        computeTask = Task(priority: .userInitiated) { [all, q, sortNewest, missingOnly] in
            var items = all

            if missingOnly {
                items = items.filter { $0.cost == nil }
            }

            if !q.isEmpty {
                let needle = q.lowercased()
                items = items.filter {
                    (($0.location ?? "").lowercased()).contains(needle)
                }
            }

            items.sort { a, b in
                sortNewest ? (a.startDate > b.startDate) : (a.startDate < b.startDate)
            }

            let m = Metrics.compute(all: all, shown: items)

            if Task.isCancelled { return }
            let computedItems = items
            await MainActor.run {
                self.computed = computedItems
                self.metrics = m
            }
        }
    }

    // MARK: - Format helpers

    private func fmt0(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0)))
    }

    private func money(_ v: Double) -> String {
        v.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    // MARK: - Metrics

    private struct Metrics: Equatable {
        var totalCount: Int
        var shownCount: Int
        var energyShown: Double
        var costKnownShown: Double
        var missingCostShown: Int
        var avgPricePerKWhShown: Double?

        static let empty = Metrics(
            totalCount: 0,
            shownCount: 0,
            energyShown: 0,
            costKnownShown: 0,
            missingCostShown: 0,
            avgPricePerKWhShown: nil
        )

        static func compute(all: [TeslaFiSession], shown: [TeslaFiSession]) -> Metrics {
            var energy: Double = 0
            var costKnown: Double = 0
            var missingCost = 0
            var priceSum: Double = 0
            var priceCount: Int = 0

            for s in shown {
                energy += max(0, s.energyAddedKWh)
                if let c = s.cost {
                    costKnown += max(0, c)
                    let kwh = max(0.000_1, s.energyAddedKWh)
                    priceSum += c / kwh
                    priceCount += 1
                } else {
                    missingCost += 1
                }
            }

            return Metrics(
                totalCount: all.count,
                shownCount: shown.count,
                energyShown: energy,
                costKnownShown: costKnown,
                missingCostShown: missingCost,
                avgPricePerKWhShown: priceCount > 0 ? (priceSum / Double(priceCount)) : nil
            )
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripShiftListView(
            sessions: [
                TeslaFiSession(
                    startDate: Date().addingTimeInterval(-7200),
                    endDate: Date().addingTimeInterval(-6600),
                    energyAddedKWh: 18.4,
                    cost: 6.21,
                    location: "Lake Grove, NY",
                    raw: [:]
                ),
                TeslaFiSession(
                    startDate: Date().addingTimeInterval(-86400 - 3600),
                    endDate: Date().addingTimeInterval(-86400 - 3300),
                    energyAddedKWh: 9.2,
                    cost: nil,
                    location: nil,
                    raw: [:]
                )
            ],
            showsNavigationTitle: true
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
