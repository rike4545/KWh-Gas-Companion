// CSVExportView.swift
// KWh Gas Companion

import SwiftUI

struct CSVExportView: View {
    // Optional injection; default pulls from store
    let entries: [ExpenseEntry]? = nil
    @EnvironmentObject private var entriesStore: EntriesStore

    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?

    private var data: [ExpenseEntry] {
        (entries ?? entriesStore.entries).sorted { $0.date < $1.date }
    }

    var body: some View {
        Form {
            Section("Summary") {
                HStack {
                    Text("Rows")
                    Spacer()
                    Text("\(data.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Export") {
                Button {
                    do {
                        exportURL = try writeCSV()
                        showShare = (exportURL != nil)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(data.isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("CSV Export")
        .sheet(isPresented: $showShare) {
            if let url = exportURL {
                ActivityView(
                    activityItems: [url],
                    excludedActivityTypes: [.assignToContact, .addToReadingList],
                    subject: "My KWh Companion Export"
                )
            }
        }
    }

    // MARK: - CSV

    private enum ExportError: LocalizedError {
        case encodingFailed
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode CSV using UTF-8."
            }
        }
    }

    private func writeCSV() throws -> URL {
        let header = [
            "id","date","category","amount","energyKWh","odometer",
            "location","notes","vehicleName","stateOfCharge","chargeType",
            "vehicleID","isBusiness"
        ].joined(separator: ",")

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let rows: [String] = data.map { e in
            func esc(_ s: String?) -> String {
                guard let s = s, !s.isEmpty else { return "" }
                let needsQuote = s.contains(",") || s.contains("\"") || s.contains("\n")
                let v = s.replacingOccurrences(of: "\"", with: "\"\"")
                return needsQuote ? "\"\(v)\"" : v
            }

            let amountStr = String(e.amount)
            let energyStr = e.energyKWh.map { String($0) } ?? ""
            let odoStr    = e.odometer.map { String($0) } ?? ""
            let socStr    = e.stateOfCharge.map { String($0) } ?? ""

            let cols: [String] = [
                e.id.uuidString,
                iso.string(from: e.date),
                esc(e.category),
                amountStr,
                energyStr,
                odoStr,
                esc(e.location),
                esc(e.notes),
                esc(e.vehicleName),
                socStr,
                esc(e.chargeType),
                e.vehicleID?.uuidString ?? "",
                e.isBusiness ? "true" : "false"
            ]
            return cols.joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")

        guard let dataOut = csv.data(using: String.Encoding.utf8) else {
            throw ExportError.encodingFailed
        }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("kwh_export_\(Int(Date().timeIntervalSince1970)).csv")

        try dataOut.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }
}

#if DEBUG
#Preview {
    NavigationStack { CSVExportView().environmentObject(EntriesStore()) }
}
#endif
