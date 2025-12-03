#!/usr/bin/env bash

###############################################################################
# readwise.sh
#
# Extract Readwise highlights and Reader content to standardized format.
#
# This script:
# 1. Fetches highlights from Readwise Export API
# 2. Fetches RSS/articles from Readwise Reader API
# 3. Outputs highlights to: DailyDigest/YYYY-MM-DD/highlights.md
# 4. Outputs RSS by category to: DailyDigest/YYYY-MM-DD/{category}.md
#
# Usage: ./readwise.sh [vault_path] [date] [--highlights-only] [--reader-only]
#   vault_path: Absolute path to Obsidian vault (optional if VAULT_PATH set in .env)
#   date: Date string in YYYY-MM-DD format (optional, defaults to yesterday)
#
# Required Environment:
#   READWISE_TOKEN: API access token
#
# Output: Creates intermediate files in DailyDigest/YYYY-MM-DD/
# Exit codes:
#   0: Success
#   1: Invalid arguments or missing token
#   2: API request failed
#   3: Output file creation failed
###############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Source dependencies
source "$SCRIPT_DIR/../utils/format_intermediate.sh"
source "$SCRIPT_DIR/readwise_client.sh"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[READWISE-EXT]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[READWISE-EXT]${NC} $*" >&2; }
log_error() { echo -e "${RED}[READWISE-EXT]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[READWISE-EXT]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}[READWISE-EXT]${NC} $*" >&2; }

# Parse arguments
VAULT_ROOT=""
DATE=""
HIGHLIGHTS_ONLY=false
READER_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --highlights-only)
            HIGHLIGHTS_ONLY=true
            shift
            ;;
        --reader-only)
            READER_ONLY=true
            shift
            ;;
        *)
            if [ -z "$VAULT_ROOT" ]; then
                VAULT_ROOT="$1"
            elif [ -z "$DATE" ]; then
                DATE="$1"
            fi
            shift
            ;;
    esac
done

# Defaults
DATE="${DATE:-$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d 2>/dev/null)}"

# Use VAULT_PATH from environment if vault_path not provided
if [ -z "$VAULT_ROOT" ]; then
    if [ -n "${VAULT_PATH:-}" ]; then
        VAULT_ROOT="$VAULT_PATH"
    else
        log_error "Usage: $0 [vault_path] [date] [--highlights-only] [--reader-only]"
        log_error "Either provide vault_path as argument or set VAULT_PATH in .env"
        exit 1
    fi
fi

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

# Check for jq (required for JSON processing)
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Install with: brew install jq"
    exit 1
fi

# Check authentication
check_readwise_auth || exit 1

log_info "Extracting Readwise content"
log_info "Vault: $VAULT_ROOT"
log_info "Date: $DATE"

# Create output directory
OUTPUT_DIR=$(ensure_daily_output_dir "$VAULT_ROOT" "$DATE")
log_info "Output directory: $OUTPUT_DIR"

# Calculate updated_after timestamp (start of the target date)
UPDATED_AFTER="${DATE}T00:00:00Z"

###############################################################################
# HIGHLIGHTS EXTRACTION
###############################################################################

extract_highlights() {
    log_section "═══ Extracting Highlights ═══"

    local output_file="$OUTPUT_DIR/highlights.md"

    # Fetch highlights
    local highlights
    highlights=$(readwise_export_highlights "$UPDATED_AFTER") || {
        log_error "Failed to fetch highlights"
        return 1
    }

    # Count highlights
    local count
    count=$(echo "$highlights" | jq 'length')
    log_info "Processing $count highlight source(s)"

    # Generate output file
    {
        create_intermediate_header "readwise-highlights" "" "$DATE" "$count"

        echo "## Items"
        echo ""

        if [ "$count" -eq 0 ]; then
            echo "_No new highlights found._"
            echo ""
        else
            # Process each book/article with highlights
            echo "$highlights" | jq -c '.[]' | while read -r item; do
                local title author category source_url
                title=$(echo "$item" | jq -r '.title // "Untitled"')
                author=$(echo "$item" | jq -r '.author // "Unknown"')
                category=$(echo "$item" | jq -r '.category // "other"')
                source_url=$(echo "$item" | jq -r '.source_url // ""')

                # Get all highlights for this item
                local item_highlights
                item_highlights=$(echo "$item" | jq -r '.highlights[] | "- " + .text' 2>/dev/null || echo "")

                if [ -n "$item_highlights" ]; then
                    echo "### Item: $title"
                    echo "**Source**: $source_url"
                    echo "**Tags**: $category, by $author"
                    echo "**Content**:"
                    echo ""
                    echo "$item_highlights"
                    echo ""
                    echo "---"
                    echo ""
                fi
            done
        fi

    } > "$output_file"

    if validate_intermediate_file "$output_file"; then
        local lines
        lines=$(wc -l < "$output_file")
        log_info "Highlights saved: $output_file ($lines lines)"
    else
        log_error "Highlights file validation failed"
        return 1
    fi
}

###############################################################################
# READER (RSS/ARTICLES) EXTRACTION
###############################################################################

