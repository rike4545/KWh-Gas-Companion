//
//  TeslaStatusTile.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/2/25.
//


// MARK: - TeslaStatusTile.swift
import SwiftUI

struct TeslaStatusTile: View {
    var chargeInfo: ChargingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.car.fill")
                    .foregroundColor(.green)
                Text(chargeInfo.vehicleName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text("Battery: \(chargeInfo.stateOfCharge)% — \(chargeInfo.timeRemaining)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.darkGray))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
