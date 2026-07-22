//
//  DecodersHubView.swift
//  KWh Gas Companion
//
//

// DecodersHubView.swift
import SwiftUI

struct DecodersHubView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    TeslaVINDecoderView()
                } label: {
                    Label("Tesla VIN Decoder", systemImage: "car.fill")
                }

                NavigationLink {
                    RivianVINDecoderView()
                } label: {
                    Label("Rivian VIN Decoder", systemImage: "leaf.fill")
                }
            } header: {
                Text("VIN Tools")
            }

            Section {
                NavigationLink {
                    TeslaServiceAlertScannerView()
                } label: {
                    Label("Tesla Service Alerts", systemImage: "exclamationmark.bubble")
                }
            } header: {
                Text("Error Plan English DeCoder")
            } footer: {
                Text("Photo scan Tesla alert screenshots, then translate common firmware codes into severity, impact, and owner action.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.automatic)
        .navigationTitle("Decoders")
    }
}

#Preview {
    NavigationStack { DecodersHubView() }
}
