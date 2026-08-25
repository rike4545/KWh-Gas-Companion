//
//  RecallsView 2.swift
//  KWh Gas Companion
//
//

import SwiftUI
import SafariServices
import UIKit

// MARK: - RecallsView
@MainActor
struct RecallsView: View {
    // Optional integration with your data model
    var vehicle: VehicleProfile? = nil
    var onUpdateVehicleVIN: ((String) -> Void)? = nil

    // Centralized VIN repository (provided by VINKit.swift)
    private var vinRepo: VINRepository {
        DefaultVINRepository(
            vehicleVINProvider: { vehicle?.vin },
            onWriteVehicleVIN: { newVIN in onUpdateVehicleVIN?(newVIN) }
        )
    }

    // MARK: – State
    @State private var vin: String = ""
    @State private var showSafari = false
    @State private var safariURL: URL? = URL(string: "https://www.nhtsa.gov/recalls")
    @State private var showCopiedVINAlert = false

    @State private var isDecoding = false
    @State private var decoded: DecodedVIN?
    @State private var recalls: [RecallRecord] = []
    @State private var fetchError: String?
    @State private var savedVIN: String? = nil
    @State private var didPrefill = false
    @StateObject private var adsStore = AdsEntitlementStore.shared

    // MARK: – External links
    private let nhtsaVINPortal   = URL(string: "https://www.nhtsa.gov/recalls")!
    private let teslaRecallURL   = URL(string: "https://service.tesla.com/en-US/vin-recall-search")!
    private let teslaCollisionURL = URL(string: "https://www.tesla.com/support/collision-support")!
    private let rivianCollisionURL = URL(string: "https://rivian.com/support/article/certified-collision-centers")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("Vehicle Recalls")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(
                        "Use your VIN for the official status of \(Text("open\u{00A0}/\u{00A0}unrepaired").bold()) recalls. Or decode the VIN to see model-level campaigns published by NHTSA."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Saved VIN card (Use / Check Now)
                if let saved = savedVIN, !saved.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Saved VIN", systemImage: "car.fill")
                            .font(.title3.bold())

                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(VIN.mask(saved))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Spacer(minLength: 12)

                            Button("Use") {
                                vin = VIN.sanitize(saved)
                            }
                            .buttonStyle(.bordered)

                            Button("Check Now") {
                                vin = VIN.sanitize(saved)
                                Task { await decodeAndFetch() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RecallsBrand.tesla)
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1))
                }

                // VIN Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("VIN (17 characters)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("e.g., 5YJ3E1EA7KF123456", text: $vin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .submitLabel(.done)
                            .accessibilityLabel("VIN")
                            .padding(12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: vin) { _, newVal in
                                let s = VIN.sanitize(newVal)
                                if s != newVal { vin = s }
                            }

                        // Smart copy/paste
                        Button {
                            if vin.isEmpty, let s = UIPasteboard.general.string {
                                vin = VIN.sanitize(s)
                            } else {
                                UIPasteboard.general.string = vin
                            }
                        } label: {
                            Image(systemName: vin.isEmpty ? "doc.on.clipboard" : "doc.on.doc")
                                .imageScale(.medium)
                                .padding(10)
                        }
                        .accessibilityLabel(vin.isEmpty ? "Paste VIN" : "Copy VIN")
                        .background(.thinMaterial, in: Circle())
                    }

                    if !vin.isEmpty {
                        HStack(spacing: 6) {
                            Circle().frame(width: 8, height: 8)
                                .foregroundStyle(VIN.isValid(vin) ? .green : .red)
                            Text(VIN.isValid(vin) ? "Looks valid" : "VIN must be 17 characters, excluding I/O/Q")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    // Save current VIN (repo writes to your store + file via Persistence)
                    if VIN.isValid(vin), VIN.sanitize(vin) != (savedVIN.map(VIN.sanitize) ?? "") {
                        Button {
                            vinRepo.saveVIN(vin)
                            refreshSavedVIN()
                        } label: {
                            Label("Save as My VIN", systemImage: "tray.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Actions
                VStack(spacing: 10) {
                    // NHTSA VIN Check (official)
                    Button {
                        safariURL = nhtsaVINPortal
                        showSafari = true
                    } label: {
                        Label("Official US NHTSA website", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RecallsBrand.tesla)
                    .controlSize(.large)

                    // Tesla Recall Check (official portal)
                    Button {
                        // Copy VIN for quick paste on Tesla portal (if valid)
                        if VIN.isValid(vin) {
                            UIPasteboard.general.string = VIN.sanitize(vin)
                            showCopiedVINAlert = true
                        }
                        safariURL = teslaRecallURL
                        showSafari = true
                    } label: {
                        Label("Tesla Recall website", systemImage: "car.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RecallsBrand.tesla)
                    .controlSize(.large)

                    HStack(spacing: 10) {
                        Button {
                            Task { await decodeAndFetch() }
                        } label: {
                            Label("List Model Recalls", systemImage: "list.bullet.rectangle.portrait")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!VIN.isValid(vin) || isDecoding)

                        Button {
                            vin = ""
                            decoded = nil
                            recalls = []
                            fetchError = nil
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                // Progress / Error
                if isDecoding {
                    ProgressView("Contacting NHTSA…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let fetchError {
                    Text(fetchError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Decoded VIN summary
                if let decoded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIN Details")
                            .font(.title3.bold())
                        Text("\(decoded.modelYear) \(decoded.make) \(decoded.model)")
                            .font(.headline)
                        if !decoded.warnings.isEmpty {
                            ForEach(decoded.warnings, id: \.self) { warn in
                                Label(warn, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                // Recalls list (model-level campaigns)
                if !recalls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model-Level Recall Campaigns")
                            .font(.title3.bold())
                        Text("This list shows all NHTSA campaigns for the decoded Year/Make/Model. For your specific vehicle’s open/unrepaired status, use the official VIN check above.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(recalls) { r in
                            RecallCard(record: r)
                        }
                    }
                }

                // COLLISION SUPPORT
                VStack(alignment: .leading, spacing: 12) {
                    Label("Collision Support", systemImage: "wrench.and.screwdriver.fill")
                        .font(.title3.bold())

                    // Exact wording requested
                    Text("In the unfortunate event and need Collision Support, here are two resources:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            safariURL = teslaCollisionURL
                            showSafari = true
                        } label: {
                            Label("Tesla Collision", systemImage: "car.side.rear.and.exclamationmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RecallsBrand.tesla)
                        .controlSize(.large)

                        Button {
                            safariURL = rivianCollisionURL
                            showSafari = true
                        } label: {
                            Label("Rivian Collision", systemImage: "leaf.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RecallsBrand.rivian)
                        .controlSize(.large)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1))

                Spacer(minLength: 20)

                // Footer disclaimer
                Text("Disclaimer: NHTSA’s official VIN portal is the authority on whether **your** vehicle has an **open\u{00A0}/\u{00A0}unrepaired** recall. The model-level list here is informational and may include campaigns not applicable to your exact configuration or already remedied.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding()
        }
        .task { await adsStore.load() }
        .navigationTitle("Recalls")
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                InAppSafariView(url: safariURL)
            }
        }
        .alert("VIN Copied", isPresented: $showCopiedVINAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your VIN is on the clipboard for quick paste into Tesla’s recall search.")
        }
        .onAppear {
            refreshSavedVIN()
            if !didPrefill, vin.isEmpty, let s = savedVIN {
                vin = VIN.sanitize(s)
                didPrefill = true
            }
        }
    }

    // MARK: – Helpers
    private func refreshSavedVIN() {
        savedVIN = vinRepo.loadVIN()
    }

    private func decodeAndFetch() async {
        fetchError = nil
        recalls = []
        decoded = nil
        guard VIN.isValid(vin) else {
            fetchError = "Enter a valid VIN (17 characters; excludes I, O, Q)."
            return
        }
        isDecoding = true
        defer { isDecoding = false }

        do {
            let d = try await RecallsClient.shared.decodeVIN(vin)
            decoded = d
            if let year = Int(d.modelYear), !d.make.isEmpty, !d.model.isEmpty {
                recalls = try await RecallsClient.shared.fetchRecalls(modelYear: year, make: d.make, model: d.model)
            } else {
                fetchError = "Couldn’t determine Year/Make/Model from that VIN."
            }
        } catch {
            fetchError = (error as? FriendlyError)?.message ?? "Couldn’t contact NHTSA services. Try again."
        }
    }
}

// MARK: - Card
fileprivate struct RecallCard: View {
    let record: RecallRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let campaign = record.campaignNumber {
                    Text(campaign).font(.headline.monospaced())
                }
                Spacer()
                if let report = record.reportDate {
                    Text(report).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let component = record.component, !component.isEmpty {
                Label(component, systemImage: "gearshape").font(.subheadline)
            }
            if let summary = record.summary, !summary.isEmpty {
                Text(summary).font(.body).foregroundStyle(.primary)
            }
            if let remedy = record.remedy, !remedy.isEmpty {
                Divider().opacity(0.3)
                Text("Remedy: \(remedy)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Networking
fileprivate struct DecodedVIN: Equatable {
    let modelYear: String
    let make: String
    let model: String
    let warnings: [String]
}
fileprivate struct VPICDecodeResponse: Decodable {
    struct Item: Decodable {
        let ModelYear: String?
        let Make: String?
        let Model: String?
        let ErrorCode: String?
        let ErrorText: String?
    }
    let Results: [Item]
}
fileprivate struct RecallsResponse: Decodable {
    let results: [RecallRecord]?
    let Results: [RecallRecord]?
    var all: [RecallRecord] { results ?? Results ?? [] }
}
fileprivate struct RecallRecord: Decodable, Identifiable {
    var id: String { campaignNumber ?? UUID().uuidString }
    let campaignNumber: String?
    let reportDate: String?
    let component: String?
    let summary: String?
    let remedy: String?
    let notes: String?
    let manufacturer: String?
    let make: String?
    let model: String?
    let modelYear: String?
    enum CodingKeys: String, CodingKey {
        case campaignNumber = "NHTSACampaignNumber"
        case reportDate     = "ReportReceivedDate"
        case component      = "Component"
        case summary        = "Summary"
        case remedy         = "Remedy"
        case notes          = "Notes"
        case manufacturer   = "Manufacturer"
        case make           = "Make"
        case model          = "Model"
        case modelYear      = "ModelYear"
    }
}
fileprivate protocol FriendlyError: Error { var message: String { get } }
fileprivate struct NetworkFriendlyError: FriendlyError { let message: String }
fileprivate actor RecallsClient {
    static let shared = RecallsClient(); private init() {}
    func decodeVIN(_ vin: String) async throws -> DecodedVIN {
        guard let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues/\(vin)?format=json") else {
            throw NetworkFriendlyError(message: "Invalid URL.")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkFriendlyError(message: "VIN decode failed.")
        }
        let decoded = try JSONDecoder().decode(VPICDecodeResponse.self, from: data)
        guard let first = decoded.Results.first else {
            throw NetworkFriendlyError(message: "No VIN results.")
        }
        let warnings = [first.ErrorText].compactMap { $0 }.filter { !$0.isEmpty && !$0.contains("0 -") }
        return DecodedVIN(
            modelYear: first.ModelYear ?? "",
            make: (first.Make ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            model: (first.Model ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            warnings: warnings
        )
    }
    func fetchRecalls(modelYear: Int, make: String, model: String) async throws -> [RecallRecord] {
        var comps = URLComponents(string: "https://api.nhtsa.gov/recalls/recallsByVehicle")!
        comps.queryItems = [
            .init(name: "make", value: make),
            .init(name: "model", value: model),
            .init(name: "modelYear", value: String(modelYear))
        ]
        guard let url = comps.url else { throw NetworkFriendlyError(message: "Invalid recalls URL.") }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkFriendlyError(message: "Recall fetch failed.")
        }
        let rr = try JSONDecoder().decode(RecallsResponse.self, from: data)
        return rr.all
    }
}

// MARK: - In-app Safari (namespaced to avoid collisions)
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: cfg)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Local brand namespace (prevents global color collisions)
fileprivate enum RecallsBrand {
    static let tesla  = Color(red: 0.91, green: 0.11, blue: 0.13)
    static let rivian = Color(red: 0.32, green: 0.64, blue: 0.42)
}

// MARK: - Preview
#if DEBUG
struct RecallsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { RecallsView() }
            .preferredColorScheme(.dark)
        NavigationStack {
            RecallsView(
                vehicle: VehicleProfile(name: "Model 3", vin: "5YJ3E1EA7KF123456"),
                onUpdateVehicleVIN: { _ in }
            )
        }
        .preferredColorScheme(.light)
    }
}
#endif
