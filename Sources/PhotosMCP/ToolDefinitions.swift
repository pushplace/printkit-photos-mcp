import MCP

let allTools: [Tool] = [
    searchPhotosTool,
    listAlbumsTool,
    getAlbumContentsTool,
    exportPhotoTool,
    createAlbumTool,
    addToAlbumTool,
]

let searchPhotosTool = Tool(
    name: "search_photos",
    description: "Search photos by date range, media type, and/or keyword. Returns local identifiers and metadata.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "start_date": .object([
                "type": .string("string"),
                "description": .string("Start date in ISO 8601 format (YYYY-MM-DD)"),
            ]),
            "end_date": .object([
                "type": .string("string"),
                "description": .string("End date in ISO 8601 format (YYYY-MM-DD)"),
            ]),
            "media_type": .object([
                "type": .string("string"),
                "description": .string("Filter by media type: image, video, or audio"),
                "enum": .array([.string("image"), .string("video"), .string("audio")]),
            ]),
            "keyword": .object([
                "type": .string("string"),
                "description": .string("Search keyword (matched against asset filenames)"),
            ]),
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Maximum number of results (default: 50)"),
            ]),
        ]),
    ])
)

let listAlbumsTool = Tool(
    name: "list_albums",
    description: "List all user albums and smart albums in the Photos library.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "include_smart_albums": .object([
                "type": .string("boolean"),
                "description": .string("Include smart albums like Favorites, Recents (default: true)"),
            ]),
        ]),
    ])
)

let getAlbumContentsTool = Tool(
    name: "get_album_contents",
    description: "Get all assets in a specific album by its local identifier.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "album_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the album"),
            ]),
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Maximum number of assets to return (default: 100)"),
            ]),
        ]),
        "required": .array([.string("album_id")]),
    ])
)

let exportPhotoTool = Tool(
    name: "export_photo",
    description: "Export a photo or video to /tmp by its local identifier. Returns the file path.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "asset_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the asset to export"),
            ]),
        ]),
        "required": .array([.string("asset_id")]),
    ])
)

let createAlbumTool = Tool(
    name: "create_album",
    description: "Create a new user album in the Photos library.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "name": .object([
                "type": .string("string"),
                "description": .string("The name for the new album"),
            ]),
        ]),
        "required": .array([.string("name")]),
    ])
)

let addToAlbumTool = Tool(
    name: "add_to_album",
    description: "Add an existing asset to an album by their local identifiers.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "asset_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the asset to add"),
            ]),
            "album_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the target album"),
            ]),
        ]),
        "required": .array([.string("asset_id"), .string("album_id")]),
    ])
)
