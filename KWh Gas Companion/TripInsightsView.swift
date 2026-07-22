import SwiftUI
import Foundation

struct TripInsightsSnapshot: Equatable {
    struct WindowSummary: Equatable, Identifiable {
        let size: Int
        let tripCount: Int
        let totalEnergyKWh: Double
        let totalKnownCost: Double
        let knownCostCount: Int
        let missingCostCount: Int
        let averageEnergyKWh: Double
        let averageKnownCost: Double?
        let averageKnownPricePerKWh: Double?

        var id: Int { size }
    }

    struct SessionExtreme: Equatable {
        let title: String
        let session: TeslaFiSession
    }

    enum TrendDirection: Equatable {
        case up
        case down
        case flat
        case unavailable
    }

    struct LocationMix: Equatable, Identifiable {
        let bucket: Bucket
        let count: Int

        var id: Bucket { bucket }

        enum Bucket: String, Equatable {
            case home
            case work
            case supercharger
            case other

            var title: String {
                switch self {
                case .home: return "Home"
                case .work: return "Work"
                case .supercharger: return "Fast"
                case .other: return "Other"
                }
            }

            var symbol: String {
                switch self {
                case .home: return "house.fill"
                case .work: return "briefcase.fill"
                case .supercharger: return "bolt.car.fill"
                case .other: return "mappin.circle.fill"
                }
            }
        }
    }

    let totalTrips: Int
    let availableWindows: [WindowSummary]
    let selectedWindow: WindowSummary?
    let cheapest: SessionExtreme?
    let mostExpensive: SessionExtreme?
    let locationMix: [LocationMix]
    let trendDirection: TrendDirection
    let trendPercent: Double?
    let trendDescription: String
    let recentSessions: [TeslaFiSession]

    static let empty = TripInsightsSnapshot(
        totalTrips: 0,
        availableWindows: [],
        selectedWindow: nil,
        cheapest: nil,
        mostExpensive: nil,
        locationMix: [],
        trendDirection: .unavailable,
        trendPercent: nil,
        trendDescription: "Import charging sessions to unlock trip insights.",
        recentSessions: []
    )

    static func build(from sessions: [TeslaFiSession], selectedWindow preferredWindow: Int = 10) -> TripInsightsSnapshot {
        let sorted = sessions.sorted { $0.endDate > $1.endDate }
        guard !sorted.isEmpty else { return .empty }

        let windows = [5, 10, 30]
            .filter { sorted.count >= min($0, 3) }
            .map { size in
                let slice = Array(sorted.prefix(size))
                let knownCosts = slice.compactMap(\.cost)
                let totalEnergy = slice.reduce(0.0) { $0 + max(0, $1.energyAddedKWh) }
                let totalKnownCost = knownCosts.reduce(0.0, +)
                let averageEnergy = slice.isEmpty ? 0 : totalEnergy / Double(slice.count)
                let averageKnownCost = knownCosts.isEmpty ? nil : totalKnownCost / Double(knownCosts.count)
                let averageKnownPricePerKWh: Double? = totalEnergy > 0 && !knownCosts.isEmpty
                    ? totalKnownCost / totalEnergy
                    : nil

                return WindowSummary(
                    size: size,
                    tripCount: slice.count,
                    totalEnergyKWh: totalEnergy,
                    totalKnownCost: totalKnownCost,
                    knownCostCount: knownCosts.count,
                    missingCostCount: max(0, slice.count - knownCosts.count),
                    averageEnergyKWh: averageEnergy,
                    averageKnownCost: averageKnownCost,
                    averageKnownPricePerKWh: averageKnownPricePerKWh
                )
            }

        let chosen = windows.first(where: { $0.size == preferredWindow }) ?? windows.first
        let costKnown = sorted.compactMap { session -> (TeslaFiSession, Double)? in
            guard let cost = session.cost else { return nil }
            return (session, cost)
        }
        let cheapest = costKnown.min { $0.1 < $1.1 }.map { SessionExtreme(title: "Cheapest", session: $0.0) }
        let mostExpensive = costKnown.max { $0.1 < $1.1 }.map { SessionExtreme(title: "Most expensive", session: $0.0) }
        let locationMix = buildLocationMix(from: Array(sorted.prefix(max(chosen?.tripCount ?? 0, 10))))
        let trend = buildTrend(from: sorted, windowSize: chosen?.size ?? 10)

        return TripInsightsSnapshot(
            totalTrips: sorted.count,
            availableWindows: windows,
            selectedWindow: chosen,
            cheapest: cheapest,
            mostExpensive: mostExpensive,
            locationMix: locationMix,
            trendDirection: trend.direction,
            trendPercent: trend.percent,
            trendDescription: trend.description,
            recentSessions: Array(sorted.prefix(8))
        )
    }

