import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public struct OnboardingFlowView: View {
    @Binding var isPresented: Bool

    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("onboarding.userName") private var storedUserName: String = ""
    @AppStorage("onboarding.primaryGoal") private var storedPrimaryGoal: String = OnboardingPrimaryGoal.saveMoney.rawValue

    @State private var step: OnboardingStep = .welcome
    @State private var draftName: String = ""
    @State private var selectedGoal: OnboardingPrimaryGoal = .saveMoney
    @State private var vehicleNickname: String = ""
    @State private var vehicleMake: String = ""
    @State private var vehicleModel: String = ""
    @State private var vehicleYear: String = ""
    @State private var isEV: Bool = true

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case nickname
        case make
        case model
        case year
    }

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                header

                TabView(selection: $step) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    identityStep.tag(OnboardingStep.identity)
                    valueStep(
                        eyebrow: "Why People Need This Companion",
                        title: "The hardest part of switching to an EV is learning a new rhythm.",
                        body: "If most drivers want a companion during the ICE-to-EV transition, this is the app built for that moment: charging, fuel comparisons, expenses, and ownership context in one calm place.",
                        highlights: [
                            "Charging and gas can live side by side while your habits catch up.",
                            "Weekly trends translate EV behavior into familiar cost and time terms.",
                            "The app stays useful after day one because it explains what changed, not just what happened."
                        ],
                        accent: previewAccent.opacity(0.92),
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                    .tag(OnboardingStep.whyItMatters)

                    vehicleStep.tag(OnboardingStep.vehicle)

                    valueStep(
                        eyebrow: personalizedEyebrow,
                        title: personalizedValueTitle,
                        body: personalizedValueBody,
                        highlights: [
                            personalizedHighlight,
                            "Vehicle-aware tools make planning and comparisons feel tailored instead of generic.",
                            "The interface theme shifts around your vehicle vibe, so the app feels like it belongs to you."
                        ],
                        accent: previewAccent,
                        systemImage: isEV ? "bolt.shield.fill" : "gauge.with.dots.needle.bottom.50percent"
                    )
                    .tag(OnboardingStep.tailoredValue)

                    prioritiesStep.tag(OnboardingStep.priorities)
                    finishStep.tag(OnboardingStep.finish)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: step)

                footer
            }
        }
        .interactiveDismissDisabled()
        .onAppear(perform: loadExistingValues)
    }

    private var accentOptions: [Color] {
        [
            previewAccent.opacity(0.95),
            previewAccent.opacity(0.35),
            Color.white.opacity(scheme == .dark ? 0.08 : 0.35)
        ]
    }

    private var onboardingPrimaryText: Color {
        scheme == .dark ? .white : Color(hex: "#132033")
    }

    private var onboardingSecondaryText: Color {
        scheme == .dark ? Color.white.opacity(0.82) : Color(hex: "#5D6D80")
    }

    private var onboardingTertiaryText: Color {
        scheme == .dark ? Color.white.opacity(0.66) : Color(hex: "#7B8A9B")
    }

    private var onboardingChromeText: Color {
        scheme == .dark ? Color.white.opacity(0.82) : Color(hex: "#3A4A5D")
    }

    private var onboardingChipFill: Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.78)
    }

    private var onboardingGlassFill: Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.74)
    }

    private var onboardingGlassStroke: Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: scheme == .dark ? "#07111F" : "#F5F8FC"),
                    Color(hex: scheme == .dark ? "#0E1827" : "#EEF2F8"),
                    Color(hex: scheme == .dark ? "#141720" : "#FFFFFF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: accentOptions,
                center: .topLeading,
                startRadius: 40,
                endRadius: 430
            )
            .offset(x: -70, y: -110)

            RadialGradient(
                colors: [
                    previewAccent.opacity(0.18),
                    previewAccent.opacity(0.06),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 380
            )
            .offset(x: 90, y: 110)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.04 : 0.26),
                            .clear,
                            Color.black.opacity(scheme == .dark ? 0.14 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(step.badgeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(onboardingChromeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(onboardingChipFill)
                    )

                Spacer()

                Button("Skip setup") {
                    completeOnboarding()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(onboardingChromeText)
            }

            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.self) { item in
                    Capsule(style: .continuous)
                        .fill(item.index <= step.index ? previewAccent : Color.white.opacity(0.18))
                        .frame(height: 6)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                        }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack {
                Button(step == .welcome ? "Maybe later" : "Back") {
                    if step == .welcome {
                        completeOnboarding()
                    } else if let previous = step.previous {
                        focusedField = nil
                        step = previous
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(onboardingChromeText)

                Spacer()

                Button(step == .finish ? "Open My Dashboard" : step.ctaTitle) {
                    handlePrimaryAction()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: "#07111F"))
                .padding(.horizontal, 22)
                .padding(.vertical, 15)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(scheme == .dark ? 0.18 : 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroCard(
                    eyebrow: "My EV Companion",
                    title: personalizedWelcomeTitle,
                    body: "A companion app for the shift from gas-car habits to EV confidence. Keep every current tool, but start with guidance that makes the transition feel less mysterious.",
                    systemImage: "car.side.and.exclamationmark"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What this companion does")
                            .font(.headline)
                            .foregroundStyle(onboardingPrimaryText)

                        onboardingBullet("Learns what you drove, what you drive now, and what feels unfamiliar.")
                        onboardingBullet("Frames charging, range, and cost in terms that make sense to former ICE drivers.")
                        onboardingBullet("Keeps the full dashboard, calculators, imports, budgeting, and vehicle tools ready when you need them.")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var identityStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard(
                    eyebrow: "Personalize",
                    title: "Let’s make the transition feel like it belongs to you.",
                    body: "A little context helps us tailor copy, recommendations, and how the app compares EV life with the gas-car routines you already understand.",
                    systemImage: "person.crop.circle.badge.checkmark"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What should we call you?")
                                .font(.headline)
                                .foregroundStyle(onboardingPrimaryText)
                            TextField("Bryan, Alex, Sam…", text: $draftName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(fieldBackground)
                                .overlay(fieldBorder)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("What matters most right now?")
                                .font(.headline)
                                .foregroundStyle(onboardingPrimaryText)

                            ForEach(OnboardingPrimaryGoal.allCases, id: \.self) { goal in
                                goalButton(goal)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var vehicleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard(
                    eyebrow: "Your Vehicle",
                    title: "Add the vehicle at the center of your transition.",
                    body: "You can change or add more later, but one vehicle now lets the app adapt its tone, tools, comparisons, and assumptions.",
                    systemImage: "car.side.rear.and.collision.and.car.side.front"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        labeledField("Nickname", placeholder: "Daily Driver", text: $vehicleNickname, field: .nickname)
                        labeledField("Make", placeholder: "Tesla, Rivian, Ford…", text: $vehicleMake, field: .make)
                        labeledField("Model", placeholder: "Model Y, R1S, F-150…", text: $vehicleModel, field: .model)
                        labeledField("Year", placeholder: "2026", text: $vehicleYear, field: .year, keyboard: .numberPad)

                        Toggle(isOn: $isEV) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This is an EV")
                                    .foregroundStyle(onboardingPrimaryText)
                                Text("Turn this off if you want to track the ICE vehicle you are comparing against.")
                                    .font(.footnote)
                                    .foregroundStyle(onboardingSecondaryText)
                            }
                        }
                        .tint(previewAccent)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var prioritiesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard(
                    eyebrow: "What You’ll See First",
                    title: dashboardPitchTitle,
                    body: dashboardPitchBody,
                    systemImage: "square.grid.3x3.topleft.fill"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Based on your setup, the app will help you:")
                            .font(.headline)
                            .foregroundStyle(onboardingPrimaryText)

                        onboardingBullet(primaryGoalActionLine)
                        onboardingBullet(vehicleActionLine)
                        onboardingBullet("Build a cleaner weekly rhythm around the costs and patterns that matter to you.")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var finishStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard(
                    eyebrow: "Ready",
                    title: finishTitle,
                    body: finishBody,
                    systemImage: "flag.checkered.2.crossed"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("You’re set up for a stronger first session.")
                            .font(.headline)
                            .foregroundStyle(onboardingPrimaryText)

                        onboardingBullet("You can keep customizing your garage, themes, and data sources in Settings any time.")
                        onboardingBullet("The app stays useful because it keeps telling you why things changed, not just what changed.")
                        onboardingBullet("If you skipped anything, you can revisit onboarding later from Settings.")
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Start here after onboarding")
                            .font(.headline)
                            .foregroundStyle(onboardingPrimaryText)

                        quickStartRow(
                            title: isEV ? "Import charging history" : "Log your first expense",
                            detail: isEV
                                ? "Open the dashboard Action Center or the Charging tab and bring in your first CSV."
                                : "Open the dashboard Action Center and add your first fuel or ownership cost."
                        )
                        quickStartRow(
                            title: "Review your dashboard suggestions",
                            detail: "The Action Center will point you to the most useful next step based on your setup."
                        )
                        quickStartRow(
                            title: "Customize later without losing progress",
                            detail: "Garage details, themes, and onboarding can all be revisited from Settings."
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func valueStep(
        eyebrow: String,
        title: String,
        body: String,
        highlights: [String],
        accent: Color,
        systemImage: String
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard(
                    eyebrow: eyebrow,
                    title: title,
                    body: body,
                    systemImage: systemImage,
                    accent: accent
                )

                VStack(spacing: 14) {
                    ForEach(highlights, id: \.self) { item in
                        glassCard {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(accent)
                                    .font(.title3)

                                Text(item)
                                    .font(.body)
                                    .foregroundStyle(onboardingPrimaryText)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func heroCard(
        eyebrow: String,
        title: String,
        body: String,
        systemImage: String,
        accent: Color? = nil
    ) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(onboardingTertiaryText)

                        Text(title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(onboardingPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        Circle()
                            .fill((accent ?? previewAccent).opacity(0.18))
                            .frame(width: 92, height: 92)
                        Image(systemName: systemImage)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(accent ?? previewAccent)
                    }
                    .accessibilityHidden(true)
                }

                Text(body)
                    .font(.body)
                    .foregroundStyle(onboardingSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func goalButton(_ goal: OnboardingPrimaryGoal) -> some View {
        Button {
            selectedGoal = goal
        } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.systemImage)
                    .font(.title3)
                    .foregroundStyle(selectedGoal == goal ? Color(hex: "#07111F") : onboardingPrimaryText)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(selectedGoal == goal ? Color(hex: "#07111F") : onboardingPrimaryText)

                    Text(goal.subtitle)
                        .font(.footnote)
                        .foregroundStyle(selectedGoal == goal ? Color(hex: "#07111F").opacity(0.74) : onboardingSecondaryText)
                }

                Spacer()

                Image(systemName: selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedGoal == goal ? Color(hex: "#07111F") : onboardingTertiaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedGoal == goal ? previewAccent : (scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.9)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder((scheme == .dark ? Color.white.opacity(selectedGoal == goal ? 0 : 0.08) : Color.black.opacity(selectedGoal == goal ? 0 : 0.06)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(goal.subtitle)
    }

    private func labeledField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundStyle(onboardingPrimaryText)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.words)
                .keyboardType(keyboard)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(fieldBackground)
                .overlay(fieldBorder)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .focused($focusedField, equals: field)
        }
    }

    private func onboardingBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "point.forward.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(previewAccent)
                .padding(.top, 3)

            Text(text)
                .font(.body)
                .foregroundStyle(onboardingPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func quickStartRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(scheme == .dark ? 0.10 : 0.24))
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(previewAccent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(onboardingPrimaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(onboardingSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var fieldBackground: AnyShapeStyle {
        AnyShapeStyle(scheme == .dark ? Color.white.opacity(0.09) : Color.white.opacity(0.92))
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
    }

    private var previewAccent: Color {
        let make = vehicleMake.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if make.contains("tesla") {
            return Color(hex: "#E82127")
        }
        if make.contains("rivian") {
            return Color(hex: "#F5B400")
        }
        return selectedGoal.accent
    }

    private var personalizedWelcomeTitle: String {
        if let firstName = trimmedName {
            return "Welcome, \(firstName). Let’s build your driving command center."
        }
        return "Build your driving command center."
    }

    private var personalizedEyebrow: String {
        if let firstName = trimmedName {
            return "Built for \(firstName)"
        }
        return "Made to fit your routine"
    }

    private var personalizedValueTitle: String {
        switch selectedGoal {
        case .saveMoney:
            return "See where your money is actually going."
        case .understandEfficiency:
            return "Translate every mile into a clearer efficiency story."
        case .planTrips:
            return "Plan with fewer guesses and better charging context."
        }
    }

    private var personalizedValueBody: String {
        let name = trimmedName ?? "You"
        switch selectedGoal {
        case .saveMoney:
            return "\(name) will get better cost visibility across charging, fuel, and ownership decisions, which makes the app useful far beyond simple logging."
        case .understandEfficiency:
            return "\(name) will see how efficiency changes with driving patterns, weather, and session quality, so the app becomes a coach instead of a notebook."
        case .planTrips:
            return "\(name) will have a more practical planning hub for range, route cost, and charging tradeoffs when longer drives show up."
        }
    }

    private var personalizedHighlight: String {
        if let vehicleName = trimmedVehicleDisplayName {
            return "We’ll treat \(vehicleName) like the main character, so the dashboard feels focused from the first screen."
        }
        return "We’ll tailor the app around the vehicle you add, so the dashboard starts with context instead of blank space."
    }

    private var dashboardPitchTitle: String {
        switch selectedGoal {
        case .saveMoney:
            return "Your dashboard will keep money questions front and center."
        case .understandEfficiency:
            return "Your dashboard will emphasize efficiency and vehicle behavior."
        case .planTrips:
            return "Your dashboard will make trip planning feel less reactive."
        }
    }

    private var dashboardPitchBody: String {
        "You’re not just setting preferences. You’re telling the app what good advice looks like for you."
    }

    private var primaryGoalActionLine: String {
        switch selectedGoal {
        case .saveMoney:
            return "Track spending trends and spot where charging or fuel costs are quietly rising."
        case .understandEfficiency:
            return "Compare sessions, mileage, and energy patterns to understand how the vehicle is really performing."
        case .planTrips:
            return "Use planning tools and context screens to make charging stops and route costs easier to reason about."
        }
    }

    private var vehicleActionLine: String {
        if let vehicleName = trimmedVehicleDisplayName {
            return "Start with a setup tuned around \(vehicleName), then expand the garage later if you need to."
        }
        return "Start with your current vehicle, then grow into a multi-vehicle setup later if your garage changes."
    }

    private var finishTitle: String {
        if let firstName = trimmedName {
            return "You’re ready, \(firstName)."
        }
        return "You’re ready."
    }

    private var finishBody: String {
        if let vehicleName = trimmedVehicleDisplayName {
            return "We’ll open the app with \(vehicleName) in mind and keep teaching you as your data grows."
        }
        return "We’ll open the app with your preferences in mind and keep teaching you as your data grows."
    }

    private var trimmedName: String? {
        let value = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var trimmedVehicleDisplayName: String? {
        let value = vehicleDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var vehicleDisplayName: String {
        let nickname = vehicleNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty { return nickname }

        let year = vehicleYear.trimmingCharacters(in: .whitespacesAndNewlines)
        let make = vehicleMake.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = vehicleModel.trimmingCharacters(in: .whitespacesAndNewlines)

        return [year, make, model]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func handlePrimaryAction() {
        if step == .finish {
            completeOnboarding()
            return
        }

        focusedField = nil

        if let next = step.next {
            step = next
        }
    }

    private func completeOnboarding() {
        storedUserName = trimmedName ?? ""
        storedPrimaryGoal = selectedGoal.rawValue
        persistStarterVehicleIfNeeded()
        UserDefaults.standard.set(true, forKey: "onboarding.v2.completed")
        isPresented = false
    }

    private func persistStarterVehicleIfNeeded() {
        let cleanedName = vehicleNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMake = vehicleMake.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedModel = vehicleModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let yearValue = Int(vehicleYear.trimmingCharacters(in: .whitespacesAndNewlines))

        let hasVehicleInfo = !cleanedName.isEmpty || !cleanedMake.isEmpty || !cleanedModel.isEmpty || yearValue != nil
        guard hasVehicleInfo else { return }

        if let existingID = profileStore.selectedVehicleID,
           let existing = profileStore.vehicles.first(where: { $0.id == existingID }),
           shouldUpdateExistingVehicle(existing: existing) {
            var updated = existing
            if !cleanedName.isEmpty { updated.name = cleanedName }
            if !cleanedMake.isEmpty { updated.make = cleanedMake }
            if !cleanedModel.isEmpty { updated.model = cleanedModel }
            if let yearValue { updated.year = yearValue }
            updated.isEV = isEV
            updated.updatedAt = Date()
            profileStore.update(updated)
            profileStore.selectVehicle(id: updated.id)
            return
        }

        let vehicle = VehicleProfile(
            name: cleanedName,
            make: cleanedMake,
            model: cleanedModel,
            year: yearValue,
            isEV: isEV,
            createdAt: Date(),
            updatedAt: Date()
        )
        profileStore.add(vehicle)
        profileStore.selectVehicle(id: vehicle.id)
    }

    private func shouldUpdateExistingVehicle(existing: VehicleProfile) -> Bool {
        let existingHasMeaningfulData =
            !existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !existing.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !existing.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            existing.year != nil

        return !existingHasMeaningfulData || profileStore.vehicles.count == 1
    }

    private func loadExistingValues() {
        draftName = storedUserName
        selectedGoal = OnboardingPrimaryGoal(rawValue: storedPrimaryGoal) ?? .saveMoney

        guard let vehicle = profileStore.selectedVehicle ?? profileStore.vehicles.first else { return }
        vehicleNickname = vehicle.name
        vehicleMake = vehicle.make
        vehicleModel = vehicle.model
        vehicleYear = vehicle.year.map(String.init) ?? ""
        isEV = vehicle.isEV
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(onboardingGlassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(onboardingGlassStroke, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.24 : 0.08), radius: 24, y: 10)
    }
}

private enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case identity
    case whyItMatters
    case vehicle
    case tailoredValue
    case priorities
    case finish

    var index: Int { rawValue }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var badgeTitle: String {
        switch self {
        case .welcome: return "Start"
        case .identity: return "About You"
        case .whyItMatters: return "Why It Works"
        case .vehicle: return "Vehicle"
        case .tailoredValue: return "Your Fit"
        case .priorities: return "Focus"
        case .finish: return "Finish"
        }
    }

    var ctaTitle: String {
        switch self {
        case .identity:
            return "Save My Preferences"
        case .vehicle:
            return "Use This Vehicle"
        case .finish:
            return "Open My Dashboard"
        default:
            return "Continue"
        }
    }
}

private enum OnboardingPrimaryGoal: String, CaseIterable {
    case saveMoney
    case understandEfficiency
    case planTrips

    var title: String {
        switch self {
        case .saveMoney: return "Spend Less"
        case .understandEfficiency: return "Know My Efficiency"
        case .planTrips: return "Plan Better Trips"
        }
    }

    var subtitle: String {
        switch self {
        case .saveMoney: return "Make charging, fuel, and ownership costs easier to compare."
        case .understandEfficiency: return "Understand how sessions and miles translate into vehicle performance."
        case .planTrips: return "Get more confidence around route costs, charging, and readiness."
        }
    }

    var systemImage: String {
        switch self {
        case .saveMoney: return "dollarsign.gauge.chart.lefthalf.righthalf"
        case .understandEfficiency: return "bolt.badge.clock"
        case .planTrips: return "map.fill"
        }
    }

    var accent: Color {
        switch self {
        case .saveMoney: return Color(hex: "#57C785")
        case .understandEfficiency: return Color(hex: "#58A6FF")
        case .planTrips: return Color(hex: "#FF9151")
        }
    }
}
