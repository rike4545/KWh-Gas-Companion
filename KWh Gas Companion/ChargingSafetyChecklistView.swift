import SwiftUI

@MainActor
struct ChargingSafetyChecklistView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @AppStorage("safetyChecklist.completed") private var completedRaw: String = ""

    private var theme: any AppThemeSpec { themeBox.base }

    private let items: [String] = [
        "Check stall number matches your car",
        "Inspect cable for damage",
        "Ensure plug clicks securely",
        "Avoid tripping hazards (cables)",
        "Watch for idle fees if the site is busy",
        "Keep charge port area dry/clean",
        "Never use an adapter you don’t trust"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing) {
                headerCard
                checklistCard

                if !adsStore.hasRemovedAds {
                    AdBannerCard(adsStore: adsStore)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Charging Safety")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick charging safety checklist")
                .font(.headline)
            Text("A short pre‑charge routine to avoid common issues.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .themedCard(prominent: true)
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Toggle(isOn: binding(for: item)) {
                    Text(item)
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
            }

            Button("Reset checklist") {
                completedRaw = ""
            }
            .font(.footnote.weight(.semibold))
        }
        .themedCard()
    }

    private func binding(for item: String) -> Binding<Bool> {
        Binding(
            get: { completedSet.contains(item) },
            set: { newValue in
                var set = completedSet
                if newValue { set.insert(item) } else { set.remove(item) }
                completedRaw = set.joined(separator: "|")
            }
        )
    }

    private var completedSet: Set<String> {
        Set(completedRaw.split(separator: "|").map(String.init))
    }
}
