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

# Construct prompt for Claude Code
# The prompt combines:
# 1. Reference to CLAUDE.md system prompt (auto-loaded by Claude Code)
# 2. Task specification
# 3. File list to process
# 4. Output file path

PROMPT="I have detected changes in the following files today ($DATE):

$FILE_LIST

Task:
1. Use your Read tool to ingest each of these files.
2. Generate a Daily Digest following the rules in CLAUDE.md.
3. The digest must follow this structure:
   - Frontmatter (YAML): date, tags
   - 📊 Snapshot: Statistics (file count, top tags)
   - 🧠 Synthesis: 1-2 paragraph narrative connecting notes thematically
   - 📝 Highlights: Per-note summaries with TL;DR, Full Summary, Key Quote, Action Items
   - 🔗 Connections: WikiLinks referenced today

4. Save the output to: $OUTPUT_FILE

CRITICAL REMINDERS:
- Preserve ALL WikiLinks in [[format]] (never convert to markdown links)
- Provide FULL SUMMARIES (2-3 paragraphs) for each note in Highlights
- Group notes thematically in Synthesis section
- Do NOT invent WikiLinks - only link to files you read
- Use exact template structure from CLAUDE.md
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
