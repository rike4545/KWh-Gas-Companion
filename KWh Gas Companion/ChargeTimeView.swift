import SwiftUI

struct ChargeTimeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var kWh = ""
    @State private var rate = ""

    private var estimated: String {
        guard let k = Double(kWh), let r = Double(rate), r > 0 else { return "--" }
        let hours = k / r
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh %dm", h, m)
    }

    var body: some View {
        NavigationStack {
            // Use adaptive layout for iPhone vs iPad
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 16) {
                        inputFields
                        resultView
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        inputFields
                        resultView
                    }
                    .padding()
                }
            }
            .navigationTitle("Charge Time")
            .accessibilityElement(children: .contain)
        }
    }
    
    private var inputFields: some View {
        Group {
            TextField("Total kWh", text: $kWh)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Total kilowatt hours to charge")
                .accessibilityHint("Enter the total energy in kilowatt hours")

            TextField("Rate (kW)", text: $rate)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Charging rate in kilowatts")
                .accessibilityHint("Enter the charger power in kilowatts")
        }
    }
    
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated Time:")
                .font(.headline)
                .accessibilityHidden(true)

            Text(estimated)
                .font(.title)
                .bold()
                .accessibilityLabel("Estimated charging time")
                .accessibilityValue(estimated)
                .accessibilityHint("Calculated from total energy and charging rate")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemFill)))
        .accessibilityElement(children: .combine)
    }
}

struct ChargeTimeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChargeTimeView()
                .previewDevice("iPhone 14")
            ChargeTimeView()
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
