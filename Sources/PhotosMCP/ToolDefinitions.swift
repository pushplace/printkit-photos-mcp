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
    description: "Search the user's Apple Photos library on this Mac. You have full access to their photos — use this when they mention their photos, pictures, camera roll, or want to find an image they took. Returns asset IDs and metadata. Search by date range, media type, and/or filename keyword.",
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
    description: "List all albums in the user's Apple Photos library on this Mac, including user-created and smart albums (Favorites, Recents, etc.).",
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
    description: "Get all photos and videos in a specific Apple Photos album by its ID.",
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
    description: "Get actual image thumbnails from the user's Photos library that you can see and analyze visually. Returns inline JPEG images for a batch of asset IDs. Use this after search_photos to look at the photos yourself, identify what's in them (pets, people, landscapes, etc.), and help the user pick the best shot.",
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
    description: "Browse the PrintKit print product catalog with sizes, prices, and SKUs. Products include metal prints, wood prints, gallery frames, acrylic blocks, and large format prints. Use this to find the right SKU before calling print_photo.",
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
    description: "Order a print of a photo from the user's Apple Photos library. Handles everything automatically: exports full-res from Photos, uploads to PrintKit, creates the order, and opens the Shopify checkout in the user's browser. The user never needs to upload or leave the conversation.",
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
