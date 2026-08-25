import SwiftUI

struct GridEmissionsForecastView: View {
    @Environment(\.openURL) private var openURL

    private let forecast = GridEmissionForecast.sample24Hours()
    private let locations = GridLocationComparison.sampleUS

    private var bestPoint: GridEmissionPoint {
        forecast.min(by: { $0.index < $1.index }) ?? forecast[0]
    }

    private var dirtiestPoint: GridEmissionPoint {
        forecast.max(by: { $0.index < $1.index }) ?? forecast[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                forecastCard
                locationComparisonCard
                integrationCard
                flexibleLoadsCard
            }
            .padding()
        }
        .background(GridEmissionBackground())
        .navigationTitle("Grid Emissions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        GridEmissionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Clean charging forecast", systemImage: "leaf.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text("Use the next 24 hours like a weather forecast for grid emissions.")
                    .font(.title2.weight(.semibold))

                Text("Green windows are cleaner. Red windows are carbon-heavy. Shift flexible electricity use when your schedule allows.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var forecastCard: some View {
        GridEmissionCard(title: "24-hour forecast", icon: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    GridEmissionMetric(title: "Now", value: "\(forecast[0].index)/100", caption: forecast[0].label)
                    GridEmissionMetric(title: "Best", value: bestPoint.hourLabel, caption: "\(bestPoint.index)/100")
                    GridEmissionMetric(title: "Avoid", value: dirtiestPoint.hourLabel, caption: "\(dirtiestPoint.index)/100")
                    GridEmissionMetric(title: "Shift upside", value: "\(max(dirtiestPoint.index - bestPoint.index, 0)) pts", caption: "cleaner")
                }

                GridEmissionStrip(points: forecast)

                HStack {
                    Label("Cleaner", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Label("Carbon-heavy", systemImage: "circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.caption.weight(.semibold))

                Text("Index values are normalized for readability. A live build should map WattTime marginal emissions data into the same green-to-red scale.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationComparisonCard: some View {
        GridEmissionCard(title: "Compare locations", icon: "map") {
            VStack(spacing: 12) {
                ForEach(locations) { location in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(location.color)
                            .frame(width: 12, height: 12)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(location.city)
                                .font(.subheadline.weight(.semibold))
                            Text("\(location.region) • best \(location.bestWindow)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(location.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(location.currentIndex)/100")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(location.color.opacity(0.16), in: Capsule())
                            .foregroundStyle(location.color)
                    }

                    if location.id != locations.last?.id {
                        Divider().opacity(0.12)
                    }
                }
            }
        }
    }

    private var integrationCard: some View {
        GridEmissionCard(title: "WattTime data path", icon: "network") {
            VStack(alignment: .leading, spacing: 12) {
                GridEmissionEndpointRow(label: "Locate grid", value: "/v3/region-from-loc")
                GridEmissionEndpointRow(label: "Real-time", value: "/v3/signal-index")
                GridEmissionEndpointRow(label: "Forecast", value: "/v3/forecast")
                GridEmissionEndpointRow(label: "Signal", value: "co2_moer")

                Text("WattTime requires registration and bearer-token auth. Region lookup should be refreshed at least monthly because grid boundaries can change.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    openURL(URL(string: "https://docs.watttime.org/")!)
                } label: {
                    Label("Open WattTime docs", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var flexibleLoadsCard: some View {
        GridEmissionCard(title: "Flexible-load ideas", icon: "clock.badge.checkmark") {
            VStack(alignment: .leading, spacing: 10) {
                GridEmissionBullet("Start EV charging during the cleanest block when the car does not need to leave immediately.")
                GridEmissionBullet("Run laundry, dishwashing, and water-heating cycles in green windows.")
                GridEmissionBullet("Charge or discharge home batteries around local high- and low-emission periods.")
                GridEmissionBullet("Compare cities before travel or before choosing where to schedule charging.")
            }
        }
    }
}

struct GridEmissionDashboardTile: View {
    private let forecast = GridEmissionForecast.sample24Hours()

    private var bestPoint: GridEmissionPoint {
        forecast.min(by: { $0.index < $1.index }) ?? forecast[0]
    }

    private var dirtiestPoint: GridEmissionPoint {
        forecast.max(by: { $0.index < $1.index }) ?? forecast[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Grid Emissions", systemImage: "leaf.circle.fill")
                    .font(.headline)
                Spacer()
                Text("24 hr")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())
            }

            GridEmissionStrip(points: forecast)

            HStack {
                GridEmissionMetric(title: "Best", value: bestPoint.hourLabel, caption: "\(bestPoint.index)/100")
                GridEmissionMetric(title: "Avoid", value: dirtiestPoint.hourLabel, caption: "\(dirtiestPoint.index)/100")
            }

            NavigationLink {
                GridEmissionsForecastView()
            } label: {
                Label("Open emissions forecast", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
    }
}

struct GridEmissionPoint: Identifiable, Hashable {
    let id = UUID()
    let hour: Int
    let index: Int
    let label: String

    var hourLabel: String {
        let normalized = ((hour % 24) + 24) % 24
        let suffix = normalized < 12 ? "AM" : "PM"
        let display = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(display) \(suffix)"
    }

    var color: Color {
        GridEmissionForecast.color(for: index)
    }
}

struct GridLocationComparison: Identifiable, Hashable {
    let id = UUID()
    let city: String
    let region: String
    let currentIndex: Int
    let bestWindow: String
    let note: String

    var color: Color {
        GridEmissionForecast.color(for: currentIndex)
    }

    static let sampleUS: [GridLocationComparison] = [
        .init(city: "San Jose, CA", region: "CAISO_NORTH", currentIndex: 32, bestWindow: "1 PM - 4 PM", note: "Solar-heavy midday window"),
        .init(city: "Austin, TX", region: "ERCOT", currentIndex: 48, bestWindow: "11 PM - 2 AM", note: "Wind often improves overnight"),
        .init(city: "Chicago, IL", region: "MISO", currentIndex: 66, bestWindow: "3 AM - 6 AM", note: "Cleaner before morning ramp"),
        .init(city: "New York, NY", region: "NYISO_NYC", currentIndex: 58, bestWindow: "10 AM - 1 PM", note: "Moderate daytime window")
    ]
}

enum GridEmissionForecast {
    static func sample24Hours(now: Int = Calendar.current.component(.hour, from: Date())) -> [GridEmissionPoint] {
        let shape = [64, 61, 58, 52, 45, 38, 31, 28, 34, 43, 51, 62, 73, 82, 86, 79, 67, 54, 42, 36, 33, 40, 49, 57]
        return shape.enumerated().map { offset, index in
            GridEmissionPoint(
                hour: (now + offset) % 24,
                index: index,
                label: label(for: index)
            )
        }
    }

    static func label(for index: Int) -> String {
        switch index {
        case ...35: return "Clean"
        case ...55: return "Moderate"
        case ...72: return "Elevated"
        default: return "Carbon-heavy"
        }
    }

    static func color(for index: Int) -> Color {
        switch index {
        case ...35: return .green
        case ...55: return .yellow
        case ...72: return .orange
        default: return .red
        }
    }
}

private struct GridEmissionCard<Content: View>: View {
    var title: String?
    var icon: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title, let icon {
                Label(title, systemImage: icon)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct GridEmissionMetric: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.75)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct GridEmissionStrip: View {
    let points: [GridEmissionPoint]

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(points) { point in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(point.color.gradient)
                        .frame(height: CGFloat(24 + (100 - point.index)) * 0.55)
                        .accessibilityLabel("\(point.hourLabel), \(point.index) out of 100, \(point.label)")
                }
            }
            HStack {
                Text(points.first?.hourLabel ?? "Now")
                Spacer()
                if !points.isEmpty {
                    Text(points[points.count / 2].hourLabel)
                }
                Spacer()
                Text(points.last?.hourLabel ?? "+24h")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Twenty four hour grid emissions forecast")
    }
}

private struct GridEmissionEndpointRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced))
        }
        .font(.subheadline)
    }
}

private struct GridEmissionBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct GridEmissionBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.black, Color(red: 0.04, green: 0.12, blue: 0.10)]
                : [Color(red: 0.96, green: 0.99, blue: 0.97), Color(red: 0.91, green: 0.96, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        GridEmissionsForecastView()
    }
}
