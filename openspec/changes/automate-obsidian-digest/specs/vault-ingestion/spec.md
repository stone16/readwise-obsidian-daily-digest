# Spec: Vault Ingestion

## Overview
Safe discovery and reading of modified Obsidian notes from an iCloud-synced vault, with chunking support for variable daily volume.

---

## ADDED Requirements

### Requirement: Safe File Discovery
The system MUST discover modified Markdown files without risking iCloud sync conflicts or vault corruption.

#### Scenario: Discover files modified in last 24 hours
**Given** an Obsidian vault at `/Users/stometa/ObsidianVault/`
**And** the vault is synced via iCloud
**And** some notes were modified in the last 24 hours
**When** the discovery script runs
**Then** it MUST return a list of modified `.md` files
**And** it MUST exclude `.obsidian/` configuration directory
**And** it MUST exclude output directories (`DailyDigest/`, `DailyDigest/Drafts/`)
**And** it MUST exclude `.icloud` placeholder files (iCloud download-on-demand)
**And** it MUST use read-only operations (`find`, `grep`) only

#### Scenario: Handle empty results gracefully
**Given** no notes were modified in the last 24 hours
**When** the discovery script runs
**Then** it MUST return an empty list
**And** it MUST exit with status code 0 (success)
**And** it MUST log "No changes detected" to the status dashboard
**And** it MUST NOT invoke Claude Code or generate digests

---

### Requirement: Chunking for High Volume
The system MUST process notes in batches when daily volume exceeds safe context limits.

#### Scenario: Single-pass processing for low volume
**Given** 8 or fewer files were modified today
**When** the ingestion engine runs
**Then** it MUST pass all files to a single Claude Code invocation
**And** it MUST include the full file list in the prompt
**And** it MUST generate a single Daily Digest directly

#### Scenario: Batch processing for high volume
**Given** 12 files were modified today (>10 threshold)
**When** the ingestion engine runs
**Then** it MUST split files into batches of 8
**And** it MUST process each batch as a "sub-digest"
**And** it MUST generate a final synthesis digest combining all sub-digests
**And** it MUST preserve WikiLinks across batch boundaries
**And** the final digest MUST be stored as a single file

#### Scenario: Handle very high volume (50+ files)
**Given** 50 files were modified today
**When** the ingestion engine runs
**Then** it MUST split into 7 batches (8 files each, last batch has 2)
**And** it MUST generate 7 sub-digests
**And** it MUST synthesize a final digest from the 7 sub-digests
**And** the total processing time MUST be <5 minutes

---

### Requirement: iCloud Sync Safety
The system MUST detect and avoid iCloud sync conflicts.

#### Scenario: Wait for iCloud download completion
**Given** a file `Projects/Important.md` appears as `Projects/Important.md.icloud` placeholder
**When** the discovery script encounters this file
**Then** it MUST skip the file
**And** it MUST log a warning: "Skipped iCloud placeholder: Projects/Important.md"
**And** it MUST continue processing other files

#### Scenario: Read-only vault access
**Given** the automation is running
**When** any script attempts to write to the vault root or subdirectories (except outputs)
**Then** the `.claude/settings.json` permissions MUST block the write
**And** Claude Code MUST fail with a permission denied error
**And** the error MUST be logged to the status dashboard

---

### Requirement: WikiLink Context Preservation
The system MUST follow WikiLinks to gather context even if target notes weren't modified today.

#### Scenario: Follow WikiLink to unmodified note
**Given** note `Daily Notes/2024-11-23.md` was modified today
**And** it contains WikiLink `[[Project Alpha]]`
**And** `Projects/Project Alpha.md` was NOT modified today
**When** Claude Code processes the daily note
**Then** it MUST have Read permission to access `Projects/Project Alpha.md`
**And** it MUST use Claude's internal Read tool to retrieve context
**And** the Daily Digest MUST preserve the WikiLink format `[[Project Alpha]]`

