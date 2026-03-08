import Foundation
import MCP
import Photos

func handleToolCall(
    params: CallTool.Parameters,
    service: PhotoKitService,
    thumbnailService: ThumbnailService,
    printKitService: PrintKitService
) async throws -> CallTool.Result {
    switch params.name {
    case "search_photos":
        return try await handleSearchPhotos(args: params.arguments ?? [:], service: service)
    case "list_albums":
        return handleListAlbums(args: params.arguments ?? [:], service: service)
    case "get_album_contents":
        return try handleGetAlbumContents(args: params.arguments ?? [:], service: service)
    case "export_photo":
        return try await handleExportPhoto(args: params.arguments ?? [:], service: service)
    case "create_album":
        return try await handleCreateAlbum(args: params.arguments ?? [:], service: service)
    case "add_to_album":
        return try await handleAddToAlbum(args: params.arguments ?? [:], service: service)
    case "get_photo_thumbnails":
        return try await handleGetPhotoThumbnails(args: params.arguments ?? [:], thumbnailService: thumbnailService)
    case "browse_printkit_products":
        return try await handleBrowsePrintkitProducts(args: params.arguments ?? [:], printKitService: printKitService)
    case "print_photo":
        return try await handlePrintPhoto(args: params.arguments ?? [:], service: service, printKitService: printKitService)
    default:
        return CallTool.Result(
            content: [.text("Unknown tool: \(params.name)")],
            isError: true
        )
    }
}

// MARK: - search_photos

private func handleSearchPhotos(
    args: [String: Value],
    service: PhotoKitService
) async throws -> CallTool.Result {
    let startDate = args["start_date"]?.stringValue.flatMap { parseDate($0) }
    let endDate = args["end_date"]?.stringValue.flatMap { parseDate($0) }
    let keyword = args["keyword"]?.stringValue
    let limit = args["limit"]?.intValue ?? 50

    var mediaType: PHAssetMediaType?
    if let typeStr = args["media_type"]?.stringValue {
        switch typeStr {
        case "image": mediaType = .image
        case "video": mediaType = .video
        case "audio": mediaType = .audio
        default: break
        }
    }

    let results = service.searchPhotos(
        startDate: startDate,
        endDate: endDate,
        mediaType: mediaType,
        keyword: keyword,
        limit: limit
    )

    return jsonResult(results)
}

// MARK: - list_albums

private func handleListAlbums(
    args: [String: Value],
    service: PhotoKitService
) -> CallTool.Result {
    let includeSmartAlbums = args["include_smart_albums"]?.boolValue ?? true
    let albums = service.listAlbums(includeSmartAlbums: includeSmartAlbums)
    return jsonResult(albums)
}

// MARK: - get_album_contents

private func handleGetAlbumContents(
    args: [String: Value],
    service: PhotoKitService
) throws -> CallTool.Result {
    guard let albumId = args["album_id"]?.stringValue else {
        return errorResult("Missing required parameter: album_id")
    }
    let limit = args["limit"]?.intValue ?? 100

    do {
        let assets = try service.getAlbumContents(albumId: albumId, limit: limit)
        return jsonResult(assets)
    } catch {
        return errorResult(error.localizedDescription)
    }
}

// MARK: - export_photo

private func handleExportPhoto(
    args: [String: Value],
    service: PhotoKitService
) async throws -> CallTool.Result {
    guard let assetId = args["asset_id"]?.stringValue else {
        return errorResult("Missing required parameter: asset_id")
    }

    do {
        let path = try await service.exportPhoto(assetId: assetId)
        return CallTool.Result(content: [.text(path)])
    } catch {
        return errorResult("Export failed: \(error.localizedDescription)")
    }
}

// MARK: - create_album

private func handleCreateAlbum(
    args: [String: Value],
    service: PhotoKitService
) async throws -> CallTool.Result {
    guard let name = args["name"]?.stringValue else {
        return errorResult("Missing required parameter: name")
    }

    do {
        let localId = try await service.createAlbum(name: name)
        let result: [String: String] = ["localIdentifier": localId, "name": name]
        return jsonResult(result)
    } catch {
        return errorResult("Failed to create album: \(error.localizedDescription)")
    }
}

// MARK: - add_to_album

