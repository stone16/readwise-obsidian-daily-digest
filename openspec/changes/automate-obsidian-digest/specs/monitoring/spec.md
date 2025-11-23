# Spec: Monitoring

## Overview
Markdown-based status dashboard integrated into the Obsidian vault for run history, failure tracking, and observability.

---

## ADDED Requirements

### Requirement: Markdown Status Files
The system MUST track execution status using markdown files within the vault.

#### Scenario: Create status file for each run
**Given** the automation completes (success or failure)
**When** the monitoring script writes status
**Then** it MUST create file: `.taskmaster/status/YYYY-MM-DD_[status].md`
**And** status MUST be one of: `success`, `failed`, `skipped`
**And** the file MUST include:
- Run timestamp
- Duration
- Files processed count
- Outputs generated (with WikiLinks)
- Logs excerpt (last 20 lines)

**And** the directory `.taskmaster/status/` MUST be created if missing

#### Scenario: Maintain symlink to latest run
**Given** a new status file is created: `2024-11-23_success.md`
**When** the monitoring script completes
**Then** it MUST update symlink: `.taskmaster/status/latest_run.md → 2024-11-23_success.md`
**And** the symlink MUST be readable in Obsidian as `[[.taskmaster/status/latest_run]]`

---

### Requirement: Status File Format
The system MUST use a consistent, Obsidian-friendly markdown format for status files.

#### Scenario: Success status file structure
**Given** the automation completed successfully on 2024-11-23
**When** the status file is generated
**Then** it MUST follow this structure:
```markdown
---
status: success
date: 2024-11-23
duration_seconds: 42
files_processed: 12
---

# Run Status: 2024-11-23

**Status**: ✅ Success
**Duration**: 42s
**Start Time**: 2024-11-23 08:00:15
**End Time**: 2024-11-23 08:00:57

## Files Processed
- 12 notes modified (2 batches)

## Outputs Generated
- [[DailyDigest/Daily Digest 2024-11-23]]
- [[DailyDigest/Drafts/2024-11-23/xiaohongshu_draft]]
- [[DailyDigest/Drafts/2024-11-23/wechat_draft]]
- [[DailyDigest/Drafts/2024-11-23/twitter_draft]]

## Execution Log (Last 20 Lines)
\`\`\`
[2024-11-23 08:00:15] [INFO] Starting automation
[2024-11-23 08:00:18] [INGESTION] Found 12 changed files
...
[2024-11-23 08:00:57] [INFO] Automation completed
\`\`\`

## Next Actions
- Review [[DailyDigest/Daily Digest 2024-11-23]]
- Edit platform drafts if needed
```

**And** WikiLinks MUST be functional when opened in Obsidian

#### Scenario: Failed status file structure
**Given** the automation failed due to Claude API timeout
**When** the status file is generated
**Then** it MUST follow this structure:
```markdown
---
status: failed
date: 2024-11-23
error_type: claude_api_timeout
---

# Run Status: 2024-11-23

**Status**: ❌ Failed
**Error**: Claude API timeout
**Duration**: 28s (before failure)

## Error Details
\`\`\`
[2024-11-23 08:00:42] [ERROR] Claude Code invocation failed
Exit code: 1
Stderr: timeout waiting for response after 30s
\`\`\`

## Troubleshooting
- Check network connectivity
- Verify Claude API status: https://status.anthropic.com
- Retry manually: `./run_manual.sh 2024-11-23`

## Full Log
See: `~/.taskmaster/logs/2024-11-23.log`
```

**And** troubleshooting section MUST provide actionable next steps

---

### Requirement: Summary Dashboard
The system MUST maintain an aggregated summary of recent runs.

#### Scenario: Update summary file with run statistics
**Given** multiple runs have occurred over the past week
**When** a new run completes
**Then** the monitoring script MUST update `.taskmaster/status/summary.md`
**And** the summary MUST include:
- Last 7 days run history (table format)
- Success rate percentage
- Average processing time
- Total files processed this week

**Structure**:
```markdown
# Automation Status Summary

**Last Updated**: 2024-11-23 23:56:00

## Recent Runs (Last 7 Days)

| Date       | Status  | Files | Duration | Outputs |
|------------|---------|-------|----------|---------|
| 2024-11-23 | ✅ Success | 12    | 42s      | [[2024-11-23_success]] |
| 2024-11-22 | ✅ Success | 8     | 28s      | [[2024-11-22_success]] |
| 2024-11-21 | ⏭️  Skipped | 0     | 1s       | [[2024-11-21_skipped]] |
| 2024-11-20 | ❌ Failed  | 15    | 31s      | [[2024-11-20_failed]] |

## Statistics
- **Success Rate**: 75% (6/8 runs)
- **Avg Processing Time**: 35s
- **Total Files This Week**: 142

## Quick Links
- [[Latest Run|.taskmaster/status/latest_run]]
- [[Failed Runs Archive|.taskmaster/status/failed/]]
```

**And** the table MUST be sortable and readable in Obsidian

---

### Requirement: Failed Run Archive
The system MUST organize failed runs for easy debugging.

#### Scenario: Copy failed run details to archive
**Given** a run fails on 2024-11-20
**When** the monitoring script writes the failure status
**Then** it MUST also copy the status file to `.taskmaster/status/failed/2024-11-20_failed.md`
**And** it MUST append full log excerpt (not just last 20 lines)
**And** it MUST create `.taskmaster/status/failed/index.md` listing all failures

