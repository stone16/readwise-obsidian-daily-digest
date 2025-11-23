# Project Context

## Purpose

Automated knowledge synthesis system for Obsidian vaults that:
1. Discovers modified notes daily (last 24 hours)
2. Generates structured Daily Digests using Claude Code
3. Creates platform-specific content drafts (Xiaohongshu, WeChat, Twitter)
4. Provides monitoring dashboards for automation runs
5. Operates with read-only safety on source notes (iCloud sync compatible)

**Goals**:
- Transform scattered daily notes into coherent knowledge synthesis
- Enable multi-platform content distribution from single source
- Maintain Obsidian's WikiLink ecosystem and graph relationships
- Provide dual execution modes (automated cron + manual invocation)

## Tech Stack

- **Shell**: Bash (v4+) for orchestration and automation
- **AI Agent**: Claude Code CLI (non-interactive mode)
- **Vault Format**: Markdown with Obsidian-specific syntax (WikiLinks, frontmatter)
- **Automation**: cron (Unix/macOS) for scheduled execution
- **Version Control**: Git for change tracking
- **Testing**: Shell script testing with test vault environment

## Project Conventions

### Code Style

**Bash Scripts**:
- Use `set -euo pipefail` for strict error handling
- Color-coded logging functions (log_info, log_warn, log_error)
- Readable variable names in UPPERCASE for constants, lowercase for locals
- Exit codes: 0=success, 1=invalid args, 2/3=failures
- Heredoc for multi-line strings (prompts, markdown generation)

**Markdown**:
- WikiLinks: `[[Note Name]]` (never markdown `[text](path.md)`)
- Frontmatter: YAML format with date, tags, metadata
- Emoji section headers: 📊, 🧠, 📝, 🔗 for visual hierarchy
- Code blocks with language tags for syntax highlighting

**File Naming**:
- Scripts: `snake_case.sh` (e.g., `discover_changes.sh`)
- Daily Digest: `Daily Digest YYYY-MM-DD.md`
- Platform drafts: `{platform}_draft.md` (e.g., `twitter_draft.md`)
- Status files: `YYYY-MM-DD_{status}.md` (e.g., `2024-11-23_success.md`)

### Architecture Patterns

**Pipeline Architecture**:
```
Discovery → Synthesis → Distribution → Monitoring
```

**Batch Processing Strategy**:
- Threshold: 10 files
- Batch size: 8 files per batch
- Sub-digest synthesis for multi-batch scenarios
- Final synthesis combines all sub-digests

**Read-Only Safety Pattern**:
- Source vault: Read-only access
- Output folders: Write-allowed (`DailyDigest/`, `.taskmaster/status/`)
- Permission enforcement via `.claude/settings.json`

**iCloud Sync Safety**:
- Detect `.icloud` placeholder files and skip
- Never modify source notes (eventual consistency model)
- Separate output directories to avoid sync conflicts

**Prompt Factory Pattern**:
- Platform-specific prompt templates in `prompts/`
- Combined prompts: Template + Source content + Task instructions
- Claude Code invocation: `claude -p "$PROMPT" --allowedTools "Read,Write,Bash"`

### Testing Strategy

**Test Vault Isolation**:
- Complete test environment in `test_vault/`
- 12 sample notes with realistic content (WikiLinks, todos, tags, code blocks)
- Separate from production vault for safe development

**Component Testing**:
- Individual script validation (discovery, synthesis, monitoring)
- Batch processing verification (13 files → 2 batches)
- Status file generation and summary dashboard calculation
- Permission validation (read/write boundaries)

**Manual Integration Testing**:
- Full pipeline execution with test vault
- Platform draft generation verification
- Cron installation dry-run
- Production vault configuration validation

### Git Workflow

**Branch Strategy**:
- OpenSpec proposal-driven development
- Feature branches for each phase implementation
- Main branch: stable, tested code only

**Commit Conventions**:
- Descriptive messages referencing tasks (e.g., "Implement Task 5: File discovery script")
- Group related changes (all Phase 3 scripts in one commit)
- Include testing notes in commit descriptions

## Domain Context

### Obsidian Knowledge Management

**WikiLinks**:
- Format: `[[Note Name]]` creates bidirectional links
- Graph view: Visual representation of note connections
- Preservation critical: System must maintain WikiLink format, not convert to markdown links

**Frontmatter**:
- YAML metadata at file start (between `---` delimiters)
- Common fields: date, tags, status, aliases
- Custom fields: platform, generated_from, etc.

**Daily Notes**:
- Atomic note-taking pattern
- File naming: `YYYY-MM-DD Note Title.md`
- Typical volume: 5-15 notes per day
- Content: Ideas, meetings, research, todos

