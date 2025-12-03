#!/usr/bin/env bash

###############################################################################
# generate_platforms.sh
#
# Generate platform-specific content drafts from any markdown file.
#
# This script:
# 1. Takes any markdown file as input (positional argument)
# 2. Generates platform-specific drafts using Claude Code
# 3. Outputs to draft/ directory with filenames based on input file
#
# Usage: ./generate_platforms.sh <input_file> [--platforms <list>]
#   input_file: Path to markdown file (required, positional)
#   --platforms: Comma-separated platforms (optional, default: all)
#
# Supported platforms:
#   - twitter: Twitter/X (Chinese)
#   - linkedin: LinkedIn (English)
#   - weixin: 公众号 (Chinese)
#   - xiaohongshu: 小红书 (Chinese)
#
# Output: Creates draft files in draft/ directory
# Exit codes:
#   0: Success
#   1: Invalid arguments
#   2: Input file not found
#   3: Some drafts failed
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

log_info() { echo -e "${GREEN}[PLATFORMS]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[PLATFORMS]${NC} $*" >&2; }
log_error() { echo -e "${RED}[PLATFORMS]${NC} $*" >&2; }
log_platform() { echo -e "${CYAN}[PLATFORM]${NC} $*" >&2; }
log_header() { echo -e "${MAGENTA}$*${NC}" >&2; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Platform configuration
# Format: platform_name:display_name:language:prompt_file
declare -A PLATFORM_CONFIG=(
    ["twitter"]="Twitter/X:chinese:twitter.md"
    ["linkedin"]="LinkedIn:english:linkedin.md"
    ["weixin"]="公众号:chinese:weixin.md"
    ["xiaohongshu"]="小红书:chinese:xiaohongshu.md"
)

ALL_PLATFORMS="twitter,linkedin,weixin,xiaohongshu"

# Parse arguments
INPUT_FILE=""
PLATFORMS_FILTER=""
PARALLEL_MODE=true  # Default to parallel

while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS_FILTER="$2"
            shift 2
            ;;
        --sequential)
            PARALLEL_MODE=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 <input_file> [--platforms <list>] [--sequential]"
            echo ""
            echo "Arguments:"
            echo "  input_file      Path to markdown file to process"
            echo ""
            echo "Options:"
            echo "  --platforms     Comma-separated list of platforms (default: all)"
            echo "                  Available: twitter, linkedin, weixin, xiaohongshu"
            echo "  --sequential    Process platforms one by one (default: parallel)"
            echo ""
            echo "Examples:"
            echo "  $0 ./daily_digest.md                          # All platforms, parallel"
            echo "  $0 ./notes.md --platforms twitter,linkedin    # Specific platforms"
            echo "  $0 ./notes.md --sequential                    # Sequential processing"
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            else
                log_error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validation
if [ -z "$INPUT_FILE" ]; then
    log_error "Usage: $0 <input_file> [--platforms <list>]"
    log_error ""
    log_error "Example: $0 ./daily_digest.md --platforms twitter,linkedin"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 2
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    log_error "Claude Code CLI not found. Please install Claude Code."
    exit 1
fi

# Resolve absolute path and extract base name
INPUT_FILE_ABS="$(cd "$(dirname "$INPUT_FILE")" && pwd)/$(basename "$INPUT_FILE")"
INPUT_BASENAME=$(basename "$INPUT_FILE" .md)
INPUT_BASENAME=$(basename "$INPUT_BASENAME" .txt)

# Determine platforms to process
if [ -z "$PLATFORMS_FILTER" ]; then
    PLATFORMS_TO_PROCESS="$ALL_PLATFORMS"
else
    PLATFORMS_TO_PROCESS="$PLATFORMS_FILTER"
fi

# Create output directory
OUTPUT_DIR="$PROJECT_ROOT/draft"
mkdir -p "$OUTPUT_DIR"

# Read source content
SOURCE_CONTENT=$(cat "$INPUT_FILE")

log_header "═══════════════════════════════════════════════════════════════"
log_header "  Platform Draft Generator"
log_header "═══════════════════════════════════════════════════════════════"
log_info "Input: $INPUT_FILE"
log_info "Output directory: $OUTPUT_DIR"
log_info "Platforms: $PLATFORMS_TO_PROCESS"
if [ "$PARALLEL_MODE" = "true" ]; then
    log_info "Mode: PARALLEL (faster)"
else
    log_info "Mode: Sequential"
fi
log_info ""

# Track results - using temp files for parallel mode
RESULTS_DIR=$(mktemp -d)
trap 'rm -rf "$RESULTS_DIR"' EXIT

