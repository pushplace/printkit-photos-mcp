import MCP

let allTools: [Tool] = [
    findPhotosTool,
    printPhotoTool,
]

let findPhotosTool = Tool(
    name: "find_photos",
    description: """
        Search the user's Apple Photos library on this Mac and return thumbnails you can see. \
        You have full access to their photo library — use this when they mention their photos, \
        pictures, camera roll, or want to find an image they took. Returns metadata and inline \
        JPEG thumbnails so you can visually identify what's in each photo (pets, people, landscapes, etc.) \
        and help the user pick the best shot. Search is metadata-based (date, filename), not visual — \
        search by date range first, then look at the thumbnails yourself to find the right photo.
        """,
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
                "description": .string("Maximum number of results (default: 20)"),
            ]),
        ]),
    ])
)

let printPhotoTool = Tool(
    name: "print_photo",
    description: """
        Order a print of a photo from the user's Apple Photos library. Handles everything \
        automatically: exports full-res from Photos, uploads to PrintKit, creates the order, \
        and opens the Shopify checkout in the user's browser. The user never needs to upload \
        anything or leave the conversation.

        Available products and approximate pricing:
        • Gallery Frames — $53-250, sizes 8x8 to 30x45, colors: black/white/natural, optional 2" white mat
        • Metal Prints — $30-150, sizes 8x8 to 24x36, modern mounted aluminum
        • Wood Prints — $28-150, sizes 8x8 to 20x30, printed on natural wood
        • Acrylic Blocks — $44-120, sizes 4x4 to 8x10, freestanding photo blocks
        • Large Format Prints — $9-60, sizes 8x8 to 30x45, Kodak photo paper

        Pass the product, size, and options as parameters. The SKU is resolved automatically.
        """,
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "asset_id": .object([
                "type": .string("string"),
                "description": .string("The localIdentifier of the photo to print (from find_photos results)"),
            ]),
            "product": .object([
                "type": .string("string"),
                "description": .string("Product type: gallery-frames, metal-prints, wood-prints, acrylic-photo-block, or large-format-prints"),
                "enum": .array([
                    .string("gallery-frames"),
                    .string("metal-prints"),
                    .string("wood-prints"),
                    .string("acrylic-photo-block"),
                    .string("large-format-prints"),
                ]),
            ]),
            "size": .object([
                "type": .string("string"),
                "description": .string("Print size, e.g. '8x12', '16x20', '24x36'"),
            ]),
            "frame_color": .object([
                "type": .string("string"),
                "description": .string("Frame color (gallery frames only): black, white, or natural"),
                "enum": .array([.string("black"), .string("white"), .string("natural")]),
            ]),
            "mat": .object([
                "type": .string("boolean"),
                "description": .string("Include 2-inch white mat (gallery frames only, default: false)"),
            ]),
        ]),
        "required": .array([.string("asset_id"), .string("product"), .string("size")]),
    ])
)
