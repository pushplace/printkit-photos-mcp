# photos-mcp

A [Model Context Protocol](https://modelcontextprotocol.io/) (MCP) server that gives LLMs access to your macOS Photos library via PhotoKit. Search, browse, export, and organize photos and albums directly from Claude.

## Tools

| Tool | Description |
|------|-------------|
| `search_photos` | Search by date range, media type (image/video/audio), and keyword |
| `list_albums` | List all user albums and smart albums |
| `get_album_contents` | Fetch assets in a specific album by ID |
| `export_photo` | Export a photo or video to `/tmp`, returns the file path |
| `create_album` | Create a new album |
| `add_to_album` | Add an existing asset to an album |

## Prerequisites

- macOS 13+
- Swift 6.1+ (included with Xcode 16.3+)
- Photos.app with photos in your library

## Installation

### Clone and build

```bash
git clone https://github.com/morganp/photos-mcp.git
cd photos-mcp
swift build
```

The binary will be at `.build/debug/photos-mcp`.

### Configure Claude Code

Add to `~/.claude.json` under your project's `mcpServers`:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-mcp/.build/debug/photos-mcp"
    }
  }
}
```

Then restart Claude Code.

### Configure Claude Desktop

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

Then restart Claude Desktop.

## Photos Permission

On first launch, macOS will prompt for Photos access. If the prompt does not appear, grant access manually:

**System Settings > Privacy & Security > Photos > photos-mcp**

To verify the Info.plist is embedded (required for the permission prompt):

```bash
otool -s __TEXT __info_plist .build/debug/photos-mcp | head -5
```

## Architecture

```
Sources/PhotosMCP/
  main.swift             -- entry point, authorization, server setup
  PhotoKitService.swift  -- all PhotoKit interactions (async bridges)
  ToolDefinitions.swift  -- MCP tool schemas (inputSchema)
  ToolHandlers.swift     -- tool call dispatch and argument parsing
Sources/Resources/
  Info.plist             -- embedded via linker for TCC Photos permission
```

Built with the official [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk).

## License

MIT
