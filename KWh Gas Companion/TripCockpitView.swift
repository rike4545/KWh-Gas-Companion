import SwiftUI

struct TripCockpitView: View {
    @State private var distance = 148.0
    @State private var averageSpeed = 48.0
    @State private var energy = 38.0
    @State private var stops = 2
    @State private var routeNote = "Home to mountain overlook"

    private var efficiency: Double {
        guard energy > 0 else { return 0 }
        return distance / energy
    }

    private var estimatedDriveTime: Double {
        guard averageSpeed > 0 else { return 0 }
        return distance / averageSpeed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripCockpitHero(
                    routeNote: routeNote,
                    distance: distance,
                    energy: energy,
                    stops: stops,
                    efficiency: efficiency
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TripCockpitMetric(title: "Average speed", value: "\(Int(averageSpeed))", unit: "mph", systemImage: "speedometer")
                    TripCockpitMetric(title: "Drive time", value: String(format: "%.1f", estimatedDriveTime), unit: "hr", systemImage: "clock.fill")
                    TripCockpitMetric(title: "Energy used", value: String(format: "%.1f", energy), unit: "kWh", systemImage: "bolt.fill")
                    TripCockpitMetric(title: "Stops", value: "\(stops)", unit: stops == 1 ? "stop" : "stops", systemImage: "mappin.and.ellipse")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Tune the Route")
                        .font(.headline)

                    TripCockpitSlider(title: "Distance", value: $distance, range: 0...800, step: 1, formattedValue: "\(Int(distance)) mi")
                    TripCockpitSlider(title: "Average speed", value: $averageSpeed, range: 0...85, step: 1, formattedValue: "\(Int(averageSpeed)) mph")
                    TripCockpitSlider(title: "Energy", value: $energy, range: 0...180, step: 0.5, formattedValue: String(format: "%.1f kWh", energy))

                    Stepper(value: $stops, in: 0...12) {
                        LabeledContent("Planned stops", value: "\(stops)")
                    }

                    TextField("Route note", text: $routeNote, axis: .vertical)
                        .lineLimit(2...)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("\(routeNote) is tracking at \(String(format: "%.1f", efficiency)) mi/kWh across \(Int(distance)) miles.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(TripCockpitBackground().ignoresSafeArea())
        .navigationTitle("Trip Cockpit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TripCockpitHero: View {
    let routeNote: String
    let distance: Double
    let energy: Double
    let stops: Int
    let efficiency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "road.lanes")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(routeNote.isEmpty ? "Untitled route" : routeNote)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(Int(distance)) miles, \(String(format: "%.1f", energy)) kWh, \(stops) stops")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Efficiency")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("\(String(format: "%.1f", efficiency)) mi/kWh")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Spacer()

                Image(systemName: efficiency >= 3.5 ? "leaf.fill" : "gauge.with.dots.needle.bottom.50percent")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct TripCockpitMetric: View {
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

private struct TripCockpitSlider: View {
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

private struct TripCockpitBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(red: 0.04, green: 0.08, blue: 0.10)]
                : [Color(red: 0.96, green: 0.99, blue: 1.0), Color(red: 0.92, green: 0.96, blue: 0.99)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