extract_reader() {
    log_section "═══ Extracting Reader Content ═══"

    # Fetch all Reader documents from feed
    local documents
    documents=$(readwise_reader_list "feed" "$UPDATED_AFTER") || {
        log_error "Failed to fetch Reader documents"
        return 1
    }

    # Also fetch from 'new' and 'later' locations
    local new_docs later_docs
    new_docs=$(readwise_reader_list "new" "$UPDATED_AFTER" 2>/dev/null) || new_docs="[]"
    later_docs=$(readwise_reader_list "later" "$UPDATED_AFTER" 2>/dev/null) || later_docs="[]"

    # Merge all documents
    documents=$(echo "$documents $new_docs $later_docs" | jq -s 'add | unique_by(.id)')

    local total_count
    total_count=$(echo "$documents" | jq 'length')
    log_info "Total Reader documents: $total_count"

    if [ "$total_count" -eq 0 ]; then
        log_info "No Reader content to process"
        return 0
    fi

    # Extract unique categories
    local categories
    categories=$(echo "$documents" | jq -r '.[].tags[]?.name // empty' | sort -u)

    # Also include documents by category field
    local doc_categories
    doc_categories=$(echo "$documents" | jq -r '.[].category // "uncategorized"' | sort -u)

    # Combine categories
    categories=$(echo -e "$categories\n$doc_categories" | sort -u | grep -v "^$" || echo "uncategorized")

    log_info "Categories found: $(echo "$categories" | tr '\n' ', ' | sed 's/,$//')"

    # Process each category
    while IFS= read -r category; do
        if [ -z "$category" ]; then
            continue
        fi

        log_debug "Processing category: $category"

        # Sanitize category name for filename (remove special chars, lowercase)
        local safe_category
        safe_category=$(echo "$category" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

        if [ -z "$safe_category" ]; then
            safe_category="uncategorized"
        fi

        local output_file="$OUTPUT_DIR/${safe_category}.md"

        # Filter documents for this category
        local category_docs
        category_docs=$(echo "$documents" | jq --arg cat "$category" '[.[] | select(.category == $cat or (.tags[]?.name == $cat))]')

        local cat_count
        cat_count=$(echo "$category_docs" | jq 'length')

        if [ "$cat_count" -eq 0 ]; then
            log_debug "No documents in category: $category"
            continue
        fi

        log_info "Category '$category': $cat_count documents"

        # Generate output file
        {
            create_intermediate_header "readwise-reader" "$category" "$DATE" "$cat_count"

            echo "## Items"
            echo ""

            echo "$category_docs" | jq -c '.[]' | while read -r doc; do
                local title author url summary content reading_progress

                title=$(echo "$doc" | jq -r '.title // "Untitled"')
                author=$(echo "$doc" | jq -r '.author // ""')
                url=$(echo "$doc" | jq -r '.source_url // .url // ""')
                summary=$(echo "$doc" | jq -r '.summary // ""')
                content=$(echo "$doc" | jq -r '.content // .html // ""' | head -c 2000)
                reading_progress=$(echo "$doc" | jq -r '.reading_progress // 0')

                # Get tags as comma-separated
                local tags
                tags=$(echo "$doc" | jq -r '[.tags[]?.name] | join(", ")' 2>/dev/null || echo "")

                echo "### Item: $title"
                echo "**Source**: $url"
                if [ -n "$tags" ]; then
                    echo "**Tags**: $tags"
                fi
                if [ -n "$author" ]; then
                    echo "**Author**: $author"
                fi
                echo "**Reading Progress**: ${reading_progress}%"
                echo "**Content**:"
                echo ""
                if [ -n "$summary" ]; then
                    echo "**Summary**: $summary"
                    echo ""
                fi
                # Include truncated content if available
                if [ -n "$content" ] && [ "$content" != "null" ]; then
                    # Strip HTML tags for cleaner output
                    echo "$content" | sed 's/<[^>]*>//g' | head -50
                fi
                echo ""
                echo "---"
                echo ""
            done

        } > "$output_file"

        if validate_intermediate_file "$output_file"; then
            local lines
            lines=$(wc -l < "$output_file")
            log_info "Category '$category' saved: $output_file ($lines lines)"
        else
            log_warn "Category '$category' file validation failed"
        fi

    done <<< "$categories"
}

###############################################################################
# MAIN EXECUTION
###############################################################################

ERRORS=0

if [ "$READER_ONLY" != "true" ]; then
    extract_highlights || ERRORS=$((ERRORS + 1))
fi

if [ "$HIGHLIGHTS_ONLY" != "true" ]; then
    extract_reader || ERRORS=$((ERRORS + 1))
fi

# Summary
log_section "═══ Extraction Complete ═══"
log_info "Output directory: $OUTPUT_DIR"
log_info "Files created:"
ls -la "$OUTPUT_DIR"/*.md 2>/dev/null | awk '{print "  - " $NF}' >&2 || log_warn "No output files created"

if [ $ERRORS -gt 0 ]; then
    log_warn "Completed with $ERRORS error(s)"
    exit 2
fi

exit 0
