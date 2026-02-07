//
//  TeslaMateWidgets.swift
//  KWh Gas Companion
//
//  NOTE: Add this file to a Widget Extension target.
//

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import ActivityKit

struct TeslaMateChargeWidget: Widget {
    let kind: String = "TeslaMateChargeWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeslaMateChargeAttributes.self) { context in
            TeslaMateLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.vehicleName)
                            .font(.caption.weight(.semibold))
                        Text("\(context.state.batteryLevel)%")
                            .font(.title3.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.chargingState.capitalized)
                            .font(.caption)
                        if let energy = context.state.energyAddedKWh {
                            Text("\(String(format: "%.1f", energy)) kWh")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let cost = context.state.cost {
                            Text("$\(String(format: "%.2f", cost))")
                                .font(.caption.weight(.semibold))
                        }
                        Spacer()
                        Text("Charging")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text("\(context.state.batteryLevel)%")
            } compactTrailing: {
                Image(systemName: "bolt.fill")
            } minimal: {
                Image(systemName: "bolt.fill")
            }
        }
    }
}

struct TeslaMateStatusWidget: Widget {
    let kind: String = "TeslaMateStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TeslaMateStatusProvider()) { entry in
            TeslaMateStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("TeslaMate Status")
        .description("Charging status, battery, and cost.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TeslaMateStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: TeslaMateWidgetSnapshot?
}

struct TeslaMateStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TeslaMateStatusEntry {
        TeslaMateStatusEntry(date: .now, snapshot: TeslaMateWidgetSnapshot(
            vehicleName: "Tesla",
            batteryLevel: 64,
            chargingState: "Charging",
            energyAddedKWh: 12.4,
            cost: 3.86,
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (TeslaMateStatusEntry) -> Void) {
        completion(TeslaMateStatusEntry(date: .now, snapshot: TeslaMateWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TeslaMateStatusEntry>) -> Void) {
        let entry = TeslaMateStatusEntry(date: .now, snapshot: TeslaMateWidgetStore.load())
        // Refresh every 15 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TeslaMateStatusWidgetView: View {
    let entry: TeslaMateStatusEntry

    var body: some View {
        let snapshot = entry.snapshot
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot?.vehicleName ?? "TeslaMate")
                .font(.headline)
            Text(snapshot?.chargingState ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.map { "\($0.batteryLevel)%" } ?? "—")
                    .font(.title2.weight(.bold))
                Spacer()
                if let cost = snapshot?.cost {
                    Text("$\(String(format: "%.2f", cost))")
                        .font(.caption.weight(.semibold))
                }
            }

            if let energy = snapshot?.energyAddedKWh {
                Text("\(String(format: "%.1f", energy)) kWh added")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct TeslaMateWidgetBundle: WidgetBundle {
    var body: some Widget {
        TeslaMateStatusWidget()
        TeslaMateChargeWidget()
    }
}

struct TeslaMateLiveActivityView: View {
    let context: ActivityViewContext<TeslaMateChargeAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.vehicleName)
                    .font(.headline)
                Text(context.state.chargingState.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(context.state.batteryLevel)%")
                    .font(.title2.weight(.bold))
                if let energy = context.state.energyAddedKWh {
                    Text("\(String(format: "%.1f", energy)) kWh")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#endif
