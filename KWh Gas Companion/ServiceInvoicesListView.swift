//
//  ServiceInvoicesListView.swift
//  My KWh Companion
//
//  Full list & viewer for Tesla Service Invoices (PDF)
//  Swift 6 / iOS 17+
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// Optional capability protocols your ServiceInvoicesStore may implement.
public protocol _InvoicesStoreDeleting {
    @MainActor func delete(invoice: ServiceInvoice) async -> Bool
}
public protocol _InvoicesStoreUpdating {
    @MainActor func update(linkedExpenseID: UUID?, for invoiceID: UUID) async
}

// Optional capability protocol for expense linking.
// Your app can implement this on ExpenseEntryWriter.
public protocol _InvoicesExpenseLinking {
    func createOrLinkExpense(
        title: String,
        amount: Decimal,
        date: Date,
        vehicleKey: String,
        sourceID: UUID
    ) async throws -> UUID
}

@MainActor
public struct ServiceInvoicesListView: View {
    // Required inputs
    public let vehicleKey: String
    public let vehicleName: String?
    private let expenseWriter: (any ExpenseEntryWriter)?

    // Store (read-only invoices array)
    @StateObject private var store = ServiceInvoicesStore()
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // UI state
    @State private var query: String = ""
    @State private var sortNewestFirst = true
    @State private var showingViewer = false
    @State private var viewingInvoice: ServiceInvoice?
    @State private var shareItem: ShareItem?
    @State private var lastError: String?

    public init(
        vehicleKey: String,
        vehicleName: String? = nil,
        expenseWriter: (any ExpenseEntryWriter)? = nil
    ) {
        self.vehicleKey = vehicleKey
        self.vehicleName = vehicleName
        self.expenseWriter = expenseWriter
    }

    public var body: some View {
        List {
            headerSection

            let filtered = filteredInvoices()
            if filtered.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No invoices found",
                        systemImage: "doc",
                        description: Text("Try importing PDFs from the landing screen.")
                    )
                }
            } else {
                Section {
                    ForEach(filtered, id: \.id) { inv in
                        Button { open(invoice: inv) } label: {
                            InvoiceRow(invoice: inv)
                        }
                        .contextMenu {
                            Button {
                                open(invoice: inv)
                            } label: {
                                Label("Open", systemImage: "doc.richtext")
                            }

                            Button {
                                export(invoice: inv)
                            } label: {
                                Label("Share / Export", systemImage: "square.and.arrow.up")
                            }

                            if let amt = inv.amount, amt > 0, expenseWriter != nil {
                                Button {
                                    linkExpense(for: inv)
                                } label: {
                                    Label("Link/Create Expense", systemImage: "link")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(invoice: inv)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("\(filtered.count) \(filtered.count == 1 ? "invoice" : "invoices")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !adsStore.hasRemovedAds {
                Section {
                    AdBannerCard(adsStore: adsStore)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vehicleName?.isEmpty == false ? "\(vehicleName!) Invoices" : "Service Invoices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sortNewestFirst.toggle()
                } label: {
                    Label(sortNewestFirst ? "Newest first" : "Oldest first",
                          systemImage: sortNewestFirst ? "arrow.down.to.line" : "arrow.up.to.line")
                }
                .help("Toggle sort order")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search title, #, or location")
        .onAppear {
            store.load(vehicleKey: vehicleKey)
        }
        .task { await adsStore.load() }
        // PDF Viewer
        .sheet(isPresented: $showingViewer) {
            if let inv = viewingInvoice {
                let url = store.url(for: inv)
                PDFViewer(url: url, title: inv.title)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Couldn’t open PDF")
                        .font(.headline)
                    Text("The file may be missing or corrupted.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        // Share
        .sheet(item: $shareItem) { item in
            ShareSheetVC(items: [item.url])
        }
        .alert("Error", isPresented: .constant(lastError != nil)) {
            Button("OK", role: .cancel) { lastError = nil }
        } message: {
            Text(lastError ?? "")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicleName?.isEmpty == false ? vehicleName! : "Current Vehicle")
                        .font(.headline)
                    Text(vehicleKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()
            }
            .padding(8)
        }
    }

    // MARK: - Filtering / Sorting

    private func filteredInvoices() -> [ServiceInvoice] {
        var items = store.invoices.filter { $0.vehicleKey == vehicleKey }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            items = items.filter { inv in
                inv.title.localizedCaseInsensitiveContains(q)
                || (inv.invoiceNumber?.localizedCaseInsensitiveContains(q) ?? false)
                || (inv.location?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }

        items.sort { a, b in
            sortNewestFirst ? (a.serviceDate > b.serviceDate) : (a.serviceDate < b.serviceDate)
        }
        return items
    }

    // MARK: - Actions

    private func open(invoice: ServiceInvoice) {
        viewingInvoice = invoice
        showingViewer = true
    }

    private func export(invoice: ServiceInvoice) {
        let url = store.url(for: invoice)
        shareItem = ShareItem(url: url)
    }

    private func delete(invoice: ServiceInvoice) {
        Task {
            let ok = await store.delete(invoice: invoice)
            if ok {
                store.load(vehicleKey: vehicleKey)
            } else {
                lastError = "Could not delete invoice."
            }
        }
    }

    private func linkExpense(for invoice: ServiceInvoice) {
        guard let writer = expenseWriter as? _InvoicesExpenseLinking else {
            lastError = "Expense writer doesn’t support linking from invoices."
            return
        }
        Task {
            do {
                let id = try await writer.createOrLinkExpense(
                    title: invoice.title,
                    amount: invoice.amount ?? 0,
                    date: invoice.serviceDate,
                    vehicleKey: invoice.vehicleKey,
                    sourceID: invoice.id
                )
                await store.update(linkedExpenseID: id, for: invoice.id)
                store.load(vehicleKey: vehicleKey)
            } catch {
                lastError = "Failed to link expense: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Identifiable wrapper for share sheets

fileprivate struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Row

fileprivate struct InvoiceRow: View {
    let invoice: ServiceInvoice

    private let df: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        return d
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text(df.string(from: invoice.serviceDate))
                        .foregroundStyle(.secondary)

                    if let amt = invoice.amount {
                        Text(currency(amt))
                            .foregroundStyle(.secondary)
                    }

                    if let num = invoice.invoiceNumber, !num.isEmpty {
                        Text("#\(num)").foregroundStyle(.secondary)
                    }

                    if let loc = invoice.location, !loc.isEmpty {
                        Text(loc).foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }

            Spacer()

            if invoice.linkedExpenseID != nil {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
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

// MARK: - PDF Viewer (PDFKit-based)

fileprivate struct PDFViewer: View {
    let url: URL
    let title: String

    var body: some View {
        NavigationStack {
            PDFKitRepresentedView(url: url)
                .background(Color(UIColor.systemBackground))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

fileprivate struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = .clear
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysAsBook = false
        pdfView.displayDirection = .vertical
        pdfView.pageShadowsEnabled = false
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - Share sheet (VC wrapper)

fileprivate struct ShareSheetVC: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ServiceInvoicesListView(
            vehicleKey: "5YJYGDEE8LF000001",
            vehicleName: "Model Y",
            expenseWriter: nil
        )
    }
}
#endif
