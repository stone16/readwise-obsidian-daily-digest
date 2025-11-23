#!/usr/bin/env bash

###############################################################################
# generate_drafts.sh
#
# Generate platform-specific content drafts from Daily Digest.
#
# This script:
# 1. Reads Daily Digest for the specified date
# 2. Loads platform-specific prompt templates
# 3. Invokes Claude Code for each platform (Xiaohongshu, WeChat, Twitter)
# 4. Saves drafts to DailyDigest/Drafts/{date}/ directory
#
# Usage: ./generate_drafts.sh <vault_path> <date>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (required)
#
# Output: Creates draft files for each platform
# Exit codes:
#   0: Success (all drafts generated)
#   1: Invalid arguments or missing dependencies
#   2: Daily Digest file not found
#   3: Platform draft generation failed
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

log_platform() {
    echo -e "${CYAN}[PLATFORM]${NC} $*" >&2
}

# Validation
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <vault_path> <date>"
    log_error "Example: $0 /path/to/vault 2024-11-23"
    exit 1
fi

VAULT_ROOT="$1"
DATE="$2"

# Validate inputs
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    log_error "Claude Code CLI not found. Please install Claude Code."
    exit 1
fi

log_info "Generating platform drafts for: $DATE"
log_info "Vault: $VAULT_ROOT"

# Locate Daily Digest file
DIGEST_FILE="$VAULT_ROOT/DailyDigest/Daily Digest $DATE.md"

if [ ! -f "$DIGEST_FILE" ]; then
    log_error "Daily Digest not found: $DIGEST_FILE"
    log_error "Run digest generation first before creating platform drafts"
    exit 2
fi

log_info "Source: $DIGEST_FILE ($(wc -l < "$DIGEST_FILE") lines)"

# Read Daily Digest content
DIGEST_CONTENT=$(cat "$DIGEST_FILE")

# Create output directory
OUTPUT_DIR="$VAULT_ROOT/DailyDigest/Drafts/$DATE"
mkdir -p "$OUTPUT_DIR"
log_info "Output directory: $OUTPUT_DIR"

# Get script directory to locate prompt templates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

log_info "Prompts directory: $PROMPTS_DIR"

# Platform configurations
declare -A PLATFORMS=(
    ["xiaohongshu"]="Xiaohongshu (小红书)"
    ["wechat"]="WeChat Official Account (微信公众号)"
    ["twitter"]="Twitter/X Thread"
)

# Success counter
SUCCESS_COUNT=0
TOTAL_PLATFORMS=${#PLATFORMS[@]}

# Generate drafts for each platform
for platform in "${!PLATFORMS[@]}"; do
    PLATFORM_NAME="${PLATFORMS[$platform]}"
    PROMPT_FILE="$PROMPTS_DIR/${platform}.md"
    OUTPUT_FILE="$OUTPUT_DIR/${platform}_draft.md"

    log_platform "Processing: $PLATFORM_NAME"

    # Check if prompt template exists
    if [ ! -f "$PROMPT_FILE" ]; then
        log_warn "Prompt template not found: $PROMPT_FILE"
        log_warn "Skipping $PLATFORM_NAME draft generation"
        continue
    fi

    # Read prompt template
    PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")

    # Construct combined prompt
    COMBINED_PROMPT="$PROMPT_TEMPLATE

---

## SOURCE CONTENT FROM DAILY DIGEST

Below is the Daily Digest content to transform:

$DIGEST_CONTENT

---

## YOUR TASK

Transform the above Daily Digest content into a ${PLATFORM_NAME} draft following ALL requirements in the prompt template above.

Save the output to: $OUTPUT_FILE

Include frontmatter:
---
platform: $platform
generated_from: \"[[DailyDigest/Daily Digest $DATE]]\"
date: $DATE
status: draft
---
"

    log_platform "Invoking Claude Code for $platform..."

    # Invoke Claude Code
    cd "$PROJECT_ROOT"
    claude -p "$COMBINED_PROMPT" --allowedTools "Read,Write,Bash" 2>&1 | tee -a "$OUTPUT_DIR/${platform}_generation.log" || {
        log_error "$PLATFORM_NAME draft generation failed"
        log_warn "Check log: $OUTPUT_DIR/${platform}_generation.log"
        continue
    }

    # Verify output file
    if [ ! -f "$OUTPUT_FILE" ]; then
        log_error "Draft file not created: $OUTPUT_FILE"
        continue
    fi

    FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
    if [ "$FILE_SIZE" -lt 50 ]; then
        log_warn "$PLATFORM_NAME draft seems suspiciously small ($FILE_SIZE bytes)"
    fi

    log_platform "✅ $PLATFORM_NAME draft complete ($(wc -l < "$OUTPUT_FILE") lines)"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
done

# Summary
echo ""
log_info "═══════════════════════════════════════════════════════════"
log_info "Draft Generation Summary"
log_info "═══════════════════════════════════════════════════════════"
log_info "Date: $DATE"
log_info "Source: Daily Digest $DATE.md"
log_info "Output: $OUTPUT_DIR"
log_info "Success: $SUCCESS_COUNT / $TOTAL_PLATFORMS platforms"

if [ "$SUCCESS_COUNT" -eq "$TOTAL_PLATFORMS" ]; then
    log_info "✅ All platform drafts generated successfully!"
    exit 0
elif [ "$SUCCESS_COUNT" -gt 0 ]; then
    log_warn "⚠️  Partial success: $SUCCESS_COUNT / $TOTAL_PLATFORMS drafts generated"
    exit 3
else
    log_error "❌ All platform drafts failed to generate"
    exit 3
fi
