import SwiftUI

@MainActor
struct EmergencyPackChecklistView: View {
    @Environment(\.appThemeBox) private var themeBox
    @StateObject private var adsStore = AdsEntitlementStore.shared
    @AppStorage("emergencyPack.completed") private var completedRaw: String = ""

    private var theme: any AppThemeSpec { themeBox.base }

    private let items: [String] = [
        "Charging cable (L2)",
        "Tire inflator or sealant kit",
        "Portable jump starter",
        "Flashlight + batteries",
        "Basic first aid kit",
        "Water + snacks",
        "Warm blanket",
        "Gloves and rain gear",
        "Phone charger / power bank",
        "Reflective triangle or vest"
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
        .navigationTitle("Emergency Pack")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adsStore.load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emergency pack checklist")
                .font(.headline)
            Text("Keep essentials for long trips or outages.")
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
