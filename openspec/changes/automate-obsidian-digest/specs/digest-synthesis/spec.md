# Spec: Digest Synthesis

## Overview
Generate structured Daily Digest from modified notes using Claude Code, preserving WikiLinks and semantic relationships.

---

## ADDED Requirements

### Requirement: System Prompt Configuration
The system MUST use a dedicated CLAUDE.md file to guide digest generation behavior.

#### Scenario: Load system prompt on startup
**Given** file `/Users/stometa/ObsidianVault/CLAUDE.md` exists with synthesis rules
**When** Claude Code is invoked from the vault directory
**Then** it MUST automatically load and apply CLAUDE.md directives
**And** the directives MUST instruct Claude to act as "Vault Architect"
**And** the directives MUST enforce WikiLink preservation
**And** the directives MUST prohibit modifying source notes

#### Scenario: Enforce read-only behavior
**Given** CLAUDE.md contains "You must NEVER modify existing notes outside Drafts or Digests folders"
**When** Claude attempts to edit a source note
**Then** the `.claude/settings.json` permissions MUST block the edit
**And** Claude MUST fail with a permission error
**And** the error MUST be logged to status dashboard

---

### Requirement: Daily Digest Structure
The system MUST generate digests following a strict markdown schema for consistency.

#### Scenario: Generate complete digest with all sections
**Given** 5 notes were modified today
**When** the synthesis engine generates a Daily Digest
**Then** the output file MUST be named `Daily Digest YYYY-MM-DD.md`
**And** it MUST contain these sections in order:
1. **Frontmatter** (YAML): `date`, `tags`
2. **📊 Snapshot**: Statistics (file count, top tags)
3. **🧠 Synthesis**: 1-2 paragraph narrative connecting notes
4. **📝 Highlights**: Per-note summaries with TL;DR, quotes, action items
5. **🔗 Connections**: WikiLinks referenced today

**And** section headers MUST use emoji prefixes as specified

#### Scenario: Preserve WikiLink format
**Given** a note contains WikiLink `[[Project Alpha]]`
**When** the Daily Digest references this note
**Then** the WikiLink MUST remain as `[[Project Alpha]]`
**And** it MUST NOT convert to markdown link `[Project Alpha](path.md)`
**And** it MUST appear in the "🔗 Connections" section

#### Scenario: Extract action items from todo lists
**Given** a note contains unchecked todo: `- [ ] Review PR #42`
**When** the Daily Digest processes this note
**Then** the "📝 Highlights" section MUST include an "Action Items" subsection
**And** it MUST list: "Review PR #42"
**And** it MUST preserve the checkbox format

#### Scenario: Generate full summary for each file
**Given** a note with substantial content (multiple paragraphs)
**When** the Daily Digest processes this note
**Then** the "📝 Highlights" section MUST include a "Full Summary" for each note
**And** the summary MUST be 2-3 paragraphs capturing:
  - Main points and key arguments
  - Important details and context
  - Overall narrative and conclusions
**And** the summary MUST be detailed enough to understand the note without reading the original
**And** it MUST come after TL;DR and before Key Quote

---

### Requirement: Semantic Grouping
The system MUST group related notes by theme, not just list files chronologically.

#### Scenario: Identify common themes across notes
**Given** 3 notes about "LLM Agents", 2 about "Project Management"
**When** the synthesis engine processes these notes
**Then** the "🧠 Synthesis" section MUST group them thematically
**And** it MUST generate narrative like: "Today focused on LLM Agent research (3 notes) and project planning (2 notes)"
**And** it MUST identify connections between themes if applicable

#### Scenario: Handle diverse unrelated notes
**Given** 5 notes covering completely different topics
**When** the synthesis engine processes these notes
**Then** the "🧠 Synthesis" MUST acknowledge the diversity
**And** it MUST NOT force artificial thematic grouping
**And** it MUST provide a factual summary of coverage areas

---

### Requirement: Batch Processing with Synthesis
The system MUST handle multi-batch processing while maintaining coherence.

#### Scenario: Generate sub-digests for batches
**Given** 16 files split into 2 batches (8 files each)
**When** the synthesis engine processes batch 1
**Then** it MUST generate a "Sub-Digest 1" with same structure as Daily Digest
**And** it MUST be saved to temporary location (not final output)
**When** batch 2 is processed
**Then** it MUST generate "Sub-Digest 2"
**And** both sub-digests MUST preserve WikiLinks independently

#### Scenario: Synthesize final digest from sub-digests
**Given** 2 sub-digests exist from batch processing
**When** the final synthesis step runs
**Then** it MUST read both sub-digests as input
**And** it MUST generate a unified "🧠 Synthesis" combining insights
**And** it MUST merge "📝 Highlights" from both batches
**And** it MUST deduplicate WikiLinks in "🔗 Connections"
**And** it MUST save the result as the final Daily Digest
**And** it MUST delete temporary sub-digest files

---

### Requirement: Hallucination Prevention
The system MUST minimize and detect hallucinated WikiLinks.

#### Scenario: Link only to verified files
**Given** Claude Code has Read access to the vault
**When** it generates WikiLinks in the Daily Digest
**Then** it MUST only link to files it has successfully read
**And** it MUST NOT invent WikiLinks to non-existent notes
**And** the CLAUDE.md prompt MUST explicitly forbid hallucination

