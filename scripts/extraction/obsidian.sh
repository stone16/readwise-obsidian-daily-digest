#!/usr/bin/env bash

###############################################################################
# obsidian.sh
#
# Extract modified Obsidian vault notes to standardized intermediate format.
#
# This script:
# 1. Discovers modified markdown files in the vault (last 24 hours)
# 2. Reads each file's content
# 3. Outputs to standardized intermediate format at DailyDigest/YYYY-MM-DD/obsidian.md
#
# Usage: ./obsidian.sh [vault_path] [date]
#   vault_path: Absolute path to Obsidian vault (optional if VAULT_PATH set in .env)
#   date: Date string in YYYY-MM-DD format (optional, defaults to yesterday)
#
# Output: Creates DailyDigest/YYYY-MM-DD/obsidian.md in standardized format
# Exit codes:
#   0: Success (including no files found)
#   1: Invalid arguments or vault path doesn't exist
#   2: File discovery failed
#   3: Output file creation failed
###############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "$SCRIPT_DIR/../utils/format_intermediate.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[OBSIDIAN]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[OBSIDIAN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[OBSIDIAN]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[OBSIDIAN]${NC} $*" >&2; }

# Get project root for .env loading
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Parse arguments
VAULT_ROOT="${1:-}"
DATE="${2:-$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d 2>/dev/null)}"

# Use VAULT_PATH from environment if vault_path not provided
if [ -z "$VAULT_ROOT" ]; then
    if [ -n "${VAULT_PATH:-}" ]; then
        VAULT_ROOT="$VAULT_PATH"
    else
        log_error "Usage: $0 [vault_path] [date]"
        log_error "Either provide vault_path as argument or set VAULT_PATH in .env"
        exit 1
    fi
fi

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

log_info "Extracting Obsidian vault changes"
log_info "Vault: $VAULT_ROOT"
log_info "Date: $DATE"

# Create output directory
OUTPUT_DIR=$(ensure_daily_output_dir "$VAULT_ROOT" "$DATE")
OUTPUT_FILE="$OUTPUT_DIR/obsidian.md"

log_info "Output: $OUTPUT_FILE"

# Find modified files
# Exclusions: .obsidian/, .git/, DailyDigest/, .taskmaster/, .icloud placeholders
log_info "Discovering modified files..."

FILE_LIST=$(find "$VAULT_ROOT" \
    -path "$VAULT_ROOT/.obsidian" -prune -o \
    -path "$VAULT_ROOT/.git" -prune -o \
    -path "$VAULT_ROOT/DailyDigest" -prune -o \
    -path "$VAULT_ROOT/Drafts" -prune -o \
    -path "$VAULT_ROOT/.taskmaster" -prune -o \
    -type f -name "*.md" \
    ! -name "*.icloud" \
    -mtime -1 \
    -print 2>/dev/null | sort) || {
    log_error "File discovery failed"
    exit 2
}

# Count files
if [ -z "$FILE_LIST" ]; then
    FILE_COUNT=0
else
    FILE_COUNT=$(echo "$FILE_LIST" | grep -c "^" || echo "0")
fi

log_info "Found $FILE_COUNT modified file(s)"

# Create output file with header
{
    create_intermediate_header "obsidian" "" "$DATE" "$FILE_COUNT"

    echo "## Items"
    echo ""

    if [ "$FILE_COUNT" -eq 0 ]; then
        echo "_No vault changes detected in the last 24 hours._"
        echo ""
    else
        # Process each file
        while IFS= read -r file_path; do
            if [ -z "$file_path" ]; then
                continue
            fi

            # Extract filename without extension for title
            filename=$(basename "$file_path" .md)

            # Get relative path from vault root
            relative_path="${file_path#$VAULT_ROOT/}"

            # Extract tags from frontmatter if present
            tags=""
            if head -1 "$file_path" 2>/dev/null | grep -q "^---$"; then
                # Extract tags from YAML frontmatter
                tags=$(sed -n '/^---$/,/^---$/p' "$file_path" 2>/dev/null | grep "^tags:" | sed 's/^tags://' | tr -d '[]' | sed 's/,/, /g' | sed 's/^ *//')
            fi

            # Read file content (limit to reasonable size)
            content=$(cat "$file_path" 2>/dev/null | head -500)

            # Check for iCloud placeholder (double-check)
            if echo "$file_path" | grep -q "\.icloud$"; then
                log_warn "Skipping iCloud placeholder: $file_path"
                continue
            fi

            # Create item entry
            create_item "$filename" "[[${relative_path%.md}]]" "$tags" "$content"

            log_debug "Processed: $filename"

        done <<< "$FILE_LIST"
    fi

} > "$OUTPUT_FILE"

# Validate output
if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Failed to create output file: $OUTPUT_FILE"
    exit 3
fi

# Validate format
if ! validate_intermediate_file "$OUTPUT_FILE"; then
    log_error "Output file validation failed"
    exit 3
fi

OUTPUT_SIZE=$(wc -l < "$OUTPUT_FILE")
log_info "Extraction complete: $OUTPUT_FILE ($OUTPUT_SIZE lines)"

exit 0
