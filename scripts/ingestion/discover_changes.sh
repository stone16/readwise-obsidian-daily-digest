#!/usr/bin/env bash

###############################################################################
# discover_changes.sh
#
# Safely discover modified Markdown files in an Obsidian vault.
#
# Usage: ./discover_changes.sh <vault_path> <date>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (optional, defaults to yesterday)
#
# Output: List of modified .md files (one per line) to stdout
# Exit codes:
#   0: Success (files found or no files found gracefully)
#   1: Invalid arguments or vault path doesn't exist
#   2: Find command failed
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Validation
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <vault_path> [date]"
    log_error "Example: $0 /path/to/vault 2024-11-23"
    exit 1
fi

VAULT_ROOT="$1"
# Default to yesterday to avoid timezone issues and ensure complete days
DATE="${2:-$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d 2>/dev/null)}"

# Validate vault path exists
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

log_info "Discovering changes in: $VAULT_ROOT"
log_info "Target date: $DATE"

# Find modified files
# - Exclude .obsidian/ (Obsidian config)
# - Exclude .git/ (version control)
# - Exclude DailyDigest/ (output directory)
# - Exclude .taskmaster/ (monitoring)
# - Only .md files
# - Exclude .icloud placeholders (iCloud sync safety)
# - Modified in last 24 hours (-mtime -1)

log_info "Running file discovery..."

FILE_LIST=$(find "$VAULT_ROOT" \
    -path "$VAULT_ROOT/.obsidian" -prune -o \
    -path "$VAULT_ROOT/.git" -prune -o \
    -path "$VAULT_ROOT/DailyDigest" -prune -o \
    -path "$VAULT_ROOT/Drafts" -prune -o \
    -path "$VAULT_ROOT/.taskmaster" -prune -o \
    -type f -name "*.md" \
    ! -name "*.icloud" \
    -mtime -1 \
    -print 2>/dev/null) || {
    log_error "Find command failed"
    exit 2
}

# Count files
FILE_COUNT=$(echo "$FILE_LIST" | grep -c "^" || echo "0")

if [ "$FILE_COUNT" -eq 0 ]; then
    log_info "No changes detected in the last 24 hours"
    exit 0
fi

log_info "Found $FILE_COUNT modified file(s)"

# Chunking strategy: batch size of 8 for >10 files
readonly BATCH_SIZE=8
readonly BATCH_THRESHOLD=10

if [ "$FILE_COUNT" -le "$BATCH_THRESHOLD" ]; then
    # Single-pass processing
    log_info "File count within threshold ($FILE_COUNT <= $BATCH_THRESHOLD), single-pass mode"
    echo "$FILE_LIST" | sort
else
    # Batch processing required
    log_warn "File count exceeds threshold ($FILE_COUNT > $BATCH_THRESHOLD), batching into groups of $BATCH_SIZE"

    # Sort files first for consistent batching
    SORTED_FILES=$(echo "$FILE_LIST" | sort)

    # Calculate number of batches
    NUM_BATCHES=$(( (FILE_COUNT + BATCH_SIZE - 1) / BATCH_SIZE ))
    log_info "Splitting into $NUM_BATCHES batch(es)"

    # Generate batches
    BATCH_NUM=1
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        # Add file to current batch
        if [ -z "${CURRENT_BATCH:-}" ]; then
            CURRENT_BATCH="$line"
            BATCH_COUNT=1
        else
            CURRENT_BATCH="$CURRENT_BATCH"$'\n'"$line"
            BATCH_COUNT=$((BATCH_COUNT + 1))
        fi

        # Output batch when size reached or end of list
        if [ "$BATCH_COUNT" -eq "$BATCH_SIZE" ]; then
            echo "BATCH_$BATCH_NUM: $CURRENT_BATCH"
            log_info "Batch $BATCH_NUM: $BATCH_COUNT files"
            BATCH_NUM=$((BATCH_NUM + 1))
            CURRENT_BATCH=""
            BATCH_COUNT=0
        fi
    done <<< "$SORTED_FILES"

    # Output remaining files as final batch
    if [ -n "${CURRENT_BATCH:-}" ]; then
        echo "BATCH_$BATCH_NUM: $CURRENT_BATCH"
        log_info "Batch $BATCH_NUM (final): $BATCH_COUNT files"
    fi
fi

# Log summary to stderr for visibility
log_info "Discovery complete: $FILE_COUNT files"

exit 0
