//  ExpenseDetailView.swift — My KWh Companion
//  Styled like Settings/Dashboard (glassy cards + gradient)
//  Aug 2025
//
//  • Uses Settings-style cards and a soft gradient background
//  • Keeps @Binding<ExpenseEntry> so edits reflect live
//  • Inline Edit (sheet -> AddEditEntryView) and Delete (alert)
//  • Safe currency/number formatting (typed Text initializers)

import SwiftUI

@MainActor
struct ExpenseDetailView: View {
    // Data
    @Binding var entry: ExpenseEntry
    @EnvironmentObject private var entriesStore: EntriesStore
    @Environment(\.dismiss) private var dismiss

    // Appearance override (parity with Settings)
    private enum AppearanceMode: String, CaseIterable { case automatic, light, dark }
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.automatic.rawValue
    private var appColorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceModeRaw) ?? .automatic {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // UI
    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    // Locale
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // Convenience
    private var kWh: Double? { entry.energyAddedKWh ?? entry.energyKWh }

    var body: some View {
        ZStack { DetailBG().ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                            .padding(.horizontal)

                        if kWh != nil || entry.costPerKWh != nil || entry.stateOfCharge != nil || (entry.chargeType?.isEmpty == false) {
                            chargingCard.padding(.horizontal)
                        }

                        if (entry.vehicleName?.isEmpty == false) || (entry.vin?.isEmpty == false) {
                            vehicleCard.padding(.horizontal)
                        }

                        if (entry.location?.isEmpty == false) || entry.odometer != nil {
                            tripCard.padding(.horizontal)
                        }

                        if entry.isBusiness { businessTag.padding(.horizontal) }

                        if let notes = entry.notes, !notes.isEmpty { notesCard(notes).padding(.horizontal) }

                        Spacer(minLength: 8)
                    }
                    .padding(.bottom, 24)
                }
            )
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .preferredColorScheme(appColorScheme)
            .alert("Delete this entry?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    // If your store exposes a remove/update API, it will handle persistence
                    entriesStore.remove(id: entry.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $isEditing) {
                AddEditEntryView(entry: entry, onSave: { updated in
                    entry = updated
                    entriesStore.update(updated)
                })
                .environmentObject(entriesStore)
            }
    }

    // MARK: - Header
    private var headerCard: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: leadingIcon)
                                    .font(.system(size: 26, weight: .semibold)))
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.category.isEmpty ? "Expense" : entry.category)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if entry.isEnergyEffective { energyBadge }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                        Text(entry.date, style: .date).font(.footnote).foregroundStyle(.secondary)
                        Text(entry.date, style: .time).font(.footnote).foregroundStyle(.secondary)
                        if let k = kWh { Text("• \(kWhString(k))").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(entry.amount, format: .currency(code: currencyCode))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let cpp = entry.costPerKWh { Text("@ \(currencyPerKWhString(cpp))").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var leadingIcon: String {
        if let cat = ExpenseCategory(rawValue: entry.category) { return cat.icon }
        return entry.isEnergyEffective ? "bolt.circle" : "doc.text"
    }

    private var energyBadge: some View {
        Text("ENERGY")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.green.opacity(0.22)))
            .overlay(Capsule().stroke(Color.green.opacity(0.45), lineWidth: 1))
    }

    // MARK: - Cards

    private var chargingCard: some View {
        SettingsCard(title: "Charging") {
            VStack(spacing: 10) {
                if let k = kWh { keyRow("Energy Added", value: kWhString(k)) }
                if let cpk = entry.costPerKWh { keyRow("Cost per kWh", value: currencyPerKWhString(cpk)) }
                if let soc = entry.stateOfCharge { keyRow("State of Charge", value: percentString(soc)) }
                if let t = entry.chargeType, !t.isEmpty { keyRow("Type", value: t) }
            }
        }
    }

    private var vehicleCard: some View {
        SettingsCard(title: "Vehicle") {
            VStack(spacing: 10) {
                if let name = entry.vehicleName, !name.isEmpty { keyRow("Name", value: name) }
                if let v = entry.vin, !v.isEmpty { keyRow("VIN", value: shortVIN(v)) }
            }
        }
    }

    private var tripCard: some View {
        SettingsCard(title: "Trip") {
            VStack(spacing: 10) {
                if let loc = entry.location, !loc.isEmpty { keyRow("Location", value: loc) }
                if let odo = entry.odometer { keyRow("Odometer", value: distanceString(odo)) }
            }
        }
    }

    private var businessTag: some View {
        SettingsCard {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                Text("Marked as business expense")
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func notesCard(_ text: String) -> some View {
        SettingsCard(title: "Notes") {
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Reusable rows & toolbar

    private func keyRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { isEditing = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Formatting helpers

    private func currencyPerKWhString(_ v: Double) -> String {
        let s = NumberFormatter.kwhCurrency(v, code: currencyCode)
        return s + "/kWh"
    }

    private func kWhString(_ v: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return v.formatted(.number.precision(.fractionLength(0...2))) + " kWh"
        } else {
            let nf = NumberFormatter(); nf.minimumFractionDigits = 0; nf.maximumFractionDigits = 2
            return (nf.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)) + " kWh"
        }
    }

    private func distanceString(_ v: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return v.formatted(.number.precision(.fractionLength(0...1))) + " mi"
        } else {
            let nf = NumberFormatter(); nf.minimumFractionDigits = 0; nf.maximumFractionDigits = 1
            return (nf.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v)) + " mi"
        }
    }

    private func percentString(_ p: Double) -> String {
        let clamped = max(0, min(1, p > 1 ? p / 100.0 : p))
        if #available(iOS 15.0, macOS 12.0, *) {
            return clamped.formatted(.percent.precision(.fractionLength(0...1)))
        } else {
            let nf = NumberFormatter(); nf.numberStyle = .percent; nf.minimumFractionDigits = 0; nf.maximumFractionDigits = 1
            return nf.string(from: NSNumber(value: clamped)) ?? "\(Int(clamped * 100))%"
        }
    }

    private func shortVIN(_ vin: String) -> String {
        let tail = String(vin.suffix(6)).uppercased()
        return vin.count > 6 ? "…\(tail)" : vin.uppercased()
    }
}

// MARK: - Local shells
fileprivate struct DetailBG: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [Color.black, Color(white: 0.12)] : [Color(white: 0.98), Color(white: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

fileprivate struct SettingsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(.bottom, 4)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Shared helpers used by this view
fileprivate extension NumberFormatter {
    static func kwhCurrency(_ value: Double, code: String?) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = code ?? Locale.current.currency?.identifier ?? "USD"
        return f.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

#Preview {
    let sample = ExpenseEntry(
        date: Date(),
        amount: 27.45,
        category: "Charging",
        energyKWh: 45.4,
        odometer: 18423.5,
        location: "Home – 123 Main St",
        notes: "Overnight session",
        vehicleName: "Model 3",
        stateOfCharge: 0.72,
        chargeType: "Home",
        isBusiness: true,
        vin: "5YJ3E1EA7KF123456"
    )
    return NavigationStack { ExpenseDetailView(entry: .constant(sample)) }
}
