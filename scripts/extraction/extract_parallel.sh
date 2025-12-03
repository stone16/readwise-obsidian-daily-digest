#!/usr/bin/env bash

###############################################################################
# extract_parallel.sh
#
# Orchestrates parallel extraction from multiple sources using subprocesses.
#
# This script:
# 1. Spawns extraction processes in parallel for each configured source
# 2. Waits for all extractors to complete
# 3. Reports results and timing
#
# Usage: ./extract_parallel.sh [vault_path] [date] [--sources <source1,source2,...>]
#   vault_path: Absolute path to Obsidian vault (optional if VAULT_PATH set in .env)
#   date: Date in YYYY-MM-DD format (optional, defaults to yesterday)
#   --sources: Comma-separated list of sources to extract (optional)
#              Available: obsidian,readwise,readwise-highlights,readwise-reader
#              Default: obsidian,readwise
#
# Output: Creates intermediate files in DailyDigest/YYYY-MM-DD/
# Exit codes:
#   0: All extractions succeeded
#   1: Invalid arguments
#   2: Some extractions failed
###############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[PARALLEL]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[PARALLEL]${NC} $*" >&2; }
log_error() { echo -e "${RED}[PARALLEL]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[PARALLEL]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}[PARALLEL]${NC} $*" >&2; }

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Parse arguments
VAULT_ROOT=""
DATE=""
SOURCES="obsidian,readwise"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sources)
            SOURCES="$2"
            shift 2
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
        log_error "Usage: $0 [vault_path] [date] [--sources <source1,source2,...>]"
        log_error "Either provide vault_path as argument or set VAULT_PATH in .env"
        exit 1
    fi
fi

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

log_section "═══════════════════════════════════════════════════════════"
log_section "Parallel Extraction - $DATE"
log_section "═══════════════════════════════════════════════════════════"
log_info "Vault: $VAULT_ROOT"
log_info "Date: $DATE"
log_info "Sources: $SOURCES"

# Create output directory
DAILY_DIR="$VAULT_ROOT/DailyDigest/$DATE"
mkdir -p "$DAILY_DIR/drafts"

# Extractor scripts
OBSIDIAN_EXTRACTOR="$SCRIPT_DIR/obsidian.sh"
READWISE_EXTRACTOR="$SCRIPT_DIR/readwise.sh"

# Track timing
START_TIME=$(date +%s)

# Arrays for job management
declare -a PIDS=()
declare -a JOB_NAMES=()
declare -a LOG_FILES=()

# Start extraction jobs based on sources
IFS=',' read -ra SOURCE_LIST <<< "$SOURCES"

for source in "${SOURCE_LIST[@]}"; do
    source=$(echo "$source" | xargs)  # Trim whitespace

    case "$source" in
        obsidian)
            if [ -x "$OBSIDIAN_EXTRACTOR" ]; then
                log_info "Starting Obsidian extraction..."
                LOG_FILE="$DAILY_DIR/.obsidian_extract.log"
                "$OBSIDIAN_EXTRACTOR" "$VAULT_ROOT" "$DATE" > "$LOG_FILE" 2>&1 &
                PIDS+=($!)
                JOB_NAMES+=("obsidian")
                LOG_FILES+=("$LOG_FILE")
            else
                log_warn "Obsidian extractor not found or not executable: $OBSIDIAN_EXTRACTOR"
            fi
            ;;
        readwise)
            if [ -x "$READWISE_EXTRACTOR" ]; then
                log_info "Starting Readwise extraction (highlights + reader)..."
                LOG_FILE="$DAILY_DIR/.readwise_extract.log"
                "$READWISE_EXTRACTOR" "$VAULT_ROOT" "$DATE" > "$LOG_FILE" 2>&1 &
                PIDS+=($!)
                JOB_NAMES+=("readwise")
                LOG_FILES+=("$LOG_FILE")
            else
                log_warn "Readwise extractor not found or not executable: $READWISE_EXTRACTOR"
            fi
            ;;
        readwise-highlights)
            if [ -x "$READWISE_EXTRACTOR" ]; then
                log_info "Starting Readwise highlights extraction..."
                LOG_FILE="$DAILY_DIR/.readwise_highlights.log"
                "$READWISE_EXTRACTOR" "$VAULT_ROOT" "$DATE" --highlights-only > "$LOG_FILE" 2>&1 &
                PIDS+=($!)
                JOB_NAMES+=("readwise-highlights")
                LOG_FILES+=("$LOG_FILE")
            else
                log_warn "Readwise extractor not found or not executable: $READWISE_EXTRACTOR"
            fi
            ;;
        readwise-reader)
            if [ -x "$READWISE_EXTRACTOR" ]; then
                log_info "Starting Readwise Reader extraction..."
                LOG_FILE="$DAILY_DIR/.readwise_reader.log"
                "$READWISE_EXTRACTOR" "$VAULT_ROOT" "$DATE" --reader-only > "$LOG_FILE" 2>&1 &
                PIDS+=($!)
                JOB_NAMES+=("readwise-reader")
                LOG_FILES+=("$LOG_FILE")
            else
                log_warn "Readwise extractor not found or not executable: $READWISE_EXTRACTOR"
            fi
            ;;
        *)
            log_warn "Unknown source: $source"
            ;;
    esac
done

# Check if any jobs were started
if [ ${#PIDS[@]} -eq 0 ]; then
    log_error "No extraction jobs started"
    exit 1
fi

log_info "Started ${#PIDS[@]} extraction job(s)"

# Wait for all jobs and collect results
FAILURES=0
declare -A RESULTS

for i in "${!PIDS[@]}"; do
    pid="${PIDS[$i]}"
    job_name="${JOB_NAMES[$i]}"
    log_file="${LOG_FILES[$i]}"

    log_debug "Waiting for $job_name (PID: $pid)..."

    if wait "$pid"; then
        RESULTS["$job_name"]="success"
        log_info "✓ $job_name completed successfully"
    else
        RESULTS["$job_name"]="failed"
        log_error "✗ $job_name failed"
        FAILURES=$((FAILURES + 1))

        # Show last few lines of log on failure
        if [ -f "$log_file" ]; then
            log_error "Last 5 lines of $job_name log:"
            tail -5 "$log_file" >&2 || true
        fi
    fi
done

# Calculate timing
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
log_section "═══════════════════════════════════════════════════════════"
log_section "Extraction Summary"
log_section "═══════════════════════════════════════════════════════════"
log_info "Duration: ${DURATION}s"
log_info "Jobs completed: $((${#PIDS[@]} - FAILURES))/${#PIDS[@]}"

for job_name in "${!RESULTS[@]}"; do
    status="${RESULTS[$job_name]}"
    if [ "$status" = "success" ]; then
        log_info "  ✓ $job_name"
    else
        log_error "  ✗ $job_name"
    fi
done

# List created files
log_info "Output files:"
ls -la "$DAILY_DIR"/*.md 2>/dev/null | awk '{print "  - " $NF}' >&2 || log_warn "  No output files created"

# Clean up log files on success
if [ $FAILURES -eq 0 ]; then
    rm -f "$DAILY_DIR"/.*.log 2>/dev/null || true
fi

if [ $FAILURES -gt 0 ]; then
    log_warn "Completed with $FAILURES failure(s)"
    exit 2
fi

log_info "All extractions completed successfully"
exit 0
