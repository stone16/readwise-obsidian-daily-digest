# Chunk Merge Prompt

You are synthesizing multiple partial digests into a final unified Daily Digest.

## Task

1. Read all chunk summaries provided
2. Create a unified Daily Digest that:
   - Has an executive summary highlighting TOP 3 highest-scoring items
   - Groups content by category/source
   - Orders items by score within categories
   - Creates a "Top Picks (Score 70+)" section
   - Adds conclusion with key themes and actionable takeaways

3. Output in this exact format:

```markdown
---
date: {{DATE}}
tags: [daily-digest, auto-generated]
---

# Daily Digest {{DATE}}

## Summary

[Executive summary - 2-3 paragraphs highlighting the most valuable content]

---

## Top Picks (Score 70+)

[High-scoring items with full detail]

---

## Category: [Name]

[Items grouped by source/category]

---

## Conclusion

[Key themes, patterns, and recommended actions]

---

## Sources

[All source URLs]
```

## Critical Requirements

- Include ALL items from ALL chunks
- Maintain accurate scores
- Deduplicate any overlapping content
- Create a seamless, unified reading experience
- Don't reveal that this was processed in chunks
