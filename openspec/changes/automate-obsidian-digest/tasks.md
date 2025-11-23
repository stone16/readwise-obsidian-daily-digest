# Tasks: Automate Obsidian Daily Digest

Ordered list of implementation tasks with validation criteria and dependencies.

---

## Phase 1: Test Vault Setup (Foundation)

### 1. Create test vault structure
**What**: Set up isolated test vault for safe development and validation
**Why**: Must validate system before touching production iCloud vault
**Validation**:
- [ ] Test vault created at `/Users/stometa/dev/obsidian_daily_digest/test_vault/`
- [ ] Directory structure matches production:
  ```
  test_vault/
    ├── Daily Notes/
    ├── Projects/
    ├── DailyDigest/
    ├── DailyDigest/Drafts/
    └── .taskmaster/status/
  ```
- [ ] Test vault opens correctly in Obsidian
**Dependencies**: None
**Estimated Time**: 5 minutes

---

### 2. Populate test vault with sample notes
**What**: Create 12 sample markdown notes with various content types
**Why**: Need realistic test data covering common patterns
**Validation**:
- [ ] 10 daily notes created in `Daily Notes/` folder
- [ ] 2 project notes created in `Projects/` folder
- [ ] Notes contain:
  - WikiLinks (e.g., `[[Project Alpha]]`)
  - Todo items (e.g., `- [ ] Task`)
  - Tags (e.g., `#learning`, `#project`)
  - Code blocks and technical content
- [ ] File modification times set to "today" using `touch`
**Dependencies**: Task 1
**Estimated Time**: 15 minutes

---

## Phase 2: Permission and Security Configuration

### 3. Create `.claude/settings.json` with strict permissions
**What**: Configure project-level Claude Code permissions for safety
**Why**: Prevent accidental vault corruption or data exfiltration
**Validation**:
- [ ] File exists at `/Users/stometa/dev/obsidian_daily_digest/.claude/settings.json`
- [ ] Contains read-only vault access configuration
- [ ] Write permissions limited to:
  - `DailyDigest/**`
  - `DailyDigest/Drafts/**`
  - `.taskmaster/status/**`
- [ ] Deny list includes: `rm`, `mv`, `curl`, `wget`, `ssh`, `.obsidian/**`
- [ ] File permissions: `chmod 600 .claude/settings.json`
**Dependencies**: None
**Estimated Time**: 10 minutes

---

### 4. Create CLAUDE.md system prompt
**What**: Define "Vault Architect" behavior and synthesis rules
**Why**: Guide Claude Code to generate correct digest format
**Validation**:
- [ ] File exists at `/Users/stometa/dev/obsidian_daily_digest/test_vault/CLAUDE.md`
- [ ] Contains sections:
  - Role definition ("Vault Architect")
  - Core directives (read-only, WikiLink preservation, semantic grouping)
  - Tone guidelines (objective, analytical, concise)
- [ ] Claude Code loads file when run from test_vault directory (verify with `cd test_vault && claude -p "test"`)
**Dependencies**: Task 1
**Estimated Time**: 10 minutes

---

## Phase 3: Core Script Development

### 5. Implement file discovery script
**What**: Create `scripts/ingestion/discover_changes.sh`
**Why**: Safely identify modified files without risking vault corruption
**Validation**:
- [ ] Script exists: `scripts/ingestion/discover_changes.sh`
- [ ] Accepts arguments: `<vault_path> <date>`
- [ ] Uses `find` with correct filters:
  - `-mtime -1` for last 24h
  - Excludes: `.obsidian/`, `Drafts/`, `DailyDigest/`, `.taskmaster/`
  - Only `*.md` files
  - Skips `.icloud` placeholders
- [ ] Returns file list to stdout (one per line)
- [ ] Handles empty results gracefully (exit 0)
- [ ] Executable: `chmod +x scripts/ingestion/discover_changes.sh`
**Dependencies**: Task 2 (needs test data)
**Estimated Time**: 30 minutes
**Test Command**: `./scripts/ingestion/discover_changes.sh test_vault $(date +%Y-%m-%d)`

---

### 6. Implement chunking logic
**What**: Add batch splitting to discovery script for >10 files
**Why**: Prevent context overflow with high daily volume
**Validation**:
- [ ] Script detects file count > 10
- [ ] Splits into batches of 8 files
- [ ] Outputs batch indicator: `BATCH_1: file1.md file2.md ...`
- [ ] Test with 12 sample files produces 2 batches
**Dependencies**: Task 5
**Estimated Time**: 20 minutes
**Test Command**: Create 15 test files, verify batching output