**Index structure**:
```markdown
# Failed Runs Archive

## All Failures

### 2024-11-20 - Claude API Timeout
[[2024-11-20_failed]]
- **Error**: Claude API timeout after 30s
- **Files**: 15 notes
- **Retry**: Succeeded on 2024-11-21 manual run

### 2024-11-18 - Permission Denied
[[2024-11-18_failed]]
- **Error**: Write permission denied to vault root
- **Fix**: Updated .claude/settings.json, retried successfully
```

---

### Requirement: Obsidian Integration
The system MUST ensure status files integrate seamlessly with Obsidian workflows.

#### Scenario: Status files appear in Obsidian graph
**Given** status files are created in `.taskmaster/status/`
**When** the user opens Obsidian graph view
**Then** status files MUST appear as nodes
**And** WikiLinks to Daily Digests MUST create visible edges
**And** failed runs SHOULD be distinguishable (via tags or folder structure)

#### Scenario: Quick access via Obsidian sidebar
**Given** the user wants to check automation status
**When** they navigate in Obsidian file explorer
**Then** they MUST see `.taskmaster/status/` directory
**And** they MUST be able to pin `latest_run.md` to starred files
**And** they MUST be able to open `summary.md` as a dashboard

---

### Requirement: Cleanup and Maintenance
The system MUST prevent unbounded growth of status files.

#### Scenario: Archive old success status files
**Given** status files accumulate over time
**When** the monitoring script runs
**Then** it SHOULD move success files older than 30 days to `.taskmaster/status/archive/YYYY-MM/`
**And** it MUST keep failed runs indefinitely (for debugging)
**And** it MUST update summary to reflect archived runs

#### Scenario: Prune log excerpts from archived files
**Given** archived status files contain full log excerpts
**When** archival occurs
**Then** the monitoring script SHOULD truncate logs to last 10 lines (save space)
**And** it MUST preserve frontmatter and summary sections
**And** it MUST add note: "Full logs archived to ~/.taskmaster/logs/archive/"

---

## Implementation Notes

### Status Writer Script: `scripts/monitoring/write_status.sh`
```bash
#!/bin/bash

STATUS="$1"  # success, failed, skipped
MESSAGE="$2"  # Details message
DATE="${3:-$(date +%Y-%m-%d)}"
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

STATUS_DIR=".taskmaster/status"
STATUS_FILE="$STATUS_DIR/${DATE}_${STATUS}.md"

mkdir -p "$STATUS_DIR"

# Frontmatter
cat > "$STATUS_FILE" <<EOF
---
status: $STATUS
date: $DATE
timestamp: $TIMESTAMP
---

# Run Status: $DATE

**Status**: $(case $STATUS in
    success) echo "✅ Success" ;;
    failed) echo "❌ Failed" ;;
    skipped) echo "⏭️  Skipped" ;;
esac)
**Message**: $MESSAGE
**Timestamp**: $TIMESTAMP

## Details
$MESSAGE

## Execution Log
\`\`\`
$(tail -20 "$HOME/.taskmaster/logs/${DATE}.log")
\`\`\`
EOF

# Update symlink
ln -sf "$(basename "$STATUS_FILE")" "$STATUS_DIR/latest_run.md"

# Update summary (simplified for MVP)
echo "Updated status: $STATUS_FILE"
```

### Summary Updater (called by write_status.sh)
```bash
update_summary() {
    SUMMARY_FILE=".taskmaster/status/summary.md"

    # Regenerate summary from recent status files
    cat > "$SUMMARY_FILE" <<EOF
# Automation Status Summary

**Last Updated**: $(date +'%Y-%m-%d %H:%M:%S')

## Recent Runs (Last 7 Days)

| Date | Status | Details |
|------|--------|---------|
$(ls -t .taskmaster/status/*.md | grep -v summary | head -7 | while read f; do
    DATE=$(basename $f | cut -d_ -f1)
    STATUS=$(basename $f | cut -d_ -f2 | cut -d. -f1)
    echo "| $DATE | $STATUS | [[$f]] |"
done)

## Quick Links
- [[Latest Run|.taskmaster/status/latest_run]]
EOF
}
```

---

## Dependencies
- **External**: Unix utilities (ln, tail, ls)
- **Internal**: All capabilities (writes status after each run)
- **Configuration**: Vault path for status directory location

---

## Testing Requirements

### Unit Tests
- [ ] Status file created with correct format
- [ ] Symlink updated to latest run
- [ ] Frontmatter YAML is valid
- [ ] WikiLinks are functional

### Integration Tests
- [ ] Status visible in Obsidian graph
- [ ] Summary table renders correctly
- [ ] Failed runs archived properly

### Manual Tests
- [ ] Status files readable in Obsidian
- [ ] WikiLinks to digests clickable
- [ ] Graph view shows status nodes

---

## Performance Requirements
- Status file write MUST complete <1 second
- Summary regeneration MUST complete <2 seconds
- No performance impact on Obsidian vault sync

---

## Error Handling
- **Directory creation fails**: Log warning, continue
- **Symlink fails**: Non-critical, log error
- **Log file missing**: Create empty status, note in message

---

## Related Capabilities
- **Depends on**: None (writes status for all other capabilities)
- **Enables**: Observability and debugging workflows
- **Coordinates with**: `orchestration` (invoked at end of pipeline)
