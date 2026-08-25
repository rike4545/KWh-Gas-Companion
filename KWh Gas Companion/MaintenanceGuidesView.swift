//
//  MaintenanceGuidesView.swift
//  KWh Gas Companion
//
//  DIY / maintenance guide hub + detail reader.
//  Swift 6 • iOS 17+
//

import SwiftUI

// MARK: - Progress

/// Tracks which guide steps have been checked off.
/// Persisted as a "|" delimited list of step ids, matching the pattern used by EtiquetteFavorites.
@MainActor
final class MaintenanceGuideProgress: ObservableObject {
    @AppStorage("maint_guide_done_steps_v1") private var raw: String = ""

    @Published private(set) var completed: Set<String> = []

    init() {
        completed = Self.parse(raw)
    }

    func isDone(_ stepID: String) -> Bool { completed.contains(stepID) }

    func toggle(_ stepID: String) {
        var next = completed
        if next.contains(stepID) { next.remove(stepID) } else { next.insert(stepID) }
        raw = Self.serialize(next)
        completed = next
    }

    func completedCount(for guide: MaintenanceGuide) -> Int {
        guide.steps.reduce(into: 0) { total, step in
            if completed.contains(step.id) { total += 1 }
        }
    }

    func isFinished(_ guide: MaintenanceGuide) -> Bool {
        !guide.steps.isEmpty && completedCount(for: guide) == guide.steps.count
    }

    func reset(_ guide: MaintenanceGuide) {
        var next = completed
        for step in guide.steps { next.remove(step.id) }
        raw = Self.serialize(next)
        completed = next
    }

    private static func parse(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "|").map(String.init).filter { !$0.isEmpty })
    }

    private static func serialize(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "|")
    }
}

// MARK: - Hub

@MainActor
struct MaintenanceGuidesView: View {

    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var progress = MaintenanceGuideProgress()

    @State private var query: String = ""
    @State private var selectedCategory: MaintenanceGuideCategory?

    private var theme: any AppThemeSpec { themeBox.base }

    private var filtered: [MaintenanceGuide] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MaintenanceGuideLibrary.all.filter { guide in
            if let selectedCategory, guide.category != selectedCategory { return false }
            guard !trimmed.isEmpty else { return true }
            return trimmed
                .split(separator: " ")
                .allSatisfy { guide.searchBlob.contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing) {
                headerCard
                searchField
                categoryFilter

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No guides match",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different term, or clear the category filter.")
                    )
                    .padding(.top, 24)
                } else {
                    ForEach(filtered) { guide in
                        NavigationLink {
                            MaintenanceGuideDetailView(guide: guide, progress: progress)
                        } label: {
                            MaintenanceGuideCard(guide: guide, progress: progress, theme: theme)
                        }
                        .buttonStyle(.plain)
                    }
                }

                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("DIY & Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Garage guides", systemImage: "wrench.and.screwdriver.fill")
                .font(.headline)
            Text("Step-by-step procedures for the jobs worth doing yourself — with the tools, torque specs, and touchscreen resets each one needs. Check off steps as you go; your progress is saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    // Inline rather than `.searchable` — the Tools dashboard already owns the
    // navigation bar's search field on this stack, so a nested one never renders.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Search guides, tools, specs", text: $query)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.pillTint.opacity(0.28), in: Capsule(style: .continuous))
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", systemImage: "square.grid.2x2", isOn: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(MaintenanceGuideLibrary.categoriesInUse) { category in
                    filterChip(
                        title: category.rawValue,
                        systemImage: category.systemImage,
                        isOn: selectedCategory == category
                    ) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isOn ? theme.accent.opacity(0.22) : theme.pillTint.opacity(0.30),
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isOn ? theme.accent.opacity(0.55) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Before you start", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(MaintenanceGuideLibrary.disclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .padding(.top, 4)
    }
}

// MARK: - Hub card

private struct MaintenanceGuideCard: View {
    let guide: MaintenanceGuide
    @ObservedObject var progress: MaintenanceGuideProgress
    let theme: any AppThemeSpec

