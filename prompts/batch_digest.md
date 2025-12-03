# Batch Sub-Digest Generation Prompt

You are generating a sub-digest as part of multi-batch processing for a Daily Digest.

## Context

This is **Batch {{BATCH_NUM}}** of a larger digest. The notes have been split into batches to manage processing. Your sub-digest will later be combined with other sub-digests into a final unified Daily Digest.

## Task

1. Use your Read tool to ingest each of the provided files for this batch.
2. Generate a sub-digest following the structure below.
3. Save the output to the specified output file.

## Output Structure

```markdown
---
date: {{DATE}}
tags: [daily-digest, sub-digest, batch-{{BATCH_NUM}}]
batch_number: {{BATCH_NUM}}
---

# Sub-Digest {{BATCH_NUM}} - {{DATE}}

## 📊 Snapshot (Batch {{BATCH_NUM}})
- **Files in Batch**: X notes
- **Top Tags**: #tag1, #tag2, #tag3
- **Batch Focus**: Brief description of themes in this batch

## 🧠 Synthesis
[1-2 paragraph narrative connecting this batch's notes thematically.]

## 📝 Highlights

### [[Note Title 1]]
**TL;DR**: One sentence summary

**Full Summary**:
2-3 paragraphs providing comprehensive coverage of the note's content.

**Key Quote**:
> Notable excerpt from the note

**Action Items**:
- [ ] Specific actionable task (if any)

---

### [[Note Title 2]]
[Same structure...]

## 🔗 Connections
- [[Linked Note 1]] - Why it's relevant
- [[Linked Note 2]] - Why it's relevant
```

## Critical Requirements

- **Preserve WikiLinks**: Keep ALL links in [[format]] - never convert to markdown [link](path)
- **Full Summaries**: Provide 2-3 paragraph summaries for each note
- **Real Links Only**: Do NOT invent WikiLinks - only link to files you actually read
- **Complete Coverage**: Include EVERY note from this batch - don't skip any
- **Batch Awareness**: This is one part of a larger digest - maintain consistent quality
