# photos-mcp

MCP server for macOS Photos.app via PhotoKit.

## Build

```
swift build
```

## Run (standalone test)

```
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}' | .build/debug/photos-mcp
```

## Run with Claude Code

Add to ~/.claude/claude_desktop_config.json (or the appropriate MCP config):

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/.build/debug/photos-mcp"
    }
  }
}
```

Then restart Claude Code / Claude Desktop.

## First Run -- Photos Permission

On first launch, macOS will prompt for Photos access.
If the prompt does not appear, grant access manually:
System Settings > Privacy & Security > Photos > photos-mcp

To verify the Info.plist is embedded (required for TCC prompt):
```
otool -s __TEXT __info_plist .build/debug/photos-mcp | head -5
```

## Tools

| Tool | Description |
|------|-------------|
| search_photos | Search by date range, media type, keyword |
| list_albums | List user and smart albums |
| get_album_contents | Fetch assets in an album by ID |
| export_photo | Export asset to /tmp, returns file path |
| create_album | Create a new album |
| add_to_album | Add an asset to an album |
| get_photo_thumbnails | Export batch of 300px JPEG thumbnails, returns inline images Claude can see |
| browse_printkit_products | Fetch PrintKit product catalog (all products or specific handle) |
| print_photo | One-shot: export photo -> upload to PrintKit -> create order -> open checkout |

## Architecture

```
Sources/PhotosMCP/
  main.swift             -- entry point, authorization, server setup
  PhotoKitService.swift  -- all PhotoKit interactions (async bridges)
  ThumbnailService.swift -- batch thumbnail export via PHImageManager
  PrintKitService.swift  -- PrintKit API client (upload, order, catalog)
  ToolDefinitions.swift  -- MCP tool schemas (inputSchema)
  ToolHandlers.swift     -- tool call dispatch and argument parsing
Sources/Resources/
  Info.plist             -- embedded via linker for TCC Photos permission
```

## Test

```
swift build && echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | .build/debug/photos-mcp
```

## Lint

```
swift build 2>&1 | head -20
```

## Dependencies

- [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) (MCP protocol handling)
- PhotoKit (macOS Photos.app access)
