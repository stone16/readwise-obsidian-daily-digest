#!/usr/bin/env bash

###############################################################################
# write_status.sh
#
# Write automation run status to markdown file for Obsidian visibility.
#
# This script creates status files in .taskmaster/status/ directory with:
# - Run metadata (date, duration, status)
# - Execution log summary
# - WikiLinks to generated outputs
# - Latest run symlink
#
# Usage: ./write_status.sh <status> <message> [date] [duration] [files_processed]
#   status: success | failed | skipped (required)
#   message: Human-readable status message (required)
#   date: Date in YYYY-MM-DD format (optional, defaults to today)
#   duration: Runtime in seconds (optional)
#   files_processed: Number of files processed (optional)
#
# Output: Creates status file and updates latest_run.md symlink
# Exit codes:
#   0: Success
#   1: Invalid arguments
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Validation
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <status> <message> [date] [duration] [files_processed]"
    log_error "  status: success | failed | skipped"
    log_error "  message: Human-readable status message"
    log_error "Example: $0 success 'Daily digest generated' 2024-11-23 42 12"
    exit 1
fi

STATUS="$1"
MESSAGE="$2"
DATE="${3:-$(date +%Y-%m-%d)}"
DURATION="${4:-}"
FILES_PROCESSED="${5:-}"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Validate status
if [[ ! "$STATUS" =~ ^(success|failed|skipped)$ ]]; then
    log_error "Invalid status: $STATUS. Must be: success, failed, or skipped"
    exit 1
fi

# Determine vault root (assuming script is in project/scripts/monitoring/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VAULT_ROOT="$PROJECT_ROOT/test_vault"  # Default to test vault

# Override with production vault if configured
if [ -f "$PROJECT_ROOT/.claude/settings.json" ]; then
    PRODUCTION_VAULT=$(grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_ROOT/.claude/settings.json" | grep -v "test_vault" | head -1 | sed 's/"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    if [ -n "$PRODUCTION_VAULT" ] && [ -d "$PRODUCTION_VAULT" ]; then
        VAULT_ROOT="$PRODUCTION_VAULT"
    fi
fi

STATUS_DIR="$VAULT_ROOT/.taskmaster/status"
mkdir -p "$STATUS_DIR"

# Status emoji
case "$STATUS" in
    success) STATUS_EMOJI="✅" ;;
    failed)  STATUS_EMOJI="❌" ;;
    skipped) STATUS_EMOJI="⏭️" ;;
esac

# Create status filename
STATUS_FILE="$STATUS_DIR/${DATE}_${STATUS}.md"

log_info "Writing status to: $STATUS_FILE"

# Generate status file content
cat > "$STATUS_FILE" <<EOF
---
status: $STATUS
date: $DATE
timestamp: $TIMESTAMP
duration_seconds: ${DURATION:-N/A}
files_processed: ${FILES_PROCESSED:-N/A}
---

# Run Status: $DATE

**Status**: $STATUS_EMOJI $STATUS
**Time**: $TIMESTAMP
**Duration**: ${DURATION:-N/A} seconds
**Files Processed**: ${FILES_PROCESSED:-N/A}

## Message

$MESSAGE

## Generated Outputs

EOF

# Add links to generated outputs (if they exist)
DIGEST_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"
if [ -f "$DIGEST_FILE" ]; then
    echo "- [[DailyDigest/Daily Digest $DATE|Daily Digest]]" >> "$STATUS_FILE"
fi

DRAFTS_DIR="$VAULT_ROOT/DailyDigest/Drafts/$DATE"
if [ -d "$DRAFTS_DIR" ]; then
    echo "" >> "$STATUS_FILE"
    echo "### Platform Drafts" >> "$STATUS_FILE"
    for draft in "$DRAFTS_DIR"/*_draft.md; do
        if [ -f "$draft" ]; then
            DRAFT_NAME=$(basename "$draft" .md)
            PLATFORM=$(echo "$DRAFT_NAME" | sed 's/_draft$//')
            echo "- [[DailyDigest/Drafts/$DATE/${DRAFT_NAME}|${PLATFORM^} Draft]]" >> "$STATUS_FILE"
        fi
    done
fi

# Add execution log summary (last 20 lines from most recent log if available)
LOG_FILE="$VAULT_ROOT/.taskmaster/status/digest_generation.log"
if [ -f "$LOG_FILE" ]; then
    cat >> "$STATUS_FILE" <<EOF

## Execution Log (Last 20 Lines)

\`\`\`
$(tail -20 "$LOG_FILE")
\`\`\`
EOF
fi

# Update latest_run.md symlink
LATEST_LINK="$STATUS_DIR/latest_run.md"
ln -sf "$(basename "$STATUS_FILE")" "$LATEST_LINK"

log_info "✅ Status file created: $STATUS_FILE"
log_info "Updated symlink: latest_run.md → $(basename "$STATUS_FILE")"

# Output file size
FILE_SIZE=$(ls -lh "$STATUS_FILE" | awk '{print $5}')
log_info "File size: $FILE_SIZE"

exit 0
