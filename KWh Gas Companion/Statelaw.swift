//
//  Statelaw.swift
//  KWh Gas Companion
//
//  Created by Bryan on 3/18/26.
//


//
//  LemonLawGuideView.swift
//  My KWh Companion
//
//  Swift 6 / iOS 17+
//
//  Standalone, self-contained view. No external dependencies.
//  Covers lemon law basics for selected U.S. states in plain language
//  with an interactive repair tracker to help users know where they stand.
//
//  LEGAL DISCLAIMER: This is general educational information only.
//  It is not legal advice. Users should consult a licensed attorney
//  for guidance specific to their situation.
//

import SwiftUI

// MARK: - Models

private struct Statelaw: Identifiable {
    let id: String          // two-letter abbreviation
    let name: String
    let color: Color
    let icon: String        // SF Symbol
    let qualifyingRepairs: Int
    let qualifyingDays: Int
    let coverageYears: Int
    let coverageMiles: Int
    let keyFacts: [String]
    let steps: [String]
    let attorneyFeesCovered: Bool
    let arbitrationRequired: Bool
    let presumptionNote: String
}

private struct RepairEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var description: String
    var daysInShop: Int
    var isSameIssue: Bool
}

// MARK: - Data

private let stateLaws: [Statelaw] = [
    Statelaw(
        id: "NY",
        name: "New York",
        color: Color(red: 0.13, green: 0.38, blue: 0.72),
        icon: "building.columns.fill",
        qualifyingRepairs: 4,
        qualifyingDays: 30,
        coverageYears: 2,
        coverageMiles: 18000,
        keyFacts: [
            "4 repair attempts for the same defect, OR",
            "30+ cumulative days out of service within 2 years / 18,000 miles",
            "Defect must substantially impair use, value, or safety",
            "Must first go through manufacturer arbitration (if program exists)",
            "You can get a full refund OR replacement vehicle"
        ],
        steps: [
            "Document every repair visit in writing -- date, description, days kept",
            "Keep all repair orders and invoices",
            "Send written notice to the manufacturer by certified mail",
            "If manufacturer has an arbitration program, file there first",
            "If arbitration fails or doesn't exist, file in court or with the AG"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "NY presumes lemon status after 4 attempts or 30 days. The burden then shifts to the manufacturer to prove the vehicle is NOT a lemon."
    ),
    Statelaw(
        id: "CA",
        name: "California",
        color: Color(red: 0.78, green: 0.18, blue: 0.18),
        icon: "sun.max.fill",
        qualifyingRepairs: 2,
        qualifyingDays: 30,
        coverageYears: 0,  // no year limit -- warranty period
        coverageMiles: 0,  // within warranty
        keyFacts: [
            "2 repair attempts for a defect that could cause death or serious injury, OR",
            "4 repair attempts for any other substantial defect, OR",
            "30+ cumulative days out of service",
            "Must occur within the warranty period (no fixed year/mile cap)",
            "Strongest lemon law in the US -- manufacturer must disprove the presumption"
        ],
        steps: [
            "Document each repair attempt with written repair orders",
            "After 2 serious-safety attempts or 4 general attempts, send a final written demand",
            "You do NOT have to use manufacturer arbitration in California",
            "File directly in court if manufacturer refuses to repurchase",
            "Attorney fees are covered -- many CA lemon law attorneys work on contingency"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: false,
        presumptionNote: "California's Song-Beverly Act creates a strong legal presumption of lemon status. The manufacturer must prove the defect does not substantially impair use, value, or safety."
    ),
    Statelaw(
        id: "FL",
        name: "Florida",
        color: Color(red: 0.96, green: 0.49, blue: 0.0),
        icon: "cloud.sun.fill",
        qualifyingRepairs: 3,
        qualifyingDays: 30,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "3 repair attempts for the same defect (or 1 attempt if likely to cause death/serious injury), OR",
            "30+ cumulative days out of service within 24 months / 24,000 miles",
            "Manufacturer gets one final repair attempt after written notice",
            "Must use manufacturer arbitration before going to court",
            "Covers new vehicles and demonstrators"
        ],
        steps: [
            "Document all repairs with written repair orders from the dealer",
            "After qualifying attempts, send written notice by certified mail",
            "Manufacturer gets a final 10-day / 1-attempt opportunity to fix",
            "If still unresolved, file with the Florida New Motor Vehicle Arbitration Board",
            "Board decision is binding on the manufacturer (but not on you)"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "Florida requires arbitration through the state board before you can sue. The board's decision binds the manufacturer but you can still reject it and go to court."
    ),
    Statelaw(
        id: "WA",
        name: "Washington",
        color: Color(red: 0.13, green: 0.55, blue: 0.33),
        icon: "leaf.fill",
        qualifyingRepairs: 4,
        qualifyingDays: 30,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "4 repair attempts for the same defect, OR",
            "2 attempts if the defect is likely to cause death or serious bodily injury, OR",
            "30+ cumulative days out of service within 2 years / 24,000 miles",
            "Written notice to the manufacturer is required before filing",
            "You may choose refund or replacement"
        ],
        steps: [
            "Keep every repair order -- note the date, mileage, and issue described",
            "After qualifying attempts, send written notice to manufacturer by certified mail",
            "Allow 40 days for manufacturer to respond / resolve",
            "If unresolved, use manufacturer arbitration if available",
            "If still unresolved, file suit in Superior Court"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: false,
        presumptionNote: "Washington requires you to notify the manufacturer in writing and give them a chance to resolve before you can seek relief. Keep copies of all correspondence."
    ),
    Statelaw(
        id: "TX",
        name: "Texas",
        color: Color(red: 0.00, green: 0.49, blue: 0.62),
        icon: "star.fill",
        qualifyingRepairs: 4,
        qualifyingDays: 30,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "4 repair attempts for the same defect, OR",
            "2 repair attempts for the same serious safety defect, OR",
            "30+ cumulative days out of service within 24 months / 24,000 miles",
            "Texas also requires written notice and an opportunity to cure",
            "State-operated lemon law arbitration is part of the process before court"
        ],
        steps: [
            "Keep every repair order and note when the defect was first reported",
            "Send written notice to the manufacturer, converter, or distributor",
            "Give the manufacturer a chance to cure after notice",
            "File with the Texas DMV lemon law process or state-operated arbitration",
            "If unresolved, pursue the remaining remedies available under Texas law"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "Texas uses a strong 24-month / 24,000-mile framework. Serious safety defects can qualify after only two failed repair attempts."
    ),
    Statelaw(
        id: "GA",
        name: "Georgia",
        color: Color(red: 0.71, green: 0.23, blue: 0.20),
        icon: "flag.fill",
        qualifyingRepairs: 3,
        qualifyingDays: 30,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "3 repair attempts for the same defect, OR",
            "1 repair attempt for a serious safety defect, OR",
            "30 cumulative days out of service within 2 years / 24,000 miles",
            "A final repair opportunity is usually required for repeat defects",
            "Georgia uses certified informal dispute resolution and a state panel process"
        ],
        steps: [
            "Report the nonconformity during the 2-year / 24,000-mile rights period",
            "Track whether the defect is a serious safety defect or a recurring defect",
            "If needed, send final-opportunity notice to the manufacturer by certified mail",
            "File with the certified informal dispute mechanism first",
            "If needed, request review through the Georgia Lemon Law Administration"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "Georgia is especially consumer-friendly on serious safety defects: one unsuccessful repair attempt may be enough to trigger the presumption."
    ),
    Statelaw(
        id: "NC",
        name: "North Carolina",
        color: Color(red: 0.10, green: 0.38, blue: 0.65),
        icon: "shield.lefthalf.filled",
        qualifyingRepairs: 4,
        qualifyingDays: 20,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "4 repair attempts for the same defect, OR",
            "20+ business days out of service during one warranty year",
            "Defect must substantially impair value to the consumer",
            "Coverage generally applies if the nonconformity occurs within 2 years / 24,000 miles",
            "Written notice to the manufacturer supports the presumption"
        ],
        steps: [
            "Keep repair orders showing the same symptom or defect description",
            "Track every business day the vehicle is unavailable for repair",
            "Notify the manufacturer directly in writing if you want to rely on the presumption",
            "Preserve warranty documents and all dealer communications",
            "If the defect persists, review refund or replacement remedies under state law"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: false,
        presumptionNote: "North Carolina stands out for its 20-business-day out-of-service path, which can be easier to hit than a 30-day rule in some states."
    ),
    Statelaw(
        id: "OH",
        name: "Ohio",
        color: Color(red: 0.58, green: 0.12, blue: 0.19),
        icon: "car.side.rear.open.fill",
        qualifyingRepairs: 3,
        qualifyingDays: 30,
        coverageYears: 1,
        coverageMiles: 18000,
        keyFacts: [
            "3 repair attempts for the same defect, OR",
            "8 repair attempts for any nonconformity, OR",
            "30+ cumulative days out of service within 1 year / 18,000 miles",
            "1 repair attempt may be enough for a defect likely to cause death or serious bodily injury",
            "Manufacturer-sponsored dispute resolution may need to be used first"
        ],
        steps: [
            "Report the problem to the manufacturer, dealer, or authorized agent within 1 year / 18,000 miles",
            "Keep every repair invoice and note how many total attempts have happened",
            "Track same-defect attempts separately from all attempts combined",
            "Use the dispute resolution process if the manufacturer requires it",
            "If the problem still qualifies, seek refund or replacement under Ohio law"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "Ohio gives consumers multiple paths to qualify, including three same-defect attempts, eight total attempts, 30 days out of service, or one failed repair for a serious safety issue."
    ),
    Statelaw(
        id: "NJ",
        name: "New Jersey",
        color: Color(red: 0.92, green: 0.70, blue: 0.10),
        icon: "building.2.crop.circle.fill",
        qualifyingRepairs: 2,
        qualifyingDays: 20,
        coverageYears: 2,
        coverageMiles: 24000,
        keyFacts: [
            "2 repair attempts for the same defect before final notice, OR",
            "1 repair attempt for a defect likely to cause death or serious bodily injury, OR",
            "20+ cumulative days out of service within 2 years / 24,000 miles",
            "Manufacturer must receive written notice by certified mail",
            "Manufacturer gets a final 10-day chance to fix after notice"
        ],
        steps: [
            "Document each repair attempt and keep the write-up language consistent",
            "Once the threshold is close, send certified-mail notice to the manufacturer",
            "Allow the manufacturer the final 10-day repair opportunity",
            "If the same defect remains, file for relief under New Jersey's Lemon Law process",
            "Preserve all certified mail receipts and final-repair paperwork"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "New Jersey's process is notice-heavy. The certified-mail notice and final 10-day opportunity to repair are central parts of the claim path."
    ),
    Statelaw(
        id: "PA",
        name: "Pennsylvania",
        color: Color(red: 0.16, green: 0.30, blue: 0.55),
        icon: "scroll.fill",
        qualifyingRepairs: 3,
        qualifyingDays: 30,
        coverageYears: 1,
        coverageMiles: 12000,
        keyFacts: [
            "3 repair attempts for the same defect, OR",
            "30+ cumulative calendar days out of service",
            "Defect must substantially impair use, value, or safety",
            "First occurrence usually must happen within 1 year / 12,000 miles or the warranty term",
            "If a compliant informal dispute process exists, consumers generally must use it first"
        ],
        steps: [
            "Deliver the vehicle to an authorized Pennsylvania repair facility when possible",
            "Keep records showing when the same defect was repaired multiple times",
            "After the second repair for the same defect, make sure the dealer notifies the manufacturer",
            "Use the manufacturer's compliant dispute process if one exists",
            "If still unresolved, seek refund or replacement under Pennsylvania law"
        ],
        attorneyFeesCovered: true,
        arbitrationRequired: true,
        presumptionNote: "Pennsylvania has a shorter practical protection window than many states, so early documentation matters more here than in a 2-year / 24,000-mile state."
    )
]

// MARK: - Main View

struct LemonLawGuideView: View {
    @Environment(\.colorScheme) private var scheme

    @State private var selectedState: Statelaw? = nil
    @State private var showDisclaimer = true
    @State private var repairEntries: [RepairEntry] = []
    @State private var showAddRepair = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    if showDisclaimer {
                        disclaimerBanner
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    stateGrid
                        .padding(.top, 24)

                    if let state = selectedState {
                        stateDetailCard(state)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    repairTrackerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    legalFooter
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .background(background)
            .navigationTitle("Lemon Law Guide")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddRepair) {
                AddRepairSheet(entries: $repairEntries)
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.28, blue: 0.28),
                    Color(red: 0.72, green: 0.14, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 56, height: 56)
                        Image(systemName: "car.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lemon Law Guide")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Know your rights. Get your repair.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // State pills
                HStack(spacing: 10) {
                    ForEach(stateLaws) { law in
                        Text(law.id)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selectedState?.id == law.id
                                          ? Color.white
                                          : Color.white.opacity(0.2))
                            )
                            .foregroundStyle(
                                selectedState?.id == law.id
                                ? Color(red: 0.72, green: 0.14, blue: 0.14)
                                : .white
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                    if selectedState?.id == law.id {
                                        selectedState = nil
                                    } else {
                                        selectedState = law
                                    }
                                }
                            }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let state = selectedState {
                    HeroThresholdSnapshot(law: state)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Text("Educational guide for common lemon-law thresholds and repair tracking.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, selectedState == nil ? 6 : 10)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Not Legal Advice")
                    .font(.subheadline.weight(.semibold))
                Text("This guide is for general information only. Laws change and vary by situation. Always consult a licensed attorney for advice specific to your case.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation { showDisclaimer = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(scheme == .dark ? 0.15 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - State grid

    private var stateGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
                Text("Select Your State")
                    .font(.headline)
                    .padding(.horizontal, 20)

                Text(selectedState == nil ? "Choose a state to personalize thresholds and next-step guidance." : "Tap a state card to compare thresholds or switch jurisdictions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Spacer().frame(width: 6)
                    ForEach(stateLaws) { law in
                        StateCardButton(
                            law: law,
                            isSelected: selectedState?.id == law.id,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                    if selectedState?.id == law.id {
                                        selectedState = nil
                                    } else {
                                        selectedState = law
                                    }
                                }
                            }
                        )
                    }
                    Spacer().frame(width: 6)
                }
            }
        }
    }

    // MARK: - State detail

    @ViewBuilder
    private func stateDetailCard(_ law: Statelaw) -> some View {
        VStack(alignment: .leading, spacing: 20) {

            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(law.color.opacity(scheme == .dark ? 0.3 : 0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: law.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(law.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(law.name + " Lemon Law")
                        .font(.title3.weight(.bold))
                    Text("At a glance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Quick numbers
            HStack(spacing: 12) {
                QuickStat(
                    value: "\(law.qualifyingRepairs)",
                    label: "Repair Attempts",
                    icon: "wrench.fill",
                    color: law.color
                )
                QuickStat(
                    value: "\(law.qualifyingDays)",
                    label: "Days in Shop",
                    icon: "calendar",
                    color: law.color
                )
                if law.coverageYears > 0 {
                    QuickStat(
                        value: "\(law.coverageYears) yr",
                        label: "Coverage",
                        icon: "checkmark.shield.fill",
                        color: law.color
                    )
                } else {
                    QuickStat(
                        value: "Warranty",
                        label: "Coverage Period",
                        icon: "checkmark.shield.fill",
                        color: law.color
                    )
                }
            }

            Divider()

            // Key facts
            VStack(alignment: .leading, spacing: 8) {
                Label("Do You Qualify?", systemImage: "questionmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(law.color)

                ForEach(law.keyFacts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(law.color)
                            .padding(.top, 7)
                        Text(fact)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Presumption note
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
                    .padding(.top, 1)
                Text(law.presumptionNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(scheme == .dark ? 0.12 : 0.07))
            )

            Divider()

            // Steps
            VStack(alignment: .leading, spacing: 10) {
                Label("What To Do -- Step by Step", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(law.color)

                ForEach(Array(law.steps.enumerated()), id: \.0) { idx, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(law.color.opacity(scheme == .dark ? 0.3 : 0.12))
                                .frame(width: 26, height: 26)
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(law.color)
                        }
                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                    }
                }
            }

            Divider()

            // Badges
            HStack(spacing: 10) {
                BadgePill(
                    text: law.attorneyFeesCovered ? "Attorney Fees Covered" : "Fees Not Covered",
                    icon: law.attorneyFeesCovered ? "checkmark.circle.fill" : "xmark.circle.fill",
                    ok: law.attorneyFeesCovered
                )
                BadgePill(
                    text: law.arbitrationRequired ? "Arbitration Required" : "No Mandatory Arbitration",
                    icon: law.arbitrationRequired ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    ok: !law.arbitrationRequired
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            StateCoverageNote(law: law)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(
                    color: law.color.opacity(scheme == .dark ? 0.2 : 0.12),
                    radius: 18, x: 0, y: 6
                )
        )
    }

    // MARK: - Repair Tracker

    private var repairTrackerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Repair Log")
                        .font(.headline)
                    Text("Track repair attempts to know where you stand.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showAddRepair = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color(red: 0.72, green: 0.14, blue: 0.14))
            }

            if repairEntries.isEmpty {
                EmptyTrackerCard(selectedState: selectedState)
            } else {
                RepairSummaryCard(
                    entries: repairEntries,
                    selectedState: selectedState
                )

                VStack(spacing: 10) {
                    ForEach(Array(repairEntries.enumerated()), id: \.element.id) { index, entry in
                        RepairEntryRow(entry: entry) {
                            withAnimation(.snappy(duration: 0.25, extraBounce: 0.02)) {
                                let entryID = repairEntries[index].id
                                repairEntries.removeAll { $0.id == entryID }
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: - Footer

    private var legalFooter: some View {
        VStack(spacing: 8) {
            Divider()
            Text("This guide summarizes general lemon law thresholds using public state and BBB AUTO LINE summaries reviewed on March 18, 2026. Laws change, and exact eligibility, notice rules, mileage limits, and dispute-resolution steps vary by state and fact pattern. Consult a licensed attorney in your state for advice on your specific situation.")
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Background

    private var background: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Tracker Status

private enum TrackerStage {
    case chooseState
    case logFirstRepair
    case buildingCase
    case mixedIssuesOnly
    case nearRepairThreshold
    case nearDayThreshold
    case nearBothThresholds
    case qualifiedByRepairs
    case qualifiedByDays
    case qualifiedByBoth

    var title: String {
        switch self {
        case .chooseState:
            return "Choose a state to personalize your status"
        case .logFirstRepair:
            return "Start your paper trail early"
        case .buildingCase:
            return "You are building documentation"
        case .mixedIssuesOnly:
            return "You have visits logged, but not a repeat defect yet"
        case .nearRepairThreshold:
            return "You are close on repeat-repair attempts"
        case .nearDayThreshold:
            return "You are close on days out of service"
        case .nearBothThresholds:
            return "You are approaching both thresholds"
        case .qualifiedByRepairs:
            return "Repeat-repair threshold may be met"
        case .qualifiedByDays:
            return "Days-out-of-service threshold may be met"
        case .qualifiedByBoth:
            return "Both common thresholds may be met"
        }
    }

    var message: String {
        switch self {
        case .chooseState:
            return "Select your state above to compare your repair log against the local threshold."
        case .logFirstRepair:
            return "Log each visit as it happens so you have dates, descriptions, and time in the shop."
        case .buildingCase:
            return "You are below the common presumption threshold, but consistent documentation matters if the issue continues."
        case .mixedIssuesOnly:
            return "Right now your log suggests different issues. Repeating the same substantial defect is often what matters most."
        case .nearRepairThreshold:
            return "One more same-issue repair may matter. Make sure the service write-up uses consistent defect language."
        case .nearDayThreshold:
            return "You are getting close on total days out of service. Keep exact pickup and drop-off dates."
        case .nearBothThresholds:
            return "Your repair history is getting close on both paths. Gather every repair order, message, and invoice now."
        case .qualifiedByRepairs:
            return "Your same-issue count appears to meet the common threshold. Review the state steps and consider legal guidance."
        case .qualifiedByDays:
            return "Your cumulative days out of service appear to meet the common threshold. Check the state process and preserve all records."
        case .qualifiedByBoth:
            return "Your log appears to meet both common thresholds. This is a strong time to organize records and escalate formally."
        }
    }

    var action: String {
        switch self {
        case .chooseState:
            return "Pick a state to unlock tailored guidance."
        case .logFirstRepair:
            return "Add your first repair visit, even if the vehicle was only in the shop for one day."
        case .buildingCase:
            return "Ask the dealer to describe the symptom consistently on each repair order."
        case .mixedIssuesOnly:
            return "If one defect keeps returning, mark only those entries as the same recurring issue."
        case .nearRepairThreshold:
            return "Save photos, messages, and any failed-fix notes before the next visit."
        case .nearDayThreshold:
            return "Include all waiting time when the vehicle was unavailable because of the defect."
        case .nearBothThresholds:
            return "Prepare a written notice packet so you are ready if the next visit does not resolve it."
        case .qualifiedByRepairs:
            return "Your next step is usually written notice, arbitration, or counsel depending on the state."
        case .qualifiedByDays:
            return "Calculate the total days carefully and verify they fall inside the coverage window."
        case .qualifiedByBoth:
            return "Review the state-specific process now and avoid losing paperwork or timeline detail."
        }
    }

    var tint: Color {
        switch self {
        case .chooseState:
            return .blue
        case .logFirstRepair, .buildingCase, .mixedIssuesOnly:
            return .green
        case .nearRepairThreshold, .nearDayThreshold, .nearBothThresholds:
            return .orange
        case .qualifiedByRepairs, .qualifiedByDays, .qualifiedByBoth:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .chooseState:
            return "map.fill"
        case .logFirstRepair:
            return "square.and.pencil"
        case .buildingCase:
            return "doc.text.fill"
        case .mixedIssuesOnly:
            return "square.stack.3d.down.right.fill"
        case .nearRepairThreshold, .nearDayThreshold, .nearBothThresholds:
            return "exclamationmark.circle.fill"
        case .qualifiedByRepairs, .qualifiedByDays, .qualifiedByBoth:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - State Card Button

private struct HeroThresholdSnapshot: View {
    let law: Statelaw

    var body: some View {
        HStack(spacing: 10) {
            SnapshotChip(text: "\(law.qualifyingRepairs) repairs", icon: "wrench.and.screwdriver.fill")
            SnapshotChip(text: "\(law.qualifyingDays) shop days", icon: "calendar.badge.clock")
            SnapshotChip(
                text: law.coverageYears > 0 ? "\(law.coverageYears) yr / \(law.coverageMiles.formatted()) mi" : "Warranty period",
                icon: "checkmark.shield.fill"
            )
        }
    }
}

private struct SnapshotChip: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.16)))
    }
}

private struct StateCardButton: View {
    let law: Statelaw
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? law.color : law.color.opacity(scheme == .dark ? 0.22 : 0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: law.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : law.color)
                }
                Text(law.id)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? law.color : .primary)
                Text(law.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 88)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? law.color.opacity(scheme == .dark ? 0.2 : 0.1)
                          : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? law.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Quick Stat

private struct QuickStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(scheme == .dark ? 0.15 : 0.08))
        )
    }
}

// MARK: - Badge Pill

private struct BadgePill: View {
    let text: String
    let icon: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ok
                      ? Color.green.opacity(0.12)
                      : Color.orange.opacity(0.12))
        )
        .foregroundStyle(ok ? .green : .orange)
    }
}

// MARK: - Empty Tracker Card

private struct EmptyTrackerCard: View {
    let selectedState: Statelaw?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: selectedState == nil ? "map" : "wrench.and.screwdriver")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selectedState == nil ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedState == nil ? "Pick a state, then start logging" : "No repairs logged yet")
                        .font(.subheadline.weight(.semibold))
                    Text(selectedState == nil
                         ? "Selecting a state lets the tracker compare your repair history with the right threshold."
                         : "Tap Add to start tracking visits, repeat defects, and days in the shop.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Helpful details to track", systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TrackerChecklistRow(text: "Exact repair date and how long the vehicle stayed in the shop")
                TrackerChecklistRow(text: "A plain-language description of the defect or symptom")
                TrackerChecklistRow(text: "Whether it is the same recurring issue as a prior visit")
            }

            Text(selectedState == nil
                 ? "Choose a state above when you are ready for tailored status guidance."
                 : "The more consistent your paperwork is, the easier it is to see when a threshold may be close.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

// MARK: - Repair Summary Card

private struct RepairSummaryCard: View {
    let entries: [RepairEntry]
    let selectedState: Statelaw?
    @Environment(\.colorScheme) private var scheme

    private var sameIssueCount: Int {
        entries.filter { $0.isSameIssue }.count
    }

    private var totalDays: Int {
        entries.map { $0.daysInShop }.reduce(0, +)
    }

    private var latestRepairDate: Date? {
        entries.map(\.date).max()
    }

    private var stage: TrackerStage {
        guard let law = selectedState else { return .chooseState }
        let metRepairs = sameIssueCount >= law.qualifyingRepairs
        let metDays = totalDays >= law.qualifyingDays
        let nearRepairs = sameIssueCount == max(law.qualifyingRepairs - 1, 0)
        let nearDays = totalDays >= max(law.qualifyingDays - 5, 0)

        if metRepairs && metDays { return .qualifiedByBoth }
        if metRepairs { return .qualifiedByRepairs }
        if metDays { return .qualifiedByDays }
        if nearRepairs && nearDays { return .nearBothThresholds }
        if nearRepairs { return .nearRepairThreshold }
        if nearDays { return .nearDayThreshold }
        if entries.isEmpty { return .logFirstRepair }
        if sameIssueCount == 0 { return .mixedIssuesOnly }
        return .buildingCase
    }

    private var statusColor: Color {
        stage.tint
    }

    private var coverageSummary: String {
        guard let law = selectedState else { return "Select a state to compare your counts." }
        if law.coverageYears > 0 {
            return "Typical window: \(law.coverageYears) years or \(law.coverageMiles.formatted()) miles."
        }
        return "Typical window: within the warranty period."
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(statusColor.opacity(scheme == .dark ? 0.22 : 0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: stage.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.title)
                        .font(.headline)
                    Text(stage.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same-Issue Repairs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(sameIssueCount)")
                            .font(.title2.weight(.bold))
                        if let law = selectedState {
                            Text("/ \(law.qualifyingRepairs) needed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider().frame(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Days Out")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(totalDays)")
                            .font(.title2.weight(.bold))
                        if let law = selectedState {
                            Text("/ \(law.qualifyingDays) needed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                TrackerMiniStat(
                    label: "All Visits",
                    value: "\(entries.count)",
                    tint: .blue
                )
                TrackerMiniStat(
                    label: "Coverage",
                    value: {
                        let years = selectedState?.coverageYears ?? 0
                        return years > 0 ? "\(years) yr" : "Warranty"
                    }(),
                    tint: selectedState?.color ?? .blue
                )
                TrackerMiniStat(
                    label: "Latest",
                    value: latestRepairDate.map(dateFormatter.string(from:)) ?? "N/A",
                    tint: .secondary,
                    usesAccentTint: false
                )
            }

            // Progress bars
            if let law = selectedState {
                VStack(spacing: 8) {
                    ProgressBarRow(
                        label: "Repair Attempts",
                        current: sameIssueCount,
                        target: law.qualifyingRepairs,
                        color: statusColor
                    )
                    ProgressBarRow(
                        label: "Days Out of Service",
                        current: totalDays,
                        target: law.qualifyingDays,
                        color: statusColor
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Recommended Next Step", systemImage: "arrow.forward.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Text(stage.action)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(coverageSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.85))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor.opacity(scheme == .dark ? 0.12 : 0.07))
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

// MARK: - Progress Bar Row

private struct ProgressBarRow: View {
    let label: String
    let current: Int
    let target: Int
    let color: Color

    private var fraction: Double {
        min(Double(current) / Double(max(target, 1)), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(target)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Repair Entry Row

private struct RepairEntryRow: View {
    let entry: RepairEntry
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var scheme

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(entry.isSameIssue
                          ? Color.red.opacity(scheme == .dark ? 0.22 : 0.1)
                          : Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.isSameIssue ? "wrench.fill" : "wrench")
                    .font(.system(size: 16))
                    .foregroundStyle(entry.isSameIssue ? .red : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.description.isEmpty ? "Repair visit" : entry.description)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("- \(entry.daysInShop) day\(entry.daysInShop == 1 ? "" : "s") in shop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                if entry.isSameIssue {
                    Text("Same issue")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                        .foregroundStyle(.red)
                } else {
                    Text("Different issue")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete repair entry")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

// MARK: - Supporting Tracker Views

private struct TrackerChecklistRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TrackerMiniStat: View {
    let label: String
    let value: String
    let tint: Color
    var usesAccentTint = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(usesAccentTint ? tint : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(usesAccentTint ? 0.12 : 0.08))
        )
    }
}

private struct StateCoverageNote: View {
    let law: Statelaw
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundStyle(law.color)
                .padding(.top, 1)
            Text(law.coverageYears > 0
                 ? "Typical coverage window: \(law.coverageYears) years or \(law.coverageMiles.formatted()) miles, whichever comes first."
                 : "Typical coverage window: during the applicable warranty period rather than a fixed year or mileage cap.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(law.color.opacity(scheme == .dark ? 0.16 : 0.08))
        )
    }
}

// MARK: - Add Repair Sheet

private struct AddRepairSheet: View {
    @Binding var entries: [RepairEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var description = ""
    @State private var daysInShop = 1
    @State private var isSameIssue = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Repair Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Issue description (e.g. battery not charging)", text: $description)
                    Stepper("Days in shop: \(daysInShop)", value: $daysInShop, in: 1...365)
                }

                Section {
                    Toggle("Same recurring issue", isOn: $isSameIssue)
                    if isSameIssue {
                        Text("Mark this if the repair is for the same defect as a previous visit. This count is what triggers lemon law thresholds.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Save Repair Entry") {
                        let entry = RepairEntry(
                            date: date,
                            description: description,
                            daysInShop: daysInShop,
                            isSameIssue: isSameIssue
                        )
                        entries.append(entry)
                        entries.sort { $0.date > $1.date }
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .bold()
                }
            }
            .navigationTitle("Log a Repair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LemonLawGuideView()
}
#endif
