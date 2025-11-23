# Obsidian Daily Digest Automation

Automated knowledge synthesis system for Obsidian vaults using Claude Code.

## Overview

This system automatically generates Daily Digests from your Obsidian notes, transforming scattered daily notes into coherent knowledge synthesis with multi-platform content distribution.

**Key Features**:
- 📊 **Automated Daily Digests**: Synthesize modified notes into concise, structured summaries (processes yesterday by default for timezone consistency)
- 🔍 **Vault-Wide Relationship Discovery**: Explore entire vault to find hidden connections
- 🔄 **Batch Processing**: Handle high-volume note days (15+ notes) with intelligent chunking
- 📱 **Multi-Platform Distribution**: Generate drafts for Xiaohongshu, WeChat, Twitter
- 🛡️ **Read-Only Safety**: Never modifies source notes, only reads and generates outputs
- ⏰ **Dual Execution**: Both automated (cron) and manual invocation
- 📈 **Monitoring Dashboard**: Track automation runs with success rates and status

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Obsidian Vault (Read-Only)                │
│  Daily Notes/  Projects/  Attachments/  (iCloud Synced)     │
└───────────────────────────┬─────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   Discovery    │ Find modified files (last 24h)
                    │  (find -mtime) │ Detect batching needs (>10 files)
                    └───────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
      ┌───────▼────────┐         ┌───────▼────────┐
      │ Single Batch   │         │  Multi-Batch   │
      │   Synthesis    │         │   Synthesis    │
      │  (8 files)     │         │ (8 per batch)  │
      └───────┬────────┘         └───────┬────────┘
              │                           │
              │        ┌──────────────────┘
              │        │ Sub-digests → Final synthesis
              └────────┼──────────┐
                       │          │
              ┌────────▼────────┐ │
              │  Daily Digest   │ │
              │  (Markdown)     │ │
              └────────┬────────┘ │
                       │          │
          ┌────────────┴──────────┴─────────────┐
          │                                     │
   ┌──────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐
   │ Xiaohongshu │  │   WeChat    │  │  Twitter   │
   │   Draft     │  │   Draft     │  │   Draft    │
   │ (Gen Z)     │  │ (Pro Form)  │  │  (Thread)  │
   └─────────────┘  └─────────────┘  └────────────┘
                       │
              ┌────────▼────────┐
              │  Monitoring     │ Status files
              │  (Dashboard)    │ Summary dashboard
              └─────────────────┘
```

## Installation

### Prerequisites

- **Claude Code CLI**: [Install Claude Code](https://github.com/anthropics/claude-code)
- **Obsidian**: Local vault with markdown notes
- **Bash**: Unix shell (macOS/Linux)
- **cron**: For automated execution (optional)

### Setup

1. **Clone repository**:
   ```bash
   git clone <repository-url>
   cd obsidian_daily_digest
   ```

2. **Configure vault path**:
   Edit `.claude/settings.json` and set your production vault path:
   ```json
   {
     "vault_config": {
       "production_vault": {
         "path": "/path/to/your/obsidian/vault",
         "enabled": true
       }
     }
   }
   ```

3. **Test with test vault** (recommended first):
   ```bash
   ./scripts/run_manual.sh
   # Select option 1 (Test vault)
   ```

4. **Install cron job** (optional, for daily automation):
   ```bash
   ./scripts/install_cron.sh
   # Default: 8:00 AM GMT+8
   ```

## Usage

### Manual Execution

Interactive runner with vault selection and date options:

```bash
./scripts/run_manual.sh

# With options:
./scripts/run_manual.sh --vault /path/to/vault --date 2024-11-23 --skip-drafts
```

**Options**:
- `--vault <path>`: Specify vault path directly
- `--date <YYYY-MM-DD>`: Custom date (default: yesterday)
- `--skip-drafts`: Skip platform draft generation
- `--yes`: Skip confirmation prompt

**Note**: All scripts default to yesterday's date to avoid timezone issues and ensure complete days are processed.

### Automated Execution (with Laptop Wake-up Support)

Install daily automation at 8:00 AM with automatic catch-up for missed days:

```bash
./scripts/install_cron.sh

# Custom time:
./scripts/install_cron.sh --time 09:30

