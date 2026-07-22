//
//  TeslaAuthManager.swift
//  KWh Gas Companion
//
//

import AuthenticationServices
import CryptoKit
import Foundation

@MainActor
final class TeslaAuthManager: NSObject, ObservableObject {
    // Configure these:
    var clientID = "<YOUR_TESLA_DEV_APP_CLIENT_ID>"
    var redirectURI = "mykwh://oauth" // Add as URL Type in Info.plist
    var regionAPIBase = URL(string: "https://fleet-api.prd.na.vn.cloud.tesla.com")! // NA default
    // Discovery (per Tesla docs, use fleet-auth host for metadata)
    private let discoveryURL = URL(string: "https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3/thirdparty/.well-known/openid-configuration")!

    @Published private(set) var isLinked = false

    private var authEndpoint: URL?
    private var tokenEndpoint: URL?
    private var currentSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""

    func loadDiscovery() async throws {
        struct Meta: Decodable { let authorization_endpoint: String; let token_endpoint: String }
        let (data, _) = try await URLSession.shared.data(from: discoveryURL)
        let meta = try JSONDecoder().decode(Meta.self, from: data)
        self.authEndpoint  = URL(string: meta.authorization_endpoint)
        self.tokenEndpoint = URL(string: meta.token_endpoint)
    }

    func startOAuth() async throws {
        if authEndpoint == nil || tokenEndpoint == nil { try await loadDiscovery() }
        guard let authEndpoint else { return }
        guard let callbackScheme = URL(string: redirectURI)?.scheme else { return }

        codeVerifier = Self.randomURLSafeString(64)
        let challenge = Self.codeChallengeS256(codeVerifier)

        guard var comps = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false) else { return }
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: "openid offline_access vehicle_device_data vehicle_location"),
            .init(name: "audience", value: regionAPIBase.absoluteString),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = comps.url else { return }

        currentSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self, let url = callbackURL, error == nil else { return }
            Task { try? await self.exchangeCode(url: url) }
        }
        currentSession?.prefersEphemeralWebBrowserSession = true
        currentSession?.start()
    }

    private func exchangeCode(url: URL) async throws {
        guard let tokenEndpoint else { return }
        let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value ?? ""

        var req = URLRequest(url: tokenEndpoint)
        req.httpMethod = "POST"
        let body = [
            "grant_type=authorization_code",
            "client_id=\(clientID)",
            "code=\(code)",
            "code_verifier=\(codeVerifier)",
            "redirect_uri=\(redirectURI)",
            "audience=\(regionAPIBase.absoluteString)"
        ].joined(separator: "&").data(using: .utf8)!

        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: req)
        struct Token: Decodable { let access_token: String; let refresh_token: String?; let expires_in: Int }
        let tok = try JSONDecoder().decode(Token.self, from: data)

        try KeychainStore.save(token: tok.access_token, refresh: tok.refresh_token, expiry: tok.expires_in)
        isLinked = true
    }

    func refreshIfNeeded() async {
        // Implement refresh using the token_endpoint and grant_type=refresh_token
    }

    // MARK: - Helpers
    private static func randomURLSafeString(_ len: Int) -> String {
        let bytes = (0..<len).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    private static func codeChallengeS256(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum KeychainStore {
    static func save(token: String, refresh: String?, expiry: Int) throws {
        // store securely; keep minimal for brevity
        UserDefaults.standard.set(token, forKey: "tesla_access")
        if let refresh { UserDefaults.standard.set(refresh, forKey: "tesla_refresh") }
        UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(expiry)), forKey: "tesla_exp")
    }
    static var accessToken: String? { UserDefaults.standard.string(forKey: "tesla_access") }
}
