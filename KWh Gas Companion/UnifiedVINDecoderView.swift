//
//  UnifiedVINDecoderView.swift
//  KWh Gas Companion
//
//  Created by Bryan on 7/13/25.
//


// UnifiedVINDecoderView.swift
// MyKwH Companion
// Selection view with tiles linking to Tesla and Rivian VIN decoders

import SwiftUI

struct UnifiedVINDecoderView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(VINBrand.allCases) { brand in
                        NavigationLink(destination: brand.decoderView()) {
                            VStack(spacing: 12) {
                                Image(systemName: brand == .tesla ? "t.circle.fill" : "r.circle.fill")
                                    .font(.system(size: 40))
                                Text(brand.rawValue)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("VIN Decoder")
        }
    }
}

struct UnifiedVINDecoderView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedVINDecoderView()
    }
}
