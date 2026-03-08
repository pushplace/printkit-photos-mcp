import Foundation
import Photos
import MCP

// Request Photos authorization before starting the server.
// Bridge the callback-based API into async/await.
let authStatus: PHAuthorizationStatus = await withCheckedContinuation { continuation in
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        continuation.resume(returning: status)
    }
}

guard authStatus == .authorized || authStatus == .limited else {
    let msg = "Photos access denied (status: \(authStatus.rawValue)). Grant access in System Settings > Privacy & Security > Photos.\n"
    fputs(msg, stderr)
    exit(1)
}

let photosService = PhotoKitService()
let thumbnailService = ThumbnailService()
let printKitService = PrintKitService()

let server = Server(
    name: "photos-mcp",
    version: "1.0.0",
    capabilities: .init(tools: .init(listChanged: false))
)

await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: allTools, nextCursor: nil)
}

await server.withMethodHandler(CallTool.self) { params in
    try await handleToolCall(params: params, service: photosService, thumbnailService: thumbnailService, printKitService: printKitService)
}

let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
