#!/usr/bin/env bash

###############################################################################
# run_manual.sh
#
# Manual runner for Daily Digest automation with interactive prompts.
#
# This script provides a user-friendly interface for manual invocation:
# - Interactive vault selection (test vs production)
# - Date selection (today vs custom)
# - Optional draft generation skip
# - Confirmation before execution
#
# Usage: ./run_manual.sh [options]
#   Options:
#     --vault <path>     Specify vault path directly
#     --date <YYYY-MM-DD> Specify date (default: yesterday)
#     --skip-drafts      Skip platform draft generation
#     --yes              Skip confirmation prompt
#
# Output: Runs daily_runner.sh with selected parameters
# Exit codes:
#   0: Success
#   1: User cancelled or invalid input
###############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_prompt() {
    echo -e "${CYAN}[?]${NC} $*"
}

log_header() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}$*${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DAILY_RUNNER="$SCRIPT_DIR/daily_runner.sh"

# Default values
VAULT_PATH=""
DATE=""
SKIP_DRAFTS=false
SKIP_CONFIRMATION=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vault)
            VAULT_PATH="$2"
            shift 2
            ;;
        --date)
            DATE="$2"
            shift 2
            ;;
        --skip-drafts)
            SKIP_DRAFTS=true
            shift
            ;;
        --yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --vault <path>      Specify vault path directly"
            echo "  --date <YYYY-MM-DD> Specify date (default: yesterday)"
            echo "  --skip-drafts       Skip platform draft generation"
            echo "  --yes               Skip confirmation prompt"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_header "Daily Digest - Manual Runner"

# STEP 1: Select vault (if not provided)
if [ -z "$VAULT_PATH" ]; then
    log_prompt "Select vault:"
    echo "  1) Test vault (test_vault/)"
    echo "  2) Production vault (configure in .claude/settings.json)"
    echo "  3) Custom path"
    read -rp "Enter choice [1-3]: " vault_choice

    case $vault_choice in
        1)
            VAULT_PATH="$PROJECT_ROOT/test_vault"
            ;;
        2)
            # Try to read production vault from settings.json
            SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
            if [ -f "$SETTINGS_FILE" ]; then
                PROD_VAULT=$(grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" | grep -v "test_vault" | head -1 | sed 's/"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
                if [ -n "$PROD_VAULT" ] && [ -d "$PROD_VAULT" ]; then
                    VAULT_PATH="$PROD_VAULT"
                else
                    log_error "Production vault not found in settings.json or path does not exist"
                    exit 1
                fi
            else
                log_error "Settings file not found: $SETTINGS_FILE"
                exit 1
            fi
            ;;
        3)
            read -rp "Enter vault path: " VAULT_PATH
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# Validate vault path
if [ ! -d "$VAULT_PATH" ]; then
    log_error "Vault path does not exist: $VAULT_PATH"
    exit 1
fi

log_info "Selected vault: $VAULT_PATH"

# STEP 2: Select date (if not provided)
if [ -z "$DATE" ]; then
    log_prompt "Select date:"
    echo "  1) Yesterday ($(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d 2>/dev/null)) [Default]"
    echo "  2) 2 days ago ($(date -v-2d +%Y-%m-%d 2>/dev/null || date -d '2 days ago' +%Y-%m-%d 2>/dev/null))"
    echo "  3) Custom date"
    read -rp "Enter choice [1-3]: " date_choice

    case $date_choice in
        1)
            # macOS vs Linux date command compatibility
            DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d 2>/dev/null)
            ;;
        2)
            DATE=$(date -v-2d +%Y-%m-%d 2>/dev/null || date -d '2 days ago' +%Y-%m-%d 2>/dev/null)
            ;;
        3)
            read -rp "Enter date (YYYY-MM-DD): " DATE
            # Validate date format
            if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                log_error "Invalid date format. Use YYYY-MM-DD"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
fi

log_info "Selected date: $DATE"

# STEP 3: Configuration summary and confirmation
echo ""
log_header "Configuration Summary"
echo -e "${BLUE}Vault:${NC}        $VAULT_PATH"
echo -e "${BLUE}Date:${NC}         $DATE"
echo -e "${BLUE}Skip Drafts:${NC}  $SKIP_DRAFTS"
echo ""

if [ "$SKIP_CONFIRMATION" != "true" ]; then
    read -rp "Proceed with digest generation? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "Operation cancelled by user"
        exit 1
    fi
fi

# STEP 4: Execute daily runner
echo ""
log_header "Executing Daily Runner"

# Set environment variables
if [ "$SKIP_DRAFTS" = "true" ]; then
    export SKIP_DRAFTS="true"
fi

# Run daily runner
"$DAILY_RUNNER" "$VAULT_PATH" "$DATE"

RUNNER_EXIT=$?

# Report result
echo ""
if [ $RUNNER_EXIT -eq 0 ]; then
    log_header "✅ Success!"
    log_info "Daily Digest generated for $DATE"
    log_info "View: $VAULT_PATH/DailyDigest/Daily Digest $DATE.md"
    log_info "Status: $VAULT_PATH/.taskmaster/status/${DATE}_*.md"
else
    log_header "❌ Failed"
    log_error "Daily runner exited with code: $RUNNER_EXIT"
    log_error "Check logs for details"
fi

exit $RUNNER_EXIT
