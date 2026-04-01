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
    case "find_photos":
        return try await handleFindPhotos(args: params.arguments ?? [:], service: service, thumbnailService: thumbnailService)
    case "print_photo":
        return try await handlePrintPhoto(args: params.arguments ?? [:], service: service, printKitService: printKitService)
    default:
        return CallTool.Result(
            content: [.text("Unknown tool: \(params.name)")],
            isError: true
        )
    }
}

// MARK: - find_photos (search + thumbnails in one call)

private func handleFindPhotos(
    args: [String: Value],
    service: PhotoKitService,
    thumbnailService: ThumbnailService
) async throws -> CallTool.Result {
    let startDate = args["start_date"]?.stringValue.flatMap { parseDate($0) }
    let endDate = args["end_date"]?.stringValue.flatMap { parseDate($0) }
    let keyword = args["keyword"]?.stringValue
    let limit = args["limit"]?.intValue ?? 20

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

    // Extract asset IDs for thumbnail generation
    guard let resultArray = results as? [[String: Any]] else {
        return jsonResult(results)
    }

    if resultArray.isEmpty {
        return CallTool.Result(content: [.text("No photos found for the given search criteria. Try widening the date range.")])
    }

    let assetIds = resultArray.compactMap { $0["localIdentifier"] as? String }

    // Cap thumbnails at 20
    let cappedIds = Array(assetIds.prefix(20))

    // Generate thumbnails
    do {
        let thumbnails = try await thumbnailService.exportThumbnails(
            assetIds: cappedIds,
            maxDimension: 300
        )

        var content: [Tool.Content] = []
        content.append(.text("Found \(resultArray.count) photos. Showing thumbnails for \(thumbnails.count):"))

        for (i, result) in thumbnails.enumerated() {
            guard let filePath = result["file_path"] else { continue }
            let assetId = result["asset_id"] ?? "unknown"
            let width = result["pixelWidth"] ?? "?"
            let height = result["pixelHeight"] ?? "?"

            // Find the matching metadata
            let meta = resultArray.first { ($0["localIdentifier"] as? String) == assetId }
            let creationDate = meta?["creationDate"] as? String ?? "unknown date"

            content.append(.text("[\(i + 1)] ID: \(assetId) | \(width)x\(height) | \(creationDate)"))

            if let imageData = FileManager.default.contents(atPath: filePath) {
                let base64 = imageData.base64EncodedString()
                content.append(.image(data: base64, mimeType: "image/jpeg", metadata: nil))
            }
        }

        return CallTool.Result(content: content)
    } catch {
        // Fall back to metadata only if thumbnails fail
        return jsonResult(results)
    }
}

// MARK: - print_photo (with SKU resolution)

private func handlePrintPhoto(
    args: [String: Value],
    service: PhotoKitService,
    printKitService: PrintKitService
) async throws -> CallTool.Result {
    guard let assetId = args["asset_id"]?.stringValue else {
        return errorResult("Missing required parameter: asset_id")
    }
    guard let product = args["product"]?.stringValue else {
        return errorResult("Missing required parameter: product")
    }
    guard let size = args["size"]?.stringValue else {
        return errorResult("Missing required parameter: size")
    }

    let frameColor = args["frame_color"]?.stringValue
    let mat = args["mat"]?.boolValue ?? false

    // Resolve SKU from parameters
    let sku: String
    do {
        sku = try await resolveSKU(
            product: product,
            size: size,
            frameColor: frameColor,
            mat: mat,
            printKitService: printKitService
        )
    } catch {
        return errorResult("Could not find a matching product: \(error.localizedDescription)")
    }

    do {
        // Step 1: Export full-res photo
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
            "sku": sku,
            "message": "Order created! Opening checkout in your browser.",
        ]
        return jsonResult(result)
    } catch {
        return errorResult("Print failed: \(error.localizedDescription)")
    }
}

// MARK: - SKU Resolution

private func resolveSKU(
    product: String,
    size: String,
    frameColor: String?,
    mat: Bool,
    printKitService: PrintKitService
) async throws -> String {
    // Fetch the variants catalog
    let catalogJSON = try await printKitService.listVariants()
    guard let data = catalogJSON.data(using: .utf8),
          let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let variants = catalog["variants"] as? [[String: Any]] else {
        throw PrintKitError.requestFailed("Could not parse variant catalog")
    }

    // Filter variants by product handle and size
    let matches = variants.filter { variant in
        guard let handle = variant["product_handle"] as? String,
              let variantSize = variant["size"] as? String else { return false }

        if handle != product { return false }
        if variantSize != size { return false }

        // For gallery frames, also match color and mat
        if product == "gallery-frames" {
            if let color = frameColor,
               let variantColor = variant["frame_color"] as? String,
               variantColor.lowercased() != color.lowercased() {
                return false
            }
            let variantMat = variant["mat"] as? String
            let hasMat = variantMat != nil && variantMat != "No Mat"
            if mat != hasMat { return false }
        }

        return true
    }

    guard let match = matches.first,
          let sku = match["sku"] as? String else {
        throw PrintKitError.requestFailed(
            "No variant found for \(product) \(size)" +
            (frameColor != nil ? " \(frameColor!)" : "") +
            (mat ? " with mat" : "")
        )
    }

    return sku
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
