//
//  HyperDriveCharts.swift
//  KWh Gas Companion
//
//  Lightweight, reusable Charts views with safe, generic APIs.
//  No dependencies on app-specific types.
//
//  Swift 6 • iOS 17+
//
//  Notes:
//  - Swift 6 removed implicit tuple-splat in closures, so we avoid `{ a, b in }`
//    for tuple inputs and instead use a small indexed wrapper.
//  - All math helpers are file-private and prefixed to reduce collisions.
//

import SwiftUI

#if canImport(Charts)
import Charts
#endif

// MARK: - Namespace

/// A namespace for reusable chart views.
public enum HyperDriveCharts {}

// MARK: - Small Helpers

#if canImport(Charts)
fileprivate struct _HDCIndexed<Element>: Identifiable {
    let id: Int
    let element: Element
}

fileprivate extension RandomAccessCollection {
    func _hdcIndexed() -> [_HDCIndexed<Element>] {
        Array(self.enumerated()).map { _HDCIndexed(id: $0.offset, element: $0.element) }
    }
}
#endif

// MARK: - Sparkline (generic X/Y)

#if canImport(Charts)
public extension HyperDriveCharts {
    struct Sparkline<Data, X: Plottable, Y: Plottable>: View where Data: RandomAccessCollection {
        private let data: Data
        private let x: KeyPath<Data.Element, X>
        private let y: KeyPath<Data.Element, Y>

        private var showPoints = false
        private var showArea = true
        private var yDomain: ClosedRange<Double>? = nil
        private var lineWidth: CGFloat = 2

        public init(_ data: Data,
                    x: KeyPath<Data.Element, X>,
                    y: KeyPath<Data.Element, Y>) {
            self.data = data
            self.x = x
            self.y = y
        }

        public func points(_ visible: Bool) -> Self {
            var c = self
            c.showPoints = visible
            return c
        }

        public func area(_ visible: Bool) -> Self {
            var c = self
            c.showArea = visible
            return c
        }

        public func yScale(_ domain: ClosedRange<Double>?) -> Self {
            var c = self
            c.yDomain = domain
            return c
        }

        public func width(_ w: CGFloat) -> Self {
            var c = self
            c.lineWidth = w
            return c
        }

        public var body: some View {
            let indexed = data._hdcIndexed()

            return Chart(indexed) { item in
                let element = item.element

                LineMark(
                    x: .value("x", element[keyPath: x]),
                    y: .value("y", element[keyPath: y])
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                if showArea {
                    AreaMark(
                        x: .value("x", element[keyPath: x]),
                        y: .value("y", element[keyPath: y])
                    )
                    .interpolationMethod(.catmullRom)
                    .opacity(0.15)
                }

                if showPoints {
                    PointMark(
                        x: .value("x", element[keyPath: x]),
                        y: .value("y", element[keyPath: y])
                    )
                    .symbolSize(15)
                }
            }
            .kwhInteractiveDataViz()
            .ifLet(yDomain) { view, domain in
                view.chartYScale(domain: domain)
            }
        }
    }
}
#endif

// MARK: - TimeSeries Line (Date, Double) with MA overlay

#if canImport(Charts)
public extension HyperDriveCharts {
    struct TimeSeriesLine<Data>: View where Data: RandomAccessCollection {
        private let data: Data
        private let date: KeyPath<Data.Element, Date>
        private let value: KeyPath<Data.Element, Double>

        private var showAverage = false
        private var averageWindow = 7
        private var yDomain: ClosedRange<Double>? = nil
        private var lineWidth: CGFloat = 2
        private var showPoints = false

        public init(_ data: Data,
                    date: KeyPath<Data.Element, Date>,
                    value: KeyPath<Data.Element, Double>) {
            self.data = data
            self.date = date
            self.value = value
        }

        public func movingAverage(window: Int = 7) -> Self {
            var c = self
            c.showAverage = true
            c.averageWindow = max(1, window)
            return c
        }

        public func yScale(_ domain: ClosedRange<Double>?) -> Self {
            var c = self
            c.yDomain = domain
            return c
        }

        public func width(_ w: CGFloat) -> Self {
            var c = self
            c.lineWidth = w
            return c
        }

        public func points(_ visible: Bool) -> Self {
            var c = self
            c.showPoints = visible
            return c
        }