    private static func buildLocationMix(from sessions: [TeslaFiSession]) -> [LocationMix] {
        var counts: [LocationMix.Bucket: Int] = [:]
        for session in sessions {
            let locationBucket = bucket(for: session)
            counts[locationBucket] = (counts[locationBucket] ?? 0) + 1
        }
        let orderedBuckets: [LocationMix.Bucket] = [.home, .work, .supercharger, .other]
        return orderedBuckets.compactMap { locationBucket in
            guard let count = counts[locationBucket], count > 0 else { return nil }
            return LocationMix(bucket: locationBucket, count: count)
        }
    }

    private static func bucket(for session: TeslaFiSession) -> LocationMix.Bucket {
        let loc = session.displayLocation.lowercased()
        if loc.contains("home") || loc.contains("garage") || loc.contains("house") {
            return .home
        }
        if loc.contains("work") || loc.contains("office") || loc.contains("campus") {
            return .work
        }
        if loc.contains("supercharg") || loc.contains("electrify america") || loc.contains("evgo") || loc.contains("chargepoint") || loc.contains("dcfc") || loc.contains("fast") {
            return .supercharger
        }
        return .other
    }

    private static func buildTrend(from sessions: [TeslaFiSession], windowSize: Int) -> (direction: TrendDirection, percent: Double?, description: String) {
        let size = max(3, min(windowSize, sessions.count))
        let recent = Array(sessions.prefix(size))
        let prior = Array(sessions.dropFirst(size).prefix(size))

        guard !recent.isEmpty else {
            return (.unavailable, nil, "Trip trend appears after a few sessions.")
        }

        let recentKnown = recent.compactMap(\.cost)
        guard !prior.isEmpty else {
            return (.unavailable, nil, "Add a few more sessions to compare against a previous window.")
        }
        guard !recentKnown.isEmpty else {
            return (.unavailable, nil, "Cost trend needs more sessions with known pricing.")
        }

        let priorKnown = prior.compactMap(\.cost)
        guard !priorKnown.isEmpty else {
            return (.unavailable, nil, "Previous trip window has no known pricing yet.")
        }

        let recentAverage = recentKnown.reduce(0.0, +) / Double(recentKnown.count)
        let priorAverage = priorKnown.reduce(0.0, +) / Double(priorKnown.count)
        guard priorAverage > 0 else {
            return (.unavailable, nil, "Previous trip window has no known pricing yet.")
        }

        let delta = ((recentAverage - priorAverage) / priorAverage) * 100
        let rounded = abs(delta.rounded())

        if abs(delta) < 3 {
            return (.flat, delta, "Average trip cost is holding steady versus the previous \(size) sessions.")
        } else if delta > 0 {
            return (.up, delta, "Average trip cost is up \(Int(rounded))% versus the previous \(size) sessions.")
        } else {
            return (.down, delta, "Average trip cost is down \(Int(rounded))% versus the previous \(size) sessions.")
        }
    }
}

