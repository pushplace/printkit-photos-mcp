import Foundation
import Photos
import AppKit

final class ThumbnailService: @unchecked Sendable {

    /// Export thumbnails for a batch of asset IDs at the given max dimension.
    /// Returns an array of dictionaries with asset_id and file_path.
    func exportThumbnails(
        assetIds: [String],
        maxDimension: Int = 300
    ) async throws -> [[String: String]] {
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds, options: nil
        )

        var results: [[String: String]] = []
        let targetSize = CGSize(width: maxDimension, height: maxDimension)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        assets.enumerateObjects { asset, _, _ in
            let assetId = asset.localIdentifier
            let sanitizedId = assetId.replacingOccurrences(of: "/", with: "_")
            let outputPath = "/tmp/thumb_\(sanitizedId).jpg"
            let outputURL = URL(fileURLWithPath: outputPath)

            // Use semaphore to bridge callback to sync context within enumerate
            let semaphore = DispatchSemaphore(value: 0)
            var exportSuccess = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                defer { semaphore.signal() }

                // Skip degraded (low-quality placeholder) deliveries
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }

                guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    return
                }

                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                guard let jpegData = bitmapRep.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: 0.7]
                ) else { return }

                do {
                    try jpegData.write(to: outputURL)
                    exportSuccess = true
                } catch {
                    // Skip this asset on write failure
                }
            }

            semaphore.wait()

            if exportSuccess {
                results.append([
                    "asset_id": assetId,
                    "file_path": outputPath,
                    "pixelWidth": "\(asset.pixelWidth)",
                    "pixelHeight": "\(asset.pixelHeight)",
                ])
            }
        }

        return results
    }
}
