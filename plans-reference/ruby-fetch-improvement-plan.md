# ruby-fetch MCP Server Improvement Plan

## Goal

Improve the ruby-fetch MCP server to better handle protected websites, particularly those using Cloudflare's bot protection.

## Background

The current implementation uses Ruby's `Net::HTTP` with a basic user-agent (`Ruby-MCP-Fetch/1.0`). When fetching Cloudflare-protected URLs (like `claude.ai/share/*`), requests are blocked by Cloudflare's "managed challenge" which requires JavaScript execution.

### Cloudflare Protection Layers (from Browserless article)
1. **Bot Scores** - Rates how "human-like" each request appears
2. **JA3/JA4 TLS Fingerprinting** - Analyses TLS handshake signatures
3. **JavaScript Challenges** - Requires actual JS execution to pass
4. **Detection IDs** - Static rules checking headers, metadata, patterns

### Current Limitations
- Generic user-agent flags requests as bots
- No proxy support for IP rotation
- No JavaScript execution capability
- Standard Net::HTTP TLS fingerprint is detectable

---

## Phase 1: Quick Wins (No Dependencies)

### 1.1 Update Default User-Agent

**File:** `server.rb` line 141

**Change:**
```ruby
# FROM:
user_agent = args['user_agent'] || 'Ruby-MCP-Fetch/1.0'

# TO:
DEFAULT_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15 (mcp:ruby-fetch +https://github.com/sgbett/dotfiles-claude/issues)'
user_agent = args['user_agent'] || DEFAULT_USER_AGENT
```

**Rationale:** A realistic browser user-agent helps pass basic bot detection. The `(mcp:ruby-fetch +https://github.com/sgbett/dotfiles-claude/issues)` suffix maintains transparency for site operators.

**Impact:** Low - Won't bypass JS challenges but reduces bot score.

### 1.2 Add Proxy Support

**File:** `server.rb`

**Schema addition:**
```ruby
proxy: {
  type: 'string',
  description: 'Proxy URL (e.g., http://user:pass@proxy:port)'
}
```

**Implementation:**
```ruby
proxy_url = args['proxy']
if proxy_url
  proxy_uri = URI.parse(proxy_url)
  http = Net::HTTP.new(uri.host, uri.port, proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
else
  http = Net::HTTP.new(uri.host, uri.port)
end
```

**Rationale:** Enables IP rotation to avoid rate limits and bans. Net::HTTP has native proxy support.

**Impact:** Medium - Useful for sites with IP-based blocking.

### 1.3 Add Common Browser Headers

**Implementation:** Add default headers that browsers typically send:
```ruby
DEFAULT_HEADERS = {
  'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language' => 'en-GB,en;q=0.9',
  'Accept-Encoding' => 'gzip, deflate, br',
  'Connection' => 'keep-alive',
  'Upgrade-Insecure-Requests' => '1'
}
```

**Rationale:** Missing standard headers are a bot detection signal.

---

## Phase 2: FlareSolverr Integration (Optional Dependency)

### 2.1 Overview

[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) is a proxy server that uses a real browser to solve Cloudflare challenges. It runs as a Docker container and exposes an HTTP API.

### 2.2 Add New Tool: `fetch_url_flaresolverr`

**Schema:**
```ruby
{
  name: 'fetch_url_flaresolverr',
  description: 'Fetch a Cloudflare-protected URL using FlareSolverr (requires FlareSolverr running)',
  inputSchema: {
    type: 'object',
    properties: {
      url: { type: 'string', description: 'The URL to fetch' },
      flaresolverr_url: {
        type: 'string',
        description: 'FlareSolverr endpoint (default: http://localhost:8191/v1)'
      },
      max_timeout: {
        type: 'integer',
        description: 'Max timeout in ms (default: 60000)'
      }
    },
    required: ['url']
  }
}
```

**Implementation:**
```ruby
def fetch_via_flaresolverr(args)
  url = args['url']
  flaresolverr_url = args['flaresolverr_url'] || 'http://localhost:8191/v1'
  max_timeout = args['max_timeout'] || 60000

  payload = {
    cmd: 'request.get',
    url: url,
    maxTimeout: max_timeout
  }

  uri = URI.parse(flaresolverr_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = (max_timeout / 1000) + 10

  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(payload)

  response = http.request(request)
  result = JSON.parse(response.body)

  if result['status'] == 'ok'
    { content: [{ type: 'text', text: result['solution']['response'] }] }
  else
    error_content("FlareSolverr error: #{result['message']}")
  end
end
```

### 2.3 Docker Setup for FlareSolverr

```bash
docker run -d \
  --name flaresolverr \
  -p 8191:8191 \
  ghcr.io/flaresolverr/flaresolverr:latest
```

### 2.4 Auto-Fallback (Optional Enhancement)

Could add automatic fallback to FlareSolverr when Cloudflare is detected:
```ruby
def fetch_url(args)
  response = fetch_url_direct(args)

  # Detect Cloudflare challenge page
  if cloudflare_challenge?(response)
    return fetch_via_flaresolverr(args) if flaresolverr_available?
  end

  response
end

def cloudflare_challenge?(response)
  return false unless response[:content]&.first&.dig(:text)
  text = response[:content].first[:text]
  text.include?('Just a moment...') && text.include?('cf_chl')
end
```

---

## Phase 3: Future Considerations (Not Planned)

### 3.1 curl-impersonate Integration
- Replaces Net::HTTP with shell-out to curl-impersonate
- Spoofs JA3/JA4 TLS fingerprints to match real browsers
- Requires external binary installation
- **Status:** Not recommended for now - adds complexity

### 3.2 Ferrum/Chrome Integration
- Full headless browser for JS-heavy sites
- Massive dependency (Chrome + gems)
- **Status:** Out of scope - use FlareSolverr instead

---

## Implementation Order

1. **Phase 1.1** - Update default user-agent
2. **Phase 1.2** - Add proxy support
3. **Phase 1.3** - Add default browser headers
4. **Phase 2.2** - Add FlareSolverr tool
5. **Phase 2.4** - Auto-fallback (optional)

---

## Files to Modify

| File | Changes |
|------|---------|
| `server.rb` | All implementation changes |
| `README.md` | Document new features, proxy usage, FlareSolverr setup |

---

## Testing Plan

1. Test basic fetch still works: `https://example.com`
2. Test with custom user-agent parameter
3. Test proxy support with a public proxy
4. Test FlareSolverr with `https://nowsecure.nl` (Cloudflare test site)
5. Test Cloudflare detection with `https://claude.ai/share/*`

---

## Decision Points

- [ ] Proceed with Phase 1 (quick wins)?
- [ ] Include FlareSolverr integration (Phase 2)?
- [ ] Add auto-fallback or keep as separate tool?
