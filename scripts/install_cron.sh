#!/usr/bin/env bash

###############################################################################
# install_cron.sh
#
# Install automated Daily Digest generation with catch-up for missed days.
#
# This script:
# 1. Detects OS (macOS uses launchd, Linux uses cron)
# 2. Creates wrapper script to handle missed days (laptop wake-up)
# 3. Configures daily execution at specified time
# 4. Catches up on any missed days when laptop was asleep
#
# Usage: ./install_cron.sh [options]
#   Options:
#     --vault <path>     Override vault path from settings
#     --time <HH:MM>     Custom execution time (default: 08:00)
#     --uninstall        Remove automation
#     --list             List current jobs only
#
# Output: Installs or removes automation job
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
UNINSTALL=false
LIST_ONLY=false

# Detect OS
OS_TYPE="$(uname -s)"

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
            echo "  --uninstall        Remove automation"
            echo "  --list             List current jobs only"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_header "Daily Digest - Automation Installer (with catch-up for laptop wake)"

# List mode
if [ "$LIST_ONLY" = "true" ]; then
    log_info "Current automation jobs:"
    if [ "$OS_TYPE" = "Darwin" ]; then
        PLIST_FILE="$HOME/Library/LaunchAgents/com.obsidian.dailydigest.plist"
        if [ -f "$PLIST_FILE" ]; then
            log_info "LaunchAgent: $PLIST_FILE"
            launchctl list | grep obsidian.dailydigest || log_info "Not currently loaded"
        else
            log_info "No LaunchAgent configured"
        fi
    else
        crontab -l 2>/dev/null || log_info "No cron jobs configured"
    fi
    exit 0
fi

# Uninstall mode
if [ "$UNINSTALL" = "true" ]; then
    log_info "Removing Daily Digest automation..."

    if [ "$OS_TYPE" = "Darwin" ]; then
        # macOS: Remove LaunchAgent
        PLIST_FILE="$HOME/Library/LaunchAgents/com.obsidian.dailydigest.plist"
        WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/daily_catchup_wrapper.sh"

        if [ -f "$PLIST_FILE" ]; then
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            log_success "LaunchAgent removed"
        fi

        if [ -f "$WRAPPER_SCRIPT" ]; then
            rm -f "$WRAPPER_SCRIPT"
            log_success "Wrapper script removed"
        fi
    else
        # Linux: Remove cron job
        CRON_MARKER="# OBSIDIAN_DAILY_DIGEST_AUTOMATION"
        BACKUP_FILE="/tmp/crontab_backup_$(date +%s).txt"
        crontab -l > "$BACKUP_FILE" 2>/dev/null || true
        log_info "Crontab backed up to: $BACKUP_FILE"

        crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab - || {
            log_warn "No cron jobs to remove or crontab is empty"
        }

        WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/daily_catchup_wrapper.sh"
        if [ -f "$WRAPPER_SCRIPT" ]; then
            rm -f "$WRAPPER_SCRIPT"
            log_success "Wrapper script removed"
        fi
    fi

    log_success "Automation removed successfully"
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

HOUR="${BASH_REMATCH[1]}"
MINUTE="${BASH_REMATCH[2]}"

log_info "Execution time: $CRON_TIME (with catch-up for missed days)"

# Path to daily runner
DAILY_RUNNER="$SCRIPT_DIR/daily_runner.sh"

if [ ! -x "$DAILY_RUNNER" ]; then
    log_error "Daily runner script not found or not executable: $DAILY_RUNNER"
    exit 1
fi

# Create wrapper script for catch-up functionality
WRAPPER_SCRIPT="$SCRIPT_DIR/daily_catchup_wrapper.sh"

log_info "Creating catch-up wrapper script..."

cat > "$WRAPPER_SCRIPT" <<'WRAPPER_EOF'
#!/usr/bin/env bash

###############################################################################
# daily_catchup_wrapper.sh
#
# Wrapper that catches up on missed Daily Digest runs.
# Useful for laptops that may be asleep during scheduled time.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_RUNNER="$SCRIPT_DIR/daily_runner.sh"
VAULT_PATH="$1"

# Get dates to process (yesterday and any missed days)
# Check last 3 days for any missing digests, starting from yesterday
DATES_TO_PROCESS=()