#### Scenario: Detect circular WikiLinks
**Given** note A links to note B
**And** note B links back to note A
**When** Claude Code follows WikiLinks
**Then** it MUST NOT enter infinite recursion
**And** it MUST limit WikiLink depth to 2 levels (configurable)
**And** it MUST log a warning if circular references detected

---

### Requirement: File Filtering Rules
The system MUST apply consistent filtering rules across all discovery operations.

#### Scenario: Exclude system and configuration files
**Given** the vault contains:
- `.obsidian/workspace.json` (system config)
- `.git/` directory (version control)
- `.DS_Store` (macOS metadata)
- `node_modules/` (if present)

**When** the discovery script runs
**Then** it MUST exclude all files matching:
- `.obsidian/**`
- `.git/**`
- `.*` hidden files
- `node_modules/**`

**And** it MUST NOT pass these to Claude Code

#### Scenario: Include only Markdown files
**Given** the vault contains:
- `Notes/Research.md` (valid)
- `Attachments/image.png` (exclude)
- `Scripts/utility.py` (exclude)
- `README.txt` (exclude)

**When** the discovery script runs
**Then** it MUST only return files matching `*.md` extension
**And** it MUST exclude all other file types

---

## Implementation Notes

### File Discovery Command
```bash
find "$VAULT_ROOT" \
    -path "$VAULT_ROOT/.obsidian" -prune -o \
    -path "$VAULT_ROOT/.git" -prune -o \
    -path "$VAULT_ROOT/DailyDigest" -prune -o \
    -path "$VAULT_ROOT/Drafts" -prune -o \
    -path "$VAULT_ROOT/.taskmaster" -prune -o \
    -type f -name "*.md" \
    ! -name "*.icloud" \
    -mtime -1 \
    -print
```

### Batch Splitting Logic
```bash
FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)

if [ "$FILE_COUNT" -le 10 ]; then
    # Single pass
    process_single_batch "$CHANGED_FILES"
else
    # Batch processing
    BATCH_SIZE=8
    split_into_batches "$CHANGED_FILES" "$BATCH_SIZE" | while read batch; do
        process_sub_digest "$batch"
    done
    synthesize_final_digest
fi
```

### iCloud Placeholder Detection
```bash
# Check if file ends with .icloud suffix
if [[ "$file" == *.icloud ]]; then
    echo "⚠️ Skipped iCloud placeholder: ${file%.icloud}"
    continue
fi
```

---

## Dependencies
- **External**: macOS `find` command with `-mtime` support
- **Internal**: None (first capability in pipeline)
- **Configuration**: `.claude/settings.json` with vault path

---

## Testing Requirements

### Unit Tests
- [ ] Discovery script returns correct file list for 24h window
- [ ] Batch splitting logic handles edge cases (0, 1, 8, 9, 10, 50 files)
- [ ] iCloud placeholder detection skips `.icloud` files
- [ ] Filter rules exclude all specified patterns

### Integration Tests
- [ ] Process test vault with 10 sample notes
- [ ] Process test vault with 15 notes (trigger batching)
- [ ] Handle vault with no changes today
- [ ] Handle vault with iCloud placeholders

### Safety Tests
- [ ] Attempt to write to vault root (MUST fail)
- [ ] Attempt to delete files (MUST fail)
- [ ] Verify read-only access to `.obsidian/` is blocked

---

## Performance Requirements
- Discovery MUST complete within 5 seconds for <1000 total files
- Batch processing overhead MUST be <10% of total runtime
- WikiLink following MUST NOT exceed 2-level depth

---

## Error Handling
- **No files found**: Exit gracefully, log status
- **iCloud placeholder**: Skip file, log warning
- **Permission denied**: Fail fast, log to dashboard
- **find command fails**: Exit with error, alert user

---

## Related Capabilities
- **Depends on**: None (foundational)
- **Enables**: `digest-synthesis` (provides file list)
- **Coordinates with**: `orchestration` (invoked by runner script)
