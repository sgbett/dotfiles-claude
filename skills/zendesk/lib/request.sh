#!/usr/bin/env bash
# Zendesk API Request Library
# Provides HTTP request wrapper with rate limiting and retry logic
#
# Requires: auth.sh to be sourced first
#
# Usage:
#   source ~/.claude/skills/zendesk/lib/auth.sh
#   source ~/.claude/skills/zendesk/lib/request.sh
#
#   # GET request
#   zendesk_request "GET" "/users/me.json"
#
#   # POST request with body
#   zendesk_request "POST" "/tickets.json" '{"ticket":{"subject":"Test"}}'
#
#   # PUT request
#   zendesk_request "PUT" "/tickets/123.json" '{"ticket":{"status":"solved"}}'

set -euo pipefail

# Configuration
# Note: Enterprise plan (700 req/min)
# See: https://developer.zendesk.com/api-reference/introduction/rate-limits/
ZENDESK_MAX_RETRIES="${ZENDESK_MAX_RETRIES:-5}"
ZENDESK_TIMEOUT="${ZENDESK_TIMEOUT:-30}"
ZENDESK_DEBUG="${ZENDESK_DEBUG:-false}"

# Source auth library if not already loaded
# Use known path since this is installed in ~/.claude/skills/zendesk/
if ! type zendesk_auth_header &>/dev/null; then
    source "${HOME}/.claude/skills/zendesk/lib/auth.sh"
fi

