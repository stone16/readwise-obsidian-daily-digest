#!/usr/bin/env bash

###############################################################################
# generate_chunked_digest.sh
#
# Generate Daily Digest from consolidated content with chunking for large inputs.
#
# This script:
# 1. Checks if consolidated content exceeds size threshold
# 2. If large: splits into chunks, processes in parallel, then merges
# 3. If small: processes directly
#
# Usage: ./generate_chunked_digest.sh <vault_path> <date>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (required)
#
# Environment:
#   MAX_CHUNK_LINES: Maximum lines per chunk (default: 500)
#   MAX_PARALLEL_JOBS: Maximum parallel Claude invocations (default: 3)
#
# Output: Creates Daily Digest file in vault/DailyDigest/
# Exit codes:
#   0: Success
#   1: Invalid arguments or missing dependencies
#   2: Chunk processing failed
#   3: Final synthesis failed
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[CHUNKED]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[CHUNKED]${NC} $*" >&2; }
log_error() { echo -e "${RED}[CHUNKED]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[CHUNKED]${NC} $*" >&2; }
log_chunk() { echo -e "${MAGENTA}[CHUNK]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}[CHUNKED]${NC} $*" >&2; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

# Configuration
MAX_CHUNK_LINES="${MAX_CHUNK_LINES:-500}"
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-3}"
SINGLE_PASS_THRESHOLD=800  # Lines below which we try single-pass first

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

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    log_error "Claude Code CLI not found. Please install Claude Code."
    exit 1
fi

# Paths
DAILY_DIR="$VAULT_ROOT/DailyDigest/$DATE"
CONSOLIDATED_FILE="$DAILY_DIR/consolidated.md"
OUTPUT_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"
# Use project temp dir instead of vault (iCloud may not allow writes)
TEMP_DIR="$PROJECT_ROOT/.tmp/chunks_$DATE"
PROMPT_FILE="$PROMPTS_DIR/digest.md"
CHUNK_PROMPT_FILE="$PROMPTS_DIR/chunk_digest.md"
MERGE_PROMPT_FILE="$PROMPTS_DIR/chunk_merge.md"

if [ ! -f "$CONSOLIDATED_FILE" ]; then
    log_error "Consolidated file not found: $CONSOLIDATED_FILE"
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Prompt template not found: $PROMPT_FILE"
    exit 1
fi

# Get content stats
TOTAL_LINES=$(wc -l < "$CONSOLIDATED_FILE" | tr -d ' ')
TOTAL_CHARS=$(wc -c < "$CONSOLIDATED_FILE" | tr -d ' ')

log_section "========================================"
log_section "Chunked Digest Generation"
log_section "========================================"
log_info "Date: $DATE"
log_info "Input: $CONSOLIDATED_FILE"
log_info "Content: $TOTAL_LINES lines, $(numfmt --to=iec $TOTAL_CHARS 2>/dev/null || echo "${TOTAL_CHARS}B")"

###############################################################################
# Strategy Selection
###############################################################################

if [ "$TOTAL_LINES" -le "$SINGLE_PASS_THRESHOLD" ]; then
    log_info "Content within threshold ($TOTAL_LINES <= $SINGLE_PASS_THRESHOLD lines)"
    log_info "Attempting single-pass processing..."

    # Try single-pass first
    PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")
    PROMPT_TEMPLATE="${PROMPT_TEMPLATE//\{\{DATE\}\}/$DATE}"

    CONTENT=$(cat "$CONSOLIDATED_FILE")

    PROMPT="$PROMPT_TEMPLATE

---

## CONSOLIDATED CONTENT TO PROCESS

$CONTENT

---

## OUTPUT

Save the generated Daily Digest to: $OUTPUT_FILE
"

    cd "$VAULT_ROOT"
    if claude -p "$PROMPT" --allowedTools "Read,Write,Bash" 2>&1; then
        if [ -f "$OUTPUT_FILE" ]; then
            log_info "Single-pass succeeded!"
            OUTPUT_SIZE=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
            log_info "Output: $OUTPUT_FILE ($OUTPUT_SIZE lines)"
            exit 0
        fi
    fi

    log_warn "Single-pass failed, switching to chunked processing..."
fi

###############################################################################
# Chunked Processing
###############################################################################

