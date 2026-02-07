//
//  TeslaEPCPartsSearchView.swift
//  KWh Gas Companion
//
//  Tesla EPC helper: embedded browser + VIN autofill + in-page find + saved terms.
//  Swift 6 • iOS 17+
//
//  Notes:
//  - This does NOT scrape Tesla EPC data.
//  - “Smart Search” is best-effort DOM automation and may break if Tesla updates EPC.
//

import SwiftUI
import WebKit
import UIKit

// MARK: - Public View

@MainActor
public struct TeslaEPCPartsSearchView: View {

    private let homeURL = URL(string: "https://epc.tesla.com/en-US/catalogs")!

    @StateObject private var web = EPCWebController()

    @State private var query: String = ""
    @State private var statusText: String = "Ready"
    @State private var showSaved: Bool = false

    /// If we need to open EPC first, queue a smart fill to run after load.
    @State private var pendingSmartFill: String? = nil

    @Environment(\.openURL) private var openURL

    // Saved terms persistence
    @AppStorage("tesla_epc_saved_parts_json")
    private var savedJSON: String = "[]"

    @State private var savedCache: [EPCSavedItem] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                if showSaved {
                    savedList
                } else {
                    EPCWebView(
                        web: web,
                        statusText: $statusText,
                        pendingSmartFill: $pendingSmartFill
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Tesla EPC Parts Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadSavedCache()
            if web.currentURL == nil {
                web.load(homeURL)
                statusText = "Opening EPC catalogs…"
            }
        }
        .onChange(of: savedJSON) { _, _ in
            reloadSavedCache()
        }
    }

    // MARK: - Header UI

