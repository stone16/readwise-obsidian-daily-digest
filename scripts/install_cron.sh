#!/usr/bin/env bash

###############################################################################
# install_cron.sh
#
# Install or update cron job for automated Daily Digest generation.
#
# This script:
# 1. Validates system requirements (cron availability)
# 2. Detects vault configuration from .claude/settings.json
# 3. Creates cron entry for daily execution at 8:00 AM GMT+8
# 4. Backs up existing crontab before modification
# 5. Provides uninstall option
#
# Usage: ./install_cron.sh [options]
#   Options:
#     --vault <path>     Override vault path from settings
#     --time <HH:MM>     Custom execution time (default: 08:00)
#     --timezone <tz>    Timezone (default: GMT+8)
#     --uninstall        Remove cron job
#     --list             List current cron jobs only
#
# Output: Installs or removes cron job
# Exit codes:
#   0: Success
#   1: Invalid arguments or system requirements not met
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

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $*"
}

log_header() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}$*${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
VAULT_PATH=""
CRON_TIME="08:00"
TIMEZONE="Asia/Shanghai"  # GMT+8
UNINSTALL=false
LIST_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vault)
            VAULT_PATH="$2"
            shift 2
            ;;
        --time)
            CRON_TIME="$2"
            shift 2
            ;;
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --vault <path>     Override vault path from settings"
            echo "  --time <HH:MM>     Custom execution time (default: 08:00)"
            echo "  --timezone <tz>    Timezone (default: Asia/Shanghai GMT+8)"
            echo "  --uninstall        Remove cron job"
            echo "  --list             List current cron jobs only"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_header "Daily Digest - Cron Job Installer"

# Check if cron is available
if ! command -v crontab &> /dev/null; then
    log_error "crontab command not found. Please install cron."
    exit 1
fi

# List mode
if [ "$LIST_ONLY" = "true" ]; then
    log_info "Current cron jobs:"
    crontab -l 2>/dev/null || log_info "No cron jobs configured"
    exit 0
fi

# Identify cron job marker
CRON_MARKER="# OBSIDIAN_DAILY_DIGEST_AUTOMATION"

# Uninstall mode
if [ "$UNINSTALL" = "true" ]; then
    log_info "Removing Daily Digest cron job..."

    # Backup current crontab
    BACKUP_FILE="/tmp/crontab_backup_$(date +%s).txt"
    crontab -l > "$BACKUP_FILE" 2>/dev/null || true
    log_info "Crontab backed up to: $BACKUP_FILE"

    # Remove lines with marker
    crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab - || {
        log_warn "No cron jobs to remove or crontab is empty"
    }

    log_success "Cron job removed successfully"
    exit 0
fi

# INSTALL MODE

# Determine vault path
if [ -z "$VAULT_PATH" ]; then
    SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        VAULT_PATH=$(grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" | grep -v "test_vault" | head -1 | sed 's/"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

        if [ -z "$VAULT_PATH" ]; then
            log_error "Production vault path not found in $SETTINGS_FILE"
            log_error "Please specify vault path with --vault option"
            exit 1
        fi
    else
        log_error "Settings file not found: $SETTINGS_FILE"
        log_error "Please specify vault path with --vault option"
        exit 1
    fi
fi

# Validate vault path
if [ ! -d "$VAULT_PATH" ]; then
    log_error "Vault path does not exist: $VAULT_PATH"
    exit 1
fi

log_info "Vault path: $VAULT_PATH"

# Parse cron time
if ! [[ "$CRON_TIME" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
    log_error "Invalid time format: $CRON_TIME (use HH:MM)"
    exit 1
fi

CRON_HOUR="${BASH_REMATCH[1]}"
CRON_MINUTE="${BASH_REMATCH[2]}"

log_info "Execution time: $CRON_TIME ($TIMEZONE)"

# Path to daily runner
DAILY_RUNNER="$SCRIPT_DIR/daily_runner.sh"

if [ ! -x "$DAILY_RUNNER" ]; then
    log_error "Daily runner script not found or not executable: $DAILY_RUNNER"
    exit 1
fi

# Create cron entry
CRON_ENTRY="$CRON_MINUTE $CRON_HOUR * * * cd \"$PROJECT_ROOT\" && \"$DAILY_RUNNER\" \"$VAULT_PATH\" >> \"$VAULT_PATH/.taskmaster/status/cron.log\" 2>&1 $CRON_MARKER"

log_info "Cron entry:"
echo "  $CRON_ENTRY"

# Confirm installation
read -rp "Install this cron job? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_warn "Installation cancelled by user"
    exit 1
fi

# Backup current crontab
BACKUP_FILE="/tmp/crontab_backup_$(date +%s).txt"
crontab -l > "$BACKUP_FILE" 2>/dev/null || true
log_info "Crontab backed up to: $BACKUP_FILE"

# Remove existing Daily Digest cron jobs (if any)
TEMP_CRON=$(mktemp)
crontab -l 2>/dev/null | grep -v "$CRON_MARKER" > "$TEMP_CRON" || true

# Add new cron entry
echo "$CRON_ENTRY" >> "$TEMP_CRON"

# Install new crontab
crontab "$TEMP_CRON"
rm -f "$TEMP_CRON"

log_success "Cron job installed successfully!"

# Verify installation
log_info "Verifying installation..."
if crontab -l | grep -q "$CRON_MARKER"; then
    log_success "✅ Cron job verified"
else
    log_error "❌ Cron job not found in crontab"
    exit 1
fi

# Display next run time
log_info "═══════════════════════════════════════════════════════════"
log_info "Next scheduled run: Daily at $CRON_TIME ($TIMEZONE)"
log_info "Log file: $VAULT_PATH/.taskmaster/status/cron.log"
log_info ""
log_info "To view current cron jobs: crontab -l"
log_info "To remove cron job: ./install_cron.sh --uninstall"
log_info "═══════════════════════════════════════════════════════════"

exit 0
