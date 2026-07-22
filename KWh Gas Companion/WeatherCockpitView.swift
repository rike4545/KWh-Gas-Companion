import SwiftUI

struct WeatherCockpitView: View {
    @State private var temperature = 64.0
    @State private var wind = 12.0
    @State private var humidity = 58.0
    @State private var rainRisk = 20.0

    private var impactScore: Int {
        let coldPenalty = max(0, 45 - temperature) * 0.7
        let heatPenalty = max(0, temperature - 85) * 0.45
        let windPenalty = wind * 0.8
        let rainPenalty = rainRisk * 0.25
        let humidityPenalty = max(0, humidity - 70) * 0.15
        return min(100, Int((coldPenalty + heatPenalty + windPenalty + rainPenalty + humidityPenalty).rounded()))
    }

    private var impactTitle: String {
        switch impactScore {
        case 0..<18: return "Low range impact"
        case 18..<42: return "Watch efficiency"
        default: return "Plan extra margin"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeatherHeroCard(
                    temperature: temperature,
                    impactScore: impactScore,
                    impactTitle: impactTitle
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    WeatherMetricCard(title: "Wind", value: "\(Int(wind))", unit: "mph", systemImage: "wind")
                    WeatherMetricCard(title: "Humidity", value: "\(Int(humidity))", unit: "%", systemImage: "humidity.fill")
                    WeatherMetricCard(title: "Rain risk", value: "\(Int(rainRisk))", unit: "%", systemImage: "cloud.rain.fill")
                    WeatherMetricCard(title: "Impact", value: "\(impactScore)", unit: "/100", systemImage: "gauge.with.dots.needle.67percent")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Adjust Forecast")
                        .font(.headline)
                    WeatherSlider(title: "Temperature", value: $temperature, range: -10...110, step: 1, formattedValue: "\(Int(temperature)) F")
                    WeatherSlider(title: "Wind", value: $wind, range: 0...60, step: 1, formattedValue: "\(Int(wind)) mph")
                    WeatherSlider(title: "Humidity", value: $humidity, range: 0...100, step: 1, formattedValue: "\(Int(humidity))%")
                    WeatherSlider(title: "Rain risk", value: $rainRisk, range: 0...100, step: 1, formattedValue: "\(Int(rainRisk))%")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label("EV Impact", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                        .font(.headline)
                    Text("Headwinds, rain, cold cabin preconditioning, and high humidity can shift trip efficiency. Keep this beside route planning when weather is unsettled.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding()
        }
        .background(WeatherCockpitBackground().ignoresSafeArea())
        .navigationTitle("Weather Cockpit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeatherHeroCard: View {
    let temperature: Double
    let impactScore: Int
    let impactTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route Weather")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                    Text(impactTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(Int(temperature)) F outside, \(impactScore)/100 efficiency pressure")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            ProgressView(value: Double(impactScore), total: 100)
                .tint(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.cyan, Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct WeatherMetricCard: View {
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

private struct WeatherSlider: View {
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

private struct WeatherCockpitBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(red: 0.04, green: 0.07, blue: 0.13)]
                : [Color(red: 0.97, green: 0.99, blue: 1.0), Color(red: 0.91, green: 0.96, blue: 0.98)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
