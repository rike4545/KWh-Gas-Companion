import SwiftUI

struct AltitudeCockpitView: View {
    @State private var currentAltitude = 412.0
    @State private var routeHigh = 1860.0
    @State private var routeLow = 68.0

    private var netClimb: Double {
        max(0, routeHigh - routeLow)
    }

    private var altitudeBand: String {
        switch netClimb {
        case 0..<800: return "Gentle profile"
        case 800..<2500: return "Rolling climb"
        default: return "Mountain profile"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AltitudeHeroCard(
                    band: altitudeBand,
                    currentAltitude: currentAltitude,
                    netClimb: netClimb
                )

                AltitudeProfileCard(routeLow: routeLow, currentAltitude: currentAltitude, routeHigh: routeHigh)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    AltitudeMetricCard(title: "Current", value: "\(Int(currentAltitude))", unit: "ft", systemImage: "location.fill")
                    AltitudeMetricCard(title: "Route high", value: "\(Int(routeHigh))", unit: "ft", systemImage: "mountain.2.fill")
                    AltitudeMetricCard(title: "Route low", value: "\(Int(routeLow))", unit: "ft", systemImage: "arrow.down.to.line.compact")
                    AltitudeMetricCard(title: "Net climb", value: "\(Int(netClimb))", unit: "ft", systemImage: "arrow.up.right")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Record Elevation")
                        .font(.headline)
                    AltitudeSlider(title: "Current altitude", value: $currentAltitude, range: 0...12000, step: 10, formattedValue: "\(Int(currentAltitude)) ft")
                    AltitudeSlider(title: "Route high", value: $routeHigh, range: 0...14000, step: 10, formattedValue: "\(Int(routeHigh)) ft")
                    AltitudeSlider(title: "Route low", value: $routeLow, range: 0...6000, step: 10, formattedValue: "\(Int(routeLow)) ft")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Trip Note", systemImage: "map.fill")
                        .font(.headline)
                    Text("Use this no-login cockpit for mountain drives, bridge-heavy routes, and elevation swings that can change range expectations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding()
        }
        .background(AltitudeCockpitBackground().ignoresSafeArea())
        .navigationTitle("Altitude Cockpit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AltitudeHeroCard: View {
    let band: String
    let currentAltitude: Double
    let netClimb: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Altitude Profile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(band)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(Int(currentAltitude)) ft now • \(Int(netClimb)) ft route climb")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.green, Color.teal, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct AltitudeProfileCard: View {
    let routeLow: Double
    let currentAltitude: Double
    let routeHigh: Double

    private var currentPosition: Double {
        guard routeHigh > routeLow else { return 0.5 }
        return min(1, max(0, (currentAltitude - routeLow) / (routeHigh - routeLow)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Shape")
                .font(.headline)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.16))
                        .frame(height: 12)
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(12, width * currentPosition), height: 12)
                    Circle()
                        .fill(.tint)
                        .frame(width: 22, height: 22)
                        .offset(x: min(max(0, width * currentPosition - 11), max(0, width - 22)))
                }
            }
            .frame(height: 24)

            HStack {
                Text("Low \(Int(routeLow)) ft")
                Spacer()
                Text("High \(Int(routeHigh)) ft")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AltitudeMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AltitudeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formattedValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: formattedValue)
                .font(.subheadline.weight(.semibold))
            Slider(value: $value, in: range, step: step)
        }
    }
}

private struct AltitudeCockpitBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(red: 0.04, green: 0.09, blue: 0.08)]
                : [Color(red: 0.97, green: 0.99, blue: 0.97), Color(red: 0.91, green: 0.97, blue: 0.96)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