**Projects**:
- Longer-form notes tracking initiatives
- Cross-reference Daily Notes via WikiLinks
- Updated intermittently (not daily)

### Content Distribution Platforms

**Xiaohongshu (小红书)**:
- Chinese lifestyle/productivity platform
- Gen Z audience (18-30 years old)
- Emoji-heavy, visual, casual tone
- <20 character titles with emojis
- 5-8 hashtags for discoverability

**WeChat Official Account (微信公众号)**:
- Professional long-form articles
- Chinese tech/business audience
- 1000+ word technical depth
- Markdown-based (Md2Wx editors)
- Structured: 导语 → 技术拆解 → 代码示例 → 总结

**Twitter/X**:
- Global developer/tech audience
- Thread format: 5-7 tweets
- Strict <280 character limit per tweet
- Engagement-optimized (hooks, CTAs)
- Build-in-public culture

### Claude Code Integration

**Non-Interactive Mode**:
- `claude -p "$PROMPT"`: Single-shot execution
- `--allowedTools`: Permission control (Read, Write, Bash)
- No interactive prompts (batch processing)
- Output logged to files for monitoring

**System Prompt (CLAUDE.md)**:
- Role definition: "Vault Architect"
- Core directives: Read-only source, WikiLink preservation, semantic grouping
- Output structure template
- Quality standards and error handling

**Context Window Management**:
- Batch processing prevents overflow
- Sub-digest synthesis for multi-batch scenarios
- 8 files per batch = optimal token usage
- Final synthesis combines all batches

## Important Constraints

### Technical Constraints

**iCloud Sync Compatibility**:
- Read-only access to source vault
- Write only to designated output folders
- Eventual consistency model (no immediate sync guarantees)
- `.icloud` placeholder detection required

**Claude Code Limitations**:
- Cannot invoke Claude Code from within Claude Code (testing constraint)
- Non-interactive mode only (no user prompts during execution)
- Permission enforcement via `.claude/settings.json`
- Tool allowlist: Read, Write, Bash only

**File System**:
- Absolute paths required (no relative paths in scripts)
- macOS/Linux only (bash v4+)
- Executable permissions required on all scripts
- cron availability for automation

### Business Constraints

**Data Privacy**:
- All processing local (no cloud sync of vault contents)
- Claude Code API for AI processing only
- No third-party services for draft generation
- User owns all generated content

**Vault Safety**:
- NEVER modify source notes
- Prevent data corruption via write restrictions
- Maintain backup-ability (source notes untouched)
- iCloud sync conflicts avoided

### Operational Constraints

**Execution Window**:
- Default: 8:00 AM GMT+8 (Beijing/Shanghai timezone)
- Customizable via cron installer
- Must complete within reasonable time (<5 minutes for normal days)

**Resource Limits**:
- Batch size: 8 files (context window optimization)
- Max daily files: 50 (safety threshold)
- Log retention: 7 days in summary dashboard

## External Dependencies

### Required Dependencies

**Claude Code CLI**:
- Installation: https://github.com/anthropics/claude-code
- Authentication: User API key
- Version: Latest stable
- Usage: AI-powered note synthesis

**Obsidian**:
- Local vault with markdown notes
- WikiLink format support
- No plugins required (vanilla Obsidian)
- Sync: iCloud, Dropbox, or local

**Unix Tools**:
- `find`: File discovery with mtime filters
- `grep`: Text processing and validation
- `date`: Timestamp generation
- `crontab`: Scheduled execution
- `bash`: Shell scripting (v4+)

### Optional Dependencies

**iCloud Drive** (optional):
- For vault sync across devices
- Eventual consistency model
- Placeholder file detection required

**Markdown Editors** (for platform drafts):
- Md2Wx: WeChat article formatting
- 墨滴 (MoDi): Alternative WeChat editor
- Twitter web interface: Direct posting

### Internal Dependencies

**Configuration Files**:
- `.claude/settings.json`: Vault path, permissions, batch size
- `vault/CLAUDE.md`: System prompt for synthesis
- `prompts/*.md`: Platform-specific generation templates

**Script Dependencies**:
- `daily_runner.sh` → depends on all component scripts
- `generate_batch_digest.sh` → calls `generate_digest.sh` for sub-digests
- `install_cron.sh` → depends on `daily_runner.sh` existence

**Filesystem Layout**:
- `test_vault/`: Required for testing and validation
- `scripts/`: All automation scripts with execute permissions
- `prompts/`: Platform templates (xiaohongshu, wechat, twitter)
- `.taskmaster/status/`: Monitoring output directory