log_section "Starting chunked processing..."
log_info "Max chunk size: $MAX_CHUNK_LINES lines"
log_info "Max parallel jobs: $MAX_PARALLEL_JOBS"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Split consolidated file by source sections
# Each "## Source:" header starts a new logical section
log_info "Splitting content by source sections..."

# Create chunk prompt template if not exists
if [ ! -f "$CHUNK_PROMPT_FILE" ]; then
    cat > "$CHUNK_PROMPT_FILE" << 'CHUNK_EOF'
# Chunk Digest Prompt

You are generating a partial digest for a chunk of content. This will be merged with other chunks later.

## Task

1. Analyze the provided content chunk
2. For each article/item, classify it and score it (0-100) based on:
   - Knowledge Depth (0-30)
   - Actionability (0-25)
   - Originality (0-20)
   - Personal Relevance (0-15)
   - Source Credibility (0-10)

3. Generate summaries based on score:
   - 0-49: 1-2 sentence brief
   - 50-69: 2-3 key bullet points
   - 70+: Full summary with insights and action items

4. Output as valid markdown with this structure:

```markdown
## Chunk Summary

### [Article Title] `[Type]` `Score: XX`

[Summary based on score tier]

---
```

## Critical Requirements

- Score EVERY item - don't skip any
- Include source links where available
- Be concise but complete
- This is a PARTIAL digest - it will be merged later
CHUNK_EOF
fi

# Create merge prompt template if not exists
if [ ! -f "$MERGE_PROMPT_FILE" ]; then
    cat > "$MERGE_PROMPT_FILE" << 'MERGE_EOF'
# Chunk Merge Prompt

You are synthesizing multiple partial digests into a final unified Daily Digest.

## Task

1. Read all chunk summaries provided
2. Create a unified Daily Digest that:
   - Has an executive summary highlighting TOP 3 highest-scoring items
   - Groups content by category/source
   - Orders items by score within categories
   - Creates a "Top Picks (Score 70+)" section
   - Adds conclusion with key themes and actionable takeaways

3. Output in this exact format:

```markdown
---
date: {{DATE}}
tags: [daily-digest, auto-generated]
---

# Daily Digest {{DATE}}

## Summary

[Executive summary - 2-3 paragraphs highlighting the most valuable content]

---

## Top Picks (Score 70+)

[High-scoring items with full detail]

---

## Category: [Name]

[Items grouped by source/category]

---

## Conclusion

[Key themes, patterns, and recommended actions]

---

## Sources

[All source URLs]
```

## Critical Requirements

- Include ALL items from ALL chunks
- Maintain accurate scores
- Deduplicate any overlapping content
- Create a seamless, unified reading experience
- Don't reveal that this was processed in chunks
MERGE_EOF
fi

# Simple fixed-size split (most reliable for large files)
declare -a CHUNK_FILES=()

log_info "Using fixed-size split ($MAX_CHUNK_LINES lines per chunk)..."
split -l "$MAX_CHUNK_LINES" "$CONSOLIDATED_FILE" "$TEMP_DIR/chunk_"

# Collect and rename chunks with numeric suffixes
CHUNK_NUM=0
for f in $(ls "$TEMP_DIR"/chunk_* 2>/dev/null | sort); do
    if [ -f "$f" ]; then
        CHUNK_NUM=$((CHUNK_NUM + 1))
        NEW_NAME="$TEMP_DIR/chunk_${CHUNK_NUM}.md"
        mv "$f" "$NEW_NAME"
        CHUNK_FILES+=("$NEW_NAME")
    fi
done

