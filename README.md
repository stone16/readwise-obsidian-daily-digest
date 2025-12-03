# Obsidian Daily Digest

Automatically synthesize your daily knowledge from Obsidian notes and Readwise highlights into cohesive digests with multi-platform distribution.

## What It Does

```
Obsidian Vault + Readwise → Daily Digest → Twitter/Newsletter/LinkedIn
```

Each morning, this system:
1. **Extracts** modified notes from your Obsidian vault
2. **Pulls** highlights and articles from Readwise
3. **Synthesizes** everything into a coherent Daily Digest
4. **Generates** platform-specific drafts for social sharing

## Quick Start

### 1. Install Dependencies

```bash
# Required
brew install jq

# Claude Code CLI (for AI synthesis)
# See: https://github.com/anthropics/claude-code
```

### 2. Configure

```bash
# Copy example config
cp .env.example .env

# Edit .env with your settings:
VAULT_PATH=/path/to/your/obsidian/vault
READWISE_TOKEN=your_token_here  # Get from https://readwise.io/access_token
```

### 3. Run

```bash
# Generate yesterday's digest (most common use)
./scripts/daily_runner_v2.sh

# Generate for a specific date
./scripts/daily_runner_v2.sh 2024-12-01

# Just extract and consolidate (no AI synthesis)
./scripts/daily_runner_v2.sh --skip-synthesis
```

## Features

| Feature | Description |
|---------|-------------|
| **Multi-Source** | Obsidian notes + Readwise highlights + RSS feeds |
| **Parallel Extraction** | All sources extracted simultaneously |
| **AI Synthesis** | Claude generates coherent narrative from fragments |
| **Platform Drafts** | Auto-generate Twitter threads, newsletters, LinkedIn posts |
| **Read-Only Safe** | Never modifies your source notes |
| **Configurable** | YAML-based platform configs, customizable prompts |

## Output

After running, you'll find:

```
YourVault/DailyDigest/
├── Daily Digest 2024-12-01.md    # Final synthesized digest
└── 2024-12-01/
    ├── obsidian.md               # Extracted vault notes
    ├── highlights.md             # Readwise highlights
    ├── technology.md             # RSS by category
    ├── consolidated.md           # All sources merged
    └── drafts/
        ├── twitter_draft.md      # Ready-to-post thread
        └── newsletter_draft.md   # Email newsletter
```

## Command Options

```bash
./scripts/daily_runner_v2.sh [vault_path] [date] [options]

# Arguments (all optional if VAULT_PATH is set in .env):
#   vault_path    Path to Obsidian vault
#   date          YYYY-MM-DD format (default: yesterday)

# Options:
#   --sources <list>    Sources to extract (default: obsidian,readwise)
#   --skip-drafts       Skip platform draft generation
#   --skip-synthesis    Only extract and consolidate
#   --skip-summary      Skip monitoring dashboard update
```

### Examples

```bash
# Use defaults from .env
./scripts/daily_runner_v2.sh

# Specific date
./scripts/daily_runner_v2.sh 2024-12-01

# Only Obsidian (no Readwise)
./scripts/daily_runner_v2.sh --sources obsidian

# Quick extraction without AI
./scripts/daily_runner_v2.sh --skip-synthesis --skip-drafts
```

## Automated Daily Runs

Set up automatic daily digest generation:

```bash
# Install (default: 8:00 AM)
./scripts/install_cron.sh

# Custom time
./scripts/install_cron.sh --time 07:00

# Uninstall
./scripts/install_cron.sh --uninstall
```

On macOS, this uses `launchd` which handles laptop sleep/wake gracefully.

## Configuration

### Environment Variables (`.env`)

```bash
# Required for Readwise integration
READWISE_TOKEN=your_token

# Optional: Default vault path
VAULT_PATH=/path/to/vault

# Optional: Default sources
EXTRACTION_SOURCES=obsidian,readwise
```

### Platform Configs (`config/platforms/`)

Each platform has a YAML config:

```yaml
# config/platforms/twitter.yaml
platform:
  name: twitter
  enabled: true

constraints:
  max_length: 280
  thread_max_posts: 10
```

### Custom Prompts (`prompts/`)

Modify generation style by editing prompt templates:

**Synthesis prompts:**
- `prompts/digest.md` - Main Daily Digest generation
- `prompts/batch_digest.md` - Sub-digest for batch processing
- `prompts/batch_synthesis.md` - Final synthesis from sub-digests

**Platform prompts:**
- `prompts/twitter.md` - Twitter thread style
- `prompts/newsletter.md` - Email newsletter format
- `prompts/linkedin.md` - LinkedIn post style

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     EXTRACTION (Parallel)                 │
├──────────────────┬───────────────────┬───────────────────┤
│  Obsidian Vault  │ Readwise Highlights│  Readwise Reader │
│   (obsidian.sh)  │   (readwise.sh)   │    (RSS feeds)   │
└────────┬─────────┴─────────┬─────────┴─────────┬─────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             ▼
                   ┌─────────────────┐
                   │  CONSOLIDATION  │  Merge all sources
                   │ (consolidate.sh)│  into single file
                   └────────┬────────┘
                            ▼
                   ┌─────────────────┐
                   │    SYNTHESIS    │  Claude AI generates
                   │(generate_digest)│  coherent narrative
                   └────────┬────────┘
                            ▼
                   ┌─────────────────┐
                   │  DISTRIBUTION   │  Platform-specific
                   │ (generate_drafts)│  content adaptation
                   └─────────────────┘
```

## Troubleshooting

### No content extracted

```bash
# Check if files were modified recently
find /path/to/vault -name "*.md" -mtime -1

# Test Readwise connection
curl -H "Authorization: Token $READWISE_TOKEN" https://readwise.io/api/v2/auth/
```

### Missing jq

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

### Validate setup

```bash
./scripts/validate_pipeline.sh
```

## Project Structure

```
obsidian_daily_digest/
├── .env.example              # Environment template
├── scripts/
│   ├── daily_runner_v2.sh    # Main orchestrator
│   ├── extraction/           # Source extractors
│   │   ├── obsidian.sh
│   │   ├── readwise.sh
│   │   └── extract_parallel.sh
│   ├── synthesis/            # Content processing
│   │   ├── consolidate.sh
│   │   └── generate_digest.sh
│   ├── distribution/         # Platform drafts
│   │   └── generate_drafts.sh
│   └── monitoring/           # Status tracking
├── config/platforms/         # Platform YAML configs
├── prompts/                  # Generation templates
└── docs/                     # Additional documentation
    └── MIGRATION.md          # v1 to v2 migration guide
```

## License

MIT

## Acknowledgments

Built with [Claude Code](https://claude.ai/code) by Anthropic.
