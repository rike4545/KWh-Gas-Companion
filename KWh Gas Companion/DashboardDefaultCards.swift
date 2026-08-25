import SwiftUI

// MARK: - Style token

struct DashboardCardStyle {
    let surface: AnyShapeStyle
    let spacing: CGFloat
    let corner: CGFloat
    let pillTint: Color
    let separator: Color
    let accent: Color
}

// MARK: - Spending breakdown card

struct DashboardSpendingBreakdownCard<CollapseControl: View>: View {
    let spending: DashboardSpending
    let currencyCode: String
    let style: DashboardCardStyle
    let isCollapsed: Bool
    @ViewBuilder let collapseControl: () -> CollapseControl

    var body: some View {
        DashboardCardChrome(style: style) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Spending Breakdown", systemImage: "chart.bar.xaxis").font(.headline)
                    Spacer()
                    DashboardPill(text: "This month", tint: style.pillTint)
                    collapseControl()
                }
                if !isCollapsed {
                    // Segmented colour bar — visual split at a glance
                    if spending.totalBuckets > 0 {
                        SpendingSegmentBar(spending: spending)
                            .frame(height: 8)
                            .padding(.bottom, 2)
                        SpendingLegend()
                            .padding(.bottom, 4)
                    }

                    spendRow("Supercharging", spending.superchargingTotal)
                    if spending.superchargingTeslaFi > 0 || spending.superchargingEntries > 0 {
                        Text([
                            spending.superchargingTeslaFi > 0
                                ? "Imported: \(currency(spending.superchargingTeslaFi))" : nil,
                            spending.superchargingEntries > 0
                                ? "Entries: \(currency(spending.superchargingEntries))" : nil
                        ].compactMap { $0 }.joined(separator: " \u{2022} "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if spending.hasPossibleOverlap {
                            Text("Note: If you logged the same sessions in Entries and imported session data, totals may overlap.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DashboardDivider(color: style.separator, opacity: 0.25)
                    spendRow("Lease / Car Payment", spending.lease)
                    spendRow("Insurance", spending.insurance)
                    spendRow("Misc", spending.misc)
                    DashboardDivider(color: style.separator, opacity: 0.25)
                    HStack {
                        Text("Total:").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(currency(spending.totalBuckets))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func spendRow(_ title: String, _ amount: Double) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(currency(amount)).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
    }
}

// MARK: - Segment bar + legend

private struct SpendingSegmentBar: View {
    let spending: DashboardSpending

    private var segments: [(color: Color, fraction: Double)] {
        let total = max(spending.totalBuckets, 0.01)
        return [
            (.blue,   spending.superchargingTotal / total),
            (.teal,   spending.lease / total),
            (.pink,   spending.insurance / total),
            (.gray,   spending.misc / total)
        ].filter { $0.fraction > 0 }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments.indices, id: \.self) { i in
                    Capsule()
                        .fill(segments[i].color.opacity(0.85))
                        .frame(width: max(geo.size.width * segments[i].fraction - 2, 4))
                }
            }
        }
    }
}

private struct SpendingLegend: View {
    private let items: [(color: Color, label: String)] = [
        (.blue,  "Supercharging"),
        (.teal,  "Lease"),
        (.pink,  "Insurance"),
        (.gray,  "Misc")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Circle()
                        .fill(items[i].color.opacity(0.85))
                        .frame(width: 7, height: 7)
                    Text(items[i].label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Budget card

struct DashboardBudgetCard<CollapseControl: View>: View {
    let spending: DashboardSpending
    let currencyCode: String
    let style: DashboardCardStyle
    let isCollapsed: Bool
    let useCategoryBudgets: Bool
    let totalBudget: Double
    let superchargingBudget: Double
    let leaseBudget: Double
    let insuranceBudget: Double
    let miscBudget: Double
    let projectedMonthlySpend: Double?
    let daysRemaining: Int
    let onEdit: () -> Void
    @ViewBuilder let collapseControl: () -> CollapseControl

    private var isOverBudget: Bool { spending.totalBuckets > totalBudget }

    var body: some View {
        DashboardCardChrome(style: style) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Budget",
                          systemImage: useCategoryBudgets ? "target" : "banknote")
                        .font(.headline)
                    Spacer()
                    Button("Edit", action: onEdit).font(.footnote.weight(.semibold))
                    collapseControl()
                }
                if !isCollapsed {
                    if totalBudget <= 0 {
                        emptyState
                    } else {
                        // Large headline number + pace chip on the same row
                        HStack(alignment: .firstTextBaseline) {
                            Text(currency(spending.totalBuckets))
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                            Text("/ \(currency(totalBudget))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            BudgetPaceChip(isOver: isOverBudget)
                        }

                        let progress = min(spending.totalBuckets / max(totalBudget, 0.01), 1)
                        ProgressBar(progress: progress, style: style, height: 10)

                        HStack {
                            let remaining = totalBudget - spending.totalBuckets
                            Text(remaining >= 0
                                 ? "Remaining: \(currency(remaining))"
                                 : "Over by \(currency(abs(remaining)))")
                            .font(.footnote)
                            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)

                            Spacer()

                            if let projected = projectedMonthlySpend, projected > 0 {
                                Text("Projected: \(currency(projected))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if daysRemaining > 0 { paceText }

                        if useCategoryBudgets {
                            DashboardDivider(color: style.separator, opacity: 0.22)
                            categoryBudgetRow(title: "Supercharging",
                                             spent: spending.superchargingTotal,
                                             budget: superchargingBudget)
                            categoryBudgetRow(title: "Lease / Payment",
                                             spent: spending.lease,
                                             budget: leaseBudget)
                            categoryBudgetRow(title: "Insurance",
                                             spent: spending.insurance,
                                             budget: insuranceBudget)
                            categoryBudgetRow(title: "Misc",
                                             spent: spending.misc,
                                             budget: miscBudget)
                        }
                    }
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(useCategoryBudgets
                 ? "Set per-category budgets to track Supercharging, Lease/Payment, Insurance, and Misc."
                 : "Set an overall monthly budget to track progress.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            Button(action: onEdit) {
                Label("Set budgets", systemImage: "slider.horizontal.3")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(style.pillTint))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Pace text

    private var paceText: some View {
        let remaining = totalBudget - spending.totalBuckets
        let neededPerDay = remaining / Double(daysRemaining)
        return Text(remaining >= 0
                    ? "To stay on budget: \(currency(neededPerDay)) /day"
                    : "Over by \(currency(abs(remaining))) so far")
            .font(.footnote)
            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
    }

    // MARK: Category row

    private func categoryBudgetRow(title: String, spent: Double, budget: Double) -> some View {
        let progress = budget > 0 ? min(max(spent / max(budget, 0.01), 0), 1) : 0
        let remaining = budget - spent
        let isOver = remaining < 0

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(currency(spent))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isOver ? Color.red : Color.primary)
            }
            if budget > 0 {
                ProgressBar(progress: progress, style: style, height: 6)
                Text(isOver
                     ? "Budget \(currency(budget)) \u{2022} Over \(currency(abs(remaining)))"
                     : "Budget \(currency(budget)) \u{2022} Remaining \(currency(remaining))")
                    .font(.caption)
                    .foregroundStyle(isOver ? Color.red : Color.secondary)
            } else {
                Text("No budget set for this category.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
    }
}

// MARK: - Pace chip

private struct BudgetPaceChip: View {
    let isOver: Bool

    var body: some View {
        Text(isOver ? "Over budget" : "On pace")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(isOver
                    ? Color.red.opacity(0.12)
                    : Color.green.opacity(0.12))
            )
            .foregroundStyle(isOver ? Color.red : Color.green)
    }
}

// MARK: - Data sources card

struct DashboardDataSourcesCard<CollapseControl: View>: View {
    let entryCount: Int
    let importedSessionCount: Int
    let missingImportedCostCount: Int   // ← new: passed in from snapshot
    let missingEntryCostCount: Int      // ← new: passed in from snapshot
    let style: DashboardCardStyle
    let isCollapsed: Bool
    @ViewBuilder let collapseControl: () -> CollapseControl

    var body: some View {
        DashboardCardChrome(style: style) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Data Sources", systemImage: "tray.full").font(.headline)
                    Spacer()
                    collapseControl()
                }
                if !isCollapsed {
                    sourceRow(
                        systemImage: "doc.text",
                        tint: .blue,
                        title: "Entries (this month)",
                        count: entryCount,
                        healthLabel: missingEntryCostCount == 0
                            ? "All costs recorded"
                            : "\(missingEntryCostCount) missing cost",
                        healthOK: missingEntryCostCount == 0
                    )

                    DashboardDivider(color: style.separator, opacity: 0.22)

                    sourceRow(
                        systemImage: "icloud.and.arrow.down",
                        tint: .secondary,
                        title: "Imported sessions (this month)",
                        count: importedSessionCount,
                        healthLabel: missingImportedCostCount == 0
                            ? "All costs recorded"
                            : "\(missingImportedCostCount) session\(missingImportedCostCount == 1 ? "" : "s") missing cost",
                        healthOK: missingImportedCostCount == 0
                    )
                }
            }
        }
    }

    private func sourceRow(
        systemImage: String,
        tint: Color,
        title: String,
        count: Int,
        healthLabel: String,
        healthOK: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(tint.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    Image(systemName: healthOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(healthOK ? Color.green : Color.red)
                    Text(healthLabel)
                        .font(.caption)
                        .foregroundStyle(healthOK ? Color.green : Color.red)
                }
            }

            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

// MARK: - Recent activity card

struct DashboardRecentActivityCard<CollapseControl: View>: View {
    @EnvironmentObject private var entriesStore: EntriesStore

    let entries: [ExpenseEntry]
    let importedSessions: [TeslaFiSession]
    let currencyCode: String
    let style: DashboardCardStyle
    let isCollapsed: Bool
    @ViewBuilder let collapseControl: () -> CollapseControl

    var body: some View {
        DashboardCardChrome(style: style) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Recent Activity", systemImage: "clock.arrow.circlepath").font(.headline)
                    Spacer()
                    collapseControl()
                }
                if !isCollapsed {
                    activityContent
                }
            }
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        if entries.isEmpty && importedSessions.isEmpty {
            Text("No activity this month yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            if !entries.isEmpty {
                Text("Latest entries")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(entries.prefix(3)) { entry in
                    NavigationLink {
                        AddEditEntryView(entry: entry) { entriesStore.upsert($0) }
                    } label: {
                        activityRow(
                            icon: entryIcon(for: entry),
                            iconTint: entryIconTint(for: entry),
                            title: entry.location ?? entry.charging?.siteName ?? entry.category,
                            subtitle: dateTime(entry.date),
                            trailing: currency(entry.amount, code: entry.currencyCode ?? currencyCode),
                            badge: badge(for: entry),
                            badgeIsAlert: false
                        )
                    }
                    .buttonStyle(.plain)
                    DashboardDivider(color: style.separator, opacity: 0.16)
                }
            }

            if !importedSessions.isEmpty {
                if !entries.isEmpty {
                    DashboardDivider(color: style.separator, opacity: 0.28)
                        .padding(.vertical, 4)
                }
                Text("Latest imported sessions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(importedSessions.prefix(3), id: \.sessionHash) { session in
                    sessionLink(for: session)
                        .buttonStyle(.plain)
                    DashboardDivider(color: style.separator, opacity: 0.16)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionLink(for session: TeslaFiSession) -> some View {
        let isFast = DashboardEntryClassifier.isFastCharge(session)
        let needsReview = session.cost == nil
        let sub = "\(dateTime(session.startDate)) \u{2022} \(String(format: "%.1f", session.energyAddedKWh)) kWh"

        if needsReview {
            NavigationLink { MissingCostAssistantView() } label: {
                activityRow(
                    icon: "bolt.fill",
                    iconTint: .orange,
                    title: session.displayLocation,
                    subtitle: sub,
                    trailing: "Add cost",
                    badge: "Needs review",
                    badgeIsAlert: true
                )
            }
        } else {
            NavigationLink { SessionAnalyticsView() } label: {
                activityRow(
                    icon: isFast ? "bolt.fill" : "icloud.and.arrow.down",
                    iconTint: isFast ? .blue : .secondary,
                    title: session.displayLocation,
                    subtitle: sub,
                    trailing: session.cost.map { currency($0, code: currencyCode) } ?? "\u{2014}",
                    badge: isFast ? "Fast charge" : "Imported",
                    badgeIsAlert: false
                )
            }
        }
    }

    // MARK: Row layout

    private func activityRow(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        trailing: String,
        badge: String?,
        badgeIsAlert: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon badge replaces the old coloured dot
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(badgeIsAlert
                                    ? Color.red.opacity(0.12)
                                    : style.pillTint.opacity(0.85))
                            )
                            .foregroundStyle(badgeIsAlert ? Color.red : Color.primary)
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(trailing)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(badgeIsAlert ? Color.red : Color.primary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    // MARK: Helpers

    private func entryIcon(for entry: ExpenseEntry) -> String {
        if DashboardEntryClassifier.isFastCharge(entry) { return "bolt.fill" }
        if entry.isEnergyEffective { return "plug.fill" }
        if DashboardEntryClassifier.isLeaseOrCarPayment(entry) { return "creditcard.fill" }
        if DashboardEntryClassifier.isInsurance(entry) { return "shield.fill" }
        return "ellipsis.circle.fill"
    }

    private func entryIconTint(for entry: ExpenseEntry) -> Color {
        if DashboardEntryClassifier.isFastCharge(entry) { return .blue }
        if entry.isEnergyEffective { return .green }
        if DashboardEntryClassifier.isLeaseOrCarPayment(entry) { return .purple }
        if DashboardEntryClassifier.isInsurance(entry) { return .orange }
        return .secondary
    }

    private func badge(for entry: ExpenseEntry) -> String? {
        if DashboardEntryClassifier.isFastCharge(entry) { return "Supercharging" }
        if DashboardEntryClassifier.isLeaseOrCarPayment(entry) { return "Payment" }
        if DashboardEntryClassifier.isInsurance(entry) { return "Insurance" }
        return nil
    }

    private func currency(_ value: Double, code: String) -> String {
        value.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    private func dateTime(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
    }
}

// MARK: - Shared primitives

private struct DashboardCardChrome<Content: View>: View {
    let style: DashboardCardStyle
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(padding: style.spacing, corner: style.corner, surface: style.surface)
    }
}

private struct DashboardPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.85)))
    }
}

private struct DashboardDivider: View {
    let color: Color
    let opacity: Double

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// Progress bar whose fill turns red when progress ≥ 1 (over budget).
private struct ProgressBar: View {
    let progress: Double
    let style: DashboardCardStyle
    let height: CGFloat

    private var fillColor: Color {
        progress >= 1 ? .red : style.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(style.pillTint.opacity(0.3))
                    .frame(height: height)
                Capsule()
                    .fill(fillColor.opacity(0.92))
                    .frame(width: geo.size.width * min(progress, 1), height: height)
                    .animation(.easeOut(duration: 0.35), value: progress)
            }
        }
        .frame(height: height)
    }
}