    private var header: some View {
        VStack(spacing: 10) {

            // Row 1: search + saved toggle
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("VIN, part #, or term (e.g. 1234567-00-A)", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { smartSearch() }

                    if !query.trimmed.isEmpty {
                        Button {
                            query = ""
                            statusText = "Cleared"
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                )

                Button {
                    showSaved.toggle()
                } label: {
                    Image(systemName: showSaved ? "globe" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(EPCPillButtonStyle(prominent: false, circular: true))
                .accessibilityLabel(showSaved ? "Show web" : "Show saved")
            }

            // Row 2: action bar (horizontal scroll, no wrap)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {

                    EPCActionPill(title: "Catalogs", systemImage: "car", prominent: false) {
                        showSaved = false
                        web.load(homeURL)
                        statusText = "Opening EPC catalogs…"
                    }

                    EPCActionPill(title: "Smart Search", systemImage: "sparkle.magnifyingglass", prominent: true) {
                        showSaved = false
                        smartSearch()
                    }
                    .disabled(query.trimmed.isEmpty)

                    Menu {
                        Button {
                            addSaved()
                        } label: {
                            SwiftUI.Label("Save Term", systemImage: "plus")
                        }
                        .disabled(query.trimmed.isEmpty)

                        Divider()

                        Button {
                            web.find(query, direction: .next)
                            statusText = "Finding next…"
                        } label: {
                            SwiftUI.Label("Find Next in Page", systemImage: "chevron.down")
                        }
                        .disabled(query.trimmed.isEmpty)

                        Button {
                            web.find(query, direction: .previous)
                            statusText = "Finding previous…"
                        } label: {
                            SwiftUI.Label("Find Previous in Page", systemImage: "chevron.up")
                        }
                        .disabled(query.trimmed.isEmpty)

                        if let url = web.currentURL {
                            Divider()

                            Button {
                                UIPasteboard.general.string = url.absoluteString
                                statusText = "Copied URL"
                            } label: {
                                SwiftUI.Label("Copy Current URL", systemImage: "doc.on.doc")
                            }

                            Button {
                                openURL(url)
                            } label: {
                                SwiftUI.Label("Open in Safari", systemImage: "safari")
                            }
                        }
                    } label: {
                        EPCIconPillLabel(systemImage: "ellipsis.circle")
                    }

                    EPCDivider()

                    EPCIconPillButton(systemImage: "chevron.left") { web.goBack() }
                        .disabled(!web.canGoBack)

                    EPCIconPillButton(systemImage: "chevron.right") { web.goForward() }
                        .disabled(!web.canGoForward)

                    EPCIconPillButton(systemImage: "arrow.clockwise") { web.reload() }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()

            // Row 3: status + host
            HStack {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let url = web.currentURL {
                    Text(url.host ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Saved List

    private var savedList: some View {
        List {
            if savedCache.isEmpty {
                ContentUnavailableView(
                    "No saved items yet",
                    systemImage: "bookmark.slash",
                    description: Text("Enter a VIN, part number, or term — then tap the menu (…) and choose Save Term.")
                )
            } else {
                Section("Saved") {
                    ForEach(savedCache.sorted(by: { $0.createdAt > $1.createdAt })) { item in
                        Button {
                            query = item.term
                            showSaved = false
                            smartSearch()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.term)
                                    .font(.headline)

                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteSaved(item) } label: {
                                SwiftUI.Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func reloadSavedCache() {
        savedCache = decodeSaved(from: savedJSON)
    }

    private func persistSavedCache(_ list: [EPCSavedItem]) {
        savedCache = list
        savedJSON = encodeSaved(list)
    }

    private func decodeSaved(from json: String) -> [EPCSavedItem] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([EPCSavedItem].self, from: data)) ?? []
    }

    private func encodeSaved(_ list: [EPCSavedItem]) -> String {
        guard let data = try? JSONEncoder().encode(list) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func addSaved() {
        let t = query.trimmed
        guard !t.isEmpty else { return }

        var list = savedCache
        list.removeAll { $0.term.caseInsensitiveCompare(t) == .orderedSame }
        list.insert(EPCSavedItem(term: t, createdAt: Date()), at: 0)

        persistSavedCache(list)
        statusText = "Saved: \(t)"
    }

    private func deleteSaved(_ item: EPCSavedItem) {
        var list = savedCache
        list.removeAll { $0.id == item.id }
        persistSavedCache(list)
        statusText = "Deleted"
    }

    // MARK: - Smart Search

    private func smartSearch() {
        let t = query.trimmed
        guard !t.isEmpty else { return }

        // URL paste -> open directly
        if let url = URL(string: t), url.scheme?.hasPrefix("http") == true {
            web.load(url)
            statusText = "Opening link…"
            return
        }

        // Ensure we're on EPC first
        let host = web.currentURL?.host?.lowercased() ?? ""
        if !host.contains("epc.tesla.com") {
            pendingSmartFill = t
            web.load(homeURL)
            statusText = "Opening EPC…"
            return
        }

        statusText = "Sending…"
        web.attemptSmartFill(term: t) { ok, message in
            self.statusText = ok ? message : "Couldn’t auto-fill here — use EPC’s search field (or open in Safari)."
        }
    }
}

// MARK: - File-private Types (avoid collisions across your project)

fileprivate struct EPCSavedItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var term: String
    var createdAt: Date
}

@MainActor
fileprivate final class EPCWebController: ObservableObject {

    enum FindDirection { case next, previous }

    let webView: WKWebView

    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var currentURL: URL? = nil

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true

        // Helps Tesla sites render more consistently in WKWebView
        wv.customUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        self.webView = wv
    }

    func load(_ url: URL) {
        currentURL = url
        webView.load(URLRequest(url: url))
        refreshNavState()
    }

    func reload() {
        webView.reload()
        refreshNavState()
    }

    func goBack() {
        webView.goBack()
        refreshNavState()
    }

    func goForward() {
        webView.goForward()
        refreshNavState()
    }

    func refreshNavState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url ?? currentURL
    }

    func find(_ term: String, direction: FindDirection) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let config = WKFindConfiguration()
        config.backwards = (direction == .previous)
        config.caseSensitive = false
        config.wraps = true

        webView.find(t, configuration: config) { _ in }
    }

    func attemptSmartFill(term: String, completion: @escaping (Bool, String) -> Void) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { completion(false, ""); return }

        let host = webView.url?.host?.lowercased() ?? ""
        guard host.contains("epc.tesla.com") else {
            completion(false, "Not on EPC")
            return
        }

        let preferVIN = Self.isLikelyVIN(t)
        let js = Self.buildSmartFillJS(term: t, preferVIN: preferVIN)

        webView.evaluateJavaScript(js) { result, _ in
            let s = (result as? String) ?? ""
            switch s {
            case "vin-ok": completion(true, "VIN entered — selecting catalog…")
            case "search-ok": completion(true, "Search submitted…")
            case "filled-ok": completion(true, "Filled field…")
            case "no-input": completion(false, "No matching field found")
            default: completion(false, "Automation failed")
            }
        }
    }

    private static func isLikelyVIN(_ s: String) -> Bool {
        let t = s.uppercased()
        guard t.count == 17 else { return false }
        for ch in t {
            guard ch.isLetter || ch.isNumber else { return false }
            if ch == "I" || ch == "O" || ch == "Q" { return false }
        }
        return true
    }

    private static func buildSmartFillJS(term: String, preferVIN: Bool) -> String {
        let q = term.jsEscaped
        let prefer = preferVIN ? "true" : "false"

        return """
        (function() {
          try {
            const q = "\(q)";
            const preferVIN = \(prefer);

            function uniq(arr) {
              const set = new Set();
              const out = [];
              for (const x of arr) { if (!set.has(x)) { set.add(x); out.push(x); } }
              return out;
            }

            function collectInputs(root, depth) {
              if (!root || depth > 6) return [];
              let inputs = [];
              try { inputs = inputs.concat(Array.from(root.querySelectorAll('input'))); } catch (e) {}
              let all = [];
              try { all = Array.from(root.querySelectorAll('*')); } catch (e) {}
              for (const el of all) {
                try { if (el.shadowRoot) inputs = inputs.concat(collectInputs(el.shadowRoot, depth + 1)); } catch (e) {}
              }
              return inputs;
            }

            const inputs = uniq(collectInputs(document, 0));

            function scoreForVIN(i) {
              const id = (i.id || '').toLowerCase();
              const name = (i.name || '').toLowerCase();
              const ph = (i.getAttribute('placeholder') || '').toLowerCase();
              const al = (i.getAttribute('aria-label') || '').toLowerCase();
              let score = 0;
              if (id.includes('vin') || name.includes('vin')) score += 7;
              if (ph.includes('vin') || al.includes('vin')) score += 7;
              if (ph.includes('serial') || al.includes('serial') || id.includes('serial') || name.includes('serial')) score += 3;
              return score;
            }

            function scoreForSearch(i) {
              const type = (i.type || '').toLowerCase();
              const id = (i.id || '').toLowerCase();
              const name = (i.name || '').toLowerCase();
              const ph = (i.getAttribute('placeholder') || '').toLowerCase();
              const al = (i.getAttribute('aria-label') || '').toLowerCase();
              let score = 0;
              if (type === 'search') score += 6;
              if (ph.includes('search') || al.includes('search')) score += 5;
              if (ph.includes('part') || al.includes('part')) score += 4;
              if (id.includes('search') || name.includes('search')) score += 3;
              return score;
            }

            function pickBest(scoringFn) {
              let best = null;
              let bestScore = 0;
              for (const i of inputs) {
                const s = scoringFn(i);
                if (s > bestScore) { bestScore = s; best = i; }
              }
              return bestScore > 0 ? best : null;
            }

            function fillAndSubmit(input) {
              try {
                input.focus();
                input.value = q;
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', which: 13, keyCode: 13, bubbles: true }));
                input.dispatchEvent(new KeyboardEvent('keyup',   { key: 'Enter', code: 'Enter', which: 13, keyCode: 13, bubbles: true }));
                const form = input.closest('form');
                if (form) { try { form.submit(); } catch(e) {} }
                return true;
              } catch (e) { return false; }
            }

            if (preferVIN) {
              const vinInput = pickBest(scoreForVIN);
              if (vinInput && fillAndSubmit(vinInput)) return "vin-ok";
            }

            const searchInput = pickBest(scoreForSearch);
            if (searchInput && fillAndSubmit(searchInput)) return "search-ok";

            const vinFallback = pickBest(scoreForVIN);
            if (vinFallback && fillAndSubmit(vinFallback)) return "filled-ok";

            return "no-input";
          } catch (e) {
            return "error";
          }
        })();
        """
    }
}

fileprivate struct EPCWebView: UIViewRepresentable {

    @ObservedObject var web: EPCWebController
    @Binding var statusText: String
    @Binding var pendingSmartFill: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(web: web, statusText: $statusText, pendingSmartFill: $pendingSmartFill)
    }

    func makeUIView(context: Context) -> WKWebView {
        web.webView.navigationDelegate = context.coordinator
        web.webView.uiDelegate = context.coordinator
        return web.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let web: EPCWebController
        private var statusText: Binding<String>
        private var pendingSmartFill: Binding<String?>

        init(web: EPCWebController, statusText: Binding<String>, pendingSmartFill: Binding<String?>) {
            self.web = web
            self.statusText = statusText
            self.pendingSmartFill = pendingSmartFill
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            statusText.wrappedValue = "Loading…"
            web.refreshNavState()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            web.refreshNavState()

            let title = (webView.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { statusText.wrappedValue = title }
            else if let url = webView.url { statusText.wrappedValue = url.host ?? "Loaded" }
            else { statusText.wrappedValue = "Loaded" }

            if let pending = pendingSmartFill.wrappedValue {
                pendingSmartFill.wrappedValue = nil
                web.attemptSmartFill(term: pending) { [weak self] ok, msg in
                    guard let self else { return }
                    self.statusText.wrappedValue = ok ? msg : "Couldn’t auto-fill here — try EPC’s field or Safari."
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            web.refreshNavState()
            statusText.wrappedValue = "Load failed: \(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            web.refreshNavState()
            statusText.wrappedValue = "Load failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Buttons (no opaque returns, no Group-as-ShapeStyle)

fileprivate struct EPCPillButtonStyle: ButtonStyle {
    let prominent: Bool
    let circular: Bool

    init(prominent: Bool, circular: Bool = false) {
        self.prominent = prominent
        self.circular = circular
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .padding(.horizontal, circular ? 0 : 12)
            .padding(.vertical, circular ? 0 : 8)
            .frame(minWidth: circular ? 44 : nil, minHeight: circular ? 44 : nil)
            .background(
                Group {
                    if circular {
                        if prominent {
                            Circle().fill(Color.accentColor.opacity(pressed ? 0.78 : 0.92))
                        } else {
                            Circle().fill(.thinMaterial)
                        }
                    } else {
                        if prominent {
                            Capsule(style: .continuous).fill(Color.accentColor.opacity(pressed ? 0.78 : 0.92))
                        } else {
                            Capsule(style: .continuous).fill(.thinMaterial)
                        }
                    }
                }
            )
            .overlay(
                Group {
                    if prominent {
                        EmptyView()
                    } else {
                        if circular {
                            Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        } else {
                            Capsule(style: .continuous).stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        }
                    }
                }
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .opacity(pressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.15), value: pressed)
    }
}

fileprivate struct EPCActionPill: View {
    let title: String
    let systemImage: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SwiftUI.Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(prominent ? Color.white : Color.primary)
        }
        .buttonStyle(EPCPillButtonStyle(prominent: prominent))
    }
}

fileprivate struct EPCIconPillLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 40, height: 30)
            .padding(.horizontal, 2)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
    }
}

fileprivate struct EPCIconPillButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 40, height: 30)
        }
        .buttonStyle(EPCPillButtonStyle(prominent: false))
    }
}

fileprivate struct EPCDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }
}

// MARK: - String helpers

fileprivate extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var jsEscaped: String {
        var s = self
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "'", with: "\\'")
        s = s.replacingOccurrences(of: "\n", with: "\\n")
        s = s.replacingOccurrences(of: "\r", with: "\\r")
        s = s.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        s = s.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return s
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TeslaEPCPartsSearchView()
            .tint(.red)
    }
}
#endif
