#!/usr/bin/env bash

###############################################################################
# generate_drafts_v2.sh
#
# Generate platform-specific content drafts using YAML configurations.
#
# This script:
# 1. Reads platform configurations from config/platforms/*.yaml
# 2. Loads Daily Digest for the specified date
# 3. Invokes Claude Code for each enabled platform
# 4. Saves drafts to DailyDigest/YYYY-MM-DD/drafts/
#
# Usage: ./generate_drafts_v2.sh <vault_path> <date> [--platforms <list>]
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (required)
#   --platforms: Comma-separated list of platforms (optional, default: all enabled)
#
# Output: Creates draft files for each platform
# Exit codes:
#   0: Success
#   1: Invalid arguments
#   2: Daily Digest not found
#   3: Some drafts failed
###############################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[DRAFTS]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[DRAFTS]${NC} $*" >&2; }
log_error() { echo -e "${RED}[DRAFTS]${NC} $*" >&2; }
log_platform() { echo -e "${CYAN}[PLATFORM]${NC} $*" >&2; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config/platforms"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

# Parse arguments
VAULT_ROOT=""
DATE=""
PLATFORMS_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS_FILTER="$2"
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

# Validation
if [ -z "$VAULT_ROOT" ] || [ -z "$DATE" ]; then
    log_error "Usage: $0 <vault_path> <date> [--platforms <list>]"
    exit 1
fi

if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

# Verify yq (YAML parser) is available - required for nested YAML config parsing
if ! command -v yq &> /dev/null; then
    log_error "yq (YAML parser) not found. Please install yq:"
    log_error "  macOS: brew install yq"
    log_error "  Linux: snap install yq or download from https://github.com/mikefarah/yq"
    exit 1
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    log_error "Claude Code CLI not found. Please install Claude Code."
    exit 1
fi

# Locate digest file (try both locations)
DIGEST_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"
CONSOLIDATED_FILE="$VAULT_ROOT/DailyDigest/$DATE/consolidated.md"

if [ -f "$DIGEST_FILE" ]; then
    SOURCE_FILE="$DIGEST_FILE"
elif [ -f "$CONSOLIDATED_FILE" ]; then
    SOURCE_FILE="$CONSOLIDATED_FILE"
else
    log_error "No digest found for $DATE"
    log_error "Looked for:"
    log_error "  - $DIGEST_FILE"
    log_error "  - $CONSOLIDATED_FILE"
    exit 2
fi

log_info "Generating platform drafts for: $DATE"
log_info "Source: $SOURCE_FILE"

# Read source content
SOURCE_CONTENT=$(cat "$SOURCE_FILE")

# Create output directory
OUTPUT_DIR="$VAULT_ROOT/DailyDigest/$DATE/drafts"
mkdir -p "$OUTPUT_DIR"

# Function to extract YAML value using yq
get_yaml_value() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    yq -r "$key // \"$default\"" "$file" 2>/dev/null || echo "$default"
}

# Function to check if platform is enabled
is_platform_enabled() {
    local config_file="$1"
    local enabled
    enabled=$(yq -r '.platform.enabled // true' "$config_file" 2>/dev/null)

    [ "$enabled" = "true" ] || [ "$enabled" = "" ]
}

# Discover platform configurations
log_info "Scanning platform configurations..."

if [ ! -d "$CONFIG_DIR" ]; then
    log_warn "Config directory not found: $CONFIG_DIR"
    log_warn "Falling back to hardcoded platforms"

    # Fallback to original behavior
    exec "$SCRIPT_DIR/generate_drafts.sh" "$VAULT_ROOT" "$DATE"
fi

# Build list of platforms to process
declare -a PLATFORM_CONFIGS=()
declare -a PLATFORM_NAMES=()

for config_file in "$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml; do
    [ -f "$config_file" ] || continue

    platform_name=$(basename "$config_file" .yaml)
    platform_name=$(basename "$platform_name" .yml)

    # Check filter if specified
    if [ -n "$PLATFORMS_FILTER" ]; then
        if ! echo ",$PLATFORMS_FILTER," | grep -q ",$platform_name,"; then
            continue
        fi
    fi

    # Check if enabled
    if ! is_platform_enabled "$config_file"; then
        log_info "  Skipping $platform_name (disabled)"
        continue
    fi

    PLATFORM_CONFIGS+=("$config_file")
    PLATFORM_NAMES+=("$platform_name")
    log_info "  Found: $platform_name"
done

