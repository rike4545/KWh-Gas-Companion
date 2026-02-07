//
//  TeslaOffer.swift
//  KWh Gas Companion
//
//  Offers + referral hub, with Wardenclyffe background links.
//  Swift 6 / iOS 17+
//

import SwiftUI
import UIKit

@MainActor
struct TeslaOfferView: View {

    // MARK: - URLs

    /// Your personal Tesla referral URL – update here if it ever changes.
    private let referralURL = URL(string: "https://www.tesla.com/referral/bryan627261")!

    private let offersURL = URL(string: "https://www.tesla.com/current-offers")!
    private let clubsURL  = URL(string: "https://engage.tesla.com/pages/clubs")!

    // Wardenclyffe background reading
    private let wardenclyffeWikiURL = URL(string: "https://en.wikipedia.org/wiki/Tesla_Science_Center_at_Wardenclyffe")!
    private let wardenclyffeOatmealURL = URL(string: "https://theoatmeal.com/blog/tesla_museum")!
    private let wardenclyffeCBSURL = URL(string: "https://www.cbsnews.com/sanfrancisco/news/tesla-ceo-pledges-1m-to-proposed-nikola-tesla-museum/")!

    // MARK: - UI State

    @State private var copiedToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                header

                VStack(spacing: 12) {
                    TeslaOfferLinkCard(
                        title: "Current Tesla Offers",
                        subtitle: "Open Tesla’s official promotions page (vehicles + energy products).",
                        url: offersURL,
                        systemImage: "tag.fill"
                    )

                    referralCard
                }

                wardenclyffeCard

                TeslaOfferLinkCard(
                    title: "Official Owners Club Directory",
                    subtitle: "Find Tesla-recognized owners clubs near you.",
                    url: clubsURL,
                    systemImage: "person.3.fill"
                )
                Text("This is not an endorsement of any one particular club. Some clubs are more inclusive than others.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 18)
            }
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .navigationTitle("Tesla Offers")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if copiedToast {
                toast("Copied referral link")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: copiedToast)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offers & Referral")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Text("Quick links for official Tesla offers, your referral link, and a short Wardenclyffe explainer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Referral

    private var referralCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    iconBadge(systemImage: "gift.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Tesla Referral Link")
                            .font(.headline)
                        Text("Use this link when ordering to apply referral benefits (when available).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text(referralURL.absoluteString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Link(destination: referralURL) {
                        Label("Open", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        UIPasteboard.general.string = referralURL.absoluteString
                        showCopiedToast()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: referralURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .groupBoxStyle(TeslaOfferGlassGroupBoxStyle())
    }

    // MARK: - Wardenclyffe

    private var wardenclyffeCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    iconBadge(systemImage: "bolt.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wardenclyffe (Nikola Tesla’s lab)")
                            .font(.headline)
                        Text("A short history + links for context.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Avoids any line-continuation tricks that can break parsing.
                Text("The Tesla Science Center at Wardenclyffe is preserving Tesla’s last remaining laboratory on Long Island.")
                    .font(.body)

                Text("In 2014, public reporting described Elon Musk pledging $1M and a Supercharger installation during a Wardenclyffe event.")
                    .font(.body)

                Text("Tesla Motors has not provided ongoing support to the Tesla Science Center at Wardenclyffe beyond the initial pledge.")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Link("► The Oatmeal’s Wardenclyffe campaign", destination: wardenclyffeOatmealURL)
                    Link("► Background (Wikipedia)", destination: wardenclyffeWikiURL)
                    Link("► 2014 coverage (CBS)", destination: wardenclyffeCBSURL)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .groupBoxStyle(TeslaOfferGlassGroupBoxStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wardenclyffe background. Includes links to The Oatmeal campaign, Wikipedia, and CBS coverage.")
    }

    // MARK: - UI Bits

    private func iconBadge(systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.accent)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private func showCopiedToast() {
        copiedToast = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            copiedToast = false
        }
    }

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12)))
    }
}

// MARK: - Link Card

fileprivate struct TeslaOfferLinkCard: View {
    let title: String
    let subtitle: String
    let url: URL
    let systemImage: String

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.accent)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle). Opens in Safari.")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass GroupBox Style

fileprivate struct TeslaOfferGlassGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
            configuration.content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TeslaOfferView()
            .preferredColorScheme(.dark)
    }
}
#endif