@MainActor
struct TripInsightsView: View {
    let sessions: [TeslaFiSession]
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var uiSettings: AppUISettings

    @State private var selectedWindowSize: Int = 10

    private var theme: any AppThemeSpec { themeBox.base }

    private var snapshot: TripInsightsSnapshot {
        TripInsightsSnapshot.build(from: sessions, selectedWindow: selectedWindowSize)
    }

    private let metricColumns = [
        GridItem(.flexible(minimum: 130), spacing: 12),
        GridItem(.flexible(minimum: 130), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                if let selected = snapshot.selectedWindow {
                    heroCard(selected)
                    windowPicker
                    metricGrid(selected)
                    trendCard
                    if snapshot.cheapest != nil || snapshot.mostExpensive != nil {
                        priceExtremesCard
                    }
                    if !snapshot.recentSessions.isEmpty {
                        recentSessionsCard
                    }
                } else {
                    emptyCard
                }
            }
            .padding()
        }
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Trip Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedWindowSize == 10, let fallback = snapshot.selectedWindow?.size {
                selectedWindowSize = fallback
            }
        }
    }

    private func heroCard(_ selected: TripInsightsSnapshot.WindowSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent driving pulse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(snapshotHeadline(for: selected))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                    Text(snapshot.trendDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                trendBadge
            }

            HStack(spacing: 10) {
                heroStat(title: "Trips tracked", value: "\(selected.tripCount)", symbol: "road.lanes")
                heroStat(title: "Total energy", value: "\(number(selected.totalEnergyKWh, digits: 1)) kWh", symbol: "bolt.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Rolling Window", systemImage: "dial.medium")
            Picker("Window", selection: $selectedWindowSize) {
                ForEach(snapshot.availableWindows) { window in
                    Text("\(window.size) trips").tag(window.size)
                }
            }
            .pickerStyle(.segmented)
        }
        .themedCard()
    }

    private func metricGrid(_ selected: TripInsightsSnapshot.WindowSummary) -> some View {
        LazyVGrid(columns: metricColumns, spacing: 12) {
            metricTile(title: "Avg energy", value: "\(number(selected.averageEnergyKWh, digits: 1)) kWh", symbol: "bolt.circle.fill")
            metricTile(title: "Known cost", value: money(selected.totalKnownCost), symbol: "dollarsign.circle.fill")
            metricTile(title: "Avg trip cost", value: selected.averageKnownCost.map(money) ?? "Need pricing", symbol: "car.rear.fill")
            metricTile(title: "Avg price / kWh", value: selected.averageKnownPricePerKWh.map(money) ?? "Need pricing", symbol: "chart.line.uptrend.xyaxis.circle.fill")
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Charging Mix", systemImage: "chart.bar.fill")

            if !snapshot.locationMix.isEmpty {
                HStack(spacing: 10) {
                    ForEach(snapshot.locationMix) { mix in
                        VStack(spacing: 8) {
                            Image(systemName: mix.bucket.symbol)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(theme.accent)
                            Text("\(mix.count)")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                            Text(mix.bucket.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tileBackground)
                    }
                }
            }

            Text(snapshot.trendDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard()
    }

    private var priceExtremesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Price Extremes", systemImage: "sparkles")
            if let cheapest = snapshot.cheapest {
                extremeRow(extreme: cheapest, style: .positive)
            }
            if let mostExpensive = snapshot.mostExpensive {
                extremeRow(extreme: mostExpensive, style: .warning)
            }
        }
        .themedCard()
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recent Sessions", systemImage: "clock.arrow.circlepath")
            ForEach(Array(snapshot.recentSessions.enumerated()), id: \.element.sessionHash) { index, session in
                sessionRow(session)
                if index < snapshot.recentSessions.count - 1 {
                    Divider()
                        .overlay(theme.separator.opacity(scheme == .dark ? 0.45 : 0.28))
                }
            }
        }
        .themedCard()
    }

    private var emptyCard: some View {
        ContentUnavailableView(
            "No Trips Yet",
            systemImage: "car",
            description: Text("Import charging sessions to unlock trip insights.")
        )
        .frame(maxWidth: .infinity)
        .themedCard(prominent: true)
    }

    private var trendBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: trendSymbol(snapshot.trendDirection))
                .font(.caption.weight(.bold))
            Text(trendBadgeText)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(trendColor(snapshot.trendDirection).opacity(scheme == .dark ? 0.22 : 0.14)))
        .foregroundStyle(trendColor(snapshot.trendDirection))
    }

    private var trendBadgeText: String {
        guard let percent = snapshot.trendPercent, snapshot.trendDirection != .unavailable else {
            return "Building trend"
        }
        if snapshot.trendDirection == .flat {
            return "Stable"
        }
        return "\(Int(abs(percent.rounded())))%"
    }

    private func heroStat(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tileBackground)
    }

    private func metricTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(14)
        .background(tileBackground)
    }

    private func extremeRow(extreme: TripInsightsSnapshot.SessionExtreme, style: ExtremeStyle) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(style.tint.opacity(scheme == .dark ? 0.20 : 0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: style.symbol)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(style.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(extreme.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(extreme.session.displayLocation)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(dateTime(extreme.session.endDate)) • \(number(extreme.session.energyAddedKWh, digits: 1)) kWh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(extreme.session.cost.map(money) ?? "Cost unknown")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .padding(14)
        .background(tileBackground)
    }

    private func sessionRow(_ session: TeslaFiSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.pillTint.opacity(scheme == .dark ? 0.28 : 0.62))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: sessionIcon(for: session))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(theme.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayLocation)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(dateTime(session.endDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(number(session.energyAddedKWh, digits: 1)) kWh added")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(session.cost.map(money) ?? "Cost unknown")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(session.cost == nil ? .secondary : .primary)
                    .monospacedDigit()
                if session.cost == nil {
                    capsuleLabel("Needs cost", tint: .orange)
                } else if session.displayLocation.lowercased().contains("supercharg") {
                    capsuleLabel("Fast charge", tint: theme.accent)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func capsuleLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(scheme == .dark ? 0.24 : 0.14)))
            .foregroundStyle(tint)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.pillTint.opacity(scheme == .dark ? 0.18 : 0.56))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.separator.opacity(scheme == .dark ? 0.50 : 0.22), lineWidth: 1)
            )
    }

    private func snapshotHeadline(for selected: TripInsightsSnapshot.WindowSummary) -> String {
        if let averageCost = selected.averageKnownCost {
            return "\(money(averageCost)) per trip"
        }
        return "\(number(selected.averageEnergyKWh, digits: 1)) kWh per trip"
    }

    private func sessionIcon(for session: TeslaFiSession) -> String {
        let name = session.displayLocation.lowercased()
        if name.contains("home") || name.contains("garage") { return "house.fill" }
        if name.contains("work") || name.contains("office") { return "briefcase.fill" }
        if name.contains("supercharg") || name.contains("fast") || name.contains("dcfc") { return "bolt.car.fill" }
        return "mappin.circle.fill"
    }

    private enum ExtremeStyle {
        case positive
        case warning

        var tint: Color {
            switch self {
            case .positive: return .green
            case .warning: return .orange
            }
        }

        var symbol: String {
            switch self {
            case .positive: return "arrow.down.circle.fill"
            case .warning: return "arrow.up.circle.fill"
            }
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    private func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }

    private func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func trendSymbol(_ direction: TripInsightsSnapshot.TrendDirection) -> String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.left.and.right"
        case .unavailable: return "clock"
        }
    }

    private func trendColor(_ direction: TripInsightsSnapshot.TrendDirection) -> Color {
        switch direction {
        case .up: return .orange
        case .down: return .green
        case .flat: return .secondary
        case .unavailable: return .secondary
        }
    }
}