# Uninstall:
./scripts/install_cron.sh --uninstall
```

**Laptop-Friendly Features**:
- **macOS**: Uses `launchd` (better than cron for laptops)
- **Yesterday Processing**: Processes yesterday's notes by default (timezone-safe)
- **Catch-up**: Automatically processes up to 3 missed days when laptop wakes up
- **Smart Detection**: Checks if digest already exists before regenerating

### Direct Invocation

Run the orchestrator directly:

```bash
./scripts/daily_runner.sh /path/to/vault [date]

# Environment variables:
SKIP_DRAFTS=true ./scripts/daily_runner.sh /path/to/vault
SKIP_SUMMARY=true ./scripts/daily_runner.sh /path/to/vault
```

## Output Structure
### Daily Digest

Generated at: `DailyDigest/Daily Digest YYYY-MM-DD.md`

```markdown
---
date: 2024-11-23
tags: [daily-digest, auto-generated]
---

# Daily Digest 2024-11-23

## 📊 Snapshot
- **Files Modified**: 13 notes
- **Top Tags**: #llm-agents, #automation, #knowledge-management
- **Primary Focus**: LLM agent architecture and automation

## 📝 Highlights

### [[Note Title]]
**Key Points**:
- Main insight or topic
- Key finding or argument
- Important detail

**Summary**: [1-2 sentence overview connecting the points]

**Action Items**:
- [ ] Specific todo (if any)