private func handleAddToAlbum(
    args: [String: Value],
    service: PhotoKitService
) async throws -> CallTool.Result {
    guard let assetId = args["asset_id"]?.stringValue else {
        return errorResult("Missing required parameter: asset_id")
    }
    guard let albumId = args["album_id"]?.stringValue else {
        return errorResult("Missing required parameter: album_id")
    }

    do {
        try await service.addToAlbum(assetId: assetId, albumId: albumId)
        return CallTool.Result(content: [.text("Asset added to album successfully.")])
    } catch {
        return errorResult("Failed to add to album: \(error.localizedDescription)")
    }
}

// MARK: - Helpers

private func parseDate(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: string)
}

private func jsonResult(_ value: Any) -> CallTool.Result {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return CallTool.Result(content: [.text("[]")])
    }
    return CallTool.Result(content: [.text(text)])
}

private func errorResult(_ message: String) -> CallTool.Result {
    CallTool.Result(content: [.text(message)], isError: true)
}

// MARK: - get_photo_thumbnails

private func handleGetPhotoThumbnails(
    args: [String: Value],
    thumbnailService: ThumbnailService
) async throws -> CallTool.Result {
    // Extract asset_ids array from the Value type
    guard let idsValue = args["asset_ids"]?.arrayValue else {
        return errorResult("Missing required parameter: asset_ids (array of strings)")
    }

    let assetIds = idsValue.compactMap { $0.stringValue }
    if assetIds.isEmpty {
        return errorResult("asset_ids array is empty or contains no valid strings")
    }

    // Cap at 20 to keep response manageable
    let cappedIds = Array(assetIds.prefix(20))
    let maxDimension = args["max_dimension"]?.intValue ?? 300

    do {
        let results = try await thumbnailService.exportThumbnails(
            assetIds: cappedIds,
            maxDimension: maxDimension
        )

        // Return image content blocks so Claude can actually see the thumbnails
        var content: [Tool.Content] = []
        for result in results {
            guard let filePath = result["file_path"] else { continue }
            let assetId = result["asset_id"] ?? "unknown"
            let width = result["pixelWidth"] ?? "?"
            let height = result["pixelHeight"] ?? "?"

            // Add metadata as text
            content.append(.text("[\(assetId)] \(width)x\(height)"))

            // Read the JPEG and return as base64 image
            if let imageData = FileManager.default.contents(atPath: filePath) {
                let base64 = imageData.base64EncodedString()
                content.append(.image(data: base64, mimeType: "image/jpeg", metadata: nil))
            }
        }

        if content.isEmpty {
            return errorResult("No thumbnails could be generated for the provided asset IDs")
        }

        return CallTool.Result(content: content)
    } catch {
        return errorResult("Thumbnail export failed: \(error.localizedDescription)")
    }
}

// MARK: - browse_printkit_products

private func handleBrowsePrintkitProducts(
    args: [String: Value],
    printKitService: PrintKitService
) async throws -> CallTool.Result {
    do {
        if let handle = args["handle"]?.stringValue {
            let json = try await printKitService.getProduct(handle: handle)
            return CallTool.Result(content: [.text(json)])
        } else {
            let json = try await printKitService.listProducts()
            return CallTool.Result(content: [.text(json)])
        }
    } catch {
        return errorResult("PrintKit catalog error: \(error.localizedDescription)")
    }
}

// MARK: - print_photo

private func handlePrintPhoto(
    args: [String: Value],
    service: PhotoKitService,
    printKitService: PrintKitService
) async throws -> CallTool.Result {
    guard let assetId = args["asset_id"]?.stringValue else {
        return errorResult("Missing required parameter: asset_id")
    }
    guard let sku = args["sku"]?.stringValue else {
        return errorResult("Missing required parameter: sku")
    }

    do {
        // Step 1: Export full-res photo to /tmp
        let filePath = try await service.exportPhoto(assetId: assetId)

        // Step 2: Upload to PrintKit
        let (publicUrl, filename) = try await printKitService.uploadPhoto(filePath: filePath)

        // Step 3: Create order
        let checkoutUrl = try await printKitService.createOrder(sku: sku, photoUrls: [publicUrl])

        // Step 4: Open checkout in browser
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [checkoutUrl]
        try process.run()

        let result: [String: String] = [
            "checkoutUrl": checkoutUrl,
            "photoUrl": publicUrl,
            "filename": filename,
            "message": "Order created! Opening checkout in your browser.",
        ]
        return jsonResult(result)
    } catch {
        return errorResult("Print failed: \(error.localizedDescription)")
    }
}
