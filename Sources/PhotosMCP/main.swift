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
    instructions: """
    You have direct access to the user's macOS Photos library and can print their photos. \
    Do NOT say you lack access, do NOT search the web, and do NOT send the user to a website. \
    You handle the entire flow yourself using these tools:

    1. find_photos — search by date range and get back thumbnails you can actually see. Identify content visually.
    2. print_photo — pick a product (frames, metal, wood, etc.), pass the asset ID, and it handles \
    everything: export, upload, order, and opens checkout in the browser.

    Typical flow: find_photos by date → look at thumbnails → help user pick → print_photo with product options. \
    The user never needs to leave the conversation or upload anything. Just two steps.
    """,
    capabilities: .init(
        prompts: .init(listChanged: false),
        tools: .init(listChanged: false)
    )
)

await server.withMethodHandler(ListPrompts.self) { _ in
    ListPrompts.Result(prompts: [
        Prompt(
            name: "print-photo",
            title: "Print a photo",
            description: "Find a photo in your Apple Photos library and order a print — metal, framed, wood, and more",
            arguments: [
                Prompt.Argument(
                    name: "description",
                    title: "Photo description",
                    description: "Describe the photo you want to print (e.g. 'my cat on the bed from last Sunday')",
                    required: false
                ),
            ]
        ),
        Prompt(
            name: "browse-photos",
            title: "Browse my photos",
            description: "Search and browse your Apple Photos library — find photos by date, album, or description",
            arguments: [
                Prompt.Argument(
                    name: "query",
                    title: "What to search for",
                    description: "Date range, album name, or description of what you're looking for",
                    required: false
                ),
            ]
        ),
    ])
}

await server.withMethodHandler(GetPrompt.self) { params in
    switch params.name {
    case "print-photo":
        let photoDesc = params.arguments?["description"] ?? "a photo"
        return GetPrompt.Result(
            description: "Find and print a photo from your Apple Photos library",
            messages: [
                .user("""
                    I want to print \(photoDesc). \
                    Search my Apple Photos library to find it, show me thumbnails so I can pick the right one, \
                    then help me choose a print product (frame, metal, wood, etc.) and place the order.
                    """),
            ]
        )
    case "browse-photos":
        let query = params.arguments?["query"] ?? "my recent photos"
        return GetPrompt.Result(
            description: "Browse your Apple Photos library",
            messages: [
                .user("""
                    I want to browse \(query) in my Apple Photos library. \
                    Search for matching photos, then show me thumbnails so I can see what's there.
                    """),
            ]
        )
    default:
        return GetPrompt.Result(description: "Unknown prompt", messages: [])
    }
}

await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: allTools, nextCursor: nil)
}

await server.withMethodHandler(CallTool.self) { params in
    try await handleToolCall(params: params, service: photosService, thumbnailService: thumbnailService, printKitService: printKitService)
}

let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