        public var body: some View {
            let indexed = data._hdcIndexed()
            let base = indexed.map { $0.element[keyPath: value] }
            let ma: [Double] = showAverage ? _hdcMovingAverage(base, window: averageWindow) : []

            return Chart(indexed) { item in
                let element = item.element
                let idx = item.id

                LineMark(
                    x: .value("Date", element[keyPath: date]),
                    y: .value("Value", element[keyPath: value])
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                if showPoints {
                    PointMark(
                        x: .value("Date", element[keyPath: date]),
                        y: .value("Value", element[keyPath: value])
                    )
                    .symbolSize(15)
                }

                if showAverage, idx < ma.count {
                    LineMark(
                        x: .value("Date", element[keyPath: date]),
                        y: .value("Avg", ma[idx])
                    )
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
            }
            .kwhInteractiveDataViz()
            .ifLet(yDomain) { view, domain in
                view.chartYScale(domain: domain)
            }
        }
    }
}
#endif

// MARK: - Bar (categorical X, numeric Y)

#if canImport(Charts)
public extension HyperDriveCharts {
    struct Bar<Data, X: Plottable>: View where Data: RandomAccessCollection {
        private let data: Data
        private let x: KeyPath<Data.Element, X>
        private let y: KeyPath<Data.Element, Double>

        private var cornerRadius: CGFloat = 6
        private var yDomain: ClosedRange<Double>? = nil
        private var showValues = false
        private var valueFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))

        public init(_ data: Data,
                    x: KeyPath<Data.Element, X>,
                    y: KeyPath<Data.Element, Double>) {
            self.data = data
            self.x = x
            self.y = y
        }

        public func radius(_ r: CGFloat) -> Self {
            var c = self
            c.cornerRadius = r
            return c
        }

        public func yScale(_ domain: ClosedRange<Double>?) -> Self {
            var c = self
            c.yDomain = domain
            return c
        }

        public func dataLabels(_ visible: Bool,
                               format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))) -> Self {
            var c = self
            c.showValues = visible
            c.valueFormat = format
            return c
        }

        public var body: some View {
            let indexed = data._hdcIndexed()

            return Chart(indexed) { item in
                let element = item.element

                BarMark(
                    x: .value("Category", element[keyPath: x]),
                    y: .value("Value", element[keyPath: y])
                )
                .cornerRadius(cornerRadius)
                .annotation(position: .top, alignment: .center) {
                    if showValues {
                        Text(element[keyPath: y], format: valueFormat)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .kwhInteractiveDataViz()
            .ifLet(yDomain) { view, domain in
                view.chartYScale(domain: domain)
            }
        }
    }
}
#endif

// MARK: - Donut / Pie

#if canImport(Charts)
public extension HyperDriveCharts {
    struct Donut<Data, Category: Plottable>: View where Data: RandomAccessCollection {

        struct Slice: Identifiable {
            let id = UUID()
            let category: Category
            let value: Double
        }

        private let slices: [Slice]
        private var innerRatio: CGFloat = 0.62
        private var showLegend = true
        private var totalFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))
        private var centerTitle: String? = nil

        public init(_ data: Data,
                    category: KeyPath<Data.Element, Category>,
                    value: KeyPath<Data.Element, Double>) {
            self.slices = data.map { Slice(category: $0[keyPath: category], value: $0[keyPath: value]) }
        }

        public func hole(_ ratio: CGFloat) -> Self {
            var c = self
            c.innerRatio = min(max(ratio, 0), 0.95)
            return c
        }

        public func legend(_ visible: Bool) -> Self {
            var c = self
            c.showLegend = visible
            return c
        }

        public func centerText(_ title: String?,
                               totalFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0))) -> Self {
            var c = self
            c.centerTitle = title
            c.totalFormat = totalFormat
            return c
        }

        public var body: some View {
            let total = slices.reduce(0) { $0 + $1.value }

            return ZStack {
                Chart(slices) { s in
                    SectorMark(
                        angle: .value("Value", s.value),
                        innerRadius: .ratio(innerRatio),
                        outerRadius: .ratio(1.0)
                    )
                    .foregroundStyle(by: .value("Category", s.category))
                }
                .kwhInteractiveChartSurface()

                if let title = centerTitle {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(total, format: totalFormat)
                            .font(.headline)
                    }
                }
            }
            .chartLegend(showLegend ? .visible : .hidden)
        }
    }
}
#endif

// MARK: - Scatter (Double, Double) + optional trendline

#if canImport(Charts)
public extension HyperDriveCharts {
    struct Scatter<Data>: View where Data: RandomAccessCollection {
        private let data: Data
        private let x: KeyPath<Data.Element, Double>
        private let y: KeyPath<Data.Element, Double>

        private var regression = false
        private var yDomain: ClosedRange<Double>? = nil
        private var xDomain: ClosedRange<Double>? = nil

        public init(_ data: Data,
                    x: KeyPath<Data.Element, Double>,
                    y: KeyPath<Data.Element, Double>) {
            self.data = data
            self.x = x
            self.y = y
        }

        public func trendline(_ visible: Bool) -> Self {
            var c = self
            c.regression = visible
            return c
        }

