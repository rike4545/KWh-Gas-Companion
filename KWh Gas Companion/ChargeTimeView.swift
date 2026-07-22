import SwiftUI

// 🔧 FIX: Removed self-wrapping NavigationStack.
// ChargeTimeView is pushed via NavigationLink from a parent that already owns a
// NavigationStack. Adding a second NavigationStack here created a double-navigation
// hierarchy: the top bar showed two back buttons, the title animation broke, and
// .navigationTitle on the inner stack was silently ignored. Removed the outer
// NavigationStack so the view inherits the parent's navigation environment.
//
// The previews create their own NavigationStack so they still render correctly.

struct ChargeTimeView: View {
    @Environment(\.appThemeBox) private var themeBox
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var kWh = ""
    @State private var rate = ""

    private var theme: any AppThemeSpec { themeBox.base }

    private var estimated: String {
        guard let k = Double(kWh), let r = Double(rate), r > 0 else { return "--" }
        let hours = k / r
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh %dm", h, m)
    }

    var body: some View {
        // 🔧 FIX: NavigationStack removed — parent navigation stack handles routing.
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                headerCard

                Group {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            inputFields
                            resultView
                        }
                    } else {
                        VStack(spacing: 16) {
                            inputFields
                            resultView
                        }
                    }
                }

                contextCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Charge Time")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .background(
            Rectangle()
                .fill(theme.screenBackground)
                .ignoresSafeArea()
        )
    }

    private var headerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Simple estimate", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)

                Text("Estimate charging time from energy added and average power. This is best for rough planning, not for predicting a full Supercharger curve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputFields: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Inputs", systemImage: "slider.horizontal.3")
                    .font(.headline)

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
    }

    private var resultView: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Time")
                    .font(.headline)
                    .accessibilityHidden(true)

                Text(estimated)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .accessibilityLabel("Estimated charging time")
                    .accessibilityValue(estimated)
                    .accessibilityHint("Calculated from total energy and charging rate")

                Text("Assumes the charger can hold that average power for the whole session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var contextCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Peak vs average", systemImage: "bolt.badge.clock")
                    .font(.headline)

                Text("Real charging is not flat. Tesla's premium NCA packs can briefly approach a 3C rate near a 250 kW Supercharger peak, but power tapers as the battery fills, so the session average is much lower.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Tesla's standard-range LFP packs are typically more conservative, often peaking closer to roughly 1C to 2C. A sustained 3C LFP pack would materially shorten 10% to 80% charging for entry-level models.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("The broader market is moving fast too. Some newer Chinese LFP packs are already advertising rates well above 3C, so this calculator is best treated as an average-power estimate rather than a claim about peak hardware capability.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(theme.spacing)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.corner, style: .continuous)
                .stroke(theme.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: theme.elevation, x: 0, y: 2)
    }
}

// MARK: - Previews

struct ChargeTimeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Previews wrap in NavigationStack so .navigationTitle renders.
            NavigationStack { ChargeTimeView() }
                .previewDevice("iPhone 14")
            NavigationStack { ChargeTimeView() }
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
