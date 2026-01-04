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
| `user_agent` | string | No | Safari UA | Custom User-Agent string |
| `headers` | object | No | `{}` | Additional HTTP headers (merged with defaults) |
| `method` | string | No | `GET` | HTTP method: GET, POST, PUT, DELETE, HEAD |
| `body` | string | No | - | Request body for POST/PUT requests |
| `follow_redirects` | boolean | No | `true` | Follow HTTP redirects |
| `proxy` | string | No | - | Proxy URL (e.g., `http://user:pass@proxy:port`) |

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

**Fetch via proxy:**
```
url: "https://example.com"
proxy: "http://proxy.example.com:8080"
```

**Fetch via authenticated proxy:**
```
url: "https://example.com"
proxy: "http://user:password@proxy.example.com:8080"
```

## Tool: fetch_url_flaresolverr

Fetch Cloudflare-protected URLs using [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr). Requires FlareSolverr running as a Docker container.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `url` | string | Yes | - | The URL to fetch |
| `flaresolverr_url` | string | No | `http://localhost:8191/v1` | FlareSolverr endpoint |
| `max_timeout` | integer | No | `60000` | Max timeout in milliseconds |

### Example

```
url: "https://cloudflare-protected-site.com"
```

### FlareSolverr Setup

```bash
# Start FlareSolverr (runs on port 8191)
docker run -d --name flaresolverr -p 8191:8191 ghcr.io/flaresolverr/flaresolverr:latest

# Check it's running
curl http://localhost:8191/
```

## Features

- **Browser-like defaults**: Realistic Safari User-Agent and standard browser headers (Accept, Accept-Language, etc.) to reduce bot detection
- **Cloudflare bypass**: Auto-fallback to FlareSolverr when Cloudflare challenge detected (if FlareSolverr is running)
- **Custom User-Agent**: Override the default User-Agent if needed
- **Proxy support**: Route requests through HTTP proxies with optional authentication
- **Additional headers**: Set any HTTP headers (auth tokens, content types, etc.)
- **Multiple HTTP methods**: GET, POST, PUT, DELETE, HEAD
- **Redirect handling**: Follows redirects by default (up to 10 hops)
- **SSL/TLS**: HTTPS with certificate verification
- **Timeouts**: 10s connection, 30s read

## Default Headers

The server sends browser-like headers by default:

```
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15 (mcp:ruby-fetch +https://github.com/sgbett/dotfiles-claude/issues)
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-GB,en;q=0.9
Connection: keep-alive
Upgrade-Insecure-Requests: 1
```

These can be overridden using the `user_agent` and `headers` parameters.

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
