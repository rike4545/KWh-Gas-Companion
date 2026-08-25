///
/// IncentivesView.swift
/// MyKwH Companion
/// Created by Bryan on 7/15/25.

import SwiftUI
import Foundation

struct IncentivesView: View {
    @State private var snapshot = TeslaIncentiveSnapshot.fallback
    @State private var isRefreshing = false
    @State private var lastRefresh: Date?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard

                if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .themedCard()
                }

                sectionHeader("Vehicle Offers", systemImage: "car.fill")
                ForEach(snapshot.vehicleOffers) { offer in
                    vehicleCard(offer)
                }

                sectionHeader("Featured Perks", systemImage: "star.fill")
                ForEach(snapshot.featuredPerks) { item in
                    highlightCard(item)
                }

                sectionHeader("Still Worth Checking", systemImage: "checklist")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.ongoingNotes) { note in
                        noteRow(note)
                    }
                }
                .themedCard()

                if !snapshot.referenceLinks.isEmpty {
                    sectionHeader("Official Links", systemImage: "link")
                    VStack(spacing: 12) {
                        ForEach(snapshot.referenceLinks) { link in
                            sourceLinkCard(link)
                        }
                    }
                }

                Text("Offers can change quickly. Confirm trim eligibility, geography, and end dates before ordering.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Tesla Incentives")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard lastRefresh == nil else { return }
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Live U.S. snapshot", systemImage: "bolt.badge.checkmark.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Spacer()
                if let lastRefresh {
                    Text(lastRefresh.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Current Tesla incentives")
                .font(.title3.weight(.bold))

            Text(snapshot.heroSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                quickStat(title: "Models", value: "\(snapshot.vehicleOffers.count)")
                quickStat(title: "Deadline", value: snapshot.primaryDeadline)
                quickStat(title: "Perks", value: "\(snapshot.featuredPerks.count)")
            }
        }
        .themedCard(prominent: true)
    }

    @ViewBuilder
    private func vehicleCard(_ offer: VehicleOffer) -> some View {
        let card = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(offer.model)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(offer.deadline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }

            if let financing = offer.financing {
                Label(financing, systemImage: "percent")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if let lease = offer.lease {
                Label(lease, systemImage: "creditcard")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if offer.url != nil {
                Label("Open official page", systemImage: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .themedCard()

        if let url = offer.url {
            Link(destination: url) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    @ViewBuilder
    private func highlightCard(_ item: IncentiveHighlight) -> some View {
        let card = VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(item.badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if item.url != nil {
                Label("Open official page", systemImage: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .themedCard()

        if let url = item.url {
            Link(destination: url) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    @ViewBuilder
    private func noteRow(_ note: IncentiveNote) -> some View {
        let row = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Label(note.title, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(note.badge)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(note.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let url = note.url {
            Link(destination: url) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func sourceLinkCard(_ link: IncentiveReferenceLink) -> some View {
        Link(destination: link.url) {
            HStack(spacing: 12) {
                Image(systemName: "safari")
                    .font(.title3)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(link.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(link.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .themedCard()
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.red)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal, 4)
    }

    private func quickStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try await TeslaIncentivesFeed.fetchSnapshot()
            loadError = nil
            lastRefresh = Date()
        } catch {
            loadError = "Live update unavailable. Showing the last built-in snapshot."
            if lastRefresh == nil {
                lastRefresh = Date()
            }
        }
    }
}

private struct VehicleOffer: Identifiable, Hashable {
    let id: String
    let model: String
    let financing: String?
    let lease: String?
    let deadline: String
    let url: URL?
}

private struct IncentiveHighlight: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let badge: String
    let url: URL?
}

private struct IncentiveNote: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let badge: String
    let url: URL?
}

private struct IncentiveReferenceLink: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let url: URL
}

private struct TeslaIncentiveSnapshot: Hashable {
    let heroSummary: String
    let primaryDeadline: String
    let vehicleOffers: [VehicleOffer]
    let featuredPerks: [IncentiveHighlight]
    let ongoingNotes: [IncentiveNote]
    let referenceLinks: [IncentiveReferenceLink]

    static let fallback = TeslaIncentiveSnapshot(
        heroSummary: "Latest tracked U.S. Tesla finance, lease, and ownership perks, with the biggest model offers clustered around late-March deadlines.",
        primaryDeadline: "3/31/26",
        vehicleOffers: [
            .init(id: "model3", model: "Model 3", financing: "2.99% APR for up to 72 months on Premium RWD, AWD, and Performance trims.", lease: "$399/mo with $4,094 down for 36 months and 10,000 annual miles.", deadline: "March 31, 2026", url: URL(string: "https://www.tesla.com/model3/design?redirect=no#overview")),
            .init(id: "modely", model: "Model Y", financing: "0% APR on Standard RWD/AWD, 0.99% APR on Premium RWD/AWD, and 5.29% APR on Performance.", lease: "$459/mo with $4,155 down for 36 months and 10,000 annual miles.", deadline: "March 31, 2026", url: URL(string: "https://www.tesla.com/modely/design?redirect=no#overview")),
            .init(id: "models", model: "Model S", financing: "3.99% APR for up to 72 months.", lease: "$1,617/mo with $7,500 down, or $1,769/mo with $2,465 down for 36 months.", deadline: "March 31, 2026", url: URL(string: "https://www.tesla.com/models/design?redirect=no#overview")),
            .init(id: "modelx", model: "Model X", financing: "3.99% APR for up to 72 months.", lease: "$1,773/mo with $7,500 down, or $1,924/mo with $2,620 down for 36 months.", deadline: "March 31, 2026", url: URL(string: "https://www.tesla.com/modelx/design?redirect=no#overview")),
            .init(id: "cybertruck", model: "Cybertruck", financing: "5.29% APR for Dual Motor AWD, 3.99% APR for Premium AWD and Cyberbeast.", lease: "$699/mo with $6,395 down for 36 months and 10,000 annual miles.", deadline: "March 31, 2026", url: URL(string: "https://www.tesla.com/cybertruck/design?redirect=no#overview"))
        ],
        featuredPerks: [
            .init(id: "powerwall", title: "Powerwall 3 rebate", detail: "Up to $1,000 back in the U.S. at $500 per Powerwall 3, max two units. Order by March 31, 2026 and install by September 30, 2026.", badge: "Home Energy", url: URL(string: "https://www.tesla.com/support/energy/powerwall/order/rebate?redirect=no")),
            .init(id: "fsd-transfer", title: "Free FSD transfer", detail: "Existing owners can transfer FSD (Supervised) to a new vehicle, with exclusions on leased and certain business-related cases.", badge: "Ends 3/31", url: URL(string: "https://www.tesla.com/support/fsd-transfer")),
            .init(id: "heroes", title: "Everyday Heroes", detail: "$500 off in the U.S. for military, first responders, medical providers, nurses, students, and teachers.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/american-heroes")),
            .init(id: "loan-interest", title: "Loan interest deduction", detail: "Up to $10,000 per tax year in deductible qualifying auto loan interest for eligible new U.S.-assembled vehicles through December 31, 2028.", badge: "Federal", url: URL(string: "https://www.irs.gov/newsroom/one-big-beautiful-bill-act-tax-deductions-for-working-americans-and-seniors"))
        ],
        ongoingNotes: [
            .init(id: "supercharging-miles", title: "Free Supercharging Miles", detail: "Trade in a gas car and you may qualify for 2,000 free Supercharging miles.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/current-offers")),
            .init(id: "section179", title: "Business Section 179 Deduction", detail: "Qualifying businesses may claim a deduction on eligible new Tesla vehicles over 6,000 lbs GVWR.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/current-offers")),
            .init(id: "fsd-trial", title: "Free 30-day Trial Of FSD", detail: "New Tesla orders include a Supervised FSD trial, with longer referral-based trials noted in the source feed.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/support/30-day-fsd-trial")),
            .init(id: "premium-connectivity", title: "Free Trial Of Premium Connectivity", detail: "30 days free for Model 3/Y, and 12 months for Cybertruck and Model S/X.", badge: "Ongoing", url: nil),
            .init(id: "demo-inventory", title: "Demo Inventory Discounts", detail: "Discounts on demo inventory vary by mileage and current stock.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/inventory/new/my")),
            .init(id: "state-local", title: "State & Local Incentives", detail: "Location-specific rebates and credits continue to change and should be checked before purchase.", badge: "Ongoing", url: URL(string: "https://www.tesla.com/support/incentives"))
        ],
        referenceLinks: [
            .init(id: "state-local-link", title: "State & Local Incentives", subtitle: "Open Tesla’s location-specific rebates and credits page.", url: URL(string: "https://www.tesla.com/support/incentives")!),
            .init(id: "fsd-transfer-link", title: "FSD Transfer", subtitle: "Open Tesla’s transfer terms page.", url: URL(string: "https://www.tesla.com/support/fsd-transfer")!),
            .init(id: "powerwall-link", title: "Powerwall Rebate", subtitle: "Open Tesla’s Powerwall rebate terms.", url: URL(string: "https://www.tesla.com/support/energy/powerwall/order/rebate?redirect=no")!)
        ]
    )
}

private enum TeslaIncentivesFeed {
    private static let feedURL = URL(string: "https://www.myteslaincentives.com/index.json")!
    private static let referralPath = "/referral/bryan627261"

    static func fetchSnapshot() async throws -> TeslaIncentiveSnapshot {
        let rows = try await fetchNorthAmericaRows()
        return buildSnapshot(from: rows)
    }

    private static func fetchNorthAmericaRows() async throws -> [FeedRow] {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FeedError.badResponse
        }

        let entries = try JSONDecoder().decode([FeedEntry].self, from: data)
        guard let entry = entries.first(where: { $0.title == "Current Tesla Incentives" || $0.permalink.contains("/posts/incentives/") }) else {
            throw FeedError.missingEntry
        }

        return try parseNorthAmericaRows(from: entry.summary)
    }

    private static func parseNorthAmericaRows(from html: String) throws -> [FeedRow] {
        guard
            let northRange = html.range(of: "<strong>North America</strong>"),
            let endRange = html.range(
                of: "<strong>Australia",
                options: [],
                range: northRange.upperBound..<html.endIndex
            )
        else {
            throw FeedError.parsing
        }

        let section = String(html[northRange.lowerBound..<endRange.lowerBound])
        let rowHTML = matches(in: section, pattern: #"<tr>(.*?)</tr>"#, options: [.dotMatchesLineSeparators])

        let rows = rowHTML.compactMap { row -> FeedRow? in
            let cells = matches(in: row, pattern: #"<t[dh][^>]*>(.*?)</t[dh]>"#, options: [.dotMatchesLineSeparators])
            guard cells.count >= 5 else { return nil }

            let title = normalizedText(fromHTML: cells[0])
            guard title.caseInsensitiveCompare("Incentive") != .orderedSame else { return nil }

            let detailHTML = cells[1]
            let detail = normalizedText(fromHTML: detailHTML)
            let urls = extractLinks(from: detailHTML)

            return FeedRow(
                title: title,
                detail: detail,
                products: normalizedText(fromHTML: cells[2]),
                countries: normalizedText(fromHTML: cells[3]),
                endDate: normalizedText(fromHTML: cells[4]),
                urls: urls
            )
        }

        guard !rows.isEmpty else { throw FeedError.parsing }
        return rows
    }

    private static func buildSnapshot(from rows: [FeedRow]) -> TeslaIncentiveSnapshot {
        let vehicleOffers = buildVehicleOffers(from: rows)
        let featuredPerks = buildFeaturedPerks(from: rows)
        let ongoingNotes = buildOngoingNotes(from: rows)
        let referenceLinks = buildReferenceLinks(from: rows)

        let deadline = vehicleOffers.map(\.deadline).first ?? "Tracked"
        let heroSummary = "Latest tracked U.S. Tesla finance, lease, and ownership perks, refreshed from the upstream incentives feed and linked back to official offer pages."

        return TeslaIncentiveSnapshot(
            heroSummary: heroSummary,
            primaryDeadline: shortDeadline(deadline),
            vehicleOffers: vehicleOffers,
            featuredPerks: featuredPerks,
            ongoingNotes: ongoingNotes,
            referenceLinks: referenceLinks
        )
    }

    private static func buildVehicleOffers(from rows: [FeedRow]) -> [VehicleOffer] {
        let models = ["Model 3", "Model Y", "Model S", "Model X", "Cybertruck"]

        return models.compactMap { model in
            let financing = rows.first(where: { $0.title == "Financing Incentives for \(model)" })
            let lease = rows.first(where: { $0.title == "Leasing Incentives for \(model)" })
            guard financing != nil || lease != nil else { return nil }

            return VehicleOffer(
                id: model.lowercased().replacingOccurrences(of: " ", with: "-"),
                model: model,
                financing: financing?.detail,
                lease: lease?.detail,
                deadline: (financing?.endDate ?? lease?.endDate ?? "Ongoing").expandedDate,
                url: preferredOfficialURL(from: (financing?.urls ?? []) + (lease?.urls ?? []))
            )
        }
    }

    private static func buildFeaturedPerks(from rows: [FeedRow]) -> [IncentiveHighlight] {
        let wanted = [
            "Powerwall 3 Rebate",
            "Free FSD Transfer",
            "Everyday Heroes (US)",
            "No Tax on Car Loan Interest Federal Incentive"
        ]

        return wanted.compactMap { title in
            guard let row = rows.first(where: { $0.title == title }) else { return nil }
            return IncentiveHighlight(
                id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: cleanedDisplayTitle(title),
                detail: row.detail,
                badge: row.endDate == "Ongoing" ? "Ongoing" : "Ends \(shortDeadline(row.endDate.expandedDate))",
                url: preferredOfficialURL(from: row.urls)
            )
        }
    }

    private static func buildOngoingNotes(from rows: [FeedRow]) -> [IncentiveNote] {
        let wanted = [
            "Free Supercharging Miles",
            "Business Section 179 Deduction",
            "Free 30-day Trial Of FSD",
            "Free Trial Of Premium Connectivity",
            "Demo Inventory Discounts",
            "State & Local Incentives"
        ]

        return wanted.compactMap { title in
            guard let row = rows.first(where: { $0.title == title }) else { return nil }
            return IncentiveNote(
                id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: cleanedDisplayTitle(title),
                detail: row.detail,
                badge: row.endDate,
                url: preferredOfficialURL(from: row.urls)
            )
        }
    }

    private static func buildReferenceLinks(from rows: [FeedRow]) -> [IncentiveReferenceLink] {
        let references: [(String, String)] = [
            ("State & Local Incentives", "Open Tesla’s location-specific rebates and credits page."),
            ("Free FSD Transfer", "Open Tesla’s transfer terms page."),
            ("Powerwall 3 Rebate", "Open Tesla’s Powerwall rebate terms."),
            ("Everyday Heroes (US)", "Open Tesla’s Everyday Heroes offer page.")
        ]

        return references.compactMap { title, subtitle in
            guard let row = rows.first(where: { $0.title == title }),
                  let url = preferredOfficialURL(from: row.urls) else { return nil }

            return IncentiveReferenceLink(
                id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: cleanedDisplayTitle(title),
                subtitle: subtitle,
                url: url
            )
        }
    }

    private static func preferredOfficialURL(from urls: [URL]) -> URL? {
        let preferred = urls.first {
            guard let host = $0.host?.lowercased() else { return false }
            return host.contains("tesla.com") || host.contains("irs.gov")
        }
        return preferred ?? urls.first
    }

    private static func extractLinks(from html: String) -> [URL] {
        let raw = matches(in: html, pattern: #"href="([^"]+)""#)
        return raw.compactMap { rawURL in
            let decoded = htmlEntityDecode(rawURL)
            guard let url = URL(string: decoded) else { return nil }
            return sanitize(url)
        }
    }

    private static func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if let host = components.host?.lowercased(), host.contains("tesla.com") {
            components.path = referralPath
            components.fragment = nil
            components.queryItems = [
                URLQueryItem(name: "redirect", value: "no"),
                URLQueryItem(name: "target", value: url.absoluteString)
            ]
            return components.url ?? url
        }

        if let items = components.queryItems, !items.isEmpty {
            components.queryItems = items
        }
        return components.url ?? url
    }

    private static func normalizedText(fromHTML html: String) -> String {
        let stripped = html
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return htmlEntityDecode(stripped)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlEntityDecode(_ text: String) -> String {
        var out = text
        let replacements = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&rsquo;": "'",
            "&nbsp;": " "
        ]
        for (from, to) in replacements {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }

    private static func matches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func cleanedDisplayTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: " (US)", with: "")
            .replacingOccurrences(of: " Of ", with: " of ")
    }

    private static func shortDeadline(_ deadline: String) -> String {
        if deadline == "Ongoing" { return deadline }
        let parts = deadline.replacingOccurrences(of: ",", with: "").split(separator: " ")
        guard parts.count >= 3 else { return deadline }
        let month = parts[0].prefix(3)
        let day = parts[1].replacingOccurrences(of: ",", with: "")
        let year = parts[2].suffix(2)
        return "\(month) \(day) '\(year)"
    }

    private enum FeedError: Error {
        case badResponse
        case missingEntry
        case parsing
    }
}

private struct FeedEntry: Decodable {
    let content: String
    let permalink: String
    let summary: String
    let title: String
}

private struct FeedRow: Hashable {
    let title: String
    let detail: String
    let products: String
    let countries: String
    let endDate: String
    let urls: [URL]
}

private extension String {
    var expandedDate: String {
        guard self != "Ongoing" else { return self }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy"
        guard let date = formatter.date(from: self) else { return self }
        return date.formatted(date: .long, time: .omitted)
    }
}

// MARK: - Preview
#if DEBUG
struct IncentivesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            IncentivesView()
        }
    }
}
#endif
