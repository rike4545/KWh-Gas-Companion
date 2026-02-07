// TeslaFindUsResponse.swift
import Foundation
import CoreLocation

// MARK: - Decodable Models

struct TeslaFindUsResponse: Decodable {
    let locations: [FindUsLocation]
}

struct FindUsLocation: Decodable, Identifiable {
    let id: String
    let name: String
    let address: String
    let coordinate: Coordinate
    let stallCount: Int?
    let amenities: [String]?

    struct Coordinate: Decodable {
        let latitude: Double
        let longitude: Double
    }

    var coordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: coordinate.latitude,
                   longitude: coordinate.longitude).distance(from: location)
    }
}

// MARK: - API Client

actor SuperchargerAPI {
    private let baseURL = URL(string: "https://www.tesla.com/findus")!

    enum FetchError: LocalizedError {
        case http(status: Int)
        case decodingFailed(json: String, underlying: Error)
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .http(let status):
                return "HTTP error: status code \(status)"
            case .decodingFailed(let json, let err):
                return "Decoding failed: \(err.localizedDescription)\nResponse JSON: \(json)"
            case .unknown(let err):
                return err.localizedDescription
            }
        }
    }

    /// Fetch charger locations within the given bounds.
    func fetch(bounds: [Double],
               location: String = "",
               functionType: String = "supercharger",
               userLocation: CLLocation? = nil,
               limit: Int? = nil) async throws -> [FindUsLocation] {

        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let boundsString = bounds.map { String($0) }.joined(separator: ",")
        comps.queryItems = [
            .init(name: "bounds", value: boundsString),
            .init(name: "location", value: location),
            .init(name: "functionType", value: functionType)
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.unknown(URLError(.badServerResponse)) }
        guard 200..<300 ~= http.statusCode else { throw FetchError.http(status: http.statusCode) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        var locations: [FindUsLocation]

        do {
            let wrapper = try decoder.decode(TeslaFindUsResponse.self, from: data)
            locations = wrapper.locations
        } catch {
            if let arr = try? decoder.decode([FindUsLocation].self, from: data) {
                locations = arr
            } else if let html = String(data: data, encoding: .utf8),
                      let locKeyRange = html.range(of: "\"locations\":"),
                      let arrayStart = html[locKeyRange.upperBound...].firstIndex(of: "[") {

                var depth = 0
                var endIndex = arrayStart
                for idx in html[arrayStart...].indices {
                    let ch = html[idx]
                    if ch == "[" { depth += 1 }
                    if ch == "]" { depth -= 1 }
                    if depth == 0 { endIndex = idx; break }
                }

                let arrayStr = String(html[arrayStart...endIndex])
                if let arrayData = arrayStr.data(using: .utf8),
                   let parsed = try? decoder.decode([FindUsLocation].self, from: arrayData) {
                    locations = parsed
                } else {
                    throw FetchError.decodingFailed(json: html, underlying: error)
                }
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "<invalid JSON>"
                throw FetchError.decodingFailed(json: raw, underlying: error)
            }
        }

        if let userLoc = userLocation {
            locations.sort { $0.distance(from: userLoc) < $1.distance(from: userLoc) }
        }
        if let limit = limit, locations.count > limit {
            locations = Array(locations.prefix(limit))
        }
        return locations
    }
}
