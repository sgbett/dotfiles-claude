#!/usr/bin/env bash
# Zendesk API Authentication Library
# Provides functions for authenticating with the Zendesk API
#
# Required environment variables:
#   ZENDESK_SUBDOMAIN - Your Zendesk subdomain (e.g., "yourcompany" for yourcompany.zendesk.com)
#   ZENDESK_EMAIL     - Email address for API authentication
#   ZENDESK_API_TOKEN - API token from Zendesk Admin > Apps and integrations > APIs > Zendesk API
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
    local missing=()
    local valid=true

    if [[ -z "${ZENDESK_SUBDOMAIN:-}" ]]; then
        missing+=("ZENDESK_SUBDOMAIN")
        valid=false
    fi

    if [[ -z "${ZENDESK_EMAIL:-}" ]]; then
        missing+=("ZENDESK_EMAIL")
        valid=false
    fi

    if [[ -z "${ZENDESK_API_TOKEN:-}" ]]; then
        missing+=("ZENDESK_API_TOKEN")
        valid=false
    fi

    if [[ "$valid" == "false" ]]; then
        zendesk_error "Missing required environment variables: ${missing[*]}"
        echo "" >&2
        echo "Set your Zendesk credentials:" >&2
        echo "  export ZENDESK_SUBDOMAIN=yourcompany" >&2
        echo "  export ZENDESK_EMAIL=you@example.com" >&2
        echo "  export ZENDESK_API_TOKEN=your_api_token" >&2
        echo "" >&2
        echo "Get your API token from:" >&2
        echo "  Zendesk Admin > Apps and integrations > APIs > Zendesk API" >&2
        return 1
    fi

    return 0
}

# Generate the Basic auth header value
# Zendesk uses email/token:api_token format for token auth
# Returns the header value (without "Authorization: " prefix)
zendesk_auth_header() {
    if ! zendesk_validate_config 2>/dev/null; then
        zendesk_error "Cannot generate auth header: missing configuration"
        return 1
    fi

    local credentials="${ZENDESK_EMAIL}/token:${ZENDESK_API_TOKEN}"
    local encoded
    encoded=$(echo -n "$credentials" | base64 | tr -d '\n')
    echo "Basic $encoded"
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

# Display current configuration (without exposing the token)
zendesk_show_config() {
    echo "Zendesk Configuration:"
    echo "  Subdomain: ${ZENDESK_SUBDOMAIN:-<not set>}"
    echo "  Email:     ${ZENDESK_EMAIL:-<not set>}"
    if [[ -n "${ZENDESK_API_TOKEN:-}" ]]; then
        echo "  API Token: <set>"
    else
        echo "  API Token: <not set>"
    fi
    echo "  Base URL:  $(zendesk_base_url 2>/dev/null || echo '<invalid>')"
}
