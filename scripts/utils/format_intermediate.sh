#!/usr/bin/env bash

###############################################################################
# format_intermediate.sh
#
# Utility functions for creating and validating standardized intermediate files.
# These functions ensure consistent format across all extraction sources.
#
# Usage: Source this file in other scripts
#   source "$SCRIPT_DIR/utils/format_intermediate.sh"
#
# Functions:
#   create_intermediate_header <source> <category> <date> <item_count>
#   create_item <title> <source_link> <tags> <content>
#   validate_intermediate_file <file_path>
###############################################################################

# Create YAML frontmatter for intermediate file
# Args: source, category (optional), date, item_count
create_intermediate_header() {
    local source="$1"
    local category="${2:-}"
    local date="$3"
    local item_count="$4"

    echo "---"
    echo "source: $source"
    if [ -n "$category" ]; then
        echo "category: $category"
    fi
    echo "date: $date"
    echo "item_count: $item_count"
    echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---"
    echo ""
}

# Create a single item entry in standardized format
# Args: title, source_link, tags, content
create_item() {
    local title="$1"
    local source_link="$2"
    local tags="$3"
    local content="$4"

    echo "### Item: $title"
    echo "**Source**: $source_link"
    if [ -n "$tags" ]; then
        echo "**Tags**: $tags"
    fi
    echo "**Content**:"
    echo "$content"
    echo ""
    echo "---"
    echo ""
}

# Validate intermediate file format
# Returns 0 if valid, 1 if invalid with error message
validate_intermediate_file() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "ERROR: File does not exist: $file_path" >&2
        return 1
    fi

    # Check for YAML frontmatter
    if ! head -1 "$file_path" | grep -q "^---$"; then
        echo "ERROR: Missing YAML frontmatter start" >&2
        return 1
    fi

    # Check for required fields
    if ! grep -q "^source:" "$file_path"; then
        echo "ERROR: Missing 'source' field in frontmatter" >&2
        return 1
    fi

    if ! grep -q "^date:" "$file_path"; then
        echo "ERROR: Missing 'date' field in frontmatter" >&2
        return 1
    fi

    if ! grep -q "^item_count:" "$file_path"; then
        echo "ERROR: Missing 'item_count' field in frontmatter" >&2
        return 1
    fi

    echo "OK: Valid intermediate file format" >&2
    return 0
}

# Extract frontmatter value
# Args: file_path, field_name
# Note: Uses sed instead of cut to preserve values containing colons (e.g., timestamps)
get_frontmatter_value() {
    local file_path="$1"
    local field="$2"

    sed -n '/^---$/,/^---$/p' "$file_path" | \
        grep "^${field}:" | \
        sed "s/^${field}:[[:space:]]*//" | \
        head -1
}

# Count items in intermediate file
count_items() {
    local file_path="$1"
    grep -c "^### Item:" "$file_path" 2>/dev/null || echo "0"
}

# Ensure output directory exists with proper structure
ensure_daily_output_dir() {
    local vault_root="$1"
    local date="$2"

    local daily_dir="$vault_root/DailyDigest/$date"
    local drafts_dir="$daily_dir/drafts"

    mkdir -p "$daily_dir"
    mkdir -p "$drafts_dir"

    echo "$daily_dir"
}
