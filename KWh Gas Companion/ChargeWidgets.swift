//
//  ChargeWidgets.swift
//  KWh Gas Companion
//
//  NOTE: Add this file to a Widget Extension target.
//

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import ActivityKit

struct ChargeActivityWidget: Widget {
    let kind: String = "ChargeActivityWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargeActivityAttributes.self) { context in
            ChargeLiveActivityView(context: context)
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

struct ChargeStatusWidget: Widget {
    let kind: String = "ChargeStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeStatusProvider()) { entry in
            ChargeStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Charging Status")
        .description("Charging status, battery, and cost.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ChargeStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: ChargeWidgetSnapshot?
}

struct ChargeStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeStatusEntry {
        ChargeStatusEntry(date: .now, snapshot: ChargeWidgetSnapshot(
            vehicleName: "Vehicle",
            batteryLevel: 64,
            chargingState: "Charging",
            energyAddedKWh: 12.4,
            cost: 3.86,
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeStatusEntry) -> Void) {
        completion(ChargeStatusEntry(date: .now, snapshot: ChargeWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeStatusEntry>) -> Void) {
        let entry = ChargeStatusEntry(date: .now, snapshot: ChargeWidgetStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ChargeStatusWidgetView: View {
    let entry: ChargeStatusEntry

    var body: some View {
        let snapshot = entry.snapshot
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot?.vehicleName ?? "Charging")
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

struct ChargeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChargeStatusWidget()
        ChargeActivityWidget()
    }
}

struct ChargeLiveActivityView: View {
    let context: ActivityViewContext<ChargeActivityAttributes>

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
