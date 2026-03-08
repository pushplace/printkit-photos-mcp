import MCP

let allTools: [Tool] = [
    searchPhotosTool,
    listAlbumsTool,
    getAlbumContentsTool,
    exportPhotoTool,
    createAlbumTool,
    addToAlbumTool,
    getPhotoThumbnailsTool,
    browsePrintkitProductsTool,
    printPhotoTool,
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

// MARK: - Thumbnail Tool

let getPhotoThumbnailsTool = Tool(
    name: "get_photo_thumbnails",
    description: "Export small JPEG thumbnails (default 300px) for a batch of photos by their asset IDs. Returns file paths that Claude can read to visually see the photos. Use after search_photos or get_album_contents to let the user preview and pick photos.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "asset_ids": .object([
                "type": .string("array"),
                "description": .string("Array of localIdentifier strings for the photos to thumbnail"),
                "items": .object([
                    "type": .string("string"),
                ]),
            ]),
            "max_dimension": .object([
                "type": .string("integer"),
                "description": .string("Maximum width/height in pixels (default: 300). Thumbnails maintain aspect ratio."),
            ]),
        ]),
        "required": .array([.string("asset_ids")]),
    ])
)

// MARK: - PrintKit Tools

let browsePrintkitProductsTool = Tool(
    name: "browse_printkit_products",
    description: "Browse the PrintKit product catalog. Returns available print products (metal prints, wood prints, gallery frames, etc.) with sizes and prices. Optionally pass a product handle to get detailed variant info.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "handle": .object([
                "type": .string("string"),
                "description": .string("Optional product handle for details (e.g. \"metal-prints\", \"wood-prints\", \"gallery-frames\", \"acrylic-photo-block\", \"large-format-prints\"). Omit to list all products."),
            ]),
        ]),
    ])
)

let printPhotoTool = Tool(
    name: "print_photo",
    description: "Print a photo from your library via PrintKit. Exports the full-res photo, uploads it, creates an order, and opens the checkout page in your browser. One-shot: asset ID + SKU in, checkout URL out.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "asset_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the photo to print"),
            ]),
            "sku": .object([
                "type": .string("string"),
                "description": .string("Product variant SKU from browse_printkit_products (e.g. \"MT-8x10\")"),
            ]),
        ]),
        "required": .array([.string("asset_id"), .string("sku")]),
    ])
)
