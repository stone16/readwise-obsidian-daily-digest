#!/usr/bin/env bash

###############################################################################
# daily_runner_v2.sh
#
# Enhanced orchestrator for Daily Digest generation with multi-source extraction.
#
# This script coordinates the complete automation pipeline:
# 1. Extraction: Parallel extraction from multiple sources (Obsidian, Readwise)
# 2. Consolidation: Merge all intermediate files
# 3. Synthesis: Generate Daily Digest using Claude
# 4. Distribution: Create platform-specific drafts
# 5. Monitoring: Write status and update summary dashboard
#
# Usage: ./daily_runner_v2.sh [vault_path] [date] [options]
#   vault_path: Absolute path to Obsidian vault (optional if VAULT_PATH set in .env)
#   date: Date in YYYY-MM-DD format (optional, defaults to yesterday)
#
# Options:
#   --sources <list>: Comma-separated sources (default: obsidian,readwise)
#   --with-platforms [list]: Generate platform drafts (default: disabled)
#                            Optional comma-separated list: twitter,linkedin,weixin,xiaohongshu
#                            If no list provided, generates all platforms
#   --skip-summary: Skip summary dashboard update
#   --skip-synthesis: Only extract and consolidate, no AI synthesis
#
# Environment Variables:
#   VAULT_PATH: Default vault path (used if vault_path not provided)
#   READWISE_TOKEN: API token for Readwise access
#   EXTRACTION_SOURCES: Default sources if --sources not specified
#
# Output: Complete Daily Digest with platform drafts
# Exit codes:
#   0: Success
#   1: Invalid arguments
#   2: Extraction failed
#   3: Consolidation failed
#   4: Synthesis failed
###############################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_phase() { echo -e "${BLUE}[PHASE]${NC} $*" >&2; }
log_success() { echo -e "${CYAN}[SUCCESS]${NC} $*" >&2; }
log_header() { echo -e "${MAGENTA}$*${NC}" >&2; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Parse arguments
VAULT_ROOT=""
DATE=""
SOURCES="${EXTRACTION_SOURCES:-obsidian,readwise}"
WITH_PLATFORMS=""
PLATFORMS_LIST=""
SKIP_SUMMARY=false
SKIP_SYNTHESIS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --sources)
            SOURCES="$2"
            shift 2
            ;;
        --with-platforms)
            WITH_PLATFORMS=true
            # Check if next arg is a platforms list (not another flag)
            if [[ $# -gt 1 ]] && [[ ! "$2" =~ ^-- ]]; then
                PLATFORMS_LIST="$2"
                shift
            fi
            shift
            ;;
        --skip-summary)
            SKIP_SUMMARY=true
            shift
            ;;
        --skip-synthesis)
            SKIP_SYNTHESIS=true
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
        log_info "Using default vault from VAULT_PATH: $VAULT_ROOT"
    else
        log_error "Usage: $0 [vault_path] [date] [options]"
        log_error ""
        log_error "Either provide vault_path as argument or set VAULT_PATH in .env"
        log_error ""
        log_error "Options:"
        log_error "  --sources <list>         Comma-separated sources (default: obsidian,readwise)"
        log_error "  --with-platforms [list]  Generate platform drafts (optional platforms list)"
        log_error "                           Platforms: twitter,linkedin,weixin,xiaohongshu"
        log_error "  --skip-summary           Skip summary dashboard update"
        log_error "  --skip-synthesis         Only extract and consolidate, no AI synthesis"
        exit 1
    fi
fi

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

# Script paths
PARALLEL_EXTRACTOR="$SCRIPT_DIR/extraction/extract_parallel.sh"
CONSOLIDATE_SCRIPT="$SCRIPT_DIR/synthesis/consolidate.sh"
GENERATE_DIGEST_SCRIPT="$SCRIPT_DIR/synthesis/generate_digest.sh"
GENERATE_PLATFORMS_SCRIPT="$SCRIPT_DIR/distribution/generate_platforms.sh"
WRITE_STATUS_SCRIPT="$SCRIPT_DIR/monitoring/write_status.sh"
UPDATE_SUMMARY_SCRIPT="$SCRIPT_DIR/monitoring/update_summary.sh"

# Output paths
DAILY_DIR="$VAULT_ROOT/DailyDigest/$DATE"
CONSOLIDATED_FILE="$DAILY_DIR/consolidated.md"
DIGEST_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"

# Track timing
START_TIME=$(date +%s)

log_header "═══════════════════════════════════════════════════════════════"
log_header "  Daily Digest v2 - Multi-Source Pipeline"
log_header "═══════════════════════════════════════════════════════════════"
log_info "Date: $DATE"
log_info "Vault: $VAULT_ROOT"
log_info "Sources: $SOURCES"
log_info ""

###############################################################################
# PHASE 1: PARALLEL EXTRACTION
###############################################################################
log_phase "1/5 Extraction - Parallel multi-source extraction"

if [ -x "$PARALLEL_EXTRACTOR" ]; then
    "$PARALLEL_EXTRACTOR" "$VAULT_ROOT" "$DATE" --sources "$SOURCES" || {
        log_error "Parallel extraction failed"
        "$WRITE_STATUS_SCRIPT" failed "Extraction failed" "$DATE" $(($(date +%s) - START_TIME)) 0 2>/dev/null || true
        exit 2
    }
else
    log_error "Parallel extractor not found: $PARALLEL_EXTRACTOR"
    exit 2
fi

# Count extracted files
EXTRACTED_FILES=$(find "$DAILY_DIR" -maxdepth 1 -name "*.md" ! -name "consolidated.md" -type f 2>/dev/null | wc -l | tr -d ' ')
log_info "Extracted $EXTRACTED_FILES source file(s)"

