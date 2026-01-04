# ruby-fetch MCP Server

A Ruby MCP (Model Context Protocol) server providing flexible web fetching with custom User-Agent strings and headers.

## Installation

The server is already configured in `~/.claude/settings.json`. Restart Claude Code to load it.

## Tool: fetch_url

Fetch a URL with custom headers and User-Agent.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `url` | string | Yes | - | The URL to fetch |
| `user_agent` | string | No | `Ruby-MCP-Fetch/1.0` | Custom User-Agent string |
| `headers` | object | No | `{}` | Additional HTTP headers as key-value pairs |
| `method` | string | No | `GET` | HTTP method: GET, POST, PUT, DELETE, HEAD |
| `body` | string | No | - | Request body for POST/PUT requests |
| `follow_redirects` | boolean | No | `true` | Follow HTTP redirects |

### Examples

**Basic fetch:**
```
url: "https://example.com"
```

**Custom User-Agent:**
```
url: "https://api.example.com/data"
user_agent: "MyBot/2.0 (compatible; research)"
```

**POST with headers:**
```
url: "https://api.example.com/submit"
method: "POST"
user_agent: "MyApp/1.0"
headers: {"Content-Type": "application/json", "Authorization": "Bearer token123"}
body: '{"key": "value"}'
```

**HEAD request (check headers only):**
```
url: "https://example.com/large-file.zip"
method: "HEAD"
```

## Features

- **Custom User-Agent**: Override the default User-Agent for sites that block bots
- **Additional headers**: Set any HTTP headers (auth tokens, content types, etc.)
- **Multiple HTTP methods**: GET, POST, PUT, DELETE, HEAD
- **Redirect handling**: Follows redirects by default (up to 10 hops)
- **SSL/TLS**: HTTPS with certificate verification
- **Timeouts**: 10s connection, 30s read

## Configuration

In `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "ruby-fetch": {
      "command": "ruby",
      "args": ["/Users/simon/.claude/mcp/ruby-fetch/server.rb"]
    }
  }
}
```

## Dependencies

Ruby stdlib only - no gems required.

## Testing

```bash
# Test initialisation
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | ruby server.rb

# Test tools list
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | ruby server.rb
```
