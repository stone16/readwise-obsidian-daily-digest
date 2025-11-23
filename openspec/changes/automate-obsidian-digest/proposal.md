# Proposal: Automate Obsidian Daily Digest

## Change ID
`automate-obsidian-digest`

## Summary
Implement an automated system using Claude Code to generate daily knowledge digests from an Obsidian vault and create platform-specific content drafts (Xiaohongshu, WeChat, Twitter), with both scheduled (cron) and manual execution modes.

## Motivation
**Problem**: Knowledge workers accumulate daily notes in Obsidian but lack automated tools to:
- Synthesize daily changes into coherent insights
- Preserve WikiLink relationships and semantic context
- Repurpose content for multiple distribution platforms
- Execute autonomously without manual intervention

**Value**:
- Zero-touch daily knowledge synthesis and review
- Multi-platform content distribution from single source
- Semantic understanding via LLM vs. rigid scripting
- Safe, permission-controlled automation

## Scope

### In Scope (MVP - Option A)
- ✅ Safe file discovery from iCloud-synced Obsidian vault
- ✅ Daily digest generation with WikiLink preservation
- ✅ Platform-specific draft generation (Xiaohongshu, WeChat, Twitter)
- ✅ Dual execution: cron scheduling + manual invocation
- ✅ Markdown-based monitoring/status UI
- ✅ Test vault creation and validation workflow
- ✅ Chunking strategy for 10+ daily pages
- ✅ Permission-controlled Claude Code execution

### Out of Scope (Deferred)
- ❌ Automatic publishing to platforms (API integrations)
- ❌ Email notifications or external monitoring systems
- ❌ Advanced error recovery mechanisms
- ❌ Multi-vault support
- ❌ Historical digest regeneration

## Architecture Overview

### Four-Layer System
```
L1: Trigger Layer (cron + manual)
    ↓
L2: Ingestion Engine (safe file discovery + chunking)
    ↓
L3: Synthesis Core (Claude Code digest generation)
    ↓
L4: Distribution Layer (platform draft generation)
    ↓
    Monitoring UI (markdown status dashboard)
```

### Key Components
1. **Ingestion Engine**: Discovers modified files (24h window), filters safely, chunks if >10 files
2. **Synthesis Core**: Claude Code with CLAUDE.md system prompt, generates Daily Digest
3. **Distribution Layer**: Prompt Factory for platform-specific drafts
4. **Orchestration**: `daily_runner.sh` + cron/manual triggers
5. **Monitoring**: `.taskmaster/status/` markdown files for run history

## Capabilities Breakdown

### 1. `vault-ingestion`
**What**: Safe discovery and reading of modified Obsidian notes
**Why**: Must respect iCloud sync, avoid corruption, handle variable volume
**Files**: `scripts/ingestion/discover_changes.sh`, `.claude/settings.json`

### 2. `digest-synthesis`
**What**: Generate structured Daily Digest from modified notes
**Why**: Core value - semantic synthesis with WikiLink preservation
**Files**: `CLAUDE.md`, `scripts/synthesis/generate_digest.sh`

### 3. `platform-drafts`
**What**: Create platform-specific content from Daily Digest
**Why**: Enable multi-platform distribution with style adaptation
**Files**: `prompts/{xiaohongshu,wechat,twitter}.md`, `scripts/distribution/generate_drafts.sh`

### 4. `orchestration`
**What**: Dual execution modes (cron + manual), environment setup
**Why**: Support both autonomous (when laptop on) and on-demand usage
**Files**: `daily_runner.sh`, `run_manual.sh`, `install_cron.sh`

### 5. `monitoring`
**What**: Markdown-based status dashboard in vault
**Why**: Match user's markdown workflow, no external tools
**Files**: `scripts/monitoring/write_status.sh`, template in `.taskmaster/status/`

## Dependencies
- Claude Code CLI (already installed, `claude -p` confirmed working)
- macOS with zsh shell
- iCloud-synced Obsidian vault at: `/Users/stometa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Central`
- Standard Unix tools: `find`, `grep`, `date`, `mkdir`

## Configuration
- **Vault Path**: `/Users/stometa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Central`
- **Output Directory**: `DailyDigest/` (new folder at vault root)
- **Cron Schedule**: 8:00 AM GMT+8 (`0 8 * * *`)
- **Platform Drafts**: `DailyDigest/Drafts/{date}/`
- **Status Dashboard**: `.taskmaster/status/`

## Testing Strategy
1. **Test Vault Creation**: Isolated vault with sample notes
2. **Dry Run Mode**: Preview without writes
3. **Single-Note Test**: Process one note end-to-end
4. **Batch Test**: Process 10+ notes with chunking
5. **Production Validation**: Manual run before cron activation

## Success Criteria
- [ ] Test vault processes 10+ sample notes safely
- [ ] Daily Digest preserves WikiLinks correctly
- [ ] Platform drafts generated in correct format
- [ ] Manual invocation works with `./run_manual.sh`
- [ ] Cron execution logs properly (when laptop on)
- [ ] Status dashboard updates after each run
- [ ] No corruption or sync conflicts in iCloud vault

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| iCloud sync conflicts | 🔴 High | Read-only vault access, write only to separate output dirs |
| Context overflow (>10 pages) | 🟡 Medium | Chunking strategy: process in batches of 8 files |
| Laptop closed at 8AM | 🟡 Medium | Cron best-effort + manual fallback script |
| Hallucinated WikiLinks | 🟡 Medium | Post-processing validation script (deferred to v2) |
| Permission drift | 🟢 Low | Lock `.claude/settings.json` permissions |

## Open Questions
- None remaining after user clarifications

## Stakeholder Sign-off
- **User**: Confirmed Option A (MVP), test vault first, iCloud safety critical
- **Technical Lead** (Claude): Architecture validated against OpenSpec patterns

---

## Next Steps
1. Review and approve this proposal
2. Create detailed spec deltas for each capability
3. Draft `tasks.md` with ordered implementation steps
4. Validate with `openspec validate automate-obsidian-digest --strict`
5. Begin implementation with test vault creation