###############################################################################
# process_platform: Generate content for a single platform
# Arguments: platform_name
# Returns: Writes result file to RESULTS_DIR
###############################################################################
process_platform() {
    local platform="$1"
    local result_file="$RESULTS_DIR/${platform}.result"

    # Parse platform config
    IFS=':' read -r display_name language prompt_file <<< "${PLATFORM_CONFIG[$platform]}"

    log_platform "Processing: $display_name ($platform)"

    # Check for prompt template
    local PROMPT_FILE="$PROMPTS_DIR/$prompt_file"
    if [ ! -f "$PROMPT_FILE" ]; then
        log_warn "  Prompt template not found: $PROMPT_FILE (skipping)"
        echo "skipped" > "$result_file"
        return
    fi

    local PROMPT_TEMPLATE
    PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")
    log_platform "  Using prompt: $prompt_file"

    # Output file
    local OUTPUT_FILE="$OUTPUT_DIR/${INPUT_BASENAME}_${platform}.md"

    # Construct combined prompt
    local COMBINED_PROMPT="$PROMPT_TEMPLATE

---

## SOURCE CONTENT

$SOURCE_CONTENT

---

## YOUR TASK

Transform the above content into a $display_name draft.

IMPORTANT:
- Output ONLY the final content ready for posting
- Do NOT include any meta-commentary or explanations
- Do NOT save to any file - just output the content directly
"

    log_platform "  Invoking Claude Code..."

    # Invoke Claude Code and capture output
    cd "$PROJECT_ROOT"

    local TEMP_OUTPUT
    TEMP_OUTPUT=$(mktemp)
    if claude -p "$COMBINED_PROMPT" --allowedTools "Read" > "$TEMP_OUTPUT" 2>&1; then
        # Check if we got meaningful output
        if [ -s "$TEMP_OUTPUT" ]; then
            # Add frontmatter and save
            {
                echo "---"
                echo "platform: $platform"
                echo "source_file: $(basename "$INPUT_FILE")"
                echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
                echo "language: $language"
                echo "status: draft"
                echo "---"
                echo ""
                cat "$TEMP_OUTPUT"
            } > "$OUTPUT_FILE"

            local FILE_SIZE
            FILE_SIZE=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
            log_platform "  ✅ Complete ($FILE_SIZE lines) → $OUTPUT_FILE"
            echo "success" > "$result_file"
        else
            log_warn "  No output generated"
            echo "empty" > "$result_file"
        fi
    else
        log_error "  Generation failed"
        echo "failed" > "$result_file"
    fi

    rm -f "$TEMP_OUTPUT"
}

# Export required variables and functions for subshells
export -f process_platform log_platform log_warn log_error
export PROMPTS_DIR SOURCE_CONTENT OUTPUT_DIR INPUT_BASENAME PROJECT_ROOT INPUT_FILE RESULTS_DIR
export RED YELLOW GREEN BLUE CYAN MAGENTA NC

# Build list of valid platforms
declare -a VALID_PLATFORMS=()
IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS_TO_PROCESS"
for platform in "${PLATFORM_ARRAY[@]}"; do
    platform=$(echo "$platform" | xargs)
    if [ -n "${PLATFORM_CONFIG[$platform]:-}" ]; then
        VALID_PLATFORMS+=("$platform")
    else
        log_warn "Unknown platform: $platform (skipping)"
    fi
done

TOTAL_PLATFORMS=${#VALID_PLATFORMS[@]}

if [ "$TOTAL_PLATFORMS" -eq 0 ]; then
    log_error "No valid platforms to process"
    exit 1
fi

# Process platforms
if [ "$PARALLEL_MODE" = "true" ] && [ "$TOTAL_PLATFORMS" -gt 1 ]; then
    log_info "Starting $TOTAL_PLATFORMS platforms in parallel..."

    # Export the associative array by converting to environment
    export PLATFORM_CONFIG_twitter="${PLATFORM_CONFIG[twitter]}"
    export PLATFORM_CONFIG_linkedin="${PLATFORM_CONFIG[linkedin]}"
    export PLATFORM_CONFIG_weixin="${PLATFORM_CONFIG[weixin]}"
    export PLATFORM_CONFIG_xiaohongshu="${PLATFORM_CONFIG[xiaohongshu]}"

    # Launch all platforms in parallel
    PIDS=()
    for platform in "${VALID_PLATFORMS[@]}"; do
        (
            # Reconstruct PLATFORM_CONFIG in subshell
            declare -A PLATFORM_CONFIG=(
                ["twitter"]="$PLATFORM_CONFIG_twitter"
                ["linkedin"]="$PLATFORM_CONFIG_linkedin"
                ["weixin"]="$PLATFORM_CONFIG_weixin"
                ["xiaohongshu"]="$PLATFORM_CONFIG_xiaohongshu"
            )
            process_platform "$platform"
        ) &
        PIDS+=($!)
    done

    # Wait for all to complete
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
else
    # Sequential processing
    for platform in "${VALID_PLATFORMS[@]}"; do
        process_platform "$platform"
    done
fi

# Count results
SUCCESS_COUNT=0
for platform in "${VALID_PLATFORMS[@]}"; do
    result_file="$RESULTS_DIR/${platform}.result"
    if [ -f "$result_file" ] && [ "$(cat "$result_file")" = "success" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

# Summary
echo "" >&2
log_header "═══════════════════════════════════════════════════════════════"
log_header "  Generation Summary"
log_header "═══════════════════════════════════════════════════════════════"
log_info "Source: $(basename "$INPUT_FILE")"
log_info "Output: $OUTPUT_DIR"
log_info "Success: $SUCCESS_COUNT / $TOTAL_PLATFORMS platforms"

# List created files
if [ -d "$OUTPUT_DIR" ]; then
    CREATED_FILES=$(find "$OUTPUT_DIR" -name "${INPUT_BASENAME}_*.md" -type f -newer "$INPUT_FILE_ABS" 2>/dev/null || true)
    if [ -n "$CREATED_FILES" ]; then
        log_info ""
        log_info "Created files:"
        echo "$CREATED_FILES" | while read -r file; do
            echo "  - $(basename "$file")" >&2
        done
    fi
fi

if [ "$SUCCESS_COUNT" -eq "$TOTAL_PLATFORMS" ] && [ "$TOTAL_PLATFORMS" -gt 0 ]; then
    log_info ""
    log_info "✅ All platform drafts generated successfully!"
    exit 0
elif [ "$SUCCESS_COUNT" -gt 0 ]; then
    log_warn ""
    log_warn "⚠️ Partial success: $SUCCESS_COUNT / $TOTAL_PLATFORMS"
    exit 3
else
    log_error ""
    log_error "❌ All platform drafts failed"
    exit 3
fi
