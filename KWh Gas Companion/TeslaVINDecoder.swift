//
//  TeslaVINDecoder.swift
//  KWh Gas Companion
//
//  Swift 6 • iOS 17+
//
//  Tesla VIN Decoder (Current vehicle + manual entry)
//  - Device-adaptive layout (iPhone/iPad)
//  - Safe VIN normalization + validation
//  - Decode results as readable cards
//  - Quick actions: Paste / Copy / Clear / Decode current vehicle VIN
//
//  ✅ Works with ProfileStore where:
//  - selectedVehicleID is UUID?
//  - vehicles[].id is UUID
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct TeslaVINDecoderView: View {

    @EnvironmentObject private var profileStore: ProfileStore

    // Theme
    @Environment(\.appThemeBox) private var themeBox
    private var T: any AppThemeSpec { themeBox.base }

    @State private var vin: String = ""
    @State private var decoded: [(String, String)] = []
    @State private var showMissingVINAlert = false
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            inputCard.frame(maxWidth: .infinity, alignment: .top)
                            resultsCard.frame(maxWidth: .infinity, alignment: .top)
                        }
                        VStack(spacing: 14) {
                            inputCard
                            resultsCard
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tesla VIN Decoder")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if showCopiedToast {
                    toast("Copied")
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert("Missing or Invalid VIN", isPresented: $showMissingVINAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your current vehicle doesn’t have a valid 17-character VIN.")
            }
            .background(T.screenBackground, ignoresSafeAreaEdges: .all)
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decode a Tesla VIN")
                .font(.title2.weight(.semibold))

            Text("Paste or type your 17-character VIN, or decode your current vehicle’s VIN.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let current = resolvedSelectedVehicle {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill").foregroundStyle(T.accent)
                    Text("Current: \(current.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(maskVIN(current.vin))
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                Text("Tip: select a current vehicle in Garage to use “Decode My Current Vehicle”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .cardStyle(corner: T.corner)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(T.accent)
                Text("Input")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("VIN")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Enter 17-character VIN", text: $vin)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                    .onChange(of: vin) { _, newValue in
                        let cleaned = Self.normalizeVINInput(newValue)
                        if cleaned != newValue { vin = cleaned }
                    }

                HStack {
                    Text(vinStatusLine)
                        .font(.caption)
                        .foregroundStyle(vinIsValid ? Color.secondary : Color.orange)

                    Spacer()

                    if vinIsValid {
                        Label("Valid", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button { decodeTesla() } label: {
                    Label("Decode", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(T.accent)
                .disabled(!vinIsValid)

                Menu {
                    Button {
                        #if canImport(UIKit)
                        if let s = UIPasteboard.general.string {
                            vin = Self.normalizeVINInput(s)
                        }
                        #endif
                    } label: { Label("Paste VIN", systemImage: "doc.on.clipboard") }

                    Button { copyVIN() } label: { Label("Copy VIN", systemImage: "doc.on.doc") }
                        .disabled(vin.isEmpty)

                    Divider()

                    Button(role: .destructive) {
                        vin = ""
                        decoded.removeAll()
                    } label: { Label("Clear", systemImage: "trash") }

                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }

            Button { decodeCurrentVehicleVIN() } label: {
                Label("Decode My Current Vehicle", systemImage: "car.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .cardStyle(corner: T.corner)
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundStyle(T.accent)
                Text("Results")
                    .font(.headline)
                Spacer()

                if !decoded.isEmpty {
                    Button { copyResults() } label: {
                        Label("Copy", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }

            if decoded.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No data yet.")
                        .font(.subheadline.weight(.semibold))
                    Text("Enter a VIN and tap Decode to see details here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(decoded, id: \.0) { name, value in
                        ResultRow(title: name, value: value)
                    }
                }
            }
        }
        .cardStyle(corner: T.corner)
    }

    // MARK: - Status

    private var vinIsValid: Bool { Self.isValidVIN(vin) }

    private var vinStatusLine: String {
        if vin.isEmpty { return "17 characters required." }
        if vin.count < 17 { return "\(vin.count)/17 characters" }
        if vin.count > 17 { return "Too long — 17 characters max." }
        if !Self.isValidVIN(vin) { return "Invalid — VIN cannot contain I, O, or Q." }
        return "Ready to decode."
    }

    // MARK: - ProfileStore bridging (selectedVehicleID: UUID? -> VehicleProfile)

    private var resolvedSelectedVehicle: VehicleProfile? {
        guard let sid = profileStore.selectedVehicleID else { return nil }
        return profileStore.vehicles.first(where: { $0.id == sid })
    }

    private func maskVIN(_ vin: String) -> String {
        let v = Self.normalizeVINInput(vin)
        guard v.count == 17 else { return v }
        return "\(v.prefix(3))••••••••\(v.suffix(3))"
    }

    // MARK: - Actions

    private func decodeCurrentVehicleVIN() {
        guard let current = resolvedSelectedVehicle else {
            showMissingVINAlert = true
            return
        }
        let currentVIN = Self.normalizeVINInput(current.vin)
        guard Self.isValidVIN(currentVIN) else {
            showMissingVINAlert = true
            return
        }
        vin = currentVIN
        decodeTesla()
    }

    private func copyVIN() {
        let v = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = v
        #endif
        showToast()
    }

    private func copyResults() {
        guard !decoded.isEmpty else { return }
        let lines = decoded.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = lines
        #endif
        showToast()
    }

    private func showToast() {
        withAnimation(.snappy) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.snappy) { showCopiedToast = false }
        }
    }

    // MARK: - Decode

    private func decodeTesla() {
        let v = Self.normalizeVINInput(vin)
        vin = v
        decoded.removeAll()

        guard Self.isValidVIN(v) else {
            decoded.append(("Error", "VIN must be exactly 17 characters and must not include I, O, or Q."))
            return
        }

        func ch(_ pos: Int) -> Character { v[v.index(v.startIndex, offsetBy: pos)] }

        let wmi = String(v.prefix(3))
        let wmiMap: [String: String] = [
            "5YJ": "USA (Fremont)",
            "7SA": "USA (Austin / newer programs)",
            "LRW": "China (Shanghai)",
            "XP7": "Germany (Berlin)",
            "SFZ": "UK (Roadster-era code)"
        ]
        decoded.append(("WMI (Country/Plant)", wmiMap[wmi] ?? "Unknown (\(wmi))"))

        let seriesMap: [Character: String] = [
            "S": "Model S", "X": "Model X", "3": "Model 3",
            "Y": "Model Y", "C": "Cybertruck", "R": "Roadster"
        ]
        decoded.append(("Model", seriesMap[ch(3)] ?? "Unknown (\(ch(3)))"))

        let bodyMap: [Character: String] = [
            "A": "5 Door LHD (Model S)",
            "B": "5 Door RHD (Model S)",
            "C": "5 Door LHD Large MPV (Model X)",
            "D": "5 Door RHD Large MPV (Model X)",
            "E": "4 Door LHD Sedan / Roadster / Truck",
            "F": "4 Door RHD Sedan",
            "G": "5 Door LHD Small MPV (Model Y)",
            "H": "5 Door RHD Small MPV (Model Y)"
        ]
        decoded.append(("Body Type", bodyMap[ch(4)] ?? "Unknown (\(ch(4)))"))

        let restraintMap: [Character: String] = [
            "1": "2F/3R belts, airbags, PODS, side/knee",
            "2": "Legacy / early vehicles",
            "3": "2F/2R belts, airbags, side/knee",
            "4": "2F/3R belts, airbags, side/knee",
            "5": "2F/2R belts, airbags, side",
            "6": "2F/3R belts, airbags, side",
            "7": "2F/3R belts, side & active hood",
            "8": "2F/2R belts, side & active hood",
            "A": "7-seat config",
            "B": "6-seat config",
            "C": "5–7 seat (X), 5 seat (Y)",
            "D": "5-seat config"
        ]
        decoded.append(("Restraints/Seating", restraintMap[ch(5)] ?? "Unknown (\(ch(5)))"))

        let batteryChemMap: [Character: String] = [
            "E": "Lithium-Ion (NMC/NCA)",
            "F": "Lithium Iron (LFP)",
            "H": "High capacity Li-Ion",
            "S": "Standard capacity Li-Ion",
            "V": "Very high capacity Li-Ion",
            "D": "Dual motor / program-dependent"
        ]
        decoded.append(("Battery Chemistry/Drive", batteryChemMap[ch(6)] ?? "Unknown (\(ch(6)))"))

        let motorMap: [Character: String] = [
            "1": "Single motor",
            "2": "Twin motors",
            "3": "Single performance motor",
            "4": "Twin performance motor",
            "A": "Single motor – standard",
            "B": "Dual motor – standard",
            "D": "Program-dependent",
            "E": "Program-dependent",
            "T": "Program-dependent"
        ]
        decoded.append(("Motor Configuration", motorMap[ch(7)] ?? "Unknown (\(ch(7)))"))

        let yearMap: [Character: Int] = [
            "C": 2012, "D": 2013, "E": 2014, "F": 2015,
            "G": 2016, "H": 2017, "J": 2018, "K": 2019,
            "L": 2020, "M": 2021, "N": 2022, "P": 2023,
            "R": 2024, "S": 2025, "T": 2026, "V": 2027,
            "W": 2028, "X": 2029, "Y": 2030
        ]
        decoded.append(("Model Year", yearMap[ch(9)].map(String.init) ?? "Unknown (\(ch(9)))"))

        let plantMap: [Character: String] = [
            "A": "Austin, TX",
            "B": "Berlin, Germany",
            "C": "Shanghai, China",
            "F": "Fremont, CA",
            "N": "Reno, NV"
        ]
        decoded.append(("Assembly Plant", plantMap[ch(10)] ?? "Unknown (\(ch(10)))"))

        decoded.append(("Production Sequence", String(v.suffix(6))))
    }

    // MARK: - Validation / Normalization

    private static func normalizeVINInput(_ input: String) -> String {
        let upper = input.uppercased()
        let filtered = upper.filter { $0.isASCII && ($0.isNumber || $0.isLetter) }
        return String(filtered.prefix(17))
    }

    private static func isValidVIN(_ v: String) -> Bool {
        guard v.count == 17 else { return false }
        let upper = v.uppercased()
        if upper.contains("I") || upper.contains("O") || upper.contains("Q") { return false }
        return upper.allSatisfy { $0.isNumber || $0.isLetter }
    }

    // MARK: - Toast

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.quaternary) }
    }
}

// MARK: - Result Row

private struct ResultRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary) }
    }
}

// MARK: - Card Style

private extension View {
    func cardStyle(corner: CGFloat) -> some View {
        self
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(.quaternary) }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TeslaVINDecoderView()
            .environmentObject(ProfileStore())
    }
}
#endif
