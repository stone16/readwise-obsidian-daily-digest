# Migration Guide: Multi-Source Pipeline v2

This guide helps you migrate from the original single-source pipeline to the enhanced multi-source pipeline.

## Quick Start

### 1. Setup Environment

Copy the environment template and add your Readwise token:

```bash
cp .env.example .env
# Edit .env and add your READWISE_TOKEN from https://readwise.io/access_token
```

### 2. Configure Default Vault (Optional)

Uncomment and set `VAULT_PATH` in your `.env` file to avoid passing the vault path each time:

```bash
# In .env
VAULT_PATH=/path/to/your/obsidian/vault
```

### 3. Validate Installation

Run the validation script to ensure all components are properly installed:

```bash
./scripts/validate_pipeline.sh
```

### 4. Run the New Pipeline

```bash
# If VAULT_PATH is set in .env, just run:
./scripts/daily_runner_v2.sh

# Or run with explicit vault path
./scripts/daily_runner_v2.sh /path/to/your/vault

# Run with specific date
./scripts/daily_runner_v2.sh /path/to/your/vault 2024-12-01

# Run with specific sources
./scripts/daily_runner_v2.sh /path/to/your/vault --sources obsidian,readwise

# Skip synthesis (just extract and consolidate)
./scripts/daily_runner_v2.sh /path/to/your/vault --skip-synthesis
```

## Directory Structure Changes

### Before (v1)

```
DailyDigest/
├── Daily Digest 2024-12-01.md
├── Daily Digest 2024-12-02.md
└── Drafts/
    └── 2024-12-02/
        ├── twitter_draft.md
        └── newsletter_draft.md
```

### After (v2)

```
DailyDigest/
├── 2024-12-01/
│   ├── obsidian.md           # Vault notes (intermediate)
│   ├── highlights.md         # Readwise highlights (intermediate)
│   ├── technology.md         # RSS by category (intermediate)
│   ├── business.md           # RSS by category (intermediate)
│   ├── consolidated.md       # Merged intermediate files
│   └── drafts/
│       ├── twitter_draft.md
│       └── newsletter_draft.md
├── 2024-12-02/
│   └── ...
└── Daily Digest 2024-12-02.md  # Final synthesized digest (same location)
```

## Script Changes

| Old Script | New Script | Notes |
|------------|------------|-------|
| `scripts/ingestion/discover_changes.sh` | `scripts/extraction/discover_changes.sh` | Moved directory |
| `scripts/daily_runner.sh` | `scripts/daily_runner_v2.sh` | Enhanced with parallel extraction |
| `scripts/distribution/generate_drafts.sh` | `scripts/distribution/generate_drafts_v2.sh` | Configurable platforms |

### New Scripts

| Script | Purpose |
|--------|---------|
| `scripts/extraction/obsidian.sh` | Extract Obsidian vault changes |
| `scripts/extraction/readwise.sh` | Extract Readwise highlights and Reader content |
| `scripts/extraction/readwise_client.sh` | Readwise API client with rate limiting |
| `scripts/extraction/extract_parallel.sh` | Parallel extraction orchestrator |
| `scripts/synthesis/consolidate.sh` | Merge intermediate files |
| `scripts/utils/format_intermediate.sh` | Shared utility functions |
| `scripts/validate_pipeline.sh` | Pipeline validation |

## Configuration

### Platform Configurations

Platform-specific settings are now in YAML files under `config/platforms/`:

```yaml
# config/platforms/twitter.yaml
platform:
  name: twitter
  display_name: "Twitter/X"
  enabled: true

constraints:
  max_length: 280
  thread_max_posts: 10
```

Available configurations:
- `twitter.yaml` - Twitter/X threads
- `newsletter.yaml` - Email newsletters
- `linkedin.yaml` - LinkedIn posts
- `blog.yaml` - Blog posts (disabled by default)

### Adding Custom Platforms

1. Create a new YAML file in `config/platforms/`:

```yaml
# config/platforms/mastodon.yaml
platform:
  name: mastodon
  display_name: "Mastodon"
  enabled: true

constraints:
  max_length: 500
```

2. Optionally create a custom prompt template at `prompts/mastodon.md`

3. Run drafts generation:

```bash
./scripts/distribution/generate_drafts_v2.sh /path/to/vault 2024-12-01 --platforms mastodon
```

## Running Individual Extractors

You can run extractors independently:

```bash
# Obsidian only
./scripts/extraction/obsidian.sh /path/to/vault 2024-12-01

# Readwise only (highlights + reader)
./scripts/extraction/readwise.sh /path/to/vault 2024-12-01

# Readwise highlights only
./scripts/extraction/readwise.sh /path/to/vault 2024-12-01 --highlights-only

# Readwise Reader/RSS only
./scripts/extraction/readwise.sh /path/to/vault 2024-12-01 --reader-only
```

## Cron Job Setup

Update your cron job to use the new runner:

```bash
# Edit crontab
crontab -e

# Old entry (replace this):
# 0 6 * * * /path/to/scripts/daily_runner.sh /path/to/vault

# New entry:
0 6 * * * cd /path/to/project && ./scripts/daily_runner_v2.sh /path/to/vault >> /tmp/daily_digest.log 2>&1
```

## Backwards Compatibility

The original `daily_runner.sh` still works and is unchanged. You can:

1. **Run both in parallel** for testing
2. **Gradually migrate** by running v2 manually first
3. **Fall back** to v1 if issues arise

## Troubleshooting

### Readwise API Issues

```bash
# Check if token is set
echo $READWISE_TOKEN

# Test API access
curl -H "Authorization: Token $READWISE_TOKEN" https://readwise.io/api/v2/auth/
```

### Validation Failures

```bash
# Run verbose validation
./scripts/validate_pipeline.sh --verbose
```

### Missing jq

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

### Permission Issues

```bash
# Make all scripts executable
chmod +x scripts/**/*.sh
```

## Rollback Procedure

If you need to revert:

1. Stop using `daily_runner_v2.sh`
2. Switch back to `daily_runner.sh`
3. Output will continue in the original flat structure

The v1 pipeline remains fully functional.
