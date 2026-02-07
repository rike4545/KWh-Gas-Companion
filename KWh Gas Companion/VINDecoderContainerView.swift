//
//  VINDecoderContainerView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/24/25.
//


import SwiftUI

/// Container view that detects VIN brand and shows the appropriate decoder
struct VINDecoderContainerView: View {
    @State private var vin: String = ""
    @State private var selectedBrand: VINBrand? = nil
    @FocusState private var isEditingVIN: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 24) {
                        brandInputSection
                            .frame(maxWidth: .infinity)
                        decoderSection
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        brandInputSection
                        decoderSection
                    }
                    .padding()
                }
            }
            .navigationTitle("VIN Decoder")
        }
    }

    /// Section for entering VIN and detecting brand
    private var brandInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Enter VIN", text: $vin)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .focused($isEditingVIN)
                .border(Color.gray)
                .accessibilityLabel("Vehicle Identification Number")
                .accessibilityHint("Enter the 17 character VIN to decode")
                .onChange(of: vin) {
                    let code = vin.trimmingCharacters(in: .whitespacesAndNewlines)
                    selectedBrand = VINBrand.from(vin: code)
                }

            if let brand = selectedBrand {
                Text("Detected brand: \(brand.rawValue)")
                    .font(.subheadline)
                    .accessibilityLabel("Detected brand: \(brand.rawValue)")
            } else {
                Text("Brand not recognized")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Brand not recognized")
            }
        }
    }

    /// Section presenting the appropriate decoder view for the detected brand
    @ViewBuilder
    private var decoderSection: some View {
        if let brand = selectedBrand {
            brand.decoderView()
        } else {
            Text("Please enter a valid VIN to see decoder.")
                .foregroundColor(.secondary)
                .accessibilityLabel("Enter valid VIN to decode")
        }
    }
}

#if DEBUG
struct VINDecoderContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VINDecoderContainerView()
                .environment(\.horizontalSizeClass, .compact)
                .previewDisplayName("iPhone")

            VINDecoderContainerView()
                .environment(\.horizontalSizeClass, .regular)
                .previewLayout(.fixed(width: 1024, height: 768))
                .previewDisplayName("iPad")
        }
    }
}
#endif
