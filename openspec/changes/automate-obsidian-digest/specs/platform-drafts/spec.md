# Spec: Platform Drafts

## Overview
Generate platform-specific content drafts (Xiaohongshu, WeChat, Twitter) from the Daily Digest using tailored prompt templates.

---

## ADDED Requirements

### Requirement: Prompt Template System
The system MUST use separate, customizable prompt templates for each platform.

#### Scenario: Load platform-specific prompts
**Given** prompt templates exist at:
- `prompts/xiaohongshu.md`
- `prompts/wechat.md`
- `prompts/twitter.md`

**When** the draft generation script runs
**Then** it MUST load each template file
**And** it MUST combine template with Daily Digest content
**And** it MUST invoke Claude Code once per platform
**And** it MUST save outputs to separate draft files

#### Scenario: Handle missing prompt template
**Given** `prompts/xiaohongshu.md` does not exist
**When** the draft generation script attempts to process Xiaohongshu
**Then** it MUST log error: "Missing prompt template: prompts/xiaohongshu.md"
**And** it MUST skip Xiaohongshu draft generation
**And** it MUST continue processing other platforms (WeChat, Twitter)
**And** it MUST report the error in status dashboard

---

### Requirement: Xiaohongshu Draft Format
The system MUST generate Xiaohongshu drafts following platform-specific style guidelines.

#### Scenario: Generate emoji-heavy visual content
**Given** the Daily Digest contains technical insights about "LLM Agents"
**When** the Xiaohongshu draft is generated
**Then** it MUST include:
- **Title**: <20 chars, pattern like "沉浸式学习 | LLM Agent 进化了！✨"
- **Emoji Density**: High, every paragraph starts/ends with emoji (✨, 💡, 📚, 🚀)
- **Structure**: Hook (relatable problem) → Solution (digest insight) → Action (how-to)
- **Tags**: #Obsidian #知识管理 #AI工具 #自我提升 #程序员日常
- **Visual Cues**: Description of 3 carousel images at end

**And** tone MUST be casual, enthusiastic, "种草" (grass-planting) style
**And** technical jargon MUST be simplified for Gen Z audience

#### Scenario: Adapt technical content for lifestyle platform
**Given** the Daily Digest discusses "Database Optimization Strategies"
**When** the Xiaohongshu draft is generated
**Then** it MUST reframe as: "后悔没早知道！提升效率的数据库技巧 😭"
**And** it MUST focus on *practical value* and *life improvement* angle
**And** it MUST avoid deep technical details (save for WeChat)

---

### Requirement: WeChat Official Account Draft Format
The system MUST generate WeChat drafts with professional depth and structure.

#### Scenario: Generate long-form professional article
**Given** the Daily Digest contains insights on "Agentic Workflows with Claude"
**When** the WeChat draft is generated
**Then** it MUST include:
- **Headline**: Professional, informative, e.g., "Deep Dive: Architecting Agentic Workflows with Claude"
- **Structure**:
  1. **导语 (Introduction)**: Contextualize the problem and its significance
  2. **技术拆解 (Technical Breakdown)**: Clear H2 headers, explain Why and How
  3. **代码示例 (Code Examples)**: Use code blocks for implementation details
  4. **总结 (Conclusion)**: Summary and future outlook
- **Length**: 1000+ words if digest content supports it
- **Tone**: Objective, insightful, professional, avoiding internet slang

**And** formatting MUST be standard Markdown (no HTML)
**And** it MUST be compatible with "Markdown 转微信" editors like Md2Wx

#### Scenario: Preserve technical depth from digest
**Given** the Daily Digest references specific technical concepts with WikiLinks
**When** the WeChat draft is generated
**Then** it MUST preserve technical accuracy and terminology
**And** it MUST expand on concepts if needed for clarity
**And** it MUST maintain authoritative, expert tone

---

### Requirement: Twitter/X Thread Draft Format
The system MUST generate Twitter thread drafts optimized for engagement.

#### Scenario: Generate 5-7 tweet thread
**Given** the Daily Digest contains insights on "Claude Code Automation"
**When** the Twitter draft is generated
**Then** it MUST structure as:
- **Tweet 1 (Hook)**: Contrarian opinion, surprising stat, or how-to promise
  - Example: "I just fired my manual note-taking process. Here's how I built autonomous ingestion with Claude Code. 🧵"
- **Tweets 2-6 (Body)**: One idea per tweet, numbered (2/7, 3/7, etc.)
- **Tweet 7 (CTA)**: Question to drive engagement
  - Example: "What's your biggest knowledge management pain point? 👇"

**And** each tweet MUST be <280 characters
**And** it MUST use bullet points for density where needed
**And** tone MUST be conversational, build-in-public style

#### Scenario: Adapt digest insights for viral potential
**Given** the Daily Digest discusses "Permission-Controlled AI Agents"
**When** the Twitter draft is generated
**Then** the hook MUST emphasize contrarian or surprising angle
**And** it MUST frame technical insights as actionable lessons
**And** it MUST optimize for Tech Twitter audience

---

### Requirement: Output File Organization
The system MUST organize draft files by date and platform for easy retrieval.

#### Scenario: Save drafts to date-specific directory
**Given** the date is 2024-11-23
**When** platform drafts are generated
**Then** they MUST be saved to `DailyDigest/Drafts/2024-11-23/`
**And** filenames MUST be:
- `xiaohongshu_draft.md`
- `wechat_draft.md`
- `twitter_draft.md`

