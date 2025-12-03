#!/usr/bin/env bash

###############################################################################
# generate_digest.sh
#
# Generate Daily Digest from modified Obsidian notes using Claude Code.
#
# Usage: ./generate_digest.sh <vault_path> <date> <file_list>
#   vault_path: Absolute path to Obsidian vault (required)
#   date: Date string in YYYY-MM-DD format (required)
#   file_list: Newline-separated list of file paths (via stdin or argument)
#
# Output: Creates Daily Digest file in vault/DailyDigest/
# Exit codes:
#   0: Success
#   1: Invalid arguments or missing dependencies
#   2: Claude Code invocation failed
#   3: Output file creation failed
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
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

# Validation
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <vault_path> <date> [file_list]"
    log_error "Example: $0 /path/to/vault 2024-11-23 'file1.md\nfile2.md'"
    exit 1
fi

VAULT_ROOT="$1"
DATE="$2"
FILE_LIST="${3:-}"

# Read from stdin if file_list not provided as argument
if [ -z "$FILE_LIST" ]; then
    log_debug "Reading file list from stdin..."
    FILE_LIST=$(cat)
fi

# Validate inputs
if [ ! -d "$VAULT_ROOT" ]; then
    log_error "Vault path does not exist: $VAULT_ROOT"
    exit 1
fi

if [ -z "$FILE_LIST" ]; then
    log_error "No files provided for digest generation"
    exit 1
fi

# Verify Claude Code is available
if ! command -v claude &> /dev/null; then
    log_error "Claude Code CLI not found. Please install Claude Code."
    log_error "Visit: https://docs.anthropic.com/claude/docs/claude-code"
    exit 1
fi

log_info "Generating Daily Digest for: $DATE"
log_info "Vault: $VAULT_ROOT"

# Count files
FILE_COUNT=$(echo "$FILE_LIST" | grep -c "^" || echo "0")
log_info "Processing $FILE_COUNT file(s)"

# Create output directory if needed
OUTPUT_DIR="$VAULT_ROOT/DailyDigest"
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE="$OUTPUT_DIR/Daily Digest $DATE.md"
log_info "Output: $OUTPUT_FILE"

# Get script directory to locate prompt templates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"
PROMPT_FILE="$PROMPTS_DIR/digest.md"

# Load prompt template
if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Prompt template not found: $PROMPT_FILE"
    exit 1
fi

PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")

# Replace placeholders in template
PROMPT_TEMPLATE="${PROMPT_TEMPLATE//\{\{DATE\}\}/$DATE}"

# Construct final prompt
PROMPT="$PROMPT_TEMPLATE

---

## FILES TO PROCESS

The following files were modified on $DATE:

$FILE_LIST

---

## OUTPUT

Save the generated Daily Digest to: $OUTPUT_FILE
"

log_info "Invoking Claude Code..."
log_debug "Prompt length: $(echo "$PROMPT" | wc -c) characters"

# Change to vault directory so CLAUDE.md is loaded
cd "$VAULT_ROOT"

# Invoke Claude Code with appropriate permissions
# --allowedTools: Limit to Read, Write, and minimal Bash for safety
claude -p "$PROMPT" --allowedTools "Read,Write,Bash" 2>&1 | tee -a "$VAULT_ROOT/.taskmaster/status/digest_generation.log" || {
    log_error "Claude Code invocation failed (exit code: $?)"
    exit 2
}

# Verify output file was created
if [ ! -f "$OUTPUT_FILE" ]; then
    log_error "Output file was not created: $OUTPUT_FILE"
    exit 3
fi

# Validate output file has content
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
if [ "$FILE_SIZE" -lt 100 ]; then
    log_warn "Output file seems suspiciously small ($FILE_SIZE bytes). Verify content."
fi

log_info "✅ Daily Digest generated successfully!"
log_info "Location: $OUTPUT_FILE"
log_info "Size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"

exit 0
