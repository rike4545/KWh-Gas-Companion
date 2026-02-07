import SwiftUI
import PhotosUI
import Vision
import UIKit

@MainActor
struct ReceiptOCRView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var recognizedText: String = ""

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var dateText: String = ""

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                uploadCard
                extractedCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Receipt Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
        .onChange(of: pickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    imageData = data
                    await recognizeText(from: data)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan a receipt")
                .font(.headline)
            Text("Automatically extracts merchant, date, and total. You can edit before saving.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var uploadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Select receipt photo", systemImage: "photo")
                    .font(.subheadline.weight(.semibold))
            }

            if let data = imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .themedCard()
    }

    private var extractedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Extracted fields")
                .font(.headline)

            fieldRow("Merchant", text: $merchant)
            fieldRow("Amount", text: $amount)
            fieldRow("Date", text: $dateText)

            if !recognizedText.isEmpty {
                Divider().opacity(0.2)
                Text("Raw OCR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recognizedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
        .themedCard()
    }

    private func fieldRow(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .multilineTextAlignment(.trailing)
                .frame(width: 180)
        }
        .font(.subheadline)
    }

    private func recognizeText(from data: Data) async {
        guard let ui = UIImage(data: data),
              let cg = ui.cgImage else { return }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n")

            await MainActor.run {
                recognizedText = joined
                parseFields(from: lines)
            }
        } catch {
            // ignore
        }
    }

    private func parseFields(from lines: [String]) {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if merchant.isEmpty {
            merchant = cleaned.first(where: { !$0.contains("$") && $0.count >= 3 }) ?? ""
        }

        if amount.isEmpty {
            let moneyPattern = #"(\$?\d+[.,]\d{2})"#
            if let match = cleaned.compactMap({ $0.firstMatch(moneyPattern) }).first {
                amount = match
            }
        }

        if dateText.isEmpty {
            let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#
            if let match = cleaned.compactMap({ $0.firstMatch(datePattern) }).first {
                dateText = match
            }
        }
    }
}

private extension String {
    func firstMatch(_ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let r = Range(match.range(at: 1), in: self) ?? Range(match.range, in: self) else { return nil }
        return String(self[r])
    }
}