# Debug logging
_zendesk_debug() {
    if [[ "$ZENDESK_DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Calculate exponential backoff with jitter
# Usage: _zendesk_backoff_delay <attempt_number>
# Returns delay in seconds
_zendesk_backoff_delay() {
    local attempt="$1"
    local base_delay=1
    local max_delay=60

    # Calculate exponential delay: 2^(attempt-1) seconds
    local delay=$((base_delay * (1 << (attempt - 1))))

    # Cap at max delay
    if [[ $delay -gt $max_delay ]]; then
        delay=$max_delay
    fi

    # Add jitter (0-25% of delay)
    local jitter=$((RANDOM % (delay / 4 + 1)))
    delay=$((delay + jitter))

    echo "$delay"
}

# Parse Retry-After header value
# Can be seconds (integer) or HTTP date
_zendesk_parse_retry_after() {
    local header_value="$1"

    # If it's a number, use it directly
    if [[ "$header_value" =~ ^[0-9]+$ ]]; then
        echo "$header_value"
        return
    fi

    # Otherwise it might be an HTTP date - for simplicity, default to 30s
    echo "30"
}

# Make an HTTP request to the Zendesk API with retry logic
# Usage: zendesk_request <METHOD> <ENDPOINT> [BODY]
#
# Arguments:
#   METHOD   - HTTP method (GET, POST, PUT, DELETE)
#   ENDPOINT - API endpoint (e.g., "/tickets/123.json")
#   BODY     - Optional JSON body for POST/PUT requests
#
# Returns:
#   Outputs the response body on success
#   Returns exit code 0 on success, non-zero on failure
#
# Environment variables:
#   ZENDESK_MAX_RETRIES - Maximum retry attempts (default: 5)
#   ZENDESK_TIMEOUT     - Request timeout in seconds (default: 30)
#   ZENDESK_DEBUG       - Set to "true" for debug output
zendesk_request() {
    local method="${1:-}"
    local endpoint="${2:-}"
    local body="${3:-}"

    # Validate arguments
    if [[ -z "$method" ]] || [[ -z "$endpoint" ]]; then
        zendesk_error "Usage: zendesk_request <METHOD> <ENDPOINT> [BODY]"
        return 1
    fi

    # Validate config
    if ! zendesk_validate_config; then
        return 1
    fi

    # Build URL
    local url
    url=$(zendesk_url "$endpoint")

    # Get auth header
    local auth_header
    auth_header=$(zendesk_auth_header)

    # Build curl arguments
    local curl_args=(
        --silent
        --show-error
        --location
        --max-time "$ZENDESK_TIMEOUT"
        --header "Authorization: $auth_header"
        --header "Content-Type: application/json"
        --header "Accept: application/json"
        --write-out "\n%{http_code}"
        --request "$method"
    )

    # Add body for POST/PUT
    if [[ -n "$body" ]] && [[ "$method" =~ ^(POST|PUT|PATCH)$ ]]; then
        curl_args+=(--data "$body")
    fi

    # Add URL
    curl_args+=("$url")

    # Retry loop
    local attempt=1
    local response
    local http_code
    local response_body

    while [[ $attempt -le $ZENDESK_MAX_RETRIES ]]; do
        _zendesk_debug "Attempt $attempt: $method $url"

        # Make the request, capturing both body and status code
        # The --write-out adds the HTTP code on a new line at the end
        response=$(curl "${curl_args[@]}" 2>&1) || {
            local curl_exit=$?
            if [[ $curl_exit -eq 28 ]]; then
                zendesk_warn "Request timed out (attempt $attempt/$ZENDESK_MAX_RETRIES)"
            else
                zendesk_warn "Request failed with curl error $curl_exit (attempt $attempt/$ZENDESK_MAX_RETRIES)"
            fi

            if [[ $attempt -lt $ZENDESK_MAX_RETRIES ]]; then
                local delay
                delay=$(_zendesk_backoff_delay "$attempt")
                zendesk_warn "Retrying in ${delay}s..."
                sleep "$delay"
                ((attempt++))
                continue
            else
                zendesk_error "Max retries ($ZENDESK_MAX_RETRIES) exceeded"
                return 1
            fi
        }

        # Extract HTTP code (last line) and body (everything else)
        http_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')

        _zendesk_debug "HTTP $http_code"

        # Handle response codes
        case "$http_code" in
            2*)
                # Success
                echo "$response_body"
                return 0
                ;;
            401)
                zendesk_error "Authentication failed (401 Unauthorized)"
                zendesk_error "Check your ZENDESK_EMAIL and ZENDESK_API_TOKEN"
                return 1
                ;;
            403)
                zendesk_error "Access forbidden (403)"
                zendesk_error "Your account may not have permission for this resource"
                return 1
                ;;
            404)
                zendesk_error "Resource not found (404): $endpoint"
                return 1
                ;;
            422)
                zendesk_error "Validation error (422)"
                echo "$response_body" >&2
                return 1
                ;;
            429)
                # Rate limited - extract Retry-After if present
                local retry_after=30

                # Try to get Retry-After from response headers
                # We'd need a separate HEAD request or parse from response
                # For now, use exponential backoff
                local delay
                delay=$(_zendesk_backoff_delay "$attempt")

                zendesk_warn "Rate limited (429) - attempt $attempt/$ZENDESK_MAX_RETRIES"

                if [[ $attempt -lt $ZENDESK_MAX_RETRIES ]]; then
                    zendesk_warn "Retrying in ${delay}s..."
                    sleep "$delay"
                    ((attempt++))
                    continue
                else
                    zendesk_error "Max retries ($ZENDESK_MAX_RETRIES) exceeded after rate limiting"
                    return 1
                fi
                ;;
            5*)
                # Server error - retry
                zendesk_warn "Server error ($http_code) - attempt $attempt/$ZENDESK_MAX_RETRIES"

                if [[ $attempt -lt $ZENDESK_MAX_RETRIES ]]; then
                    local delay
                    delay=$(_zendesk_backoff_delay "$attempt")
                    zendesk_warn "Retrying in ${delay}s..."
                    sleep "$delay"
                    ((attempt++))
                    continue
                else
                    zendesk_error "Max retries ($ZENDESK_MAX_RETRIES) exceeded after server errors"
                    return 1
                fi
                ;;
            *)
                zendesk_error "Unexpected response code: $http_code"
                echo "$response_body" >&2
                return 1
                ;;
        esac
    done

    zendesk_error "Request failed after $ZENDESK_MAX_RETRIES attempts"
    return 1
}

# Convenience functions for common HTTP methods
zendesk_get() {
    zendesk_request "GET" "$@"
}

zendesk_post() {
    zendesk_request "POST" "$@"
}

zendesk_put() {
    zendesk_request "PUT" "$@"
}

zendesk_delete() {
    zendesk_request "DELETE" "$@"
}
