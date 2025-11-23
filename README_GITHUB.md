# Obsidian Daily Digest Automation

Automated knowledge synthesis system for Obsidian vaults using Claude Code.

## What It Does

Automatically generates Daily Digests from your Obsidian notes:
- 📊 Synthesizes modified notes into structured summaries
- 🔍 Discovers relationships across your entire vault
- 📱 Creates platform-specific content (Xiaohongshu, WeChat, Twitter)
- 🛡️ Read-only access to source notes (safe for iCloud-synced vaults)
- ⏰ Runs daily via cron/launchd with automatic catch-up

## Quick Start

### Prerequisites
- [Claude Code CLI](https://github.com/anthropics/claude-code)
- Obsidian vault with markdown notes
- Bash (macOS/Linux)

### Installation

```bash
git clone <repository-url>
cd obsidian_daily_digest

# Configure your vault path in .claude/settings.json
# Update production_vault.path to your Obsidian vault location

# Test with included test vault
./scripts/run_manual.sh --vault test_vault --yes

# Install daily automation (8:00 AM GMT+8)
./scripts/install_cron.sh
```

## Usage

**Manual run**:
```bash
./scripts/run_manual.sh
```

**Custom date**:
```bash
./scripts/run_manual.sh --date 2024-11-23
```

**Direct execution**:
```bash
./scripts/daily_runner.sh /path/to/vault
```

## Output

Daily Digest generated at: `vault/DailyDigest/Daily Digest YYYY-MM-DD.md`

Platform drafts at: `vault/DailyDigest/Drafts/YYYY-MM-DD/`
- Xiaohongshu (小红书) - Gen Z style
- WeChat (微信公众号) - Professional long-form
- Twitter/X - Thread format

## Architecture

```
Discovery → Batch Processing → Synthesis → Platform Drafts → Monitoring
```

- **Batch Processing**: Automatically chunks >10 files (8 per batch)
- **Safety**: Read-only source access, writes only to DailyDigest/
- **Laptop-Friendly**: Catch-up mechanism for missed days

## Configuration

Edit `.claude/settings.json`:
```json
{
  "vault_config": {
    "production_vault": {
      "path": "/path/to/your/vault",
      "enabled": true
    }
  }
}
```

## Project Structure

```
├── scripts/
│   ├── daily_runner.sh          # Main orchestrator
│   ├── run_manual.sh            # Interactive runner
│   ├── install_cron.sh          # Automation installer
│   ├── ingestion/               # File discovery
│   ├── synthesis/               # Digest generation
│   ├── distribution/            # Platform drafts
│   └── monitoring/              # Status tracking
├── prompts/                     # Platform templates
└── test_vault/                  # Test environment
```

## Safety Features

- **Read-Only Source Access**: Never modifies existing notes
- **iCloud Safe**: Skips placeholder files, prevents sync conflicts
- **WikiLink Preservation**: Maintains Obsidian graph relationships
- **Isolated Writes**: Only writes to DailyDigest/ and .taskmaster/status/

## Troubleshooting

**No files discovered**: Check modification times with `find vault -name "*.md" -mtime -1`

**Automation not running**:
- macOS: `launchctl list | grep obsidian`
- Linux: `crontab -l | grep OBSIDIAN`

**Logs**: Check `vault/.taskmaster/status/` for execution logs

## Development

Built with [Claude Code](https://claude.com/claude-code) - Anthropic's agentic coding assistant.

See full documentation in the detailed README.md.

## License

MIT