        public func yScale(_ domain: ClosedRange<Double>?) -> Self {
            var c = self
            c.yDomain = domain
            return c
        }

        public func xScale(_ domain: ClosedRange<Double>?) -> Self {
            var c = self
            c.xDomain = domain
            return c
        }

        public var body: some View {
            let indexed = data._hdcIndexed()
            let pts = indexed.map { (Double($0.element[keyPath: x]), Double($0.element[keyPath: y])) }
            let lr = regression ? _hdcLinearRegression(pts) : nil

            return Chart {
                ForEach(indexed) { item in
                    let element = item.element
                    PointMark(
                        x: .value("x", element[keyPath: x]),
                        y: .value("y", element[keyPath: y])
                    )
                }

                if let lr {
                    let (m, b, minX, maxX) = lr

                    LineMark(
                        x: .value("x", minX),
                        y: .value("y", m * minX + b)
                    )
                    LineMark(
                        x: .value("x", maxX),
                        y: .value("y", m * maxX + b)
                    )
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
            }
            .kwhInteractiveDataViz()
            .ifLet(yDomain) { view, domain in
                view.chartYScale(domain: domain)
            }
            .ifLet(xDomain) { view, domain in
                view.chartXScale(domain: domain)
            }
        }
    }
}
#endif

// MARK: - View helpers

fileprivate extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Math helpers (file-private to avoid collisions)

/// Simple centered moving average. Returns array aligned to input length.
fileprivate func _hdcMovingAverage(_ values: [Double], window: Int) -> [Double] {
    let n = max(window, 1)
    guard !values.isEmpty else { return [] }
    var out = Array(repeating: 0.0, count: values.count)

    // Cumulative sum for O(n)
    var cumsum = [0.0]
    cumsum.reserveCapacity(values.count + 1)
    for v in values { cumsum.append(cumsum.last! + v) }

    for i in values.indices {
        let half = n / 2
        let lo = max(0, i - half)
        let hi = min(values.count - 1, i + (n - 1 - half))
        let sum = cumsum[hi + 1] - cumsum[lo]
        out[i] = sum / Double(hi - lo + 1)
    }
    return out
}

/// Ordinary least squares y = m*x + b, returning (m, b, minX, maxX).
fileprivate func _hdcLinearRegression(_ pts: [(Double, Double)]) -> (m: Double, b: Double, minX: Double, maxX: Double)? {
    guard pts.count >= 2 else { return nil }
    let n = Double(pts.count)
    let sumX = pts.reduce(0) { $0 + $1.0 }
    let sumY = pts.reduce(0) { $0 + $1.1 }
    let sumXX = pts.reduce(0) { $0 + $1.0 * $1.0 }
    let sumXY = pts.reduce(0) { $0 + $1.0 * $1.1 }

    let denom = (n * sumXX - sumX * sumX)
    guard denom != 0 else { return nil }

    let m = (n * sumXY - sumX * sumY) / denom
    let b = (sumY - m * sumX) / n
    let minX = pts.map { $0.0 }.min() ?? 0
    let maxX = pts.map { $0.0 }.max() ?? 0
    return (m, b, minX, maxX)
}

// MARK: - Previews (optional)

#if DEBUG && canImport(Charts)
struct HyperDriveCharts_Previews: PreviewProvider {
    struct DemoPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let category: String
    }

    static var sample: [DemoPoint] = {
        let now = Date()
        return (0..<28).map { i in
            .init(
                date: Calendar.current.date(byAdding: .day, value: -27 + i, to: now)!,
                value: Double.random(in: 20...100),
                category: ["Home", "Fast", "Public"].randomElement()!
            )
        }
    }()

    static var previews: some View {
        VStack(spacing: 24) {
            HyperDriveCharts.Sparkline(sample, x: \.date, y: \.value)
                .points(true)
                .area(true)
                .width(2)
                .frame(height: 120)
                .padding()

            HyperDriveCharts.TimeSeriesLine(sample, date: \.date, value: \.value)
                .movingAverage(window: 5)
                .points(true)
                .frame(height: 200)
                .padding()

            HyperDriveCharts.Bar(sample, x: \.category, y: \.value)
                .dataLabels(true, format: .number.precision(.fractionLength(0)))
                .frame(height: 220)
                .padding()

            HyperDriveCharts.Donut(sample, category: \.category, value: \.value)
                .centerText("Total", totalFormat: .number.precision(.fractionLength(0)))
                .hole(0.6)
                .frame(height: 240)
                .padding()

            HyperDriveCharts.Scatter(sample, x: \.value, y: \.value)
                .trendline(true)
                .frame(height: 220)
                .padding()
        }
        .padding()
    }
}
#endif
