//
//  ServiceInvoicesLandingView.swift
//  My KWh Companion
//
//  Landing screen for Tesla Service Invoices.
//  iOS 17+ / Swift 6
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct ServiceInvoicesLandingView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var store = ServiceInvoicesStore()   // used for preview + imports

    @State private var navigateToList = false
    @State private var showingImporter = false
    @State private var importing = false

    private let expenseWriter: ExpenseEntryWriter?

    public init(expenseWriter: ExpenseEntryWriter? = nil) {
        self.expenseWriter = expenseWriter
    }

    private var currentVehicleKey: String? {
        let vin = profileStore.trackedVehicleVIN.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? nil : vin
    }

    public var body: some View {
        VStack(spacing: 20) {
            header

            if let vehicleKey = currentVehicleKey {
                vehicleBadge(vehicleKey: vehicleKey, name: profileStore.selectedVehicle?.name)

                if store.invoices.isEmpty {
                    ContentUnavailableView(
                        "No invoices yet",
                        systemImage: "doc",
                        description: Text("Import Tesla service PDFs or open the invoices list.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    recentInvoicesList
                }

                actionsRow(vehicleKey: vehicleKey)
            } else {
                ContentUnavailableView(
                    "No Vehicle Selected",
                    systemImage: "car",
                    description: Text("Pick a vehicle in Profiles, then manage its service invoices here.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            }

        }
        .padding()
        .navigationDestination(isPresented: $navigateToList) {
            destinationListView()
        }
        .onAppear {
            store.expenseWriter = expenseWriter
            if let key = currentVehicleKey {
                store.load(vehicleKey: key)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            guard let vehicleKey = currentVehicleKey else { return }
            switch result {
            case .success(let urls):
                importing = true
                Task {
                    store.load(vehicleKey: vehicleKey) // ensure correct bucket
                    _ = await store.importPDFs(urls: urls, vehicleKey: vehicleKey)
                    importing = false
                    navigateToList = true
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 46, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.accent)
            Text("Service Invoices (PDF)")
                .font(.title3).bold()
            Text("Import Tesla service PDFs, view them, and (optionally) auto-link expenses for non-zero charges.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func vehicleBadge(vehicleKey: String, name: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "car.fill")
                .foregroundStyle(.white)
                .padding(8)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? "Current Vehicle").font(.headline)
                Text(vehicleKey).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private var recentInvoicesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Invoices").font(.headline)
            ForEach(store.invoices.prefix(3), id: \.id) { inv in
                ServiceInvoiceRow(invoice: inv)
            }
            if store.invoices.count > 3 {
                Text("…and \(store.invoices.count - 3) more")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionsRow(vehicleKey: String) -> some View {
        HStack {
            NavigationLink {
                // ✅ Removed `store:` — only pass what the ListView expects
                ServiceInvoicesListView(
                    vehicleKey: vehicleKey,
                    expenseWriter: expenseWriter
                )
                .environmentObject(profileStore)
            } label: {
                Label("Open Invoices", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingImporter = true
            } label: {
                Label(importing ? "Importing…" : "Import PDFs",
                      systemImage: importing ? "arrow.down.circle" : "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(importing)

            Spacer()
        }
    }

    @ViewBuilder
    private func destinationListView() -> some View {
        if let key = currentVehicleKey {
            // ✅ Also fixed here
            ServiceInvoicesListView(
                vehicleKey: key,
                expenseWriter: expenseWriter
            )
            .environmentObject(profileStore)
        } else {
            ContentUnavailableView(
                "No Vehicle Selected",
                systemImage: "car",
                description: Text("Return after selecting a vehicle in Profiles.")
            )
        }
    }
}

// MARK: - Shared Row
fileprivate struct ServiceInvoiceRow: View {
    let invoice: ServiceInvoice
    private let df: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        return d
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "doc.text").foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title).font(.headline)
                HStack(spacing: 12) {
                    Text(df.string(from: invoice.serviceDate)).foregroundStyle(.secondary)
                    if let amt = invoice.amount { Text(currency(amt)).foregroundStyle(.secondary) }
                    if let invNo = invoice.invoiceNumber, !invNo.isEmpty {
                        Text("#\(invNo)").foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if invoice.linkedExpenseID != nil {
                Image(systemName: "link").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func currency(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf.string(from: d as NSDecimalNumber) ?? "\(d)"
    }
}
