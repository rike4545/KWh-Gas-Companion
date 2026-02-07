import SwiftUI

struct DashboardLayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox

    @ObservedObject var layout: DashboardLayoutStore

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Visible Cards")) {
                    ForEach(layout.order, id: \.self) { kind in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: kind))
                                .foregroundStyle(theme.accent)
                            Text(title(for: kind))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !layout.hidden.contains(kind) },
                                set: { _ in layout.toggleHidden(kind) }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove(perform: move)
                }

                Section {
                    Button("Reset to Tesla Layout") {
                        layout.order = DashboardCardKind.defaultOrder
                        layout.hidden = []
                    }
                }
            }
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        layout.order.move(fromOffsets: source, toOffset: destination)
    }

    private func title(for kind: DashboardCardKind) -> String {
        switch kind {
        case .greeting: return "Greeting"
        case .actionCenter: return "Action Center"
        case .insights: return "Quick Insights"
        case .savingsScore: return "Savings Score"
        case .weeklyForecast: return "Weekly Forecast"
        case .weeklyHealth: return "Weekly Health Report"
        case .schedulePlanner: return "Smart Charging Planner"
        case .priceWatchlist: return "Price Watchlist"
        case .spendingBreakdown: return "Spending Breakdown"
        case .budget: return "Budget"
        case .dataSources: return "Data Sources"
        case .recentActivity: return "Recent Activity"
        }
    }

    private func icon(for kind: DashboardCardKind) -> String {
        switch kind {
        case .greeting: return "wave.3.right"
        case .actionCenter: return "sparkles"
        case .insights: return "lightbulb"
        case .savingsScore: return "gauge.high"
        case .weeklyForecast: return "chart.line.uptrend.xyaxis"
        case .weeklyHealth: return "doc.text.magnifyingglass"
        case .schedulePlanner: return "clock.badge.checkmark"
        case .priceWatchlist: return "tag"
        case .spendingBreakdown: return "chart.bar.xaxis"
        case .budget: return "target"
        case .dataSources: return "tray.2"
        case .recentActivity: return "clock.arrow.circlepath"
        }
    }
}
