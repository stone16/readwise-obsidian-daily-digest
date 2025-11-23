# Spec: Orchestration

## Overview
Dual execution modes (cron scheduling + manual invocation) with environment setup and error handling for the automation pipeline.

---

## ADDED Requirements

### Requirement: Dual Execution Modes
The system MUST support both automated (cron) and manual (on-demand) execution.

#### Scenario: Install cron job for automated execution
**Given** the user runs `./install_cron.sh`
**When** the installation script executes
**Then** it MUST add a cron entry: `55 23 * * * /path/to/daily_runner.sh`
**And** it MUST verify cron service is enabled on macOS
**And** it MUST create log directory `~/.taskmaster/logs/` if missing
**And** it MUST set executable permissions on `daily_runner.sh`
**And** it MUST print confirmation: "✅ Cron job installed. Will run daily at 08:00."

#### Scenario: Manual execution with date override
**Given** the user runs `./run_manual.sh 2024-11-15`
**When** the script executes
**Then** it MUST process files modified on 2024-11-15 (not today)
**And** it MUST generate digest named `Daily Digest 2024-11-15.md`
**And** it MUST display real-time progress to stdout
**And** it MUST exit with status code 0 on success, 1 on failure

#### Scenario: Manual execution without date (default to today)
**Given** the user runs `./run_manual.sh` (no date argument)
**When** the script executes
**Then** it MUST default to today's date
**And** it MUST process files modified in the last 24 hours
**And** it MUST generate digest for today's date

---

### Requirement: Environment Setup
The system MUST configure the execution environment correctly for both cron and manual modes.

#### Scenario: Source shell environment in cron context
**Given** cron runs with minimal PATH (typically `/usr/bin:/bin`)
**When** `daily_runner.sh` is invoked by cron
**Then** it MUST explicitly source `~/.zshrc` or `~/.bash_profile`
**And** it MUST export PATH to include `/usr/local/bin`, `/opt/homebrew/bin`
**And** it MUST verify `claude` command is accessible: `which claude`
**And** it MUST fail fast if `claude` not found, logging error

#### Scenario: Validate Claude authentication before execution
**Given** the script is about to invoke Claude Code
**When** it checks authentication status
**Then** it MUST verify `~/.claude/auth.json` exists
**And** it MUST test with `claude -p "test" --dry-run` (if available)
**And** it MUST fail with error if authentication invalid
**And** the error MUST instruct user to run `claude login`

---

### Requirement: Script Composition and Modularity
The system MUST organize scripts modularly for maintainability and reuse.

#### Scenario: Core runner script invokes modular components
**Given** `daily_runner.sh` is the main orchestrator
**When** it executes the pipeline
**Then** it MUST call sub-scripts in sequence:
1. `scripts/ingestion/discover_changes.sh` → returns file list
2. `scripts/synthesis/generate_digest.sh` → creates Daily Digest
3. `scripts/distribution/generate_drafts.sh` → creates platform drafts
4. `scripts/monitoring/write_status.sh` → updates status dashboard

**And** it MUST pass outputs of step N as inputs to step N+1
**And** it MUST halt pipeline if any step fails (exit code ≠ 0)
**And** it MUST log each step's start/end time and status

#### Scenario: Modular scripts are independently testable
**Given** the script `scripts/ingestion/discover_changes.sh` exists
**When** a developer runs it standalone: `./discover_changes.sh`
**Then** it MUST work without requiring `daily_runner.sh`
**And** it MUST accept vault path as argument or use default
**And** it MUST output results to stdout for piping

---

### Requirement: Error Handling and Recovery
The system MUST handle failures gracefully and provide actionable feedback.

#### Scenario: Handle "no changes detected" gracefully
**Given** no files were modified in the last 24 hours
**When** the ingestion script returns empty file list
**Then** the runner MUST log: "No changes detected. Exiting."
**And** it MUST skip digest generation and draft creation
**And** it MUST write status: "SKIPPED - No changes"
**And** it MUST exit with status code 0 (success, not error)

#### Scenario: Handle Claude API failures with retry
**Given** Claude Code invocation fails with network timeout
**When** the synthesis script detects the failure (exit code ≠ 0)
**Then** it MUST retry once after 10-second delay
**And** if retry fails, it MUST log full error to `~/.taskmaster/logs/error.log`
**And** it MUST write status: "FAILED - Claude API timeout"
**And** it MUST exit with status code 1

#### Scenario: Handle permission denied errors
**Given** Claude Code attempts write to blocked location (e.g., vault root)
**When** `.claude/settings.json` blocks the operation
**Then** the script MUST capture stderr output
**And** it MUST log error: "Permission denied - check .claude/settings.json"
**And** it MUST write status: "FAILED - Permission error"
**And** it MUST exit with status code 1

---

### Requirement: Logging and Observability
The system MUST provide comprehensive logging for debugging and audit.

#### Scenario: Log all operations to timestamped file
**Given** the runner script is executing
**When** any operation occurs (discovery, synthesis, draft gen)
**Then** it MUST log to `~/.taskmaster/logs/YYYY-MM-DD.log`
**And** each log entry MUST include:
- Timestamp: `[2024-11-23 08:00:42]`
- Level: `INFO`, `WARN`, `ERROR`
- Component: `[INGESTION]`, `[SYNTHESIS]`, `[DRAFTS]`
- Message: Descriptive text

**And** stdout/stderr from Claude Code MUST be captured to log

