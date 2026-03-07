import Foundation
import MCP
import Photos

func handleToolCall(
    params: CallTool.Parameters,
    service: PhotoKitService
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
