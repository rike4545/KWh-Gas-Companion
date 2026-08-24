//
//  TeslaDeliveryOrderEditor.swift
//  KWh Gas Companion
//
//  Manual order entry, and the paste-in importer for a Tesla order payload the
//  owner pulled themselves.
//
//  Swift 6 • iOS 17+
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Editor

@MainActor
struct TeslaDeliveryOrderEditor: View {

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TeslaDeliveryOrder
    @State private var optionCodesText: String
    @State private var odometerText: String

    @State private var hasReservationDate: Bool
    @State private var hasBookedDate: Bool
    @State private var hasAppointment: Bool

    @State private var showingImport = false

    private let isNew: Bool
    private let onSave: (TeslaDeliveryOrder) -> Void

    init(order: TeslaDeliveryOrder, onSave: @escaping (TeslaDeliveryOrder) -> Void) {
        _draft = State(initialValue: order)
        _optionCodesText = State(initialValue: order.optionCodes.joined(separator: ", "))
        _odometerText = State(initialValue: order.odometer.map { TeslaDeliveryOrder.trimmedNumber($0) } ?? "")
        _hasReservationDate = State(initialValue: order.reservationDate != nil)
        _hasBookedDate = State(initialValue: order.orderBookedDate != nil)
        _hasAppointment = State(initialValue: order.deliveryAppointment != nil)
        self.isNew = order.referenceNumber.isEmpty && order.vin.isEmpty && order.modelCode.isEmpty
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        Button {
                            showingImport = true
                        } label: {
                            Label("Paste order JSON instead", systemImage: "doc.on.clipboard")
                        }
                    } footer: {
                        Text("If you already pulled your order payload from Tesla, paste it and every field below fills itself in.")
                    }
                }

                Section("Vehicle") {
                    TextField("Nickname (optional)", text: $draft.nickname)

                    Picker("Model", selection: $draft.modelCode) {
                        Text("Not set").tag("")
                        ForEach(TeslaModelCatalog.pickerOptions, id: \.code) { option in
                            Text(option.name).tag(option.code)
                        }
                    }

                    TextField("Trim (e.g. Long Range AWD)", text: $draft.trim)
                }

                Section {
                    TextField("Reference number (RN…)", text: $draft.referenceNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("VIN", text: $draft.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())

                    if !draft.vin.isEmpty && !draft.hasVIN {
                        Label("A VIN is 17 characters", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Both stay on this device. The VIN unlocks the plant, model year, battery, and drive-unit decode.")
                }

                Section {
                    Toggle("Order date", isOn: $hasReservationDate)
                    if hasReservationDate {
                        DatePicker(
                            "Ordered",
                            selection: Binding(
                                get: { draft.reservationDate ?? Date() },
                                set: { draft.reservationDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    Toggle("Booked date", isOn: $hasBookedDate)
                    if hasBookedDate {
                        DatePicker(
                            "Booked",
                            selection: Binding(
                                get: { draft.orderBookedDate ?? Date() },
                                set: { draft.orderBookedDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Dates")
                }

                Section {
                    TextField("Delivery window (e.g. Sep 15 – Sep 30)", text: $draft.deliveryWindowDisplay)
                        .onChange(of: draft.deliveryWindowDisplay) { _, newValue in
                            let bounds = TeslaDeliveryWindowParser.parse(newValue)
                            draft.windowStart = bounds.start
                            draft.windowEnd = bounds.end
                        }

                    if let start = draft.windowStart {
                        LabeledContent("Parsed start", value: start.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    if let end = draft.windowEnd {
                        LabeledContent("Parsed end", value: end.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }

                    TextField("ETA to delivery center", text: $draft.etaToDeliveryCenter)
                    TextField("Routing location", text: $draft.routingLocation)

                    Toggle("Delivery appointment", isOn: $hasAppointment)
                    if hasAppointment {
                        DatePicker(
                            "Appointment",
                            selection: Binding(
                                get: { draft.deliveryAppointment ?? Date() },
                                set: {
                                    draft.deliveryAppointment = $0
                                    draft.deliveryAppointmentText = $0.formatted(date: .abbreviated, time: .shortened)
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("Delivery")
                } footer: {
                    Text("Type the window exactly as Tesla shows it. The countdown comes from parsing that text, so both stay in sync.")
                }

                Section {
                    TextField("Order status code (e.g. BOOKED)", text: $draft.orderStatusCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if !draft.orderStatusCode.isEmpty {
                        Text(draft.statusDescription.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Odometer", text: $odometerText)
                        .keyboardType(.decimalPad)

                    Picker("Stage", selection: $draft.stageOverride) {
                        Text("Infer from data (\(draft.inferredStage.title))").tag(DeliveryStage?.none)
                        ForEach(DeliveryStage.allCases) { stage in
                            Text(stage.title).tag(DeliveryStage?.some(stage))
                        }
                    }
                } header: {
                    Text("Status")
                } footer: {
                    Text("Leave the stage on “Infer” unless you know something the fields haven't caught up to.")
                }

                Section {
                    TextField("Option codes, comma separated", text: $optionCodesText, axis: .vertical)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())

                    if !decodedPreview.isEmpty {
                        Text(decodedPreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Build (mktOptions)")
                } footer: {
                    Text("From your order's mktOptions field or the window sticker. Codes are decoded locally.")
                }

                Section("Notes") {
                    TextField("Anything you want to remember", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(isNew ? "Track an Order" : "Edit Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .sheet(isPresented: $showingImport) {
                TeslaOrderJSONImportSheet(order: draft) { imported in
                    apply(imported)
                }
            }
            .onChange(of: hasReservationDate) { _, on in
                if !on { draft.reservationDate = nil } else if draft.reservationDate == nil { draft.reservationDate = Date() }
            }
            .onChange(of: hasBookedDate) { _, on in
                if !on { draft.orderBookedDate = nil } else if draft.orderBookedDate == nil { draft.orderBookedDate = Date() }
            }
            .onChange(of: hasAppointment) { _, on in
                if !on {
                    draft.deliveryAppointment = nil
                    draft.deliveryAppointmentText = ""
                } else if draft.deliveryAppointment == nil {
                    let now = Date()
                    draft.deliveryAppointment = now
                    draft.deliveryAppointmentText = now.formatted(date: .abbreviated, time: .shortened)
                }
            }
        }
    }

    private var decodedPreview: String {
        TeslaOptionCodeDecoder.decode(optionCodesText).oneLine
    }

    private func apply(_ imported: TeslaDeliveryOrder) {
        draft = imported
        optionCodesText = imported.optionCodes.joined(separator: ", ")
        odometerText = imported.odometer.map { TeslaDeliveryOrder.trimmedNumber($0) } ?? ""
        hasReservationDate = imported.reservationDate != nil
        hasBookedDate = imported.orderBookedDate != nil
        hasAppointment = imported.deliveryAppointment != nil
    }

    private func save() {
        var result = draft
        result.vin = result.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        result.referenceNumber = result.referenceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        result.optionCodes = TeslaOptionCodeDecoder.split(optionCodesText)

        let odometerValue = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        result.odometer = odometerValue.isEmpty ? nil : Double(odometerValue)
        if result.odometer != nil && result.odometerUnit.isEmpty { result.odometerUnit = "Miles" }

        let bounds = TeslaDeliveryWindowParser.parse(result.deliveryWindowDisplay)
        result.windowStart = bounds.start
        result.windowEnd = bounds.end

        onSave(result)
        dismiss()
    }
}

// MARK: - JSON import

@MainActor
struct TeslaOrderJSONImportSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox

    let order: TeslaDeliveryOrder
    let onApply: (TeslaDeliveryOrder) -> Void

    @State private var text: String = ""
    @State private var result: TeslaOrderImportResult?
    @State private var errorMessage: String?

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing) {
                    instructionsCard
                    editorCard

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .themedCard()
                    }

                    if let result {
                        matchesCard(result)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("Paste Order JSON")
            .navigationBarTitleDisplayMode(.inline)
            .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let result {
                            onApply(result.order)
                            dismiss()
                        }
                    }
                    .disabled(result == nil)
                }
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What to paste", systemImage: "info.circle")
                .font(.headline)

            Text("""
            The response from Tesla's order or /tasks endpoint, however you obtained it — a single order, an array of orders, or a merged blob. The parser searches the whole payload for known field names rather than expecting a fixed shape.

            It reads: order status, model, VIN, trim, mktOptions, reservation and booked dates, delivery window, ETA to delivery center, appointment, routing location, and odometer.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Parsing happens on this device. Nothing is uploaded.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Payload")
                    .font(.headline)
                Spacer()
                #if canImport(UIKit)
                Button {
                    if let pasted = UIPasteboard.general.string {
                        text = pasted
                        parse()
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                #endif
                if !text.isEmpty {
                    Button {
                        text = ""
                        result = nil
                        errorMessage = nil
                    } label: {
                        Text("Clear").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }

            TextEditor(text: $text)
                .font(.caption.monospaced())
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    theme.pillTint.opacity(0.20),
                    in: RoundedRectangle(cornerRadius: theme.smallCorner, style: .continuous)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                parse()
            } label: {
                Label("Parse payload", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func matchesCard(_ result: TeslaOrderImportResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Found \(result.matchedFields.count) field\(result.matchedFields.count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            ForEach(result.matchedFields, id: \.self) { field in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(field).font(.footnote)
                    Spacer()
                }
            }

            Divider().padding(.vertical, 2)

            LabeledContent("Stage after import", value: result.order.stage.title)
                .font(.footnote)

            let changes = result.order.changes(comparedTo: order)
            if changes.isEmpty {
                Text("Nothing moved since your last update — this payload matches what's already tracked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(changes.count) change\(changes.count == 1 ? "" : "s") will be journaled:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(changes) { change in
                    Text("• \(change.field): \(change.oldDisplay) → \(change.newDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func parse() {
        errorMessage = nil
        result = nil
        do {
            result = try TeslaOrderJSONImporter.apply(json: text, to: order)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
