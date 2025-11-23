#!/usr/bin/env bash

###############################################################################
# update_summary.sh
#
# Generate aggregated summary dashboard of automation runs.
#
# This script:
# 1. Scans .taskmaster/status/ for recent status files
# 2. Parses frontmatter to extract run metadata
# 3. Generates summary table with last 7 runs
# 4. Calculates success rate percentage
# 5. Provides quick links to latest and failed runs
#
# Usage: ./update_summary.sh <vault_path>
#   vault_path: Absolute path to Obsidian vault (required)
#
# Output: Creates/updates .taskmaster/status/summary.md
# Exit codes:
#   0: Success
#   1: Invalid arguments or no status files found
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
    log_error "Usage: $0 <vault_path>"
    log_error "Example: $0 /path/to/vault"
    exit 1
fi

VAULT_ROOT="$1"

# Validate vault path
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

STATUS_DIR="$VAULT_ROOT/.taskmaster/status"

# Check if status directory exists
if [ ! -d "$STATUS_DIR" ]; then
    log_error "Status directory not found: $STATUS_DIR"
    log_error "Run digest generation first to create status files"
    exit 1
fi

SUMMARY_FILE="$STATUS_DIR/summary.md"

log_info "Generating summary dashboard for: $VAULT_ROOT"

# Find all status files (excluding summary.md and latest_run.md symlink)
STATUS_FILES=$(find "$STATUS_DIR" -maxdepth 1 -type f -name "*_*.md" ! -name "summary.md" | sort -r | head -7)

if [ -z "$STATUS_FILES" ]; then
    log_error "No status files found in $STATUS_DIR"
    exit 1
fi

# Count files
FILE_COUNT=$(echo "$STATUS_FILES" | wc -l | tr -d ' ')
log_info "Found $FILE_COUNT recent status file(s)"

# Initialize counters
TOTAL_RUNS=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Temporary file for table rows
TEMP_TABLE=$(mktemp)

# Parse each status file
while IFS= read -r status_file; do
    if [ ! -f "$status_file" ]; then
        continue
    fi

    TOTAL_RUNS=$((TOTAL_RUNS + 1))

    # Extract frontmatter fields
    STATUS=$(grep "^status:" "$status_file" | head -1 | sed 's/status: *//')
    DATE=$(grep "^date:" "$status_file" | head -1 | sed 's/date: *//')
    TIMESTAMP=$(grep "^timestamp:" "$status_file" | head -1 | sed 's/timestamp: *//')
    DURATION=$(grep "^duration_seconds:" "$status_file" | head -1 | sed 's/duration_seconds: *//')
    FILES_PROCESSED=$(grep "^files_processed:" "$status_file" | head -1 | sed 's/files_processed: *//')

    # Count status types
    case "$STATUS" in
        success)
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            STATUS_EMOJI="✅"
            ;;
        failed)
            FAILED_COUNT=$((FAILED_COUNT + 1))
            STATUS_EMOJI="❌"
            ;;
        skipped)
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            STATUS_EMOJI="⏭️"
            ;;
        *)
            STATUS_EMOJI="❓"
            ;;
    esac

    # Generate WikiLink to status file
    STATUS_BASENAME=$(basename "$status_file" .md)
    STATUS_LINK="[[.taskmaster/status/${STATUS_BASENAME}\|${DATE}]]"

    # Format duration
    if [ "$DURATION" = "N/A" ]; then
        DURATION_DISPLAY="N/A"
    else
        DURATION_DISPLAY="${DURATION}s"
    fi

    # Write table row
    echo "| $STATUS_EMOJI | $STATUS_LINK | $TIMESTAMP | $DURATION_DISPLAY | $FILES_PROCESSED |" >> "$TEMP_TABLE"

done <<< "$STATUS_FILES"

# Calculate success rate
if [ "$TOTAL_RUNS" -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT / $TOTAL_RUNS) * 100}")
else
    SUCCESS_RATE="0.0"
fi

log_info "Statistics: $SUCCESS_COUNT success, $FAILED_COUNT failed, $SKIPPED_COUNT skipped"
log_info "Success rate: ${SUCCESS_RATE}%"

# Generate summary.md
cat > "$SUMMARY_FILE" <<EOF
---
type: summary
generated: $(date +"%Y-%m-%d %H:%M:%S")
total_runs: $TOTAL_RUNS
success_count: $SUCCESS_COUNT
failed_count: $FAILED_COUNT
skipped_count: $SKIPPED_COUNT
success_rate: ${SUCCESS_RATE}%
---

# Automation Summary Dashboard

**Last Updated**: $(date +"%Y-%m-%d %H:%M:%S")

## 📊 Performance Metrics

| Metric | Value |
|--------|-------|
| **Total Runs** | $TOTAL_RUNS |
| **✅ Successes** | $SUCCESS_COUNT |
| **❌ Failures** | $FAILED_COUNT |
| **⏭️ Skipped** | $SKIPPED_COUNT |
| **Success Rate** | ${SUCCESS_RATE}% |

## 📋 Recent Runs (Last 7)

| Status | Date | Timestamp | Duration | Files |
|--------|------|-----------|----------|-------|
EOF

# Append table rows
cat "$TEMP_TABLE" >> "$SUMMARY_FILE"

# Add quick links section
cat >> "$SUMMARY_FILE" <<EOF

## 🔗 Quick Links

- **Latest Run**: [[.taskmaster/status/latest_run|Latest Run Status]]
EOF

# Find and link failed runs
FAILED_FILES=$(find "$STATUS_DIR" -maxdepth 1 -type f -name "*_failed.md" ! -name "summary.md" | sort -r | head -3)

if [ -n "$FAILED_FILES" ]; then
    cat >> "$SUMMARY_FILE" <<EOF
- **Recent Failures**:
EOF

    while IFS= read -r failed_file; do
        if [ ! -f "$failed_file" ]; then
            continue
        fi
        FAILED_BASENAME=$(basename "$failed_file" .md)
        FAILED_DATE=$(echo "$FAILED_BASENAME" | cut -d'_' -f1)
        echo "  - [[.taskmaster/status/${FAILED_BASENAME}|${FAILED_DATE}]]" >> "$SUMMARY_FILE"
    done <<< "$FAILED_FILES"
fi

# Add notes section
cat >> "$SUMMARY_FILE" <<EOF

## 📝 Notes

- Summary automatically updated after each automation run
- Shows last 7 runs for quick overview
- Click any date to view detailed run status
- Success rate calculated from displayed runs only

---

*Generated by automation monitoring system*
EOF

# Cleanup
rm -f "$TEMP_TABLE"

log_info "✅ Summary dashboard created: $SUMMARY_FILE"
log_info "File size: $(ls -lh "$SUMMARY_FILE" | awk '{print $5}')"

exit 0
