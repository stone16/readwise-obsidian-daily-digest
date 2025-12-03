# Chunk Digest Prompt

You are generating a partial digest for a chunk of content. This will be merged with other chunks later.

## Task

1. Analyze the provided content chunk
2. For each article/item, classify it and score it (0-100) based on:
   - Knowledge Depth (0-30)
   - Actionability (0-25)
   - Originality (0-20)
   - Personal Relevance (0-15)
   - Source Credibility (0-10)

3. Generate summaries based on score:
   - 0-49: 1-2 sentence brief
   - 50-69: 2-3 key bullet points
   - 70+: Full summary with insights and action items

4. Output as valid markdown with this structure:

```markdown
## Chunk Summary

### [Article Title] `[Type]` `Score: XX`

[Summary based on score tier]

---
```

## Critical Requirements

- Score EVERY item - don't skip any
- Include source links where available
- Be concise but complete
- This is a PARTIAL digest - it will be merged later
