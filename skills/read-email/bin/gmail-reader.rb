#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone Gmail reader script for Claude Code skill
# Uses OAuth tokens from /opt/ruby/paperless project

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "google-apis-gmail_v1"
  gem "googleauth"
end

require "google/apis/gmail_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "json"
require "optparse"

TOKEN_PATH = ENV.fetch("GMAIL_TOKEN_PATH", File.expand_path("~/.claude/gmail_token.yaml"))
SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY
USER_ID = "me"

# Validate required environment variables
%w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each do |var|
  unless ENV[var]
    warn "Error: #{var} environment variable is not set"
    exit 1
  end
end

def authorizer
  client_id = Google::Auth::ClientId.new(
    ENV.fetch("GOOGLE_CLIENT_ID"),
    ENV.fetch("GOOGLE_CLIENT_SECRET")
  )

  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  credentials = authorizer.get_credentials(USER_ID)

  if credentials.nil?
    warn "Gmail authorization required. Run the OAuth flow to generate #{TOKEN_PATH}"
    exit 1
  end

  credentials
end

def extract_body(payload)
  # Try to find plain text part first
  plain_text = find_part_by_mime_type(payload, "text/plain")
  return decode_body(plain_text.body.data) if plain_text&.body&.data

  # Fall back to HTML and strip tags
  html_part = find_part_by_mime_type(payload, "text/html")
  if html_part&.body&.data
    html = decode_body(html_part.body.data)
    return strip_html(html)
  end

  # Last resort: check if body is directly on payload
  if payload.body&.data
    return decode_body(payload.body.data)
  end

  "[No body content found]"
end

def find_part_by_mime_type(part, mime_type)
  return part if part.mime_type == mime_type

  part.parts&.each do |p|
    result = find_part_by_mime_type(p, mime_type)
    return result if result
  end

  nil
end

def decode_body(data)
  return "" if data.nil? || data.empty?

  # Gmail uses URL-safe Base64, may omit padding
  padding_needed = (4 - data.length % 4) % 4
  padded = data + ("=" * padding_needed)
  decoded = Base64.urlsafe_decode64(padded)
  # Properly encode as UTF-8, preserving valid characters
  decoded.force_encoding("UTF-8")
  decoded.valid_encoding? ? decoded : decoded.encode("UTF-8", "binary", invalid: :replace, undef: :replace)
rescue ArgumentError
  data.to_s
end

def strip_html(html)
  # Basic HTML stripping - remove tags and decode common entities
  text = html
    .gsub(/<style[^>]*>.*?<\/style>/mi, "")
    .gsub(/<script[^>]*>.*?<\/script>/mi, "")
    .gsub(/<[^>]+>/, " ")
    .gsub(/&nbsp;/, " ")
    .gsub(/&amp;/, "&")
    .gsub(/&lt;/, "<")
    .gsub(/&gt;/, ">")
    .gsub(/&quot;/, '"')
    .gsub(/&#39;/, "'")
    .gsub(/\s+/, " ")
    .strip
  text
end

def extract_headers(message)
  headers = {}
  message.payload.headers.each do |header|
    case header.name.downcase
    when "from"
      headers[:from] = header.value
    when "to"
      headers[:to] = header.value
    when "subject"
      headers[:subject] = header.value
    when "date"
      headers[:date] = header.value
    end
  end
  headers
end

def fetch_emails(sender:, limit: 10, query: nil)
  service = Google::Apis::GmailV1::GmailService.new
  service.authorization = authorizer

  # Build query
  q = if query
        query
      elsif sender
        "from:#{sender}"
      else
        ""
      end

  messages = []
  page_token = nil

  loop do
    result = service.list_user_messages(USER_ID, q: q, page_token: page_token, max_results: [limit - messages.length, 100].min)
    break unless result.messages

    messages.concat(result.messages)
    break if messages.length >= limit

    page_token = result.next_page_token
    break unless page_token
  end

  messages.first(limit).map do |msg|
    full_message = service.get_user_message(USER_ID, msg.id)
    headers = extract_headers(full_message)
    body = extract_body(full_message.payload)

    {
      id: msg.id,
      from: headers[:from],
      to: headers[:to],
      subject: headers[:subject],
      date: headers[:date],
      body: body
    }
  end
end

# Parse command line arguments
options = { limit: 10 }

OptionParser.new do |opts|
  opts.banner = "Usage: gmail-reader.rb [options]"

  opts.on("-f", "--from SENDER", "Filter by sender email address") do |v|
    options[:from] = v
  end

  opts.on("-q", "--query QUERY", "Gmail search query (overrides --from)") do |v|
    options[:query] = v
  end

  opts.on("-l", "--limit N", Integer, "Maximum number of emails to return (default: 10)") do |v|
    options[:limit] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

if options[:from].nil? && options[:query].nil?
  warn "Error: Must specify --from or --query"
  exit 1
end

emails = fetch_emails(sender: options[:from], limit: options[:limit], query: options[:query])

# Ensure all string values are properly encoded as UTF-8 for JSON
emails.each do |email|
  email.each do |key, value|
    email[key] = value.encode("UTF-8", invalid: :replace, undef: :replace) if value.is_a?(String)
  end
end

puts JSON.pretty_generate(emails)
