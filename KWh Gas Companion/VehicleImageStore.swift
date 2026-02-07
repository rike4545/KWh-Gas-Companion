//
//  VehicleImageStore.swift
//  KWh Gas Companion
//
//  Custom per-vehicle photos (stored on-device) + automatic Tesla/Rivian fallbacks (bundled assets).
//
//  Rules:
//  - If a custom photo exists for a vehicle, it ALWAYS wins.
//  - If no custom photo exists, Tesla/Rivian vehicles show an automatic photo based on model.
//  - Automatic photos use your existing asset names:
//      Tesla: roadster, model 3, model y, model x, model s
//      Rivian: RivianR1S, RivianR1T, RivianR2, RivianR3
//
//  Swift 6 • iOS 17+
//

import Foundation
import UIKit

enum VehicleImageStore {

    enum StoreError: Error {
        case encodingFailed
    }

    private static let folder = "VehiclePhotos"

    private static func folderURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent(folder, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func vehicleFolderURL(_ vehicleId: UUID) -> URL {
        let dir = folderURL().appendingPathComponent(vehicleId.uuidString, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for id: UUID) -> URL {
        folderURL().appendingPathComponent(id.uuidString + ".jpg")
    }

    static func url(for vehicleId: UUID, photoId: UUID) -> URL {
        vehicleFolderURL(vehicleId).appendingPathComponent(photoId.uuidString + ".jpg")
    }

    static func exists(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    // MARK: - Custom image (sync)

    static func load(id: UUID) -> UIImage? {
        let u = url(for: id)
        guard FileManager.default.fileExists(atPath: u.path) else { return nil }
        return UIImage(contentsOfFile: u.path)
    }

    static func save(_ image: UIImage, id: UUID, quality: CGFloat = 0.88) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StoreError.encodingFailed
        }
        try data.write(to: url(for: id), options: .atomic)
    }

    static func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    // MARK: - Gallery images (per vehicle)

    static func load(vehicleId: UUID, photoId: UUID) -> UIImage? {
        let u = url(for: vehicleId, photoId: photoId)
        guard FileManager.default.fileExists(atPath: u.path) else { return nil }
        return UIImage(contentsOfFile: u.path)
    }

    static func save(_ image: UIImage, vehicleId: UUID, photoId: UUID, quality: CGFloat = 0.88) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StoreError.encodingFailed
        }
        try data.write(to: url(for: vehicleId, photoId: photoId), options: .atomic)
    }

    static func delete(vehicleId: UUID, photoId: UUID) {
        try? FileManager.default.removeItem(at: url(for: vehicleId, photoId: photoId))
    }

    // MARK: - Custom image (async overloads)

    static func load(id: UUID) async -> UIImage? {
        await Task.detached(priority: .utility) { load(id: id) }.value
    }

    static func save(_ image: UIImage, id: UUID, quality: CGFloat = 0.88) async throws {
        try await Task.detached(priority: .utility) { try save(image, id: id, quality: quality) }.value
    }

    static func delete(id: UUID) async {
        await Task.detached(priority: .utility) { delete(id: id) }.value
    }

    static func load(vehicleId: UUID, photoId: UUID) async -> UIImage? {
        await Task.detached(priority: .utility) { load(vehicleId: vehicleId, photoId: photoId) }.value
    }

    static func save(_ image: UIImage, vehicleId: UUID, photoId: UUID, quality: CGFloat = 0.88) async throws {
        try await Task.detached(priority: .utility) { try save(image, vehicleId: vehicleId, photoId: photoId, quality: quality) }.value
    }

    static func delete(vehicleId: UUID, photoId: UUID) async {
        await Task.detached(priority: .utility) { delete(vehicleId: vehicleId, photoId: photoId) }.value
    }

    // MARK: - Automatic fallback (Tesla / Rivian)

    /// Automatic bundled image (Tesla/Rivian only). Returns nil for other makes.
    static func automaticImage(for vehicle: VehicleProfile) -> UIImage? {
        let make = vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modelText = [vehicle.model, vehicle.name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
        let vin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if isTesla(make: make, vin: vin) {
            return UIImage(named: teslaAssetName(for: modelText))
        }

        if isRivian(make: make, vin: vin) {
            return UIImage(named: rivianAssetName(for: modelText))
        }

        return nil
    }

    /// UI convenience: custom wins; otherwise automatic (Tesla/Rivian); otherwise nil.
    static func preferredImage(for vehicle: VehicleProfile) -> UIImage? {
        if let cover = coverImage(for: vehicle) { return cover }
        return automaticImage(for: vehicle)
    }

    static func hasCustomPhoto(for vehicle: VehicleProfile) -> Bool {
        if let coverId = vehicle.coverPhotoId, load(vehicleId: vehicle.id, photoId: coverId) != nil { return true }
        if let first = vehicle.galleryPhotoIds.first, load(vehicleId: vehicle.id, photoId: first) != nil { return true }
        return exists(id: vehicle.id)
    }

    static func coverImage(for vehicle: VehicleProfile) -> UIImage? {
        if let coverId = vehicle.coverPhotoId,
           let img = load(vehicleId: vehicle.id, photoId: coverId) {
            return img
        }
        if let first = vehicle.galleryPhotoIds.first,
           let img = load(vehicleId: vehicle.id, photoId: first) {
            return img
        }
        if let legacy = load(id: vehicle.id) { return legacy }
        return nil
    }

    // MARK: - Helpers

    private static func isTesla(make: String, vin: String) -> Bool {
        if make.contains("tesla") { return true }
        // Conservative WMI hints (helps when make is blank)
        return vin.hasPrefix("5YJ") || vin.hasPrefix("7SA") || vin.hasPrefix("LRW")
    }

    private static func isRivian(make: String, vin: String) -> Bool {
        if make.contains("rivian") { return true }
        // Conservative WMI hint
        return vin.hasPrefix("7FC")
    }

    private static func normalizeModelKey(_ model: String) -> String {
        model
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
    }

    private static func teslaAssetName(for modelRaw: String) -> String {
        // Asset names you provided (exact):
        // roadster, model 3, model y, model x, model s
        let k = normalizeModelKey(modelRaw)

        if k.contains("roadster") { return "roadster" }

        // Try explicit "model3" / "model 3" patterns first.
        if k.contains("model3") || k == "3" || k == "m3" { return "model 3" }
        if k.contains("modely") || k == "y" || k == "my" { return "model y" }
        if k.contains("modelx") || k == "x" || k == "mx" { return "model x" }
        if k.contains("models") || k == "s" || k == "ms" { return "model s" }

        // Fallback: prefer Model Y if user typed "y", otherwise Model 3 as a safe default.
        return "model 3"
    }

    private static func rivianAssetName(for modelRaw: String) -> String {
        // Asset names you provided (exact):
        // RivianR1S, RivianR1T, RivianR2, RivianR3
        let k = normalizeModelKey(modelRaw)

        if k.contains("r1s") { return "RivianR1S" }
        if k.contains("r1t") { return "RivianR1T" }
        if k.contains("r2") { return "RivianR2" }
        if k.contains("r3") { return "RivianR3" }

        // Fallback: pick the more common SUV silhouette.
        return "RivianR1S"
    }
}