#### Scenario: Rotate logs to prevent disk bloat
**Given** log files accumulate over time
**When** the runner checks log directory size
**Then** it SHOULD delete logs older than 30 days (configurable)
**And** it MUST keep at least the last 7 days regardless of size

---

### Requirement: Idempotency and Safe Re-runs
The system MUST allow safe re-execution without side effects.

#### Scenario: Re-running for same date overwrites outputs
**Given** `Daily Digest 2024-11-23.md` already exists
**When** the user runs `./run_manual.sh 2024-11-23` again
**Then** it MUST overwrite the existing digest file
**And** it MUST overwrite platform drafts in `DailyDigest/Drafts/2024-11-23/`
**And** it MUST log: "Overwriting existing digest for 2024-11-23"
**And** it MUST NOT create versioned copies (digest_v2.md)

#### Scenario: Dry-run mode for testing (optional)
**Given** the user runs `./run_manual.sh --dry-run`
**When** the script executes
**Then** it MUST perform discovery and log what *would* be processed
**And** it MUST NOT invoke Claude Code
**And** it MUST NOT write any output files
**And** it MUST print summary: "Dry run: Would process 12 files"

---

## Implementation Notes

### Main Orchestrator: `daily_runner.sh`
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Environment setup
export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin
source "$HOME/.zshrc"

# Configuration
VAULT_ROOT="/Users/stometa/ObsidianVault"
DATE_STR="${1:-$(date +%Y-%m-%d)}"
LOG_FILE="$HOME/.taskmaster/logs/${DATE_STR}.log"

mkdir -p "$(dirname "$LOG_FILE")"

# Logging helper
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$LOG_FILE"
}

# Main pipeline
log "INFO" "Starting automation for $DATE_STR"

# Step 1: Discovery
CHANGED_FILES=$(scripts/ingestion/discover_changes.sh "$VAULT_ROOT" "$DATE_STR")
if [ -z "$CHANGED_FILES" ]; then
    log "INFO" "No changes detected. Exiting."
    scripts/monitoring/write_status.sh "SKIPPED" "No changes"
    exit 0
fi

# Step 2: Synthesis
log "INFO" "Generating Daily Digest..."
if ! scripts/synthesis/generate_digest.sh "$VAULT_ROOT" "$DATE_STR" "$CHANGED_FILES"; then
    log "ERROR" "Digest generation failed"
    scripts/monitoring/write_status.sh "FAILED" "Synthesis error"
    exit 1
fi

# Step 3: Platform Drafts
log "INFO" "Generating platform drafts..."
if ! scripts/distribution/generate_drafts.sh "$VAULT_ROOT" "$DATE_STR"; then
    log "WARN" "Draft generation failed (non-critical)"
    # Continue anyway - digest is the core output
fi

# Step 4: Status Update
scripts/monitoring/write_status.sh "SUCCESS" "Processed $(echo "$CHANGED_FILES" | wc -l) files"
log "INFO" "Automation completed successfully"
```

### Manual Runner: `run_manual.sh`
```bash
#!/bin/bash

# User-friendly wrapper with progress output
echo "🚀 Starting manual Obsidian Daily Digest generation..."

DATE_ARG="${1:-$(date +%Y-%m-%d)}"
echo "📅 Processing date: $DATE_ARG"

# Run main orchestrator with real-time output
./daily_runner.sh "$DATE_ARG" 2>&1 | tee /dev/tty

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Generation complete! Check DailyDigest/"
else
    echo "❌ Generation failed. Check ~/.taskmaster/logs/ for details"
    exit 1
fi
```

### Cron Installer: `install_cron.sh`
```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRON_ENTRY="55 23 * * * $SCRIPT_DIR/daily_runner.sh >> $HOME/.taskmaster/logs/cron.log 2>&1"

# Check if already installed
if crontab -l 2>/dev/null | grep -q "daily_runner.sh"; then
    echo "⚠️  Cron job already installed"
    exit 0
fi

# Install
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
echo "✅ Cron job installed. Will run daily at 08:00"
echo "📋 To verify: crontab -l"
```

---

## Dependencies
- **External**: macOS cron, zsh/bash shell, Unix utilities
- **Internal**: All capability scripts (ingestion, synthesis, drafts, monitoring)
- **Configuration**: `.claude/settings.json`, vault path

---

## Testing Requirements

### Unit Tests
- [ ] Environment variables set correctly
- [ ] Logging function writes to correct file
- [ ] Error handling halts pipeline on failure
- [ ] Date override argument parsed correctly

### Integration Tests
- [ ] Full pipeline runs end-to-end for test vault
- [ ] Cron job triggers correctly (test with `* * * * *` every minute)
- [ ] Manual runner displays progress output
- [ ] Dry-run mode doesn't create files

### Safety Tests
- [ ] Pipeline stops if Claude auth missing
- [ ] Re-run on same date overwrites safely
- [ ] Failure in step N prevents step N+1 execution

---

## Performance Requirements
- Full pipeline (discovery → synthesis → drafts → status) MUST complete <3 minutes for typical day
- Script startup overhead MUST be <1 second
- Log file writes MUST not block main execution

---

## Error Handling
- **Claude not found in PATH**: Fail fast with setup instructions
- **Authentication expired**: Fail with "Run 'claude login'"
- **Disk full**: Fail with clear error (rare but critical)
- **Network timeout**: Retry once, then fail

---

## Related Capabilities
- **Depends on**: All other capabilities (orchestrates entire pipeline)
- **Enables**: End-to-end automation and manual catch-up workflows
- **Coordinates with**: `monitoring` (writes execution status)
