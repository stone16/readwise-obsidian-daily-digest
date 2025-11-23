# Design: Automate Obsidian Daily Digest

## Architectural Decisions

### AD-001: iCloud Safety Strategy
**Decision**: Treat Obsidian vault as **read-only** from automation's perspective.

**Context**:
- User's vault is synced via iCloud
- iCloud uses eventual consistency model
- Writing to synced vault during sync could cause conflicts
- Vault contains valuable existing content

**Rationale**:
- **Read Safety**: Only use `find` and `grep` for discovery, never modify source notes
- **Write Isolation**: All outputs (digests, drafts, status) go to dedicated directories:
  - `DailyDigest/` (new folder at vault root for daily digests)
  - `DailyDigest/Drafts/{date}/` (platform drafts)
  - `.taskmaster/status/` (monitoring data)
- **Sync Awareness**: Wait for iCloud sync completion before reading (check `*.icloud` placeholder files)
- **Vault Path**: `/Users/stometa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Central`

**Alternatives Considered**:
- ❌ Direct vault writes: Too risky with iCloud sync
- ❌ Obsidian API: No official API for automation
- ✅ **Chosen**: Separate output directories, read-only vault access

**Consequences**:
- ✅ No risk of vault corruption
- ✅ User can review/edit outputs safely
- ⚠️ User must manually move/integrate drafts if desired

---

### AD-002: Chunking Strategy for Variable Volume
**Decision**: Process notes in **batches of 8 files** when >10 files detected.

**Context**:
- User reports 10+ pages daily (variable)
- Claude 3.5 Sonnet context: 200k tokens
- Average Obsidian note: ~1-2k tokens
- Need headroom for prompts, system messages, outputs

**Rationale**:
- **Batch Size Calculation**:
  - Max safe input: ~150k tokens (leaving 50k for responses)
  - Assuming 2k avg note + 1k overhead: ~3k per file
  - Safe batch: 150k / 3k = ~50 files theoretical
  - **Conservative batch: 8 files** (24k tokens), allows for outliers
- **Chunking Logic**:
  ```bash
  if file_count > 10; then
    split into batches of 8
    generate sub-digests
    final synthesis digest
  else
    single-pass digest
  fi
  ```

**Alternatives Considered**:
- ❌ Dynamic token counting: Too complex for MVP
- ❌ Single-pass all files: Risk context overflow
- ✅ **Chosen**: Fixed batch size with synthesis step

**Consequences**:
- ✅ Handles 10-100+ files safely
- ⚠️ Extra synthesis step adds latency
- ⚠️ Sub-digests may lose subtle connections (acceptable for MVP)

---

### AD-003: Dual Execution Model
**Decision**: Support both **cron scheduling** and **manual invocation** via separate entry points.

**Context**:
- User's laptop may be closed at 8AM
- macOS cron only runs when system awake
- Need flexibility for on-demand execution

**Rationale**:
- **Cron Mode** (`install_cron.sh`):
  - Best-effort execution at 08:00 daily
  - Logs to `~/.taskmaster/logs/cron.log`
  - Silent failures if laptop closed
- **Manual Mode** (`run_manual.sh`):
  - Interactive execution with progress output
  - Date override capability: `./run_manual.sh 2024-11-22`
  - Immediate feedback for debugging

**Alternatives Considered**:
- ❌ launchd agents: More complex, not essential for MVP
- ❌ Cron-only: Doesn't handle closed laptop
- ✅ **Chosen**: Dual modes with shared core logic

**Consequences**:
- ✅ Flexible execution timing
- ✅ Easy manual catch-up if cron missed
- ⚠️ User must remember to run manually if desired daily

---

### AD-004: Permission Model
**Decision**: Use **project-level `.claude/settings.json`** with explicit allow/deny lists.

**Context**:
- Claude Code defaults to interactive permission requests
- Automation requires non-interactive mode (`-p`)
- Must prevent accidental destructive operations

**Rationale**:
```json
{
  "permissions": {
    "allow": {
      "Bash": [
        "find '/Users/stometa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Central' -type f -name '*.md'",
        "grep -r 'pattern' '/Users/stometa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Central'",
        "date +%Y-%m-%d"
      ],
      "Read": ["**"],
      "Write": [
        "DailyDigest/**",
        ".taskmaster/status/**"
      ]
    },
    "deny": [
      "rm", "mv", "curl", "wget", "ssh",
      ".obsidian/**"
    ]
  }
}
```

**Alternatives Considered**:
- ❌ `--dangerously-skip-permissions`: Too risky
- ❌ Global settings: Affects other projects
- ✅ **Chosen**: Project-scoped granular permissions

**Consequences**:
- ✅ Safe automated execution
- ✅ Prevents vault corruption
- ⚠️ Must update settings if adding new scripts

---

### AD-005: Monitoring via Markdown Dashboard
**Decision**: Status tracking via **markdown files** in `.taskmaster/status/` directory.

**Context**:
- User prefers markdown-based workflows
- No external monitoring tools desired
- Need visibility into run history and failures

**Rationale**:
- **Structure**:
  ```
  .taskmaster/status/
    ├── latest_run.md (symlink to most recent)
    ├── 2024-11-23_success.md
    ├── 2024-11-22_failed.md
    └── summary.md (aggregated stats)
  ```
- **Content Format**:
  ```markdown
  # Run Status: 2024-11-23

  **Status**: ✅ Success
  **Duration**: 42s
  **Files Processed**: 12 (2 batches)
  **Outputs**:
  - [[DailyDigest/Daily Digest 2024-11-23]]
  - [[DailyDigest/Drafts/2024-11-23/xiaohongshu_draft]]

  ## Logs
  [Excerpt of key logs]
  ```

