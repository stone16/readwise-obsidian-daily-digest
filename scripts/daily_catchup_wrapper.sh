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

# Get dates to process (today and any missed days)
# Check last 3 days for any missing digests
DATES_TO_PROCESS=()

for days_ago in 0 1 2; do
    if [ "$days_ago" -eq 0 ]; then
        CHECK_DATE=$(date +%Y-%m-%d)
    else
        # macOS vs Linux date compatibility
        CHECK_DATE=$(date -v-${days_ago}d +%Y-%m-%d 2>/dev/null || date -d "${days_ago} days ago" +%Y-%m-%d 2>/dev/null)
    fi

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