    private var done: Int { progress.completedCount(for: guide) }
    private var total: Int { guide.steps.count }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(String(format: "%02d", guide.number))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: guide.systemImage)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 34, height: 34)
                    .background(theme.pillTint.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(guide.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(guide.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(guide.timeEstimate, systemImage: "clock")
                    Label(guide.difficulty.rawValue, systemImage: guide.difficulty.systemImage)
                    if total > 0 && done > 0 {
                        Label(
                            progress.isFinished(guide) ? "Done" : "\(done)/\(total)",
                            systemImage: progress.isFinished(guide) ? "checkmark.circle.fill" : "checklist"
                        )
                        .foregroundStyle(progress.isFinished(guide) ? Color.green : Color.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

// MARK: - Detail

@MainActor
struct MaintenanceGuideDetailView: View {

    let guide: MaintenanceGuide
    @ObservedObject var progress: MaintenanceGuideProgress

    @Environment(\.appThemeBox) private var themeBox
    @State private var showingLogSheet = false

    private var theme: any AppThemeSpec { themeBox.base }

    private var done: Int { progress.completedCount(for: guide) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                heroCard

                if !guide.specs.isEmpty { specsCard }
                if !guide.tools.isEmpty || !guide.parts.isEmpty { toolsCard }
                if !guide.steps.isEmpty { stepsSection }
                if !guide.warnings.isEmpty { warningsCard }
                if !guide.tips.isEmpty { tipsCard }
                if let reset = guide.resetNote { resetCard(reset) }

                logButton
                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Rectangle().fill(theme.screenBackground).ignoresSafeArea())
        .toolbar {
            if done > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        progress.reset(guide)
                    } label: {
                        Label("Reset progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            DIYServiceEntryEditor(
                prefillTitle: guide.title,
                prefillNotes: guide.summary,
                prefillTags: ["DIY", guide.category.rawValue]
            ) { entry in
                let store = DIYServiceVaultStore()
                store.items.insert(entry, at: 0)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: guide.systemImage)
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                Text(String(format: "Guide %02d", guide.number))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(guide.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            WrapChips(chips: [
                (guide.category.rawValue, guide.category.systemImage),
                (guide.difficulty.rawValue, guide.difficulty.systemImage),
                (guide.timeEstimate, "clock"),
                (guide.appliesTo, "car")
            ], theme: theme)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(prominent: true)
    }

    private var specsCard: some View {
        card(title: "Specs", systemImage: "ruler") {
            VStack(spacing: 8) {
                ForEach(guide.specs) { spec in
                    HStack(alignment: .top, spacing: 12) {
                        Text(spec.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(spec.value)
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if spec.id != guide.specs.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    private var toolsCard: some View {
        card(title: "Tools & parts", systemImage: "wrench.adjustable") {
            VStack(alignment: .leading, spacing: 12) {
                if !guide.tools.isEmpty {
                    listBlock(heading: "Tools", items: guide.tools, systemImage: "screwdriver")
                }
                if !guide.parts.isEmpty {
                    listBlock(heading: "Parts", items: guide.parts, systemImage: "shippingbox")
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            HStack {
                Text("Steps")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(done)/\(guide.steps.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            ForEach(guide.steps) { step in
                stepRow(step)
            }
        }
    }

    private func stepRow(_ step: MaintenanceGuideStep) -> some View {
        let isDone = progress.isDone(step.id)

        return Button {
            progress.toggle(step.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? Color.green : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step \(step.number)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(step.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .strikethrough(isDone, color: .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)

                if let caution = step.caution {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(caution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 32)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isDone ? 0.68 : 1)
            .themedCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(step.number). \(step.title)")
        .accessibilityValue(isDone ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle")
    }

    private var warningsCard: some View {
        card(title: "Warnings", systemImage: "exclamationmark.triangle.fill", tint: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(guide.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                        Text(warning)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var tipsCard: some View {
        card(title: "Tips", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(guide.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(tip)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func resetCard(_ note: String) -> some View {
        card(title: "Reset the reminder", systemImage: "arrow.counterclockwise.circle") {
            Text(note)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var logButton: some View {
        Button {
            showingLogSheet = true
        } label: {
            Label("Log this to DIY Service Vault", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.pillTint.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var disclaimerCard: some View {
        Text(MaintenanceGuideLibrary.disclaimer)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }

    // MARK: Helpers

    private func listBlock(heading: String, items: [String], systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func card<Content: View>(
        title: String,
        systemImage: String,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint ?? .primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

// MARK: - Chips

private struct WrapChips: View {
    let chips: [(String, String)]
    let theme: any AppThemeSpec

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                Label(chip.0, systemImage: chip.1)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.pillTint.opacity(0.35), in: Capsule(style: .continuous))
            }
        }
    }
}

// Chips reflow using the shared FlowLayout declared in NotificationRole.swift.