---

### 7. Create digest generation script
**What**: Implement `scripts/synthesis/generate_digest.sh`
**Why**: Core value - semantic synthesis with Claude Code
**Validation**:
- [ ] Script exists: `scripts/synthesis/generate_digest.sh`
- [ ] Accepts arguments: `<vault_path> <date> <file_list>`
- [ ] Constructs prompt combining CLAUDE.md rules + file list
- [ ] Invokes: `claude -p "$PROMPT" --allowedTools "Read,Write,Bash"`
- [ ] Generates file: `DailyDigest/Daily Digest YYYY-MM-DD.md`
- [ ] Output follows schema:
  - Frontmatter YAML
  - 📊 Snapshot section
  - 🧠 Synthesis section
  - 📝 Highlights section
  - 🔗 Connections section
- [ ] WikiLinks preserved (not converted to markdown links)
**Dependencies**: Task 4 (CLAUDE.md), Task 5 (file list)
**Estimated Time**: 45 minutes
**Test Command**: Process 5 test notes, verify digest structure

---

### 8. Implement batch synthesis workflow
**What**: Extend digest script to handle multi-batch processing
**Why**: Support 10+ files per day safely
**Validation**:
- [ ] Detects `BATCH_` markers in file list
- [ ] Generates sub-digests for each batch
- [ ] Saves sub-digests to temp location: `.taskmaster/tmp/sub_digest_N.md`
- [ ] Final synthesis step combines all sub-digests
- [ ] Deletes temporary sub-digests after synthesis
- [ ] Final output matches single-batch format
**Dependencies**: Task 6 (chunking), Task 7 (single digest)
**Estimated Time**: 40 minutes
**Test Command**: Process 12 files (2 batches), verify final digest

---

## Phase 4: Content Distribution

### 9. Create prompt templates for platforms
**What**: Write platform-specific style guides in `prompts/` directory
**Why**: Enable multi-platform content transformation
**Validation**:
- [ ] Files created:
  - `prompts/xiaohongshu.md`
  - `prompts/wechat.md`
  - `prompts/twitter.md`
- [ ] Each template contains:
  - Role definition
  - Input specification
  - Requirements (structure, tone, formatting)
  - Example patterns
- [ ] Templates are markdown files (user-editable)
**Dependencies**: None
**Estimated Time**: 30 minutes

---

### 10. Implement draft generation script
**What**: Create `scripts/distribution/generate_drafts.sh`
**Why**: Transform Daily Digest into platform-specific content
**Validation**:
- [ ] Script exists: `scripts/distribution/generate_drafts.sh`
- [ ] Accepts arguments: `<vault_path> <date>`
- [ ] Reads Daily Digest from `DailyDigest/Daily Digest <date>.md`
- [ ] Loads each prompt template
- [ ] Invokes Claude Code 3 times (one per platform)
- [ ] Generates outputs:
  - `DailyDigest/Drafts/<date>/xiaohongshu_draft.md`
  - `DailyDigest/Drafts/<date>/wechat_draft.md`
  - `DailyDigest/Drafts/<date>/twitter_draft.md`
- [ ] Each draft includes frontmatter with `generated_from` WikiLink
**Dependencies**: Task 7 (digest exists), Task 9 (templates)
**Estimated Time**: 40 minutes
**Test Command**: Generate drafts from test digest, verify formats

---

## Phase 5: Monitoring and Status Tracking

### 11. Create status dashboard script
**What**: Implement `scripts/monitoring/write_status.sh`
**Why**: Provide visibility into automation runs
**Validation**:
- [ ] Script exists: `scripts/monitoring/write_status.sh`
- [ ] Accepts arguments: `<status> <message> [date]`
- [ ] Creates status file: `.taskmaster/status/<date>_<status>.md`
- [ ] Status file includes:
  - Frontmatter (status, date, timestamp)
  - Formatted status section
  - Last 20 lines of execution log
  - WikiLinks to generated outputs
- [ ] Updates symlink: `latest_run.md → <date>_<status>.md`
- [ ] Status types: success, failed, skipped
**Dependencies**: None
**Estimated Time**: 30 minutes
**Test Command**: `./scripts/monitoring/write_status.sh success "Test run" 2024-11-23`

---

### 12. Implement summary dashboard
**What**: Create aggregated summary in `.taskmaster/status/summary.md`
**Why**: Quick overview of recent automation runs
**Validation**:
- [ ] Summary file auto-generated after each run
- [ ] Contains table of last 7 runs
- [ ] Shows success rate percentage
- [ ] Includes quick links to latest run and failed runs
- [ ] Readable and sortable in Obsidian
**Dependencies**: Task 11
**Estimated Time**: 25 minutes
**Test Command**: Run automation 3 times, verify summary updates