if [ "$EXTRACTED_FILES" -eq 0 ]; then
    log_warn "No content extracted from any source"
    "$WRITE_STATUS_SCRIPT" skipped "No content extracted" "$DATE" $(($(date +%s) - START_TIME)) 0 2>/dev/null || true
    exit 0
fi

###############################################################################
# PHASE 2: CONSOLIDATION
###############################################################################
log_phase "2/5 Consolidation - Merging intermediate files"

if [ -x "$CONSOLIDATE_SCRIPT" ]; then
    "$CONSOLIDATE_SCRIPT" "$VAULT_ROOT" "$DATE" || {
        log_error "Consolidation failed"
        "$WRITE_STATUS_SCRIPT" failed "Consolidation failed" "$DATE" $(($(date +%s) - START_TIME)) "$EXTRACTED_FILES" 2>/dev/null || true
        exit 3
    }
else
    log_error "Consolidation script not found: $CONSOLIDATE_SCRIPT"
    exit 3
fi

if [ ! -f "$CONSOLIDATED_FILE" ]; then
    log_error "Consolidated file not created"
    exit 3
fi

CONSOLIDATED_SIZE=$(wc -l < "$CONSOLIDATED_FILE" | tr -d ' ')
log_info "Consolidated file: $CONSOLIDATED_SIZE lines"

###############################################################################
# PHASE 3: SYNTHESIS (Optional)
###############################################################################
if [ "$SKIP_SYNTHESIS" = "true" ]; then
    log_phase "3/5 Synthesis - SKIPPED (--skip-synthesis)"
    # Copy consolidated as the digest
    cp "$CONSOLIDATED_FILE" "$DIGEST_FILE"
else
    log_phase "3/5 Synthesis - Generating Daily Digest with Claude"

    if [ -x "$GENERATE_DIGEST_SCRIPT" ]; then
        # Pass consolidated content to digest generator
        cat "$CONSOLIDATED_FILE" | "$GENERATE_DIGEST_SCRIPT" "$VAULT_ROOT" "$DATE" || {
            log_warn "Synthesis failed, using consolidated file as fallback"
            cp "$CONSOLIDATED_FILE" "$DIGEST_FILE"
        }
    else
        log_warn "Synthesis script not found, using consolidated file"
        cp "$CONSOLIDATED_FILE" "$DIGEST_FILE"
    fi
fi

if [ ! -f "$DIGEST_FILE" ]; then
    log_error "Digest file not created"
    exit 4
fi

DIGEST_SIZE=$(wc -l < "$DIGEST_FILE" | tr -d ' ')
log_success "Daily Digest: $DIGEST_SIZE lines"

###############################################################################
# PHASE 4: DISTRIBUTION (Optional)
###############################################################################
if [ -z "$WITH_PLATFORMS" ]; then
    log_phase "4/5 Distribution - SKIPPED (use --with-platforms to enable)"
else
    log_phase "4/5 Distribution - Generating platform drafts"

    if [ -x "$GENERATE_PLATFORMS_SCRIPT" ]; then
        # Build the command with optional platforms filter
        PLATFORMS_CMD=("$GENERATE_PLATFORMS_SCRIPT" "$DIGEST_FILE")
        if [ -n "$PLATFORMS_LIST" ]; then
            PLATFORMS_CMD+=("--platforms" "$PLATFORMS_LIST")
            log_info "Platforms: $PLATFORMS_LIST"
        else
            log_info "Platforms: all (twitter, linkedin, weixin, xiaohongshu)"
        fi

        "${PLATFORMS_CMD[@]}" || {
            log_warn "Platform draft generation failed (non-fatal)"
        }
    else
        log_warn "Platform generation script not found: $GENERATE_PLATFORMS_SCRIPT"
    fi
fi

###############################################################################
# PHASE 5: MONITORING
###############################################################################
if [ "$SKIP_SUMMARY" = "true" ]; then
    log_phase "5/5 Monitoring - SKIPPED (--skip-summary)"
else
    log_phase "5/5 Monitoring - Updating status and summary"

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    if [ -x "$WRITE_STATUS_SCRIPT" ]; then
        "$WRITE_STATUS_SCRIPT" success "Daily digest generated (v2 pipeline)" "$DATE" "$DURATION" "$EXTRACTED_FILES" 2>/dev/null || true
    fi

    if [ -x "$UPDATE_SUMMARY_SCRIPT" ]; then
        "$UPDATE_SUMMARY_SCRIPT" "$VAULT_ROOT" 2>/dev/null || log_warn "Summary update failed (non-fatal)"
    fi
fi

###############################################################################
# SUMMARY
###############################################################################
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log_header ""
log_header "═══════════════════════════════════════════════════════════════"
log_success "  Pipeline Complete!"
log_header "═══════════════════════════════════════════════════════════════"
log_info "Date: $DATE"
log_info "Duration: ${DURATION}s"
log_info "Sources extracted: $EXTRACTED_FILES"
log_info ""
log_info "Output files:"
log_info "  Digest: $DIGEST_FILE"
log_info "  Consolidated: $CONSOLIDATED_FILE"
log_info "  Intermediate: $DAILY_DIR/*.md"

if [ -n "$WITH_PLATFORMS" ] && [ -d "$PROJECT_ROOT/draft" ]; then
    DRAFT_COUNT=$(find "$PROJECT_ROOT/draft" -name "*.md" -type f -newer "$DIGEST_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DRAFT_COUNT" -gt 0 ]; then
        log_info "  Platform drafts: $PROJECT_ROOT/draft/ ($DRAFT_COUNT files)"
    fi
fi

exit 0
