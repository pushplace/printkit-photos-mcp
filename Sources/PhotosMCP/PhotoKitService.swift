import Foundation
import Photos

final class PhotoKitService: @unchecked Sendable {

    // MARK: - Search Photos

    func searchPhotos(
        startDate: Date?,
        endDate: Date?,
        mediaType: PHAssetMediaType?,
        keyword: String?,
        limit: Int
    ) -> [[String: String]] {
        let fetchOptions = PHFetchOptions()
        var predicates: [NSPredicate] = []

        if let startDate {
            predicates.append(NSPredicate(format: "creationDate >= %@", startDate as NSDate))
        }
        if let endDate {
            predicates.append(NSPredicate(format: "creationDate <= %@", endDate as NSDate))
        }
        if let mediaType {
            predicates.append(NSPredicate(format: "mediaType == %d", mediaType.rawValue))
        }

        if !predicates.isEmpty {
            fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        let results = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [[String: String]] = []
        let dateFormatter = ISO8601DateFormatter()

        results.enumerateObjects { asset, _, stop in
            var info: [String: String] = [
                "localIdentifier": asset.localIdentifier,
                "mediaType": Self.mediaTypeString(asset.mediaType),
                "pixelWidth": "\(asset.pixelWidth)",
                "pixelHeight": "\(asset.pixelHeight)",
            ]
            if let date = asset.creationDate {
                info["creationDate"] = dateFormatter.string(from: date)
            }
            if let location = asset.location {
                info["latitude"] = "\(location.coordinate.latitude)"
                info["longitude"] = "\(location.coordinate.longitude)"
            }

            // If keyword provided, filter by original filename
            if let keyword = keyword {
                let resources = PHAssetResource.assetResources(for: asset)
                let filename = resources.first?.originalFilename ?? ""
                if !filename.localizedCaseInsensitiveContains(keyword) {
                    return
                }
            }

            assets.append(info)
        }

        return assets
    }

    // MARK: - List Albums

    func listAlbums(includeSmartAlbums: Bool) -> [[String: String]] {
        var albums: [[String: String]] = []

        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            albums.append([
                "localIdentifier": collection.localIdentifier,
                "title": collection.localizedTitle ?? "(untitled)",
                "type": "user",
                "estimatedAssetCount": "\(collection.estimatedAssetCount)",
            ])
        }

        if includeSmartAlbums {
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .any, options: nil
            )
            smartAlbums.enumerateObjects { collection, _, _ in
                // Skip empty smart albums
                let count = collection.estimatedAssetCount
                if count == 0 { return }
                albums.append([
                    "localIdentifier": collection.localIdentifier,
                    "title": collection.localizedTitle ?? "(untitled)",
                    "type": "smart",
                    "estimatedAssetCount": "\(count)",
                ])
            }
        }

        return albums
    }

    // MARK: - Get Album Contents

    func getAlbumContents(albumId: String, limit: Int) throws -> [[String: String]] {
        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId], options: nil
        )
        guard let collection = collections.firstObject else {
            throw PhotoKitError.albumNotFound(albumId)
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = limit
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var results: [[String: String]] = []
        let dateFormatter = ISO8601DateFormatter()

        assets.enumerateObjects { asset, _, _ in
            var info: [String: String] = [
                "localIdentifier": asset.localIdentifier,
                "mediaType": Self.mediaTypeString(asset.mediaType),
                "pixelWidth": "\(asset.pixelWidth)",
                "pixelHeight": "\(asset.pixelHeight)",
            ]
            if let date = asset.creationDate {
                info["creationDate"] = dateFormatter.string(from: date)
            }
            results.append(info)
        }
        return results
    }

    // MARK: - Export Photo

    func exportPhoto(assetId: String) async throws -> String {
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId], options: nil
        )
        guard let asset = assets.firstObject else {
            throw PhotoKitError.assetNotFound(assetId)
        }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            throw PhotoKitError.noResourceAvailable(assetId)
        }

        let filename = resource.originalFilename
        let sanitizedId = assetId.replacingOccurrences(of: "/", with: "_")
        let outputURL = URL(fileURLWithPath: "/tmp/\(sanitizedId)_\(filename)")

        try? FileManager.default.removeItem(at: outputURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: outputURL,
                options: options
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        return outputURL.path
    }

    // MARK: - Create Album

    func createAlbum(name: String) async throws -> String {
        var placeholder: PHObjectPlaceholder?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                    withTitle: name
                )
                placeholder = request.placeholderForCreatedAssetCollection
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: PhotoKitError.albumCreationFailed(name))
                } else {
                    continuation.resume()
                }
            }
        }

        guard let localIdentifier = placeholder?.localIdentifier else {
            throw PhotoKitError.albumCreationFailed(name)
        }
        return localIdentifier
    }

    // MARK: - Add to Album

    func addToAlbum(assetId: String, albumId: String) async throws {
        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId], options: nil
        )
        guard let album = collections.firstObject else {
            throw PhotoKitError.albumNotFound(albumId)
        }

        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId], options: nil
        )
        guard let asset = assets.firstObject else {
            throw PhotoKitError.assetNotFound(assetId)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                guard let request = PHAssetCollectionChangeRequest(for: album) else {
                    return
                }
                request.addAssets([asset] as NSFastEnumeration)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: PhotoKitError.addToAlbumFailed(assetId, albumId))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helpers

    private static func mediaTypeString(_ type: PHAssetMediaType) -> String {
        switch type {
        case .image: return "image"
        case .video: return "video"
        case .audio: return "audio"
        default: return "unknown"
        }
    }
}

// MARK: - Errors

enum PhotoKitError: Error, LocalizedError {
    case assetNotFound(String)
    case albumNotFound(String)
    case noResourceAvailable(String)
    case albumCreationFailed(String)
    case addToAlbumFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .assetNotFound(let id):
            return "Asset not found: \(id)"
        case .albumNotFound(let id):
            return "Album not found: \(id)"
        case .noResourceAvailable(let id):
            return "No resource data available for asset: \(id)"
        case .albumCreationFailed(let name):
            return "Failed to create album: \(name)"
        case .addToAlbumFailed(let assetId, let albumId):
            return "Failed to add asset \(assetId) to album \(albumId)"
        }
    }
}
