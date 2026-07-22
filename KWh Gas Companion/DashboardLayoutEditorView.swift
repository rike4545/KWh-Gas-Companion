import SwiftUI

struct DashboardLayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemeBox) private var themeBox

    @ObservedObject var layout: DashboardLayoutStore

    private var theme: any AppThemeSpec { themeBox.base }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(layout.visibleCount) card\(layout.visibleCount == 1 ? "" : "s") visible")
                            .font(.headline)
                        Text("Choose a focused dashboard or turn on everything, then fine-tune the individual cards below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            layout.applyRecommendedLayout()
                        } label: {
                            presetRow(
                                title: "Recommended Layout",
                                subtitle: "Focused dashboard with the app's suggested cards"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            layout.showAllCards()
                        } label: {
                            presetRow(
                                title: "Show Every Card",
                                subtitle: "Turn on all dashboard cards at once"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

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
                    Button("Reset to Recommended Layout") {
                        layout.applyRecommendedLayout()
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

    private func presetRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.bubble.left")
                .foregroundStyle(theme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func title(for kind: DashboardCardKind) -> String {
        switch kind {
        case .greeting: return "Greeting"
        case .actionCenter: return "Action Center"
        case .costOfCharging: return "Cost of Charging"
        case .gasComparison: return "Gas vs Electric"
        case .insights: return "Quick Insights"
        case .savingsScore: return "Savings Score"
        case .weeklyForecast: return "Weekly Forecast"
        case .gridEmissions: return "Grid Emissions"
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
        case .costOfCharging: return "creditcard.circle"
        case .gasComparison: return "fuelpump"
        case .insights: return "lightbulb"
        case .savingsScore: return "gauge.high"
        case .weeklyForecast: return "chart.line.uptrend.xyaxis"
        case .gridEmissions: return "leaf.circle"
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
