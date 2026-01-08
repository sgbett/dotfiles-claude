# Plan: Ruby MCP Server for Flexible Web Fetching

## Goal
Create a Ruby MCP server that provides flexible web fetching with custom User-Agent strings and headers.

## Files to Create

### 1. MCP Server Script
**Path:** `~/.claude/mcp/ruby-fetch/server.rb`

Features:
- JSON-RPC 2.0 over stdio (MCP protocol)
- `fetch_url` tool with parameters:
  - `url` (required) - URL to fetch
  - `user_agent` - custom User-Agent string
  - `headers` - additional HTTP headers hash
  - `method` - HTTP method (GET, POST, PUT, DELETE)
  - `body` - request body for POST/PUT
- Error handling with meaningful messages
- HTTPS support
- Timeouts (10s connect, 30s read)

### 2. Configuration
**Path:** `~/.claude/settings.json`

Add MCP server configuration pointing to the Ruby script.

## Implementation Steps

1. Create directory `~/.claude/mcp/ruby-fetch/`
2. Create `server.rb` with:
   - MCPFetchServer class
   - JSON-RPC request handling (initialize, tools/list, tools/call)
   - HTTP fetching with Net::HTTP
   - Custom User-Agent and headers support
3. Make script executable
4. Update `~/.claude/settings.json` to register the MCP server

## Dependencies
- Ruby stdlib only (json, net/http, uri) - no gems required
