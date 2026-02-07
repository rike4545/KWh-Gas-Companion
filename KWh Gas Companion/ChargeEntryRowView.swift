//
//  ChargeEntryRowView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//  - Compatible with TeslaFiSession(startDate:endDate:energyAddedKWh:cost:location:raw:)
//  - No local TeslaFiSession declaration (avoids redeclaration/ambiguity)
//  - Inline edit sheet; parent can handle onEdit/onDelete
//

import SwiftUI

@MainActor
struct ChargeEntryRowView: View {
    let session: TeslaFiSession

    // Optional actions supplied by parent
    var onEdit: ((TeslaFiSession) -> Void)? = nil
    var onDelete: ((TeslaFiSession) -> Void)? = nil

    // Edit state
    @State private var showEdit = false
    @State private var editStart: Date = .now
    @State private var editEnd: Date = .now
    @State private var editKWh: String = ""
    @State private var editCost: String = ""
    @State private var editLocation: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title line: Location • kWh • Cost
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayLocation(session))
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(fmt1(session.energyAddedKWh)) kWh")
                    .font(.subheadline)

                if let c = session.cost {
                    Divider().frame(height: 14)
                    Text(currency(c))
                        .font(.subheadline).bold()
                }
            }

            // Subtitle line: date/time range + duration
            Text("\(dateTime(session.startDate)) — \(dateTime(session.endDate)) • \(durationText(from: session.startDate, to: session.endDate))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button {
                beginEdit()
                showEdit = true
            } label: { Label("Edit", systemImage: "pencil") }

            Button(role: .destructive) {
                onDelete?(session)
            } label: { Label("Delete", systemImage: "trash") }
        }
        .onTapGesture {
            // Tap = quick edit; change behavior if you prefer a detail screen
            beginEdit()
            showEdit = true
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                editForm
                    .navigationTitle("Edit Session")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showEdit = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { saveEdit() }
                                .disabled(!canSave)
                        }
                    }
            }
        }
    }

    // MARK: - Edit UI

    private var editForm: some View {
        Form {
            Section(header: Text("When")) {
                DatePicker("Start", selection: $editStart, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $editEnd, displayedComponents: [.date, .hourAndMinute])
            }
            Section(header: Text("Energy & Cost")) {
                TextField("Energy added (kWh)", text: $editKWh)
                    .keyboardType(.decimalPad)
                TextField("Cost (optional)", text: $editCost)
                    .keyboardType(.decimalPad)
            }
            Section(header: Text("Location")) {
                TextField("Location (optional)", text: $editLocation)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var canSave: Bool {
        // basic checks: start <= end, kWh is numeric and >= 0
        guard editStart <= editEnd else { return false }
        guard let k = Double(editKWh.trimmingCharacters(in: .whitespacesAndNewlines)), k >= 0 else { return false }
        return true
    }

    private func beginEdit() {
        editStart = session.startDate
        editEnd = session.endDate
        editKWh = String(format: "%.3f", session.energyAddedKWh)
        if let c = session.cost {
            editCost = String(format: "%.2f", c)
        } else {
            editCost = ""
        }
        editLocation = session.location ?? ""
    }

    private func saveEdit() {
        let kwh = Double(editKWh.trimmingCharacters(in: .whitespacesAndNewlines)) ?? session.energyAddedKWh
        let costValue: Double? = {
            let t = editCost.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : Double(t)
        }()

        // ✅ Use the lean initializer (no `id:`)
        let updated = TeslaFiSession(
            startDate: editStart,
            endDate: editEnd,
            energyAddedKWh: kwh,
            cost: costValue,
            location: editLocation.isEmpty ? nil : editLocation,
            raw: session.raw
        )

        onEdit?(updated)
        showEdit = false
    }

    // MARK: - Helpers / Formatters

    private func displayLocation(_ s: TeslaFiSession) -> String {
        let trimmed = (s.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown" : trimmed
    }

    private func fmt1(_ v: Double) -> String { String(format: "%.1f", v) }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    private func dateTime(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: d)
    }

    private func durationText(from: Date, to: Date) -> String {
        let secs = max(0, to.timeIntervalSince(from))
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
