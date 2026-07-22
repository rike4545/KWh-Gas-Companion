import SwiftUI

struct CostPerMileAndCO2View: View {
    init(entries: [ExpenseEntry]? = nil) {}

    var body: some View {
        EVGasComparisonHubView()
            .navigationTitle("Cost & CO2 per Mile")
            .navigationBarTitleDisplayMode(.inline)
    }
}
