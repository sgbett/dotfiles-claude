#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP Server for flexible web fetching with custom User-Agent and headers
# Protocol: JSON-RPC 2.0 over stdio (MCP specification)

require 'json'
require 'net/http'
require 'uri'

class MCPFetchServer
  PROTOCOL_VERSION = '2024-11-05'
  SERVER_NAME = 'ruby-fetch'
  SERVER_VERSION = '1.0.0'

  def initialize
    @tools = [
      {
        name: 'fetch_url',
        description: 'Fetch a URL with custom headers including User-Agent. Supports GET, POST, PUT, DELETE methods.',
        inputSchema: {
          type: 'object',
          properties: {
            url: {
              type: 'string',
              description: 'The URL to fetch'
            },
            user_agent: {
              type: 'string',
              description: 'Custom User-Agent string (default: Ruby-MCP-Fetch/1.0)'
            },
            headers: {
              type: 'object',
              description: 'Additional HTTP headers as key-value pairs'
            },
            method: {
              type: 'string',
              enum: %w[GET POST PUT DELETE HEAD],
              description: 'HTTP method (default: GET)'
            },
            body: {
              type: 'string',
              description: 'Request body for POST/PUT requests'
            },
            follow_redirects: {
              type: 'boolean',
              description: 'Follow HTTP redirects (default: true)'
            }
          },
          required: ['url']
        }
      }
    ]
  end

  def run
    $stderr.puts "#{SERVER_NAME} v#{SERVER_VERSION} started"

    $stdin.each_line do |line|
      next if line.strip.empty?

      begin
        request = JSON.parse(line)
        response = handle_request(request)
        if response
          $stdout.puts(JSON.generate(response))
          $stdout.flush
        end
      rescue JSON::ParserError => e
        error_response = {
          jsonrpc: '2.0',
          id: nil,
          error: { code: -32700, message: "Parse error: #{e.message}" }
        }
        $stdout.puts(JSON.generate(error_response))
        $stdout.flush
      end
    end
  end

  private

  def handle_request(request)
    id = request['id']
    method = request['method']
    params = request['params'] || {}

    result = case method
    when 'initialize'
      handle_initialize(params)
    when 'notifications/initialized'
      return nil # No response for notifications
    when 'tools/list'
      handle_tools_list
    when 'tools/call'
      handle_tool_call(params)
    when 'ping'
      {}
    else
      return {
        jsonrpc: '2.0',
        id: id,
        error: { code: -32601, message: "Method not found: #{method}" }
      }
    end

    { jsonrpc: '2.0', id: id, result: result }
  end

  def handle_initialize(_params)
    {
      protocolVersion: PROTOCOL_VERSION,
      capabilities: { tools: {} },
      serverInfo: {
        name: SERVER_NAME,
        version: SERVER_VERSION
      }
    }
  end

  def handle_tools_list
    { tools: @tools }
  end

  def handle_tool_call(params)
    tool_name = params['name']
    arguments = params['arguments'] || {}

    case tool_name
    when 'fetch_url'
      fetch_url(arguments)
    else
      error_content("Unknown tool: #{tool_name}")
    end
  end

  def fetch_url(args)
    url = args['url']
    return error_content('URL is required') if url.nil? || url.empty?

    user_agent = args['user_agent'] || 'Ruby-MCP-Fetch/1.0'
    extra_headers = args['headers'] || {}
    method = (args['method'] || 'GET').upcase
    body = args['body']
    follow_redirects = args.fetch('follow_redirects', true)
    max_redirects = 10

    begin
      uri = URI.parse(url)
      redirect_count = 0

      loop do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 30
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

        headers = { 'User-Agent' => user_agent }.merge(extra_headers)

        request = case method
        when 'GET'
          Net::HTTP::Get.new(uri.request_uri, headers)
        when 'POST'
          req = Net::HTTP::Post.new(uri.request_uri, headers)
          req.body = body if body
          req
        when 'PUT'
          req = Net::HTTP::Put.new(uri.request_uri, headers)
          req.body = body if body
          req
        when 'DELETE'
          Net::HTTP::Delete.new(uri.request_uri, headers)
        when 'HEAD'
          Net::HTTP::Head.new(uri.request_uri, headers)
        else
          return error_content("Unsupported HTTP method: #{method}")
        end

        response = http.request(request)

        if follow_redirects && response.is_a?(Net::HTTPRedirection)
          redirect_count += 1
          return error_content("Too many redirects (max #{max_redirects})") if redirect_count > max_redirects

          location = response['location']
          uri = URI.parse(location)
          next
        end

        content = if method == 'HEAD'
          "Status: #{response.code} #{response.message}\nHeaders:\n#{format_headers(response)}"
        else
          response.body || ''
        end

        return {
          content: [
            {
              type: 'text',
              text: content
            }
          ]
        }
      end

    rescue URI::InvalidURIError => e
      error_content("Invalid URL: #{e.message}")
    rescue SocketError => e
      error_content("Connection failed: #{e.message}")
    rescue Net::OpenTimeout
      error_content("Connection timed out after 10 seconds")
    rescue Net::ReadTimeout
      error_content("Read timed out after 30 seconds")
    rescue OpenSSL::SSL::SSLError => e
      error_content("SSL error: #{e.message}")
    rescue StandardError => e
      error_content("Error: #{e.class} - #{e.message}")
    end
  end

  def format_headers(response)
    response.each_header.map { |k, v| "  #{k}: #{v}" }.join("\n")
  end

  def error_content(message)
    {
      content: [{ type: 'text', text: message }],
      isError: true
    }
  end
end

MCPFetchServer.new.run if __FILE__ == $PROGRAM_NAME