for days_ago in 1 2 3; do
    # macOS vs Linux date compatibility
    CHECK_DATE=$(date -v-${days_ago}d +%Y-%m-%d 2>/dev/null || date -d "${days_ago} days ago" +%Y-%m-%d 2>/dev/null)

    # Check if digest exists for this date
    DIGEST_FILE="$VAULT_PATH/DailyDigest/Daily Digest $CHECK_DATE.md"

    if [ ! -f "$DIGEST_FILE" ]; then
        DATES_TO_PROCESS+=("$CHECK_DATE")
    fi
done

# Process each missing date
if [ ${#DATES_TO_PROCESS[@]} -eq 0 ]; then
    echo "[INFO] All digests up to date, nothing to process"
    exit 0
fi

echo "[INFO] Catching up on ${#DATES_TO_PROCESS[@]} missed digest(s): ${DATES_TO_PROCESS[*]}"

for process_date in "${DATES_TO_PROCESS[@]}"; do
    echo "[INFO] Processing digest for $process_date..."
    "$DAILY_RUNNER" "$VAULT_PATH" "$process_date" || {
        echo "[WARN] Failed to process digest for $process_date"
    }
done

echo "[INFO] Catch-up complete"
WRAPPER_EOF

# Make wrapper executable
chmod +x "$WRAPPER_SCRIPT"
log_success "Wrapper script created: $WRAPPER_SCRIPT"

# Platform-specific installation
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: Use LaunchAgent
    log_info "Detected macOS - using LaunchAgent"

    PLIST_FILE="$HOME/Library/LaunchAgents/com.obsidian.dailydigest.plist"

    # Ensure LaunchAgents directory exists
    mkdir -p "$HOME/Library/LaunchAgents"

    # Create plist file
    cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.obsidian.dailydigest</string>

    <key>ProgramArguments</key>
    <array>
        <string>$WRAPPER_SCRIPT</string>
        <string>$VAULT_PATH</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$HOUR</integer>
        <key>Minute</key>
        <integer>$MINUTE</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$VAULT_PATH/.taskmaster/status/launchd.log</string>

    <key>StandardErrorPath</key>
    <string>$VAULT_PATH/.taskmaster/status/launchd-error.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

    log_info "LaunchAgent plist created: $PLIST_FILE"

    # Confirm installation
    read -rp "Install LaunchAgent? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "Installation cancelled by user"
        exit 1
    fi

    # Load the LaunchAgent
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"

    log_success "LaunchAgent installed and loaded!"
    log_info "═══════════════════════════════════════════════════════════"
    log_info "Next scheduled run: Daily at $CRON_TIME"
    log_info "Catch-up: Checks last 3 days for missing digests on each run"
    log_info "Log file: $VAULT_PATH/.taskmaster/status/launchd.log"
    log_info ""
    log_info "To view status: launchctl list | grep obsidian"
    log_info "To uninstall: ./install_cron.sh --uninstall"
    log_info "═══════════════════════════════════════════════════════════"

else
    # Linux: Use cron with wrapper
    log_info "Detected Linux - using cron"

    if ! command -v crontab &> /dev/null; then
        log_error "crontab command not found. Please install cron."
        exit 1
    fi

    CRON_MARKER="# OBSIDIAN_DAILY_DIGEST_AUTOMATION"
    CRON_ENTRY="$MINUTE $HOUR * * * \"$WRAPPER_SCRIPT\" \"$VAULT_PATH\" >> \"$VAULT_PATH/.taskmaster/status/cron.log\" 2>&1 $CRON_MARKER"

    log_info "Cron entry:"
    echo "  $CRON_ENTRY"

    # Confirm installation
    read -rp "Install cron job? [y/N]: " confirm
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

    log_info "═══════════════════════════════════════════════════════════"
    log_info "Next scheduled run: Daily at $CRON_TIME"
    log_info "Catch-up: Checks last 3 days for missing digests on each run"
    log_info "Log file: $VAULT_PATH/.taskmaster/status/cron.log"
    log_info ""
    log_info "To view cron jobs: crontab -l"
    log_info "To uninstall: ./install_cron.sh --uninstall"
    log_info "═══════════════════════════════════════════════════════════"
fi

exit 0
