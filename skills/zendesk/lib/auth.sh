#!/usr/bin/env bash
# Zendesk API Authentication Library
# Provides functions for authenticating with the Zendesk API
#
# Authentication is OAuth client_credentials (API tokens are being removed by
# Zendesk: https://support.zendesk.com/hc/en-us/articles/10851263566234). A
# short-lived bearer token is minted from an OAuth client's id/secret and cached
# on disk for its lifetime so repeated calls don't re-mint.
#
# Required environment variables:
#   ZENDESK_SUBDOMAIN     - Your Zendesk subdomain (e.g., "yourcompany" for yourcompany.zendesk.com)
#   ZENDESK_CLIENT_ID     - OAuth client identifier (Admin > Apps and integrations > APIs > OAuth clients)
#   ZENDESK_CLIENT_SECRET - OAuth client secret for that client
# Optional:
#   ZENDESK_OAUTH_SCOPE     - Scope requested for the token (default: read)
#   ZENDESK_TOKEN_CACHE_DIR - Directory for the cached token (default: $XDG_CACHE_HOME/zendesk-skill)
#
# Usage:
#   source ~/.claude/skills/zendesk/lib/auth.sh
#   zendesk_validate_config || exit 1
#   AUTH_HEADER=$(zendesk_auth_header)
#   BASE_URL=$(zendesk_base_url)

set -euo pipefail

# Colours for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No colour

# Print error message to stderr
zendesk_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

# Print success message
zendesk_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print warning message
zendesk_warn() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

# Validate that all required environment variables are set
# Returns 0 if valid, 1 if invalid
zendesk_validate_config() {
    local var
    local missing=()

    for var in ZENDESK_SUBDOMAIN ZENDESK_CLIENT_ID ZENDESK_CLIENT_SECRET; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        zendesk_error "Missing required environment variables: ${missing[*]}"
        echo "" >&2
        echo "Set your Zendesk OAuth credentials:" >&2
        echo "  export ZENDESK_SUBDOMAIN=yourcompany" >&2
        echo "  export ZENDESK_CLIENT_ID=your_oauth_client_identifier" >&2
        echo "  export ZENDESK_CLIENT_SECRET=your_oauth_client_secret" >&2
        echo "" >&2
        echo "Create a confidential OAuth client at:" >&2
        echo "  Zendesk Admin > Apps and integrations > APIs > OAuth clients" >&2
        return 1
    fi

    return 0
}

# Path to the cached bearer token file
_zendesk_token_cache_file() {
    local dir="${ZENDESK_TOKEN_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/zendesk-skill}"
    echo "${dir}/oauth-token"
}

# Mint (or reuse) an OAuth client_credentials access token.
# Echoes the raw token on stdout; all diagnostics go to stderr.
_zendesk_access_token() {
    local cache_file now expiry token
    cache_file=$(_zendesk_token_cache_file)
    now=$(date +%s)

    # Reuse a cached token while it's valid (60s safety margin).
    if [[ -f "$cache_file" ]]; then
        expiry=$(cut -d' ' -f1 "$cache_file" 2>/dev/null || echo "")
        token=$(cut -d' ' -f2- "$cache_file" 2>/dev/null || echo "")
        if [[ "$expiry" =~ ^[0-9]+$ ]] && [[ -n "$token" ]] && (( now < expiry - 60 )); then
            echo "$token"
            return 0
        fi
    fi

    # Mint a fresh token via the client_credentials grant.
    local url response http_code body access_token expires_in
    url="https://${ZENDESK_SUBDOMAIN}.zendesk.com/oauth/tokens"
    response=$(curl --silent --show-error --location --max-time 30 \
        --write-out $'\n%{http_code}' \
        --request POST "$url" \
        --header "Content-Type: application/json" \
        --data "{\"grant_type\":\"client_credentials\",\"client_id\":\"${ZENDESK_CLIENT_ID}\",\"client_secret\":\"${ZENDESK_CLIENT_SECRET}\",\"scope\":\"${ZENDESK_OAUTH_SCOPE:-read}\"}") || {
        zendesk_error "OAuth token request failed (network error)"
        return 1
    }

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != 2* ]]; then
        zendesk_error "OAuth token request failed (HTTP $http_code)"
        echo "$body" >&2
        return 1
    fi

    access_token=$(echo "$body" | jq -r '.access_token // empty')
    expires_in=$(echo "$body" | jq -r '.expires_in // 0')

    if [[ -z "$access_token" ]]; then
        zendesk_error "OAuth response contained no access_token"
        echo "$body" >&2
        return 1
    fi

    # Cache owner-only for reuse across the many calls a single command makes.
    local cache_dir
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir" && chmod 700 "$cache_dir" 2>/dev/null || true
    (umask 077; echo "$(( now + expires_in )) ${access_token}" > "$cache_file")

    echo "$access_token"
}

# Generate the Authorization header value (without "Authorization: " prefix)
# Returns a bearer token from the OAuth client_credentials grant.
zendesk_auth_header() {
    if ! zendesk_validate_config 2>/dev/null; then
        zendesk_error "Cannot generate auth header: missing configuration"
        return 1
    fi

    local token
    token=$(_zendesk_access_token) || return 1
    echo "Bearer $token"
}

# Get the Zendesk API base URL
# Returns: https://{subdomain}.zendesk.com/api/v2
zendesk_base_url() {
    if ! zendesk_validate_config 2>/dev/null; then
        zendesk_error "Cannot construct base URL: missing configuration"
        return 1
    fi

    echo "https://${ZENDESK_SUBDOMAIN}.zendesk.com/api/v2"
}

# Get the full URL for an API endpoint
# Usage: zendesk_url "/tickets/123.json"
zendesk_url() {
    local endpoint="${1:-}"
    if [[ -z "$endpoint" ]]; then
        zendesk_error "zendesk_url requires an endpoint argument"
        return 1
    fi

    # Remove leading slash if present to avoid double slashes
    endpoint="${endpoint#/}"

    echo "$(zendesk_base_url)/${endpoint}"
}

# Display current configuration (without exposing the secret)
zendesk_show_config() {
    echo "Zendesk Configuration:"
    echo "  Subdomain:     ${ZENDESK_SUBDOMAIN:-<not set>}"
    echo "  OAuth Client:  ${ZENDESK_CLIENT_ID:-<not set>}"
    if [[ -n "${ZENDESK_CLIENT_SECRET:-}" ]]; then
        echo "  Client Secret: <set>"
    else
        echo "  Client Secret: <not set>"
    fi
    echo "  Base URL:      $(zendesk_base_url 2>/dev/null || echo '<invalid>')"
}
