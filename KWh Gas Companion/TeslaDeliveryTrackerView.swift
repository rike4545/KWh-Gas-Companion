//
//  TeslaDeliveryTrackerView.swift
//  KWh Gas Companion
//
//  Delivery Tracker hub — every tracked order, where each one sits on the
//  delivery ladder, and a combined feed of what changed since the last check.
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct TeslaDeliveryTrackerView: View {

    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var store = TeslaDeliveryOrderStore()

    @State private var showingAdd = false
    @State private var notificationsGranted: Bool?

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                headerCard

                if store.orders.isEmpty {
                    emptyState
                } else {
                    ForEach(store.sortedOrders) { order in
                        NavigationLink {
                            TeslaDeliveryOrderDetailView(orderID: order.id, store: store)
                        } label: {
                            TeslaDeliveryOrderCard(order: order, theme: theme)
                        }
                        .buttonStyle(.plain)
                    }

                    if !store.combinedChangeLog.isEmpty {
                        changeFeedCard
                    }

                    remindersCard
                }

                sourceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Delivery Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Track a new order")
            }
        }
        .sheet(isPresented: $showingAdd) {
            TeslaDeliveryOrderEditor(order: TeslaDeliveryOrder()) { new in
                store.add(new)
            }
        }
        .task {
            notificationsGranted = await TeslaDeliveryOrderStore.notificationsEnabled()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Waiting on a Tesla", systemImage: "shippingbox.and.arrow.backward")
                .font(.headline)

            Text("Track where an order actually sits — order placed through handover — with a journal of every field that moves. Paste the order JSON you pulled from Tesla and it fills itself in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.orders.isEmpty {
                HStack(spacing: 10) {
                    statPill(
                        value: "\(store.activeOrders.count)",
                        label: store.activeOrders.count == 1 ? "active order" : "active orders"
                    )
                    if let soonest = soonestCountdown {
                        statPill(value: soonest, label: "next up")
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    /// The nearest window start across active orders, for the header pill.
    private var soonestCountdown: String? {
        store.activeOrders
            .compactMap { order -> (Int, String)? in
                guard let days = order.daysUntilWindowStart ?? order.daysUntilWindowEnd else { return nil }
                return (days, order.countdownText)
            }
            .filter { $0.0 >= 0 }
            .min { $0.0 < $1.0 }?
            .1
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.pillTint.opacity(0.30), in: RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            ContentUnavailableView(
                "No orders tracked",
                systemImage: "shippingbox",
                description: Text("Add your order to start the countdown and the change journal.")
            )

            Button {
                showingAdd = true
            } label: {
                Label("Track an order", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Change feed

    private var changeFeedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What changed", systemImage: "clock.arrow.2.circlepath")
                .font(.headline)

            ForEach(Array(store.combinedChangeLog.prefix(6).enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(row.order.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text(row.entry.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(changeLine(row.entry))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.separator.opacity(0.35)).frame(height: 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func changeLine(_ entry: DeliveryChangeLogEntry) -> String {
        entry.isFirstAppearance
            ? "\(entry.field): \(entry.newDisplay)"
            : "\(entry.field): \(entry.oldDisplay) → \(entry.newDisplay)"
    }

    // MARK: - Reminders

    @ViewBuilder
    private var remindersCard: some View {
        if notificationsGranted == false {
            VStack(alignment: .leading, spacing: 8) {
                Label("Turn on delivery reminders", systemImage: "bell.badge")
                    .font(.headline)
                Text("Get a nudge a week before your window opens, on the day it opens, the night before a delivery appointment, and if the window passes with no car.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        let granted = await TeslaDeliveryOrderStore.requestNotificationAuthorization()
                        notificationsGranted = granted
                        if granted { store.refreshAllReminders() }
                    }
                } label: {
                    Text("Enable reminders")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    // MARK: - Provenance

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Where the data comes from", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))

            Text("""
            This app does not sign in to Tesla to read your order. Order data lives on Tesla's private first-party endpoints, which are not part of the public Fleet API, so everything here is either entered by you or pasted in from a payload you pulled yourself.

            Nothing you enter leaves this device.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

// MARK: - Order card

@MainActor
struct TeslaDeliveryOrderCard: View {

    let order: TeslaDeliveryOrder
    let theme: any AppThemeSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(order.displayName)
                    .font(.headline)
                Spacer()
                if order.isComplete {
                    Label("Delivered", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if order.isWindowOverdue {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Text(order.countdownText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(order.isWindowOverdue ? .orange : theme.accent)

            DeliveryStageBar(stage: order.stage, theme: theme)

            HStack(spacing: 6) {
                Image(systemName: order.stage.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(order.stage.title)
                    .font(.footnote.weight(.semibold))
                Spacer()
                if order.hasVIN {
                    Text(order.vin.suffix(6))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if !order.spec.oneLine.isEmpty {
                Text(order.spec.oneLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .contentShape(Rectangle())
    }
}

// MARK: - Stage bar

/// Nine segments, filled up to the current stage. Compact enough for a card and
/// readable enough to tell two orders apart at a glance.
struct DeliveryStageBar: View {

    let stage: DeliveryStage
    let theme: any AppThemeSpec

    var body: some View {
        HStack(spacing: 3) {
            ForEach(DeliveryStage.allCases) { candidate in
                Capsule()
                    .fill(candidate.step <= stage.step ? theme.accent : theme.separator.opacity(0.35))
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Stage \(stage.step + 1) of \(DeliveryStage.allCases.count): \(stage.title)")
    }
}