## 🧠 Synthesis
[1-2 paragraph narrative connecting today's notes thematically and revealing patterns discovered]

## 🔗 Connections
**From Today's Notes**:
- [[Note referenced in today's files]]

**Related Notes in Vault** (discovered via exploration):
- [[Older Note 1]] - Similar topic or project connection
- [[Older Note 2]] - Referenced by or references today's notes
```

### Platform Drafts

Generated at: `DailyDigest/Drafts/YYYY-MM-DD/{platform}_draft.md`

**Xiaohongshu** (小红书):
- Emoji-heavy Gen Z style
- <20 char title with emojis
- Hook → Solution → Action structure
- 5-8 hashtags
- Visual cue suggestions

**WeChat Official Account** (微信公众号):
- Professional long-form (1000+ words)
- 导语 → 技术拆解 → 代码示例 → 总结
- Markdown compatible with Md2Wx editors
- Technical depth preserved

**Twitter/X Thread** (中文推文):
- 5-7 tweet thread in Chinese
- <280 chars per tweet (中英文混合)
- Numbered format (1/7, 2/7, etc.)
- Hook → Value → CTA structure
- Build-in-public style
- Engagement-optimized for Chinese tech community

### Monitoring Dashboard

**Status Files**: `.taskmaster/status/YYYY-MM-DD_{status}.md`
- Run metadata (date, duration, status)
- Execution log summary
- WikiLinks to generated outputs

**Summary Dashboard**: `.taskmaster/status/summary.md`
- Last 7 runs table
- Success rate percentage
- Quick links to latest and failed runs
- Performance metrics

## Configuration

### Vault Safety

The system uses **read-only access** to source notes:

**Allowed Writes** (`.claude/settings.json`):
- `DailyDigest/` (digest output)
- `DailyDigest/Drafts/` (platform drafts)
- `.taskmaster/status/` (monitoring)

**Read-Only**:
- `Daily Notes/` (source notes)
- `Projects/` (source notes)
- `.obsidian/` (never accessed)

### Batch Processing

**Threshold**: 10 files
- ≤10 files: Single-pass synthesis
- >10 files: Batch processing (8 files per batch)

**Why batching?**
- Prevents context window overflow
- Maintains semantic coherence
- Handles high-volume note days

### Platform Prompts

Located in `prompts/`:
- `xiaohongshu.md`: Xiaohongshu generation rules
- `wechat.md`: WeChat article guidelines
- `twitter.md`: Twitter thread patterns

Modify these files to customize output style.

## Project Structure

```
obsidian_daily_digest/
├── README.md                           # This file
├── .claude/
│   └── settings.json                   # Vault config & permissions
├── test_vault/                         # Test environment
│   ├── Daily Notes/                    # Sample notes
│   ├── Projects/                       # Sample projects
│   ├── DailyDigest/                    # Output digests
│   ├── CLAUDE.md                       # System prompt
│   └── .taskmaster/status/             # Monitoring
├── scripts/
│   ├── daily_runner.sh                 # Main orchestrator
│   ├── run_manual.sh                   # Interactive runner
│   ├── install_cron.sh                 # Cron installer
│   ├── ingestion/
│   │   └── discover_changes.sh         # File discovery
│   ├── synthesis/
│   │   ├── generate_digest.sh          # Single-batch synthesis
│   │   └── generate_batch_digest.sh    # Multi-batch synthesis
│   ├── distribution/
│   │   └── generate_drafts.sh          # Platform drafts
│   └── monitoring/
│       ├── write_status.sh             # Status logging
│       └── update_summary.sh           # Dashboard update
├── prompts/
│   ├── xiaohongshu.md                  # Xiaohongshu template
│   ├── wechat.md                       # WeChat template
│   └── twitter.md                      # Twitter template
└── openspec/
    ├── proposal.md                     # Original proposal
    ├── tasks.md                        # Implementation tasks
    └── project.md                      # Domain context
```

## Troubleshooting

### Common Issues

**1. No files discovered**
- Check file modification times: `find vault -name "*.md" -mtime -1`
- Verify vault path is correct
- Ensure notes were modified in last 24 hours

**2. Claude Code connection failed**
- Verify Claude Code is installed: `which claude`
- Check authentication: `claude --version`
- Review logs: `vault/.taskmaster/status/digest_generation.log`

**3. Digest generation incomplete**
- Check log files in `.taskmaster/status/`
- Verify all notes are readable (no iCloud placeholders)
- Review batch processing: files should split at 10+ threshold

**4. Platform drafts missing**
- Check if `SKIP_DRAFTS` environment variable is set
- Verify prompt templates exist in `prompts/`
- Review generation logs in `DailyDigest/Drafts/{date}/`

**5. Automation not running**
- **macOS**: Check LaunchAgent status: `launchctl list | grep obsidian`
- **macOS**: View logs: `tail -f vault/.taskmaster/status/launchd.log`
- **Linux**: Verify cron: `crontab -l | grep OBSIDIAN`
- **Linux**: Check cron log: `tail -f vault/.taskmaster/status/cron.log`
- **Catch-up**: Wrapper checks last 3 days, processes missing digests automatically

### Debug Mode

Run scripts with verbose logging:

```bash
bash -x ./scripts/daily_runner.sh /path/to/vault 2>&1 | tee debug.log
```

## Safety & Best Practices

### iCloud Sync Safety

**Read-Only Source Access**:
- System never modifies existing notes
- Only writes to designated output folders
- Prevents sync conflicts and corruption

**iCloud Placeholder Detection**:
- Discovery script skips `.icloud` placeholder files
- Only processes fully downloaded notes

### WikiLink Preservation

System maintains `[[WikiLink]]` format (not markdown `[link](path)`):
- ✅ Preserves Obsidian graph relationships
- ✅ Enables bidirectional linking
- ❌ Never fabricates non-existent links

### Testing Before Production

**Always test with test_vault first**:

```bash
# 1. Test discovery
./scripts/ingestion/discover_changes.sh test_vault

# 2. Test manual run
./scripts/run_manual.sh --vault test_vault --yes

# 3. Verify outputs
ls -lh test_vault/DailyDigest/
ls -lh test_vault/.taskmaster/status/
```

## Development

### Adding New Platforms

1. Create prompt template in `prompts/{platform}.md`
2. Add platform to `PLATFORMS` array in `scripts/distribution/generate_drafts.sh`:
   ```bash
   declare -A PLATFORMS=(
       ["xiaohongshu"]="Xiaohongshu (小红书)"
       ["wechat"]="WeChat Official Account"
       ["twitter"]="Twitter/X Thread"
       ["your_platform"]="Your Platform Name"
   )
   ```
3. Test with manual run

### Customizing Synthesis Rules

Edit `test_vault/CLAUDE.md` (or production `vault/CLAUDE.md`):
- Modify output structure (current: Snapshot → Highlights → Synthesis → Connections)
- Adjust summary verbosity (current: 2-4 bullet points + 1-2 sentence summary per note)
- Configure relationship discovery depth
- Add custom quality standards
- Update Obsidian formatting requirements

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Acknowledgments

Built with [Claude Code](https://claude.com/claude-code) - Anthropic's agentic coding assistant.