if [ ${#PLATFORM_CONFIGS[@]} -eq 0 ]; then
    log_warn "No enabled platforms found"
    exit 0
fi

log_info "Processing ${#PLATFORM_CONFIGS[@]} platform(s)"

# Track results
SUCCESS_COUNT=0
TOTAL_PLATFORMS=${#PLATFORM_CONFIGS[@]}

# Process each platform
for i in "${!PLATFORM_CONFIGS[@]}"; do
    config_file="${PLATFORM_CONFIGS[$i]}"
    platform="${PLATFORM_NAMES[$i]}"

    # Extract configuration
    display_name=$(get_yaml_value "$config_file" ".platform.display_name" "$platform")
    max_length=$(get_yaml_value "$config_file" ".constraints.max_length" "")
    format_type=$(get_yaml_value "$config_file" ".formatting.format" "")
    tone=$(get_yaml_value "$config_file" ".content.tone" "professional")
    output_filename=$(get_yaml_value "$config_file" ".output.filename" "${platform}_draft.md")

    log_platform "Processing: $display_name"

    OUTPUT_FILE="$OUTPUT_DIR/$output_filename"

    # Check for custom prompt template
    PROMPT_FILE="$PROMPTS_DIR/${platform}.md"

    if [ -f "$PROMPT_FILE" ]; then
        PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")
        log_platform "  Using custom prompt: $PROMPT_FILE"
    else
        # Generate prompt from YAML config
        PROMPT_TEMPLATE="You are creating content for $display_name.

## Platform Requirements
- Format: $format_type
- Tone: $tone"

        if [ -n "$max_length" ] && [ "$max_length" != "null" ]; then
            PROMPT_TEMPLATE="$PROMPT_TEMPLATE
- Maximum length: $max_length characters"
        fi

        PROMPT_TEMPLATE="$PROMPT_TEMPLATE

## Instructions
Transform the source content into an engaging $display_name post that:
1. Captures the key insights and highlights
2. Uses appropriate formatting for the platform
3. Maintains the specified tone
4. Stays within character limits if applicable

Output only the final content ready for posting."

        log_platform "  Using generated prompt from config"
    fi

    # Construct combined prompt
    COMBINED_PROMPT="$PROMPT_TEMPLATE

---

## SOURCE CONTENT

$SOURCE_CONTENT

---

## YOUR TASK

Transform the above content into a $display_name draft.

Save the output to: $OUTPUT_FILE

Include frontmatter:
---
platform: $platform
generated_from: \"Daily Digest $DATE\"
date: $DATE
status: draft
---
"

    log_platform "  Invoking Claude Code..."

    # Invoke Claude Code
    cd "$PROJECT_ROOT"
    if claude -p "$COMBINED_PROMPT" --allowedTools "Read,Write,Bash" > "$OUTPUT_DIR/${platform}_generation.log" 2>&1; then
        if [ -f "$OUTPUT_FILE" ]; then
            FILE_SIZE=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
            log_platform "  ✅ Complete ($FILE_SIZE lines)"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

            # Clean up log on success
            rm -f "$OUTPUT_DIR/${platform}_generation.log"
        else
            log_warn "  Draft file not created"
        fi
    else
        log_error "  Generation failed"
        log_warn "  Check log: $OUTPUT_DIR/${platform}_generation.log"
    fi
done

# Summary
echo "" >&2
log_info "═══════════════════════════════════════════════════════════"
log_info "Draft Generation Summary"
log_info "═══════════════════════════════════════════════════════════"
log_info "Date: $DATE"
log_info "Source: $(basename "$SOURCE_FILE")"
log_info "Output: $OUTPUT_DIR"
log_info "Success: $SUCCESS_COUNT / $TOTAL_PLATFORMS platforms"

# List created files
if [ -d "$OUTPUT_DIR" ]; then
    DRAFT_FILES=$(find "$OUTPUT_DIR" -name "*_draft.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DRAFT_FILES" -gt 0 ]; then
        log_info "Created files:"
        ls -la "$OUTPUT_DIR"/*_draft.md 2>/dev/null | awk '{print "  - " $NF}' >&2
    fi
fi

if [ "$SUCCESS_COUNT" -eq "$TOTAL_PLATFORMS" ]; then
    log_info "✅ All platform drafts generated successfully!"
    exit 0
elif [ "$SUCCESS_COUNT" -gt 0 ]; then
    log_warn "⚠️ Partial success: $SUCCESS_COUNT / $TOTAL_PLATFORMS"
    exit 3
else
    log_error "❌ All platform drafts failed"
    exit 3
fi
