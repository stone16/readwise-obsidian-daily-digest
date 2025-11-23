#!/usr/bin/env bash

###############################################################################
# generate_batch_digest.sh
#
# Handle multi-batch Daily Digest generation with sub-digest synthesis.
#
# This script:
# 1. Detects if input contains batch markers (BATCH_1:, BATCH_2:, etc.)
# 2. Generates sub-digests for each batch
# 3. Synthesizes final digest from all sub-digests
# 4. Cleans up temporary files
#
# Usage: ./generate_batch_digest.sh <vault_path> <date> <batch_input>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (required)
#   batch_input: Output from discover_changes.sh (via stdin or argument)
#
# Output: Creates Daily Digest file in vault/DailyDigest/
# Exit codes:
#   0: Success
#   1: Invalid arguments
#   2: Sub-digest generation failed
#   3: Final synthesis failed
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*" >&2
}

log_batch() {
    echo -e "${MAGENTA}[BATCH]${NC} $*" >&2
}

# Validation
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <vault_path> <date> [batch_input]"
    exit 1
fi

VAULT_ROOT="$1"
DATE="$2"
BATCH_INPUT="${3:-}"

# Read from stdin if not provided as argument
if [ -z "$BATCH_INPUT" ]; then
    log_debug "Reading batch input from stdin..."
    BATCH_INPUT=$(cat)
fi

# Validate inputs
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

if [ -z "$BATCH_INPUT" ]; then
    log_error "No batch input provided"
    exit 1
fi

# Detect if batch processing is needed
if ! echo "$BATCH_INPUT" | grep -q "^BATCH_"; then
    # No batch markers - single-pass processing
    log_info "Single-pass mode detected (no batch markers)"
    exec "$(dirname "$0")/generate_digest.sh" "$VAULT_ROOT" "$DATE" "$BATCH_INPUT"
fi

log_batch "Multi-batch mode detected"

# Create temp directory for sub-digests
TEMP_DIR="$VAULT_ROOT/.taskmaster/tmp"
mkdir -p "$TEMP_DIR"
log_info "Temp directory: $TEMP_DIR"

# Parse batches and generate sub-digests
SUB_DIGEST_FILES=()
BATCH_NUM=0

while IFS= read -r line; do
    if [[ "$line" =~ ^BATCH_([0-9]+):\ (.*)$ ]]; then
        BATCH_NUM="${BASH_REMATCH[1]}"
        BATCH_FILES="${BASH_REMATCH[2]}"

        log_batch "Processing Batch $BATCH_NUM"

        SUB_DIGEST_FILE="$TEMP_DIR/sub_digest_${BATCH_NUM}.md"
        SUB_DIGEST_FILES+=("$SUB_DIGEST_FILE")

        # Generate sub-digest for this batch
        log_info "Generating sub-digest $BATCH_NUM..."

        SUB_PROMPT="I have detected changes in the following files (Batch $BATCH_NUM of multi-batch processing):

$BATCH_FILES

Task:
1. Use your Read tool to ingest each of these files.
2. Generate a sub-digest following CLAUDE.md rules.
3. This is PART of a larger digest - use the same structure but note this is \"Sub-Digest $BATCH_NUM\"
4. Save to: $SUB_DIGEST_FILE

Structure:
- Frontmatter (YAML): date, tags, batch_number: $BATCH_NUM
- 📊 Snapshot: Statistics for this batch
- 🧠 Synthesis: Thematic narrative for this batch
- 📝 Highlights: Per-note summaries (TL;DR, Full Summary, Key Quote, Action Items)
- 🔗 Connections: WikiLinks in this batch

CRITICAL: Preserve ALL WikiLinks in [[format]], provide FULL SUMMARIES.
"

        cd "$VAULT_ROOT"
        claude -p "$SUB_PROMPT" --allowedTools "Read,Write,Bash" 2>&1 | tee -a "$TEMP_DIR/batch_${BATCH_NUM}.log" || {
            log_error "Sub-digest $BATCH_NUM generation failed"
            exit 2
        }

        if [ ! -f "$SUB_DIGEST_FILE" ]; then
            log_error "Sub-digest file not created: $SUB_DIGEST_FILE"
            exit 2
        fi

        log_batch "✅ Sub-digest $BATCH_NUM complete ($(wc -l < "$SUB_DIGEST_FILE") lines)"
    fi
done <<< "$BATCH_INPUT"

# Count total batches
TOTAL_BATCHES=${#SUB_DIGEST_FILES[@]}
log_batch "Generated $TOTAL_BATCHES sub-digest(s)"

# Final synthesis: combine all sub-digests into final Daily Digest
OUTPUT_DIR="$VAULT_ROOT/DailyDigest"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/Daily Digest $DATE.md"

log_info "Synthesizing final Daily Digest from $TOTAL_BATCHES sub-digests..."

# Read all sub-digests
SUB_DIGEST_CONTENT=""
for SUB_FILE in "${SUB_DIGEST_FILES[@]}"; do
    SUB_DIGEST_CONTENT+="

---
$(cat "$SUB_FILE")
---

"
done

SYNTHESIS_PROMPT="I have generated $TOTAL_BATCHES sub-digests from today's modified notes ($DATE).

Below are all the sub-digests:

$SUB_DIGEST_CONTENT

Task:
1. Read and understand all sub-digests.
2. Generate a UNIFIED Daily Digest that synthesizes insights across ALL batches.
3. Follow the CLAUDE.md template structure exactly.
4. Save to: $OUTPUT_FILE

Requirements for final synthesis:
- **📊 Snapshot**: Combine statistics from all batches (total file count, merged top tags)
- **🧠 Synthesis**: Create a unified 1-2 paragraph narrative connecting ALL notes thematically
  - Identify overarching themes across batches
  - Note relationships between batch themes
- **📝 Highlights**: Merge all per-note summaries from all batches (preserve ALL notes)
  - Maintain original TL;DR, Full Summary, Key Quote, Action Items
  - Order logically by theme, not batch number
- **🔗 Connections**: Deduplicate and combine all WikiLinks from all batches

CRITICAL:
- This is the FINAL digest users will read - it must be coherent and complete
- Preserve ALL WikiLinks in [[format]]
- Do NOT lose any notes from sub-digests - include every single one
- The user should not know this was generated from multiple batches
"

cd "$VAULT_ROOT"
claude -p "$SYNTHESIS_PROMPT" --allowedTools "Read,Write,Bash" 2>&1 | tee -a "$TEMP_DIR/final_synthesis.log" || {
    log_error "Final synthesis failed"
    exit 3
}

if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Final digest file not created: $OUTPUT_FILE"
    exit 3
fi

log_info "✅ Final Daily Digest generated successfully!"
log_info "Location: $OUTPUT_FILE"
log_info "Size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"

# Cleanup temporary files
log_info "Cleaning up temporary sub-digests..."
rm -f "${SUB_DIGEST_FILES[@]}"
rm -f "$TEMP_DIR"/batch_*.log
rm -f "$TEMP_DIR/final_synthesis.log"
log_debug "Cleanup complete"

exit 0
