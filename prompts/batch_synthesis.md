# Batch Synthesis Prompt

You are synthesizing multiple sub-digests into a final unified Daily Digest.

## Context

Multiple batches of notes were processed separately, each generating a sub-digest. Your task is to combine all sub-digests into a single, cohesive Daily Digest that reads as if it was generated from all notes at once.

## Task

1. Read and understand all provided sub-digests.
2. Generate a UNIFIED Daily Digest that synthesizes insights across ALL batches.
3. The final output should be seamless - readers should NOT know it was generated from multiple batches.
4. Save the output to the specified output file.

## Output Structure

```markdown
---
date: {{DATE}}
tags: [daily-digest, auto-generated]
---

# Daily Digest {{DATE}}

## 📊 Snapshot
- **Files Modified**: X notes (combined from all batches)
- **Top Tags**: #tag1, #tag2, #tag3 (merged and deduplicated)
- **Primary Focus**: Unified theme description

## 🧠 Synthesis
[1-2 paragraph narrative connecting ALL notes thematically across all batches. Identify overarching themes that span multiple batches. Note relationships between different batch themes.]

## 📝 Highlights

[Merge ALL per-note summaries from all batches here. Order logically by theme, NOT by batch number. Maintain the full structure for each note: TL;DR, Full Summary, Key Quote, Action Items.]

### [[Note Title 1]]
**TL;DR**: One sentence summary

**Full Summary**:
[Preserve the full 2-3 paragraph summary from the sub-digest]

**Key Quote**:
> Notable excerpt

**Action Items**:
- [ ] Tasks if any

---

[Continue for ALL notes from ALL batches...]

## 🔗 Connections

**From Today's Notes**:
[Deduplicated list of all WikiLinks from all batches]

**Related Notes in Vault**:
[Combined connections discovered across all batches]
```

## Critical Requirements

- **Complete Coverage**: Include EVERY note from EVERY sub-digest - do not drop any
- **Unified Narrative**: Synthesis should weave together themes across all batches
- **Preserve WikiLinks**: Keep ALL links in [[format]]
- **Deduplicate**: Merge duplicate connections, combine statistics correctly
- **Seamless Output**: Final digest should not reveal batch processing
- **Thematic Ordering**: Group notes by theme in Highlights, not by original batch
- **Accurate Counts**: Sum file counts correctly across all batches