**Alternatives Considered**:
- ❌ JSON logs: Not markdown-native
- ❌ External dashboard: Against user's workflow
- ✅ **Chosen**: Markdown status files with WikiLinks

**Consequences**:
- ✅ Native Obsidian integration
- ✅ Easy to review in vault graph
- ⚠️ Manual cleanup needed for old status files

---

### AD-006: Prompt Factory Architecture
**Decision**: Use **separate prompt templates** per platform, loaded dynamically.

**Context**:
- Three platforms: Xiaohongshu, WeChat, Twitter
- Each has distinct style requirements
- Daily Digest is the source-of-truth content

**Rationale**:
- **Template Structure**:
  ```
  prompts/
    ├── xiaohongshu.md (emoji-heavy, visual)
    ├── wechat.md (professional, long-form)
    └── twitter.md (thread format, concise)
  ```
- **Invocation Pattern**:
  ```bash
  DIGEST_CONTENT=$(cat "Daily Digest 2024-11-23.md")
  TEMPLATE=$(cat "prompts/xiaohongshu.md")

  claude -p "
  Template: $TEMPLATE

  Source Content:
  $DIGEST_CONTENT
  " > drafts/xiaohongshu_draft.md
  ```

**Alternatives Considered**:
- ❌ Single prompt with platform switch: Less maintainable
- ❌ Hardcoded prompts in script: Not user-editable
- ✅ **Chosen**: Template files for customization

**Consequences**:
- ✅ User can customize platform styles easily
- ✅ Clear separation of concerns
- ⚠️ Three separate Claude API calls (cost)

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ Obsidian Vault (iCloud)                             │
│ /Users/stometa/ObsidianVault/                       │
│   ├── Daily Notes/                                  │
│   ├── Projects/                                     │
│   └── ... (READ-ONLY ACCESS)                        │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │ Ingestion Engine    │
         │ (discover_changes)  │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │ Files > 10?         │
         └──┬────────────────┬─┘
            │ NO             │ YES
            ▼                ▼
    ┌───────────────┐  ┌────────────────┐
    │ Single Pass   │  │ Batch (8 files)│
    │ Digest Gen    │  │ + Synthesis    │
    └───────┬───────┘  └────────┬───────┘
            │                   │
            └─────────┬─────────┘
                      ▼
         ┌────────────────────────┐
         │ Daily Digest (MD)      │
         │ DailyDigest/           │
         │ YYYY-MM-DD.md          │
         └────────┬───────────────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
        ▼         ▼         ▼
    ┌─────┐  ┌──────┐  ┌────────┐
    │ XHS │  │ WeChat│  │Twitter│
    │Draft│  │ Draft │  │ Draft │
    └─────┘  └───────┘  └────────┘
        │         │         │
        └─────────┼─────────┘
                  ▼
         ┌────────────────────┐
         │ Status Dashboard   │
         │ .taskmaster/status/│
         └────────────────────┘
```

---

## Security Considerations

### Threat Model
| Threat | Impact | Mitigation |
|--------|--------|------------|
| Accidental file deletion | 🔴 Critical | Deny `rm`, read-only vault access |
| Data exfiltration | 🔴 Critical | Deny `curl`, `wget`, `ssh` |
| iCloud sync corruption | 🟡 High | Write isolation, never modify source notes |
| Prompt injection via notes | 🟡 Medium | Trust user's own notes, sandbox Claude execution |
| Permission drift | 🟢 Low | Lock settings file, version control |

### Authentication & Secrets
- **Claude API Key**: Managed by `claude login`, stored in `~/.claude/auth.json`
- **No Additional Secrets**: No platform API keys in MVP
- **File Permissions**: `chmod 600 .claude/settings.json`

---

## Performance Considerations

### Expected Latencies
- **Discovery** (find): ~1-2s for 10k files
- **Single Digest**: ~10-15s (Claude API call)
- **Batch Digest** (3 batches): ~45-60s
- **Platform Drafts**: ~30s (3 parallel calls)
- **Total Runtime**: 1-2 minutes for typical day

### Optimization Opportunities (Future)
- [ ] Parallel Claude calls for platform drafts
- [ ] Caching of unchanged notes
- [ ] Incremental digest updates

---

## Testing Approach

### Test Vault Structure
```
test_vault/
  ├── Daily Notes/
  │   ├── 2024-11-23.md (10 sample notes)
  │   └── ...
  ├── Projects/
  │   └── Sample Project.md (with WikiLinks)
  ├── Reflections/
  │   └── Daily Digests/ (output dir)
  └── Drafts/
      └── SocialMedia/ (output dir)
```

### Test Scenarios
1. **Single Note**: Process 1 note, verify WikiLinks preserved
2. **Batch Processing**: Process 12 notes, verify chunking
3. **Empty Day**: No changes, verify graceful exit
4. **WikiLink Following**: Note references another, verify context
5. **Special Characters**: Ensure markdown escaping works

---

## Future Evolution

### V2 Enhancements (Out of MVP Scope)
- [ ] Hallucinated WikiLink validation
- [ ] Email notifications on failure
- [ ] Historical digest regeneration
- [ ] Multi-vault support
- [ ] Advanced error recovery

### Platform Integration (V3)
- [ ] WeChat Official Account API
- [ ] Xiaohongshu publishing API
- [ ] Twitter/X API for threads

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-11-23 | Read-only vault access | iCloud safety |
| 2024-11-23 | Batch size = 8 files | Conservative context management |
| 2024-11-23 | Markdown status dashboard | User workflow alignment |
| 2024-11-23 | Dual execution modes | Laptop availability variance |