**And** the directory MUST be created if it doesn't exist
**And** existing drafts with same name MUST be overwritten (not versioned)

#### Scenario: Include source reference in draft frontmatter
**Given** a draft is generated from `Daily Digest 2024-11-23.md`
**When** the draft file is created
**Then** it MUST include frontmatter:
```yaml
---
platform: xiaohongshu
generated_from: "[[DailyDigest/Daily Digest 2024-11-23]]"
date: 2024-11-23
status: draft
---
```

**And** the WikiLink to source digest MUST be functional in Obsidian

---

### Requirement: Content Transformation Rules
The system MUST apply platform-appropriate transformations to digest content.

#### Scenario: Remove WikiLinks for external platforms
**Given** the Daily Digest contains WikiLink `[[Project Alpha]]`
**When** generating Xiaohongshu/WeChat/Twitter drafts
**Then** WikiLinks SHOULD be converted to plain text: "Project Alpha"
**Or** replaced with context: "我的项目 Project Alpha"
**And** WikiLink syntax `[[...]]` MUST NOT appear in final drafts

#### Scenario: Adjust technical depth by platform
**Given** the Daily Digest mentions "Context window optimization with chunking"
**Then** transformations MUST be:
- **Xiaohongshu**: "让 AI 记住更多内容的技巧 💡"
- **WeChat**: "深入探讨：如何通过分块技术优化上下文窗口"
- **Twitter**: "Context window hack: split prompts into chunks. Works like a charm. 🧵"

---

## Implementation Notes

### Xiaohongshu Prompt Template
```markdown
# prompts/xiaohongshu.md

**Role**: Top-tier Xiaohongshu content creator specializing in "Productivity & Tech Life"

**Input**: Read "🧠 Synthesis" and "📝 Highlights" from Daily Digest

**Task**: Transform technical content into viral Xiaohongshu post

**Requirements**:
- **Title**: <20 chars, patterns like "沉浸式学习 | XXX 进化了！✨"
- **Emoji Density**: High, every paragraph starts/ends with emoji
- **Structure**: Hook → Solution → Action
- **Tags**: #Obsidian #知识管理 #AI工具 #自我提升
- **Visual Cues**: Describe 3 carousel images

**Tone**: Casual, enthusiastic, "种草" style
```

### WeChat Prompt Template
```markdown
# prompts/wechat.md

**Role**: Chief Editor of Tech Blog on WeChat

**Input**: Full Daily Digest content

**Task**: Write structured, professional article

**Requirements**:
- **Headline**: Professional, informative
- **Structure**: 导语 → 技术拆解 → 代码示例 → 总结
- **Length**: 1000+ words
- **Formatting**: Standard Markdown only
- **Tone**: Objective, insightful, no slang
```

### Twitter Prompt Template
```markdown
# prompts/twitter.md

**Role**: Tech Twitter Influencer

**Input**: Daily Digest insights

**Task**: Create viral Thread (5-7 tweets)

**Requirements**:
- **Hook (Tweet 1)**: Contrarian opinion or surprising stat
- **Body Tweets**: One idea per tweet, <280 chars, numbered
- **CTA (Last Tweet)**: Engagement question

**Example Hook**: "I just fired my manual process. Here's how I built autonomous X. 🧵"
```

### Draft Generation Script
```bash
DIGEST_PATH="DailyDigest/Daily Digest $DATE.md"
DIGEST_CONTENT=$(cat "$DIGEST_PATH")
OUTPUT_DIR="DailyDigest/Drafts/$DATE"

mkdir -p "$OUTPUT_DIR"

for platform in xiaohongshu wechat twitter; do
    TEMPLATE=$(cat "prompts/$platform.md")

    PROMPT="$TEMPLATE

---
SOURCE CONTENT FROM DAILY DIGEST:
$DIGEST_CONTENT
"

    claude -p "$PROMPT" \
        --allowedTools "Read,Write" \
        > "$OUTPUT_DIR/${platform}_draft.md"
done
```

---

## Dependencies
- **External**: Claude Code CLI
- **Internal**: `digest-synthesis` (provides Daily Digest as input)
- **Configuration**: Prompt template files in `prompts/`

---

## Testing Requirements

### Unit Tests
- [ ] Prompt templates load correctly
- [ ] WikiLinks removed from drafts
- [ ] Frontmatter includes source reference
- [ ] Output directory created if missing

### Integration Tests
- [ ] Generate all 3 platform drafts from sample digest
- [ ] Verify Xiaohongshu draft has emoji density
- [ ] Verify WeChat draft has professional structure
- [ ] Verify Twitter draft has tweet count and char limits

### Quality Tests
- [ ] Xiaohongshu draft appeals to Gen Z audience (manual review)
- [ ] WeChat draft maintains technical depth (manual review)
- [ ] Twitter thread hook is engaging (manual review)

---

## Performance Requirements
- All 3 platform drafts MUST generate within 60 seconds total
- Single platform draft MUST complete within 20 seconds
- File writes MUST be atomic (no partial writes)

---

## Error Handling
- **Missing prompt template**: Skip platform, log error
- **Claude API timeout**: Retry once per platform
- **Permission denied on output dir**: Fail fast, log error
- **Empty Daily Digest**: Skip all platforms, log warning

---

## Related Capabilities
- **Depends on**: `digest-synthesis` (Daily Digest input)
- **Enables**: Manual review and publishing workflow
- **Coordinates with**: `monitoring` (logs draft generation status)