TOTAL_CHUNKS=${#CHUNK_FILES[@]}
log_info "Created $TOTAL_CHUNKS chunk(s)"

# Show chunk sizes
for i in "${!CHUNK_FILES[@]}"; do
    CHUNK_LINES=$(wc -l < "${CHUNK_FILES[$i]}" | tr -d ' ')
    log_chunk "Chunk $((i + 1)): $CHUNK_LINES lines"
done

if [ "$TOTAL_CHUNKS" -eq 0 ]; then
    log_error "No chunks created - content may be malformed"
    exit 2
fi

###############################################################################
# Sequential Chunk Processing (parallel causes Claude CLI file locking issues)
###############################################################################

log_section "Processing chunks sequentially..."

declare -a SUMMARY_FILES=()

CHUNK_PROMPT=$(cat "$CHUNK_PROMPT_FILE")

for i in "${!CHUNK_FILES[@]}"; do
    CHUNK_FILE="${CHUNK_FILES[$i]}"
    CHUNK_IDX=$((i + 1))
    SUMMARY_FILE="$TEMP_DIR/summary_${CHUNK_IDX}.md"
    SUMMARY_FILES+=("$SUMMARY_FILE")
    LOG_FILE="$TEMP_DIR/chunk_${CHUNK_IDX}.log"

    # Build prompt for this chunk
    CHUNK_CONTENT=$(cat "$CHUNK_FILE")

    PROMPT="$CHUNK_PROMPT

---

## CONTENT CHUNK $CHUNK_IDX of $TOTAL_CHUNKS

$CHUNK_CONTENT

---

## OUTPUT

Write your chunk summary directly below. Do not create files.
"

    # Run Claude sequentially to avoid file locking issues
    log_chunk "Processing chunk $CHUNK_IDX/$TOTAL_CHUNKS..."
    cd "$VAULT_ROOT"
    claude -p "$PROMPT" --allowedTools "" 2>"$LOG_FILE" > "$SUMMARY_FILE" || {
        echo "CHUNK_FAILED" > "$SUMMARY_FILE"
        log_error "Chunk $CHUNK_IDX failed"
    }

    # Brief pause between chunks to ensure file handles are released
    sleep 1
done

log_info "All chunks processed"

# Check results
FAILED_CHUNKS=0
for i in "${!SUMMARY_FILES[@]}"; do
    SUMMARY_FILE="${SUMMARY_FILES[$i]}"
    if [ ! -f "$SUMMARY_FILE" ] || grep -q "CHUNK_FAILED" "$SUMMARY_FILE" 2>/dev/null; then
        FAILED_CHUNKS=$((FAILED_CHUNKS + 1))
        log_error "Chunk $((i + 1)) failed"
    else
        CHUNK_SIZE=$(wc -l < "$SUMMARY_FILE" | tr -d ' ')
        log_chunk "Chunk $((i + 1)) complete: $CHUNK_SIZE lines"
    fi
done

if [ "$FAILED_CHUNKS" -eq "$TOTAL_CHUNKS" ]; then
    log_error "All chunks failed!"
    exit 2
fi

log_info "Chunk processing: $((TOTAL_CHUNKS - FAILED_CHUNKS))/$TOTAL_CHUNKS succeeded"

###############################################################################
# Merge Chunk Summaries
###############################################################################

log_section "Merging chunk summaries into final digest..."

# Combine all summaries
ALL_SUMMARIES=""
for SUMMARY_FILE in "${SUMMARY_FILES[@]}"; do
    if [ -f "$SUMMARY_FILE" ] && ! grep -q "CHUNK_FAILED" "$SUMMARY_FILE" 2>/dev/null; then
        CHUNK_CONTENT=$(cat "$SUMMARY_FILE")
        ALL_SUMMARIES="$ALL_SUMMARIES

---
## Chunk Summary
$CHUNK_CONTENT
---
"
    fi
done

# Load merge prompt
MERGE_PROMPT=$(cat "$MERGE_PROMPT_FILE")
MERGE_PROMPT="${MERGE_PROMPT//\{\{DATE\}\}/$DATE}"

FINAL_PROMPT="$MERGE_PROMPT

---

## CHUNK SUMMARIES TO MERGE

Total chunks processed: $TOTAL_CHUNKS

$ALL_SUMMARIES

---

## OUTPUT

Save the unified Daily Digest to: $OUTPUT_FILE
"

cd "$VAULT_ROOT"
claude -p "$FINAL_PROMPT" --allowedTools "Write" 2>&1 || {
    log_error "Final merge failed"

    # Fallback: concatenate summaries as-is
    log_warn "Creating fallback digest from chunk summaries..."
    {
        echo "---"
        echo "date: $DATE"
        echo "tags: [daily-digest, auto-generated, chunked]"
        echo "---"
        echo ""
        echo "# Daily Digest $DATE"
        echo ""
        echo "_Note: This digest was generated from chunked processing._"
        echo ""
        echo "$ALL_SUMMARIES"
    } > "$OUTPUT_FILE"
}

# Verify output
if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Output file was not created"
    exit 3
fi

OUTPUT_SIZE=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
log_info "Final digest created: $OUTPUT_SIZE lines"

# Cleanup
log_debug "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

log_section "========================================"
log_info "Chunked digest generation complete!"
log_info "Output: $OUTPUT_FILE"
log_section "========================================"

exit 0
