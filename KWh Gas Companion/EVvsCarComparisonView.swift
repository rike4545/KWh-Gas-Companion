import SwiftUI

struct EVvsCarComparisonView: View {
    init(evCostPerMile: Double? = nil, carCostPerMile: Double? = nil) {}

    var body: some View {
        EVGasComparisonHubView()
            .navigationTitle("EV vs ICE")
            .navigationBarTitleDisplayMode(.inline)
    }
}
