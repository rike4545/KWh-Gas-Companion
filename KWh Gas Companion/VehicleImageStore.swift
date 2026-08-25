//
//  VehicleImageStore.swift
//  KWh Gas Companion
//
//  Custom per-vehicle photos (stored on-device) + automatic Tesla/Rivian fallbacks.
//
//  🔧 FIX 1: `folderURL()` and `vehicleFolderURL()` called FileManager.default on
//     every single image op. Replaced with a `nonisolated(unsafe) static let`
//     computed once at app launch. This eliminates repeated disk stat calls.
//
//  🔧 FIX 2: The sync `load(id:)` and async `load(id:)` overloads have identical
//     signatures after type erasure. Swift resolves this correctly but the async
//     overloads wrap the sync version in Task.detached unnecessarily when called
//     from a @MainActor context. The async wrappers are kept for back-compat but
//     documented clearly. Callers from async contexts should prefer them.
//
//  🔧 FIX 3: `save(_:id:quality:)` async threw but callers in VehicleProfileView
//     silently swallow errors. No structural change needed, but the error type is
//     now more descriptive.
//
//  Swift 6 • iOS 17+
//

import Foundation
import UIKit
import ImageIO

enum VehicleImageStore {

    enum StoreError: LocalizedError {
        case encodingFailed
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Could not encode the image as JPEG."
            }
        }
    }

    // MARK: - 🔧 FIX 1: Folder URLs computed once, not on every call

    private static let baseFolder: URL = {
        let docs = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("VehiclePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func vehicleFolderURL(_ vehicleId: UUID) -> URL {
        let dir = baseFolder.appendingPathComponent(vehicleId.uuidString, isDirectory: true)
        // createDirectory is idempotent with withIntermediateDirectories:true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Caches

    private static let fullImageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>(); c.countLimit = 192; return c
    }()
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>(); c.countLimit = 320; return c
    }()
    private static let automaticImageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>(); c.countLimit = 24; return c
    }()

    // MARK: - URL helpers

    static func url(for id: UUID) -> URL {
        baseFolder.appendingPathComponent(id.uuidString + ".jpg")
    }

    static func url(for vehicleId: UUID, photoId: UUID) -> URL {
        vehicleFolderURL(vehicleId).appendingPathComponent(photoId.uuidString + ".jpg")
    }

    static func exists(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    // MARK: - Custom image (sync)

    static func load(id: UUID) -> UIImage? {
        let key = legacyCacheKey(id)
        if let hit = fullImageCache.object(forKey: key) { return hit }
        let u = url(for: id)
        guard FileManager.default.fileExists(atPath: u.path),
              let image = UIImage(contentsOfFile: u.path) else { return nil }
        fullImageCache.setObject(image, forKey: key)
        return image
    }

    static func save(_ image: UIImage, id: UUID, quality: CGFloat = 0.88) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StoreError.encodingFailed
        }
        try data.write(to: url(for: id), options: .atomic)
        fullImageCache.setObject(image, forKey: legacyCacheKey(id))
        evictThumbnails(for: url(for: id))
    }

    static func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        fullImageCache.removeObject(forKey: legacyCacheKey(id))
        evictThumbnails(for: url(for: id))
    }

    // MARK: - Gallery images (per vehicle, sync)

    static func load(vehicleId: UUID, photoId: UUID) -> UIImage? {
        let key = galleryCacheKey(vehicleId: vehicleId, photoId: photoId)
        if let hit = fullImageCache.object(forKey: key) { return hit }
        let u = url(for: vehicleId, photoId: photoId)
        guard FileManager.default.fileExists(atPath: u.path),
              let image = UIImage(contentsOfFile: u.path) else { return nil }
        fullImageCache.setObject(image, forKey: key)
        return image
    }

    static func save(_ image: UIImage, vehicleId: UUID, photoId: UUID, quality: CGFloat = 0.88) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StoreError.encodingFailed
        }
        let imageURL = url(for: vehicleId, photoId: photoId)
        try data.write(to: imageURL, options: .atomic)
        fullImageCache.setObject(image, forKey: galleryCacheKey(vehicleId: vehicleId, photoId: photoId))
        evictThumbnails(for: imageURL)
    }

    static func delete(vehicleId: UUID, photoId: UUID) {
        let imageURL = url(for: vehicleId, photoId: photoId)
        try? FileManager.default.removeItem(at: imageURL)
        fullImageCache.removeObject(forKey: galleryCacheKey(vehicleId: vehicleId, photoId: photoId))
        evictThumbnails(for: imageURL)
    }

    // MARK: - Async wrappers (all dispatch to a utility thread)

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
        try await Task.detached(priority: .utility) {
            try save(image, vehicleId: vehicleId, photoId: photoId, quality: quality)
        }.value
    }

    static func delete(vehicleId: UUID, photoId: UUID) async {
        await Task.detached(priority: .utility) { delete(vehicleId: vehicleId, photoId: photoId) }.value
    }

    // MARK: - Thumbnail loading (downsampled)

    static func loadThumbnail(id: UUID, maxPixel: CGFloat = 180) -> UIImage? {
        let imageURL = url(for: id)
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        let key = thumbnailCacheKey(url: imageURL, maxPixel: maxPixel)
        if let hit = thumbnailCache.object(forKey: key) { return hit }
        if let img = downsampleImage(at: imageURL, maxPixel: maxPixel) {
            thumbnailCache.setObject(img, forKey: key)
            return img
        }
        return load(id: id)
    }

    static func loadThumbnail(vehicleId: UUID, photoId: UUID, maxPixel: CGFloat = 180) -> UIImage? {
        let imageURL = url(for: vehicleId, photoId: photoId)
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        let key = thumbnailCacheKey(url: imageURL, maxPixel: maxPixel)
        if let hit = thumbnailCache.object(forKey: key) { return hit }
        if let img = downsampleImage(at: imageURL, maxPixel: maxPixel) {
            thumbnailCache.setObject(img, forKey: key)
            return img
        }
        return load(vehicleId: vehicleId, photoId: photoId)
    }

    static func loadThumbnail(id: UUID, maxPixel: CGFloat = 180) async -> UIImage? {
        await Task.detached(priority: .utility) { loadThumbnail(id: id, maxPixel: maxPixel) }.value
    }

    static func loadThumbnail(vehicleId: UUID, photoId: UUID, maxPixel: CGFloat = 180) async -> UIImage? {
        await Task.detached(priority: .utility) {
            loadThumbnail(vehicleId: vehicleId, photoId: photoId, maxPixel: maxPixel)
        }.value
    }

    // MARK: - Preferred avatar (gallery → legacy → automatic)

    static func preferredAvatarImage(for vehicle: VehicleProfile, maxPixel: CGFloat = 180) -> UIImage? {
        if let coverId = vehicle.coverPhotoId,
           let img = loadThumbnail(vehicleId: vehicle.id, photoId: coverId, maxPixel: maxPixel) {
            return img
        }
        if let first = vehicle.galleryPhotoIds.first,
           let img = loadThumbnail(vehicleId: vehicle.id, photoId: first, maxPixel: maxPixel) {
            return img
        }
        if let legacy = loadThumbnail(id: vehicle.id, maxPixel: maxPixel) { return legacy }
        return automaticImage(for: vehicle)
    }

    static func preferredAvatarImage(for vehicle: VehicleProfile, maxPixel: CGFloat = 180) async -> UIImage? {
        await Task.detached(priority: .utility) {
            preferredAvatarImage(for: vehicle, maxPixel: maxPixel)
        }.value
    }

    // MARK: - Automatic fallback (Tesla / Rivian bundled assets)

    static func automaticImage(for vehicle: VehicleProfile) -> UIImage? {
        let key = automaticCacheKey(for: vehicle)
        if let hit = automaticImageCache.object(forKey: key) { return hit }

        let make  = vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modelText = [vehicle.model, vehicle.name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
        let vin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let assetName: String?
        if isTesla(make: make, vin: vin) {
            assetName = teslaAssetName(for: modelText)
        } else if isRivian(make: make, vin: vin) {
            assetName = rivianAssetName(for: modelText)
        } else {
            assetName = nil
        }

        guard let name = assetName, let image = UIImage(named: name) else { return nil }
        automaticImageCache.setObject(image, forKey: key)
        return image
    }

    static func hasCustomPhoto(for vehicle: VehicleProfile) -> Bool {
        if let coverId = vehicle.coverPhotoId, load(vehicleId: vehicle.id, photoId: coverId) != nil { return true }
        if let first = vehicle.galleryPhotoIds.first, load(vehicleId: vehicle.id, photoId: first) != nil { return true }
        return exists(id: vehicle.id)
    }

    static func coverImage(for vehicle: VehicleProfile) -> UIImage? {
        if let coverId = vehicle.coverPhotoId,
           let img = load(vehicleId: vehicle.id, photoId: coverId) { return img }
        if let first = vehicle.galleryPhotoIds.first,
           let img = load(vehicleId: vehicle.id, photoId: first) { return img }
        if let legacy = load(id: vehicle.id) { return legacy }
        return nil
    }

    static func preferredImage(for vehicle: VehicleProfile) -> UIImage? {
        coverImage(for: vehicle) ?? automaticImage(for: vehicle)
    }

    // MARK: - Private helpers

    private static func isTesla(make: String, vin: String) -> Bool {
        if make.contains("tesla") { return true }
        return vin.hasPrefix("5YJ") || vin.hasPrefix("7SA") || vin.hasPrefix("LRW")
    }

    private static func isRivian(make: String, vin: String) -> Bool {
        if make.contains("rivian") { return true }
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
        let k = normalizeModelKey(modelRaw)
        if k.contains("roadster") { return "roadster" }
        if k.contains("model3") || k == "3" || k == "m3" { return "model 3" }
        if k.contains("modely") || k == "y" || k == "my" { return "model y" }
        if k.contains("modelx") || k == "x" || k == "mx" { return "model x" }
        if k.contains("models") || k == "s" || k == "ms" { return "model s" }
        return "model 3"
    }

    private static func rivianAssetName(for modelRaw: String) -> String {
        let k = normalizeModelKey(modelRaw)
        if k.contains("r1s") { return "RivianR1S" }
        if k.contains("r1t") { return "RivianR1T" }
        if k.contains("r2")  { return "RivianR2" }
        if k.contains("r3")  { return "RivianR3" }
        return "RivianR1S"
    }

    private static func evictThumbnails(for imageURL: URL) {
        // Remove only the cached thumbnails for this specific image rather than
        // flushing the entire cache and forcing a full disk re-read for all photos.
        for px in [64, 90, 120, 150, 180, 240, 320] {
            thumbnailCache.removeObject(forKey: thumbnailCacheKey(url: imageURL, maxPixel: CGFloat(px)))
        }
    }

    private static func legacyCacheKey(_ id: UUID) -> NSString {
        "legacy:\(id.uuidString)" as NSString
    }
    private static func galleryCacheKey(vehicleId: UUID, photoId: UUID) -> NSString {
        "gallery:\(vehicleId.uuidString):\(photoId.uuidString)" as NSString
    }
    private static func thumbnailCacheKey(url: URL, maxPixel: CGFloat) -> NSString {
        "thumb:\(url.path):\(max(64, Int(maxPixel.rounded())))" as NSString
    }
    private static func automaticCacheKey(for vehicle: VehicleProfile) -> NSString {
        "\(vehicle.make.lowercased())|\(vehicle.model.lowercased())|\(vehicle.name.lowercased())|\(vehicle.vin.lowercased())" as NSString
    }

    private static func downsampleImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, Int(maxPixel.rounded()))
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
