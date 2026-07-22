import SwiftUI
import SafariServices

@MainActor
struct NHTSACrashReportingView: View {
    @State private var selectedURL: IdentifiedNHTSAURL?

    private let sourceURL = URL(string: "https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting#data")!

    var body: some View {
        NavigationStack {
            ZStack {
                NHTSABackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        NHTSACard {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "car.rear.and.tire.marks")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("NHTSA Crash Reporting")
                                        .font(.title3.weight(.semibold))
                                    Text("Standing General Order data for ADS and Level 2 crash reporting.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        NHTSACard(title: "Official source") {
                            Text("This tool points to NHTSA's official Standing General Order page and its public crash-reporting data section.")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Button {
                                selectedURL = IdentifiedNHTSAURL(sourceURL)
                            } label: {
                                Label("Open official NHTSA page", systemImage: "safari")
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal)

                        NHTSACard(title: "What it covers") {
                            VStack(alignment: .leading, spacing: 10) {
                                NHTSARow(title: "ADS reports", detail: "Automated driving systems in use or recently disengaged.")
                                NHTSARow(title: "Level 2 reports", detail: "Specified ADAS features such as lane centering with adaptive cruise control.")
                                NHTSARow(title: "Source", detail: "Crash reports submitted by manufacturers and operators under the federal order.")
                                NHTSARow(title: "Use case", detail: "A regulatory reporting feed and research reference, not a simple safety leaderboard.")
                            }
                        }
                        .padding(.horizontal)

                        NHTSACard(title: "Why comparisons can mislead") {
                            VStack(alignment: .leading, spacing: 10) {
                                NHTSABullet(text: "The dataset is not intended for apples-to-apples manufacturer comparisons.")
                                NHTSABullet(text: "Counts are not normalized by miles driven, fleet size, or feature usage.")
                                NHTSABullet(text: "Manufacturers can differ in ODD, sensing stack, reporting maturity, and deployment scale.")
                                NHTSABullet(text: "Reports may evolve over time as investigations continue.")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("NHTSA Crash Reporting")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedURL) { item in
                NHTSASafariSheet(url: item.url)
            }
        }
    }
}

private struct NHTSARow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NHTSABullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 7, height: 7)
                .padding(.top, 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private struct IdentifiedNHTSAURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
    init(_ url: URL) { self.url = url }
}

private struct NHTSASafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct NHTSABackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(red: 0.06, green: 0.08, blue: 0.13)]
                : [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.91, green: 0.95, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct NHTSACard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    NHTSACrashReportingView()
}