#### Scenario: Log suspicious WikiLinks (deferred validation)
**Given** a WikiLink `[[New Concept]]` appears in the digest
**And** the file `New Concept.md` does not exist
**When** the digest is generated
**Then** the system MUST log a warning: "⚠️ Potential hallucinated link: [[New Concept]]"
**And** it MUST continue processing (validation deferred to v2)
**And** the warning MUST appear in the status dashboard

---

### Requirement: Output Location and Naming
The system MUST save digests to the correct vault location with consistent naming.

#### Scenario: Save to designated output directory
**Given** the vault path is `/Users/stometa/ObsidianVault/`
**When** a Daily Digest is generated
**Then** it MUST be saved to `DailyDigest/`
**And** the directory MUST be created if it doesn't exist
**And** the filename MUST be `Daily Digest YYYY-MM-DD.md`
**And** the date MUST match the day being processed (not necessarily today)

#### Scenario: Handle date override for manual runs
**Given** the user runs `./run_manual.sh 2024-11-15`
**When** the synthesis engine generates the digest
**Then** the filename MUST be `Daily Digest 2024-11-15.md`
**And** the frontmatter `date` field MUST be `2024-11-15`
**And** it MUST process files modified on 2024-11-15, not today

---

## Implementation Notes

### CLAUDE.md System Prompt
```markdown
# Claude Code Project Guidelines for Obsidian Automation

## Role & Purpose
You are the "Vault Architect," an autonomous agent responsible for synthesizing knowledge.
Your goal is to read daily changes and generate a structured digest.

## Core Directives
1. **Read-Only on Source**: You MUST NEVER modify existing notes outside Drafts or Digests folders.
2. **WikiLink Preservation**: When referencing a note, ALWAYS use [[Note Name]] format.
3. **Semantic Grouping**: Group notes by theme or project. Identify connections.
4. **Hallucination Check**: Do not invent WikiLinks. Only link to verified files.
5. **Full Summaries**: For each note in Highlights, provide a comprehensive 2-3 paragraph summary capturing all key points.

## Tone
Objective, analytical, yet concise for synthesis. Detailed and thorough for individual file summaries.
```

### Digest Template Structure
```markdown
---
date: YYYY-MM-DD
tags:
  - daily-digest
  - auto-generated
---

# Daily Digest YYYY-MM-DD

## 📊 Snapshot
- **Files Modified**: X notes
- **Top Tags**: #tag1, #tag2, #tag3
- **Primary Focus**: [Main theme]

## 🧠 Synthesis
[1-2 paragraph narrative connecting today's notes thematically]

## 📝 Highlights

### [[Note Title 1]]
**TL;DR**: One-sentence summary

**Full Summary**:
[2-3 paragraph comprehensive summary of the entire note, capturing main points, key arguments, and important details. Should be detailed enough to understand the note without reading the original.]

**Key Quote**: > "Extracted quote from note"

**Action Items**:
- [ ] Specific todo from note

[Repeat for each note]

## 🔗 Connections
Today's notes referenced:
- [[Connected Note 1]]
- [[Connected Note 2]]
```

### Claude Code Invocation
```bash
cd "$VAULT_ROOT"

PROMPT="I have detected changes in the following files:
$CHANGED_FILES

Task:
1. Use your Read tool to ingest these files.
2. Generate a 'Daily Digest' following the rules in CLAUDE.md.
3. Save the output to 'DailyDigest/Daily Digest $DATE_STR.md'.
"

claude -p "$PROMPT" \
    --allowedTools "Read,Write,Bash" \
    >> "$LOG_FILE" 2>&1
```

---

## Dependencies
- **External**: Claude Code CLI with authentication
- **Internal**: `vault-ingestion` (provides file list)
- **Configuration**: CLAUDE.md system prompt, `.claude/settings.json`

---

## Testing Requirements

### Unit Tests
- [ ] CLAUDE.md loads correctly on Claude Code startup
- [ ] Digest structure matches template exactly
- [ ] WikiLink format preserved (not converted to markdown links)
- [ ] Action items extracted from todo checkboxes

### Integration Tests
- [ ] Generate digest from 5 sample notes
- [ ] Generate digest with batch processing (16 notes)
- [ ] Handle notes with circular WikiLinks (depth limit)
- [ ] Process notes with special characters in filenames

### Quality Tests
- [ ] Synthesis section is coherent and thematic
- [ ] No hallucinated WikiLinks appear (manual review)
- [ ] Frontmatter YAML is valid
- [ ] Emoji section headers render correctly in Obsidian

---

## Performance Requirements
- Single digest generation MUST complete within 20 seconds
- Batch synthesis (3 batches) MUST complete within 60 seconds
- Final digest file size SHOULD be <50KB for typical day

---

## Error Handling
- **Claude API timeout**: Retry once, then fail with error log
- **Permission denied on write**: Fail fast, log to dashboard
- **Empty file list**: Exit without generating digest
- **CLAUDE.md missing**: Use fallback inline prompt (log warning)

---

## Related Capabilities
- **Depends on**: `vault-ingestion` (file list input)
- **Enables**: `platform-drafts` (digest as source content)
- **Coordinates with**: `monitoring` (logs synthesis metrics)
