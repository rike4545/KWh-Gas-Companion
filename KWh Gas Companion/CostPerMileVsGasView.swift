import SwiftUI

@MainActor
struct CostPerMileVsGasView: View {
    var body: some View {
        EVGasComparisonHubView()
            .navigationTitle("Cost per Mile")
            .navigationBarTitleDisplayMode(.inline)
    }
}
