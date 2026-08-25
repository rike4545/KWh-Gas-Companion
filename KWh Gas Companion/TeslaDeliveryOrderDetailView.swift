//
//  TeslaDeliveryOrderDetailView.swift
//  KWh Gas Companion
//
//  One order in full — stage ladder, the facts Tesla exposes, the decoded VIN
//  and build sheet, and the change journal.
//
//  Swift 6 • iOS 17+
//

import SwiftUI

@MainActor
struct TeslaDeliveryOrderDetailView: View {

    let orderID: UUID
    @ObservedObject var store: TeslaDeliveryOrderStore

    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditor = false
    @State private var showingImport = false
    @State private var showingDeleteConfirm = false
    @State private var shareVIN = false

    private var theme: any AppThemeSpec { themeBox.base }
    private var order: TeslaDeliveryOrder? { store.order(id: orderID) }

    var body: some View {
        Group {
            if let order {
                content(order)
            } else {
                ContentUnavailableView(
                    "Order removed",
                    systemImage: "shippingbox",
                    description: Text("This order is no longer being tracked.")
                )
            }
        }
        .navigationTitle(order?.displayName ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEditor = true } label: {
                        Label("Edit order", systemImage: "pencil")
                    }
                    Button { showingImport = true } label: {
                        Label("Paste order JSON", systemImage: "doc.on.clipboard")
                    }
                    if let order, !order.isComplete {
                        Button { markDelivered(order) } label: {
                            Label("Mark delivered", systemImage: "checkmark.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Stop tracking", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let order {
                TeslaDeliveryOrderEditor(order: order) { updated in
                    store.update(updated)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            if let order {
                TeslaOrderJSONImportSheet(order: order) { updated in
                    store.update(updated)
                }
            }
        }
        .confirmationDialog(
            "Stop tracking this order?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop tracking", role: .destructive) {
                store.delete(id: orderID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The change journal for this order is deleted too.")
        }
    }

    // MARK: - Content

    private func content(_ order: TeslaDeliveryOrder) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                heroCard(order)
                stageLadder(order)

                if order.stage.step >= DeliveryStage.inTransit.step && !order.isComplete {
                    checklistLink(order)
                }

                factsCard(order)

                if order.hasVIN, let decoded = order.decodedVIN {
                    vinCard(order, decoded: decoded)
                }

                if !order.spec.isEmpty {
                    buildSheetCard(order)
                }

                if !order.statusDescription.raw.isEmpty {
                    statusCard(order)
                }

                if !order.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesCard(order)
                }

                journalCard(order)
                shareCard(order)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: Hero

    private func heroCard(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(order.countdownText)
                .font(.title2.weight(.bold))
                .foregroundStyle(order.isWindowOverdue ? .orange : theme.accent)
                .fixedSize(horizontal: false, vertical: true)

            if !order.deliveryWindowDisplay.isEmpty {
                Label(order.deliveryWindowDisplay, systemImage: "calendar")
                    .font(.subheadline)
            }

            DeliveryStageBar(stage: order.stage, theme: theme)

            HStack(spacing: 12) {
                if let days = order.daysSinceOrder {
                    heroStat("\(days)", "days since order")
                }
                heroStat("\(order.stage.step + 1)/\(DeliveryStage.allCases.count)", "stage")
                if let checked = order.lastCheckedAt {
                    heroStat(relative(checked), "last checked")
                }
            }

            if order.isWindowOverdue {
                Text("The window has closed without a delivery. Tesla usually issues a new one — a message to your advisor tends to shake it loose faster than waiting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Stage ladder

    private func stageLadder(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Delivery stages", systemImage: "list.bullet.indent")
                    .font(.headline)
                Spacer()
                if order.stageOverride != nil {
                    Text("Set manually")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(theme.pillTint.opacity(0.4), in: Capsule())
                }
            }

            ForEach(DeliveryStage.allCases) { candidate in
                stageRow(candidate, current: order.stage)
            }

            Text("Tesla publishes no stage machine — these are inferred from which fields have appeared on the order. Signal for the current stage: \(order.stage.signal).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func stageRow(_ candidate: DeliveryStage, current: DeliveryStage) -> some View {
        let isPast = candidate.step < current.step
        let isCurrent = candidate == current

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: isPast ? "checkmark.circle.fill" : (isCurrent ? candidate.systemImage : "circle"))
                    .font(.subheadline)
                    .foregroundStyle(isPast ? .green : (isCurrent ? theme.accent : Color.secondary.opacity(0.5)))
                    .frame(width: 22)

                if candidate != DeliveryStage.allCases.last {
                    Rectangle()
                        .fill(isPast ? Color.green.opacity(0.5) : theme.separator.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(minHeight: isCurrent ? 34 : 18)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    .foregroundStyle(isCurrent ? .primary : (isPast ? .primary : .secondary))

                if isCurrent {
                    Text(candidate.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isCurrent ? 6 : 2)

            Spacer(minLength: 0)
        }
    }

    // MARK: Checklist hand-off

    /// Surfaced once the car is physically moving — that's the point at which
    /// reading the inspection list stops being premature.
    private func checklistLink(_ order: TeslaDeliveryOrder) -> some View {
        NavigationLink {
            DeliveryChecklistView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Delivery Day Checklist")
                        .font(.subheadline.weight(.semibold))
                    Text(order.deliveryAppointment == nil
                         ? "Worth reading through before the appointment lands."
                         : "Your appointment is set — run this before you sign anything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Facts

    private func factsCard(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Order details", systemImage: "doc.text")
                .font(.headline)

            factRow("Model", order.modelName)
            if !order.trim.isEmpty { factRow("Trim", order.trim) }
            if !order.referenceNumber.isEmpty { factRow("Reference", order.referenceNumber, monospaced: true) }
            if order.hasVIN { factRow("VIN", order.vin, monospaced: true) }
            if let date = order.reservationDate { factRow("Ordered", date.formatted(date: .abbreviated, time: .omitted)) }
            if let date = order.orderBookedDate { factRow("Booked", date.formatted(date: .abbreviated, time: .omitted)) }
            if !order.deliveryWindowDisplay.isEmpty { factRow("Delivery window", order.deliveryWindowDisplay) }
            if !order.etaToDeliveryCenter.isEmpty { factRow("ETA to center", order.etaToDeliveryCenter) }
            if !order.routingLocation.isEmpty { factRow("Routing location", order.routingLocation) }
            if !order.deliveryAppointmentText.isEmpty { factRow("Appointment", order.deliveryAppointmentText) }

            if let odometer = order.odometer {
                let unit = order.odometerUnit.isEmpty ? "" : " \(order.odometerUnit.lowercased())"
                factRow("Odometer", "\(TeslaDeliveryOrder.trimmedNumber(odometer))\(unit)")

                if odometer > 0 {
                    Text("A non-zero odometer means the car has been built and driven — factory to rail, or rail to lot. It's the earliest hard proof the vehicle physically exists.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func factRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(monospaced ? .footnote.monospaced() : .footnote.weight(.medium))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: VIN

    private func vinCard(_ order: TeslaDeliveryOrder, decoded: TeslaVINInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Decoded VIN", systemImage: "number.square")
                .font(.headline)

            factRow("Plant", decoded.plant)
            if let year = decoded.modelYear { factRow("Model year", String(year)) }
            factRow("Series", decoded.series)
            factRow("Body", decoded.bodyType)
            factRow("Battery", decoded.fuelType)
            factRow("Drive unit", decoded.motorType)
            factRow("Sequence", decoded.serial, monospaced: true)

            Text("Production sequence rises over time within a plant — it's the number owners compare when guessing where they sit in a build run.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Build sheet

    private func buildSheetCard(_ order: TeslaDeliveryOrder) -> some View {
        let spec = order.spec

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Build sheet", systemImage: "list.clipboard")
                    .font(.headline)
                Spacer()
                Text("\(spec.recognizedCount)/\(spec.items.count) decoded")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(spec.categories) { category in
                VStack(alignment: .leading, spacing: 5) {
                    Label(category.rawValue, systemImage: category.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)

                    ForEach(spec.items(in: category)) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 62, alignment: .leading)
                            Text(item.label)
                                .font(.footnote)
                                .foregroundStyle(item.isRecognized ? .primary : .secondary)
                                .italic(!item.isRecognized)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Tesla has never published its option codes. These are community-mapped and get reused between refreshes — treat the build sheet as a strong hint, and the window sticker as the record.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Status

    private func statusCard(_ order: TeslaDeliveryOrder) -> some View {
        let status = order.statusDescription

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Order status", systemImage: "circle.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text(status.raw)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(theme.pillTint.opacity(0.4), in: Capsule())
            }

            Text(status.label)
                .font(.subheadline.weight(.semibold))

            Text(status.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Notes

    private func notesCard(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
            Text(order.notes)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Journal

    private func journalCard(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Change journal", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                Spacer()
                Text("\(order.changeLog.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if order.changeLog.isEmpty {
                Text("Nothing logged yet. Every time you edit a tracked field or paste a fresh payload, the old and new values land here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(order.changeLog.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(entry.field)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if entry.isFirstAppearance {
                            Text(entry.newDisplay)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(entry.oldDisplay)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .strikethrough(true, color: .secondary)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                Text(entry.newDisplay)
                                    .font(.footnote.weight(.medium))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(theme.separator.opacity(0.3)).frame(height: 0.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Share

    private func shareCard(_ order: TeslaDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Share your status", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text(order.forumSummary(includeVIN: shareVIN))
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.pillTint.opacity(0.22), in: RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous))

            Toggle("Include full VIN", isOn: $shareVIN)
                .font(.footnote)

            Text("The reference number is never included — it identifies your order to anyone who has it. Without the VIN toggle, only the plant and model year go out.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: order.forumSummary(includeVIN: shareVIN)) {
                Label("Share summary", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: Actions

    private func markDelivered(_ order: TeslaDeliveryOrder) {
        var updated = order
        updated.stageOverride = .delivered
        if updated.orderStatusCode.isEmpty { updated.orderStatusCode = "DELIVERED" }
        store.update(updated)
    }
}
