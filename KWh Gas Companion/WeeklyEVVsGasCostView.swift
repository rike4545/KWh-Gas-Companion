import SwiftUI

@MainActor
struct WeeklyEVVsGasCostView: View {
    var body: some View {
        EVGasComparisonHubView()
            .navigationTitle("Weekly EV vs Gas")
            .navigationBarTitleDisplayMode(.inline)
    }
}
