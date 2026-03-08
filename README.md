# Print My Photos

An MCP server that connects your macOS Photos library to Claude. Browse your photos, see visual thumbnails, and print them as wall art via [PrintKit](https://printkit.dev).

Built on [morganp/photos-mcp](https://github.com/morganp/photos-mcp) (PhotoKit) + [PrintKit](https://printkit.dev) (print API).

## The Flow

1. "Show me my vacation photos" -- `search_photos` finds them by date/keyword
2. "Let me see them" -- `get_photo_thumbnails` exports 300px JPEGs, Claude sees them visually
3. "Print that sunset as a metal print" -- `print_photo` exports, uploads, creates order, opens checkout

## Tools

| Tool | Description |
|------|-------------|
| `search_photos` | Search by date range, media type, keyword |
| `list_albums` | List all user and smart albums |
| `get_album_contents` | Fetch assets in a specific album |
| `get_photo_thumbnails` | Export batch thumbnails (300px JPEG). Claude sees the actual images. |
| `export_photo` | Export full-res photo/video to `/tmp` |
| `create_album` | Create a new album |
| `add_to_album` | Add an asset to an album |
| `browse_printkit_products` | Browse PrintKit catalog -- metal, wood, acrylic, frames, etc. |
| `print_photo` | One-shot print: asset ID + SKU in, checkout URL out |

## Prerequisites

- macOS 13+
- Swift 6.1+ (Xcode 16.3+)
- Photos.app with photos in your library

## Install

```bash
git clone https://github.com/user/photos-mcp.git
cd photos-mcp
swift build
```

## Configure Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-mcp/.build/debug/photos-mcp"
    }
  }
}
```

## Configure Claude Code

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-mcp/.build/debug/photos-mcp"
    }
  }
}
```

## Photos Permission

On first launch, macOS will prompt for Photos access. If it doesn't appear, grant manually:

**System Settings > Privacy & Security > Photos > photos-mcp**

To verify Info.plist is embedded:

```bash
otool -s __TEXT __info_plist .build/debug/photos-mcp | head -5
```

## Architecture

```
Sources/PhotosMCP/
  main.swift             -- entry point, auth, server setup
  PhotoKitService.swift  -- PhotoKit interactions (search, export, albums)
  ThumbnailService.swift -- batch thumbnail export via PHImageManager
  PrintKitService.swift  -- PrintKit API client (upload, order, catalog)
  ToolDefinitions.swift  -- MCP tool schemas
  ToolHandlers.swift     -- tool dispatch and argument parsing
Sources/Resources/
  Info.plist             -- embedded for TCC Photos permission
```

## How PrintKit Works

No API key needed. The `print_photo` tool:

1. Exports full-res photo from Photos via PhotoKit
2. Gets a presigned S3 upload URL from `printkit.dev/api/upload`
3. Uploads the image to S3
4. Creates an order via `printkit.dev/api/add-to-cart`
5. Opens the Shopify checkout in your browser

## License

MIT