---

## Phase 6: Orchestration and Integration

### 13. Create main orchestrator script
**What**: Implement `daily_runner.sh` to coordinate entire pipeline
**Why**: Single entry point for automation workflow
**Validation**:
- [ ] Script exists: `daily_runner.sh` in project root
- [ ] Sets up environment (PATH, source shell config)
- [ ] Validates Claude Code authentication
- [ ] Calls sub-scripts in sequence:
  1. `discover_changes.sh`
  2. `generate_digest.sh`
  3. `generate_drafts.sh`
  4. `write_status.sh`
- [ ] Passes outputs between steps correctly
- [ ] Halts on failure (exit code ≠ 0)
- [ ] Logs all operations to `~/.taskmaster/logs/<date>.log`
- [ ] Handles "no changes" gracefully
- [ ] Executable: `chmod +x daily_runner.sh`
**Dependencies**: Tasks 5, 7, 10, 11 (all sub-scripts)
**Estimated Time**: 45 minutes
**Test Command**: `./daily_runner.sh $(date +%Y-%m-%d)` with test vault

---

### 14. Create manual runner script
**What**: Implement `run_manual.sh` for user-friendly invocation
**Why**: Enable on-demand execution with progress feedback
**Validation**:
- [ ] Script exists: `run_manual.sh` in project root
- [ ] Accepts optional date argument: `./run_manual.sh [YYYY-MM-DD]`
- [ ] Defaults to today if no date provided
- [ ] Displays progress output to terminal (tee to log)
- [ ] Shows emoji status indicators (🚀, ✅, ❌)
- [ ] Returns clear success/failure message
- [ ] Executable: `chmod +x run_manual.sh`
**Dependencies**: Task 13 (orchestrator)
**Estimated Time**: 20 minutes
**Test Command**: `./run_manual.sh 2024-11-23` (verify output formatting)

---

### 15. Create cron installer script
**What**: Implement `install_cron.sh` for automated scheduling
**Why**: Enable hands-off daily execution
**Validation**:
- [ ] Script exists: `install_cron.sh` in project root
- [ ] Checks if cron job already installed
- [ ] Adds cron entry: `55 23 * * * <path>/daily_runner.sh`
- [ ] Creates log directory: `~/.taskmaster/logs/`
- [ ] Verifies Claude Code in PATH
- [ ] Prints confirmation message with verification command
- [ ] Executable: `chmod +x install_cron.sh`
**Dependencies**: Task 13 (orchestrator)
**Estimated Time**: 20 minutes
**Test Command**: Run installer, verify with `crontab -l`, remove after test

---

## Phase 7: Testing and Validation

### 16. End-to-end test with test vault
**What**: Run full automation on test vault and verify all outputs
**Why**: Validate entire pipeline before production use
**Validation**:
- [ ] Manual run completes successfully: `./run_manual.sh`
- [ ] Daily Digest generated correctly
- [ ] All 3 platform drafts created
- [ ] Status dashboard updated
- [ ] Summary table shows run
- [ ] No errors in log file
- [ ] WikiLinks functional in Obsidian
- [ ] No files modified in test vault source notes
**Dependencies**: Tasks 1-15 (complete system)
**Estimated Time**: 30 minutes
**Test Command**: `./run_manual.sh $(date +%Y-%m-%d) && echo "SUCCESS"`

---

### 17. Test batch processing with 15+ notes
**What**: Create additional test notes and verify chunking
**Why**: Ensure high-volume handling works correctly
**Validation**:
- [ ] Create 15 test notes (trigger 2 batches)
- [ ] Run automation: `./run_manual.sh`
- [ ] Verify sub-digests created in temp location
- [ ] Verify final digest synthesizes both batches
- [ ] Verify temp files deleted
- [ ] Total runtime < 90 seconds
**Dependencies**: Task 16 (base system working)
**Estimated Time**: 20 minutes

---

### 18. Test failure scenarios
**What**: Simulate failures and verify error handling
**Why**: Ensure graceful failure and useful error messages
**Validation**:
- [ ] **No changes**: Remove test notes' timestamps, verify "skipped" status
- [ ] **Permission denied**: Temporarily block write permissions, verify error logged
- [ ] **Missing template**: Delete `prompts/xiaohongshu.md`, verify skip + warning
- [ ] **Claude timeout**: Mock timeout (manual test), verify retry logic
- [ ] All failures logged to status dashboard
- [ ] Status shows actionable troubleshooting steps
**Dependencies**: Task 16
**Estimated Time**: 30 minutes

