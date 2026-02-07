// PDFViewerView.swift
import SwiftUI
import PDFKit

public struct PDFViewerView: View {
    let url: URL
    let title: String

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }

    public var body: some View {
        PDFKitRepresentable(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black.opacity(0.001)) // avoid pure-black while loading
    }
}

private struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.displayMode = .singlePageContinuous
        v.autoScales = true
        v.displayDirection = .vertical
        v.backgroundColor = .systemBackground
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        v.document = PDFDocument(url: url)
    }
}
