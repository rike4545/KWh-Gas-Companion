//
//  RouteProbe 2.swift
//  KWh Gas Companion
//
//  Created by Bryan on 8/31/25.
//


import SwiftUI

/// A defensive shell for navigation destinations:
/// - Shows content immediately if it paints its body
/// - Otherwise shows a small "Preparing…" overlay after `graceDelay`
/// - If still not painted after `timeout`, shows an error + Retry
///
/// Usage:
///     withNavBar(
///       RouteProbe(title: "Forecast") {
///         ForecastChartView()
///           .environmentObject(entriesStore)
///       }
///     )
@MainActor
public struct RouteProbe<Content: View>: View {
    // MARK: Config
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let graceDelay: TimeInterval
    private let timeout: TimeInterval
    private let onTimeout: (() -> Void)?
    @ViewBuilder private var content: Content

    // MARK: State
    @State private var painted = false
    @State private var showOverlay = false
    @State private var didTimeout = false
    @State private var refreshID = UUID()     // forces content re-init on Retry

    // MARK: Init
    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        graceDelay: TimeInterval = 0.30,
        timeout: TimeInterval = 6.0,
        onTimeout: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.graceDelay = graceDelay
        self.timeout = timeout
        self.onTimeout = onTimeout
        self.content = content()
    }

    // MARK: Body
    public var body: some View {
        ZStack {
            // Real destination view
            content
                .id(refreshID)
                .onAppear { painted = true }

            // Overlay states
            if !painted && !didTimeout {
                if showOverlay {
                    preparingOverlay
                        .transition(.opacity)
                }
            }

            if didTimeout && !painted {
                timeoutOverlay
                    .transition(.opacity)
            }
        }
        .task {
            // Grace delay before we show the spinner, prevents flicker on fast loads
            try? await Task.sleep(nanoseconds: UInt64(graceDelay * 1_000_000_000))
            if !painted { withAnimation(.easeInOut(duration: 0.2)) { showOverlay = true } }

            // Hard timeout
            let remaining = max(timeout - graceDelay, 0.0)
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            if !painted {
                didTimeout = true
                onTimeout?()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }

    // MARK: Overlays
    @ViewBuilder
    private var preparingOverlay: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.large)
                    .font(.system(size: 22, weight: .semibold))
            }
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView().padding(.top, 4)
            Text("Preparing view…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
        .padding()
        .accessibilityLabel("\(title). Preparing view.")
    }

    @ViewBuilder
    private var timeoutOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .yellow.opacity(0.25))
                .imageScale(.large)
                .font(.system(size: 24, weight: .bold))
            Text(title)
                .font(.headline)
            Text("This screen didn’t finish loading.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
            HStack(spacing: 12) {
                Button(role: .cancel) {
                    // Let the user back out cleanly
                    // No-op here; back button will do the job.
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                Button {
                    // Retry by forcing a fresh init of the content
                    painted = false
                    didTimeout = false
                    showOverlay = false
                    refreshID = UUID()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
        .padding()
        .accessibilityLabel("\(title). Screen did not finish loading. Retry or go back.")
    }
}