---

## Phase 8: Production Preparation

### 19. Update project configuration for production vault
**What**: Configure system to use actual iCloud Obsidian vault
**Why**: Ready for production deployment
**Validation**:
- [ ] Copy CLAUDE.md to production vault root
- [ ] Update `.claude/settings.json` with production vault path
- [ ] Verify production vault path in all scripts
- [ ] Test discovery script on production vault (dry-run mode)
- [ ] Verify no writes to production vault during dry-run
**Dependencies**: Task 18 (all tests pass)
**Estimated Time**: 15 minutes
**⚠️ CRITICAL**: Only proceed if all tests pass on test vault

---

### 20. First production manual run
**What**: Execute automation on real vault for the first time
**Why**: Validate production behavior before cron automation
**Validation**:
- [ ] Run manually: `./run_manual.sh $(date +%Y-%m-%d)`
- [ ] Review Daily Digest for quality and accuracy
- [ ] Verify WikiLinks to real notes work correctly
- [ ] Check platform drafts reflect actual content appropriately
- [ ] No corruption or sync conflicts in iCloud vault
- [ ] Status dashboard accessible in Obsidian
**Dependencies**: Task 19
**Estimated Time**: 20 minutes
**⚠️ CRITICAL**: Have vault backup before running

---

### 21. Install cron job for daily automation
**What**: Enable automated daily execution
**Why**: Achieve zero-touch automation goal
**Validation**:
- [ ] Run: `./install_cron.sh`
- [ ] Verify cron entry: `crontab -l`
- [ ] Test cron execution (temporarily set to `* * * * *` every minute)
- [ ] Verify cron log file created: `~/.taskmaster/logs/cron.log`
- [ ] Verify execution works when terminal not open
- [ ] Reset cron to production schedule: `55 23 * * *`
**Dependencies**: Task 20 (production validation)
**Estimated Time**: 15 minutes

---

## Phase 9: Documentation and Handoff

### 22. Create README.md with usage instructions
**What**: Document setup, usage, and troubleshooting
**Why**: Enable user self-service and future maintenance
**Validation**:
- [ ] README.md exists in project root
- [ ] Covers:
  - System overview and capabilities
  - Installation steps
  - Manual execution: `./run_manual.sh [date]`
  - Cron setup: `./install_cron.sh`
  - Configuration files explained
  - Troubleshooting common issues
  - How to customize prompt templates
- [ ] Examples and screenshots included
**Dependencies**: Task 21 (system complete)
**Estimated Time**: 30 minutes

---

### 23. Update openspec/project.md with domain context
**What**: Document project-specific conventions and constraints
**Why**: Preserve design decisions for future reference
**Validation**:
- [ ] `openspec/project.md` updated with:
  - Purpose: Obsidian automation with Claude Code
  - Tech stack: Bash, Claude Code CLI, Markdown
  - Architecture: Four-layer system (L1-L4)
  - Constraints: iCloud safety, read-only vault
  - Domain context: Obsidian WikiLinks, personal knowledge management
**Dependencies**: Task 22
**Estimated Time**: 15 minutes

---

## Summary

**Total Tasks**: 23
**Estimated Total Time**: 8-10 hours (across multiple sessions)
**Critical Dependencies**: Test vault creation → Script development → Testing → Production deployment
**Risk Mitigation**: All testing on isolated test vault before touching production

**Phases**:
1. **Foundation** (Tasks 1-2): 20 minutes
2. **Security** (Tasks 3-4): 20 minutes
3. **Core Scripts** (Tasks 5-8): 2.5 hours
4. **Distribution** (Tasks 9-10): 1.5 hours
5. **Monitoring** (Tasks 11-12): 1 hour
6. **Orchestration** (Tasks 13-15): 1.5 hours
7. **Testing** (Tasks 16-18): 1.5 hours
8. **Production** (Tasks 19-21): 1 hour
9. **Documentation** (Tasks 22-23): 45 minutes

**Parallel Opportunities**:
- Tasks 3-4 (permissions) can run parallel to Tasks 1-2 (test vault)
- Tasks 9 (templates) can run parallel to Tasks 5-8 (scripts)
- Task 12 (summary) can run parallel to Task 11 (status)

**Validation Gates**:
- ✅ After Task 8: Core automation works on test vault
- ✅ After Task 16: Full pipeline validated end-to-end
- ✅ After Task 18: Error handling proven robust
- ✅ After Task 20: Production vault safely processed

