#!/usr/bin/env bash

###############################################################################
# consolidate.sh
#
# Consolidates intermediate files from multiple sources into a unified digest.
#
# This script:
# 1. Reads all intermediate files from DailyDigest/YYYY-MM-DD/
# 2. Merges content while preserving source attribution
# 3. Outputs a consolidated daily digest ready for synthesis
#
# Usage: ./consolidate.sh <vault_path> <date>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date in YYYY-MM-DD format (required)
#
# Output: Creates DailyDigest/YYYY-MM-DD/consolidated.md
# Exit codes:
#   0: Success
#   1: Invalid arguments
#   2: No intermediate files found
#   3: Consolidation failed
###############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../utils/format_intermediate.sh"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[CONSOLIDATE]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[CONSOLIDATE]${NC} $*" >&2; }
log_error() { echo -e "${RED}[CONSOLIDATE]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[CONSOLIDATE]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}[CONSOLIDATE]${NC} $*" >&2; }

# Validation
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <vault_path> <date>"
    exit 1
fi

VAULT_ROOT="$1"
DATE="$2"

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

DAILY_DIR="$VAULT_ROOT/DailyDigest/$DATE"
OUTPUT_FILE="$DAILY_DIR/consolidated.md"

if [ ! -d "$DAILY_DIR" ]; then
    log_error "Daily directory does not exist: $DAILY_DIR"
    exit 2
fi

log_info "Consolidating intermediate files"
log_info "Date: $DATE"
log_info "Directory: $DAILY_DIR"

# Find all intermediate markdown files (excluding consolidated.md and drafts/)
INTERMEDIATE_FILES=$(find "$DAILY_DIR" -maxdepth 1 -name "*.md" ! -name "consolidated.md" -type f 2>/dev/null | sort)

if [ -z "$INTERMEDIATE_FILES" ]; then
    log_warn "No intermediate files found in $DAILY_DIR"
    exit 2
fi

FILE_COUNT=$(echo "$INTERMEDIATE_FILES" | grep -c "^" || echo "0")
log_info "Found $FILE_COUNT intermediate file(s)"

# Track statistics
TOTAL_ITEMS=0
declare -A SOURCE_COUNTS

# Process and consolidate
{
    echo "---"
    echo "type: consolidated"
    echo "date: $DATE"
    echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---"
    echo ""
    echo "# Daily Digest - $DATE"
    echo ""
    echo "## Summary"
    echo ""
    echo "_This consolidated digest contains content from multiple sources._"
    echo ""

    # Process each intermediate file
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi

        filename=$(basename "$file" .md)
        log_debug "Processing: $filename"

        # Extract source from frontmatter
        source_name=$(get_frontmatter_value "$file" "source" 2>/dev/null || echo "$filename")
        category=$(get_frontmatter_value "$file" "category" 2>/dev/null || echo "")
        item_count=$(get_frontmatter_value "$file" "item_count" 2>/dev/null || echo "0")

        # Update statistics
        TOTAL_ITEMS=$((TOTAL_ITEMS + item_count))
        SOURCE_COUNTS["$source_name"]=$((${SOURCE_COUNTS["$source_name"]:-0} + item_count))

        # Create section header
        echo "---"
        echo ""
        if [ -n "$category" ]; then
            echo "## Source: ${source_name} - ${category}"
        else
            echo "## Source: ${source_name}"
        fi
        echo ""
        echo "_${item_count} item(s)_"
        echo ""

        # Extract items section (everything after "## Items")
        sed -n '/^## Items$/,$ p' "$file" | tail -n +2

    done <<< "$INTERMEDIATE_FILES"

    # Add footer with statistics
    echo ""
    echo "---"
    echo ""
    echo "## Consolidation Statistics"
    echo ""
    echo "- **Total Items**: $TOTAL_ITEMS"
    echo "- **Sources Processed**: $FILE_COUNT"
    echo "- **Generated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""

} > "$OUTPUT_FILE"

# Validate output
if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Failed to create consolidated file"
    exit 3
fi

OUTPUT_SIZE=$(wc -l < "$OUTPUT_FILE")
log_info "Consolidation complete: $OUTPUT_FILE ($OUTPUT_SIZE lines)"
log_info "Total items consolidated: $TOTAL_ITEMS"

exit 0
