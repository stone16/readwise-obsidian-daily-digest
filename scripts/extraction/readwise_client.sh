#!/usr/bin/env bash

###############################################################################
# readwise_client.sh
#
# Readwise API client with authentication, rate limiting, and pagination.
#
# This script provides functions for interacting with Readwise APIs:
# - Export API v2 (highlights)
# - Reader API (articles, RSS)
#
# Usage: Source this file in other scripts
#   source "$SCRIPT_DIR/readwise_client.sh"
#
# Required Environment:
#   READWISE_TOKEN: API access token from https://readwise.io/access_token
#
# Functions:
#   readwise_export_highlights <updated_after>
#   readwise_reader_list <location> <updated_after>
#   readwise_reader_categories
###############################################################################

# API endpoints
readonly READWISE_EXPORT_API="https://readwise.io/api/v2/export/"
readonly READWISE_READER_API="https://readwise.io/api/v3/list/"

# Rate limiting configuration
readonly RATE_LIMIT_DELAY=3  # seconds between requests
readonly MAX_RETRIES=3
readonly BACKOFF_MULTIPLIER=2

# Colors for logging
readonly RW_GREEN='\033[0;32m'
readonly RW_YELLOW='\033[1;33m'
readonly RW_RED='\033[0;31m'
readonly RW_NC='\033[0m'

rw_log_info() { echo -e "${RW_GREEN}[READWISE]${RW_NC} $*" >&2; }
rw_log_warn() { echo -e "${RW_YELLOW}[READWISE]${RW_NC} $*" >&2; }
rw_log_error() { echo -e "${RW_RED}[READWISE]${RW_NC} $*" >&2; }

# Check if READWISE_TOKEN is set
check_readwise_auth() {
    if [ -z "${READWISE_TOKEN:-}" ]; then
        rw_log_error "READWISE_TOKEN environment variable not set"
        rw_log_error "Get your token from: https://readwise.io/access_token"
        return 1
    fi
    return 0
}

# Make API request with rate limiting and retry logic
# Args: method, url, [data]
# Returns: JSON response to stdout
readwise_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local retry=0
    local delay=$RATE_LIMIT_DELAY

    check_readwise_auth || return 1

    while [ $retry -lt $MAX_RETRIES ]; do
        rw_log_info "API request: $method $url (attempt $((retry + 1))/$MAX_RETRIES)"

        local response
        local http_code

        if [ "$method" = "GET" ]; then
            response=$(curl -s -w "\n%{http_code}" \
                -H "Authorization: Token $READWISE_TOKEN" \
                -H "Content-Type: application/json" \
                "$url" 2>/dev/null)
        else
            response=$(curl -s -w "\n%{http_code}" \
                -X "$method" \
                -H "Authorization: Token $READWISE_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url" 2>/dev/null)
        fi

        # Extract HTTP code (last line)
        http_code=$(echo "$response" | tail -1)
        # Extract body (all but last line)
        local body=$(echo "$response" | sed '$d')

        case "$http_code" in
            200|201)
                echo "$body"
                return 0
                ;;
            204)
                # No content - valid response
                echo "{}"
                return 0
                ;;
            429)
                # Rate limited
                rw_log_warn "Rate limited, waiting ${delay}s before retry..."
                sleep "$delay"
                delay=$((delay * BACKOFF_MULTIPLIER))
                retry=$((retry + 1))
                ;;
            401)
                rw_log_error "Authentication failed. Check your READWISE_TOKEN."
                return 1
                ;;
            404)
                rw_log_error "Resource not found: $url"
                return 1
                ;;
            *)
                rw_log_error "API error: HTTP $http_code"
                rw_log_error "Response: $body"
                retry=$((retry + 1))
                sleep "$delay"
                ;;
        esac
    done

    rw_log_error "Max retries exceeded for $url"
    return 1
}

# Export highlights from Readwise
# Args: updated_after (ISO 8601 date, optional)
# Returns: JSON array of highlights
readwise_export_highlights() {
    local updated_after="${1:-}"
    local url="$READWISE_EXPORT_API"
    local all_results="[]"
    local page_cursor=""

    if [ -n "$updated_after" ]; then
        url="${url}?updatedAfter=${updated_after}"
    fi

    rw_log_info "Fetching highlights (updated after: ${updated_after:-all time})"

    # Paginate through all results
    while true; do
        local page_url="$url"
        if [ -n "$page_cursor" ]; then
            if [[ "$page_url" == *"?"* ]]; then
                page_url="${page_url}&pageCursor=${page_cursor}"
            else
                page_url="${page_url}?pageCursor=${page_cursor}"
            fi
        fi

        local response
        response=$(readwise_request "GET" "$page_url") || return 1

        # Extract results
        local results
        results=$(echo "$response" | jq -r '.results // []')

        # Merge with all_results
        all_results=$(echo "$all_results $results" | jq -s 'add')

        # Check for next page
        page_cursor=$(echo "$response" | jq -r '.nextPageCursor // empty')

        if [ -z "$page_cursor" ] || [ "$page_cursor" = "null" ]; then
            break
        fi

        rw_log_info "Fetching next page..."
        sleep "$RATE_LIMIT_DELAY"
    done

    local count
    count=$(echo "$all_results" | jq 'length')
    rw_log_info "Retrieved $count highlight(s)"

    echo "$all_results"
}

# List documents from Readwise Reader
# Args: location (feed, archive, new, later), updated_after (ISO date)
# Returns: JSON array of documents
readwise_reader_list() {
    local location="${1:-feed}"
    local updated_after="${2:-}"
    local url="$READWISE_READER_API"
    local all_results="[]"
    local page_cursor=""

    # Build query params
    local params="location=$location"
    if [ -n "$updated_after" ]; then
        params="${params}&updatedAfter=${updated_after}"
    fi
    url="${url}?${params}"

    rw_log_info "Fetching Reader documents (location: $location, updated after: ${updated_after:-all time})"

    # Paginate through all results
    while true; do
        local page_url="$url"
        if [ -n "$page_cursor" ]; then
            page_url="${page_url}&pageCursor=${page_cursor}"
        fi

        local response
        response=$(readwise_request "GET" "$page_url") || return 1

        # Extract results
        local results
        results=$(echo "$response" | jq -r '.results // []')

        # Merge with all_results
        all_results=$(echo "$all_results $results" | jq -s 'add')

        # Check for next page
        page_cursor=$(echo "$response" | jq -r '.nextPageCursor // empty')

        if [ -z "$page_cursor" ] || [ "$page_cursor" = "null" ]; then
            break
        fi

        rw_log_info "Fetching next page..."
        sleep "$RATE_LIMIT_DELAY"
    done

    local count
    count=$(echo "$all_results" | jq 'length')
    rw_log_info "Retrieved $count document(s)"

    echo "$all_results"
}

# Get unique categories/tags from Reader documents
# Args: JSON array of documents (via stdin)
# Returns: Newline-separated list of categories
readwise_extract_categories() {
    jq -r '.[].tags[]?.name // empty' | sort -u
}

# Format ISO 8601 date for yesterday
get_yesterday_iso() {
    date -v-1d +%Y-%m-%dT00:00:00Z 2>/dev/null || \
    date -d yesterday +%Y-%m-%dT00:00:00Z 2>/dev/null
}

# Format ISO 8601 date for N days ago
get_days_ago_iso() {
    local days="${1:-1}"
    date -v-${days}d +%Y-%m-%dT00:00:00Z 2>/dev/null || \
    date -d "$days days ago" +%Y-%m-%dT00:00:00Z 2>/dev/null
}
