#!/usr/bin/env bash

###############################################################################
# daily_runner.sh
#
# Main orchestrator for automated Daily Digest generation.
#
# This script coordinates the complete automation pipeline:
# 1. Discovery: Find modified files in vault
# 2. Synthesis: Generate Daily Digest (batch or single-pass)
# 3. Distribution: Create platform-specific drafts
# 4. Monitoring: Write status and update summary dashboard
#
# Usage: ./daily_runner.sh <vault_path> [date]
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date in YYYY-MM-DD format (optional, defaults to yesterday)
#
# Environment Variables:
#   SKIP_DRAFTS: Set to "true" to skip platform draft generation
#   SKIP_SUMMARY: Set to "true" to skip summary dashboard update
#
# Output: Complete Daily Digest with platform drafts and monitoring
# Exit codes:
#   0: Success (digest generated)
#   1: Invalid arguments
#   2: Discovery failed
#   3: Digest generation failed
#   4: Draft generation failed (non-fatal if SKIP_DRAFTS=true)
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
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

log_phase() {
    echo -e "${BLUE}[PHASE]${NC} $*" >&2
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $*" >&2
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

# Validate vault path
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Script paths
DISCOVER_SCRIPT="$SCRIPT_DIR/ingestion/discover_changes.sh"
GENERATE_DIGEST_SCRIPT="$SCRIPT_DIR/synthesis/generate_digest.sh"
GENERATE_BATCH_DIGEST_SCRIPT="$SCRIPT_DIR/synthesis/generate_batch_digest.sh"
GENERATE_DRAFTS_SCRIPT="$SCRIPT_DIR/distribution/generate_drafts.sh"
WRITE_STATUS_SCRIPT="$SCRIPT_DIR/monitoring/write_status.sh"
UPDATE_SUMMARY_SCRIPT="$SCRIPT_DIR/monitoring/update_summary.sh"

# Validate all scripts exist
for script in "$DISCOVER_SCRIPT" "$GENERATE_DIGEST_SCRIPT" "$GENERATE_BATCH_DIGEST_SCRIPT" \
              "$GENERATE_DRAFTS_SCRIPT" "$WRITE_STATUS_SCRIPT" "$UPDATE_SUMMARY_SCRIPT"; do
    if [ ! -x "$script" ]; then
        log_error "Required script not found or not executable: $script"
        exit 1
    fi
done

log_info "═══════════════════════════════════════════════════════════"
log_info "Daily Digest Automation - $DATE"
log_info "═══════════════════════════════════════════════════════════"
log_info "Vault: $VAULT_ROOT"
log_info "Date: $DATE"

# Track timing
START_TIME=$(date +%s)

# PHASE 1: DISCOVERY
log_phase "1/4 Discovery - Finding modified files"

DISCOVERY_OUTPUT=$("$DISCOVER_SCRIPT" "$VAULT_ROOT" 2>&1) || {
    log_error "File discovery failed"
    "$WRITE_STATUS_SCRIPT" failed "File discovery failed" "$DATE" 0 0
    exit 2
}

# Check if any files found
FILE_COUNT=$(echo "$DISCOVERY_OUTPUT" | grep -c "^/" || true)

if [ "$FILE_COUNT" -eq 0 ]; then
    log_warn "No modified files found in last 24 hours"
    "$WRITE_STATUS_SCRIPT" skipped "No modified files found in last 24 hours" "$DATE" $(($(date +%s) - START_TIME)) 0

    # Update summary even on skip
    if [ "${SKIP_SUMMARY:-false}" != "true" ]; then
        "$UPDATE_SUMMARY_SCRIPT" "$VAULT_ROOT" 2>&1 || log_warn "Summary update failed (non-fatal)"
    fi

    log_info "✅ Run complete (skipped - no changes)"
    exit 0
fi

log_info "Found $FILE_COUNT modified file(s)"

# PHASE 2: SYNTHESIS
log_phase "2/4 Synthesis - Generating Daily Digest"

# Check if batching is needed (detect BATCH_ markers)
if echo "$DISCOVERY_OUTPUT" | grep -q "^BATCH_"; then
    log_info "Multiple batches detected, using batch synthesis workflow"
    SYNTHESIS_SCRIPT="$GENERATE_BATCH_DIGEST_SCRIPT"
else
    log_info "Single batch detected, using direct synthesis"
    SYNTHESIS_SCRIPT="$GENERATE_DIGEST_SCRIPT"
fi

# Generate digest
echo "$DISCOVERY_OUTPUT" | "$SYNTHESIS_SCRIPT" "$VAULT_ROOT" "$DATE" 2>&1 || {
    log_error "Digest generation failed"
    "$WRITE_STATUS_SCRIPT" failed "Digest generation failed" "$DATE" $(($(date +%s) - START_TIME)) "$FILE_COUNT"
    exit 3
}

DIGEST_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"

if [ ! -f "$DIGEST_FILE" ]; then
    log_error "Digest file not created: $DIGEST_FILE"
    "$WRITE_STATUS_SCRIPT" failed "Digest file not created" "$DATE" $(($(date +%s) - START_TIME)) "$FILE_COUNT"
    exit 3
fi

DIGEST_SIZE=$(wc -l < "$DIGEST_FILE")
log_success "Daily Digest generated ($DIGEST_SIZE lines)"

# PHASE 3: DISTRIBUTION
log_phase "3/4 Distribution - Generating platform drafts"

if [ "${SKIP_DRAFTS:-false}" = "true" ]; then
    log_warn "Skipping platform draft generation (SKIP_DRAFTS=true)"
else
    "$GENERATE_DRAFTS_SCRIPT" "$VAULT_ROOT" "$DATE" 2>&1 || {
        log_warn "Platform draft generation failed (non-fatal)"
        # Continue execution - drafts are optional
    }
fi

# PHASE 4: MONITORING
log_phase "4/4 Monitoring - Updating status and summary"

# Calculate execution time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Write status
"$WRITE_STATUS_SCRIPT" success "Daily digest generated successfully" "$DATE" "$DURATION" "$FILE_COUNT"

# Update summary dashboard
if [ "${SKIP_SUMMARY:-false}" = "true" ]; then
    log_warn "Skipping summary dashboard update (SKIP_SUMMARY=true)"
else
    "$UPDATE_SUMMARY_SCRIPT" "$VAULT_ROOT" 2>&1 || log_warn "Summary update failed (non-fatal)"
fi

# Final summary
log_info "═══════════════════════════════════════════════════════════"
log_success "Automation Complete!"
log_info "═══════════════════════════════════════════════════════════"
log_info "Date: $DATE"
log_info "Files Processed: $FILE_COUNT"
log_info "Duration: ${DURATION}s"
log_info "Digest: $DIGEST_FILE"
log_info "Status: $VAULT_ROOT/.taskmaster/status/${DATE}_success.md"

exit 0
