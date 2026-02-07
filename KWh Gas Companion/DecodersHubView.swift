//
//  DecodersHubView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/11/25.
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.automatic)
        .navigationTitle("VIN Decoders")
    }
}

#Preview {
    NavigationStack { DecodersHubView() }
}
