# Daily Digest Generation Prompt

You are generating a Daily Digest from multiple content sources (Obsidian notes, RSS feeds, Readwise highlights, etc.).

## Task

1. Use your Read tool to ingest each of the provided files.
2. Generate a Daily Digest following the structure below.
3. Save the output to the specified output file.

## Output Structure

```markdown
---
date: {{DATE}}
tags: [daily-digest, auto-generated]
---

# Daily Digest {{DATE}}

## Summary

[2-3 paragraph TL;DR at the top. This should give readers a quick overview of the day's key insights and themes. Write this as an executive summary that captures the most important points.]

## Category: [Source/Topic Name]

### [Item Title]
- Key insight or takeaway ([source](url))
- Another important point ([source](url))
- Actionable item or learning ([source](url))

### [Another Item Title]
- Bullet point with insight ([source](url))
- Related observation ([source](url))

## Category: [Another Source/Topic]

### [Item Title]
- Key insight ([source](url))
- Supporting detail ([source](url))

[... repeat for each category ...]

## Conclusion

[1-2 paragraph synthesis at the bottom. Connect the dots across categories, identify overarching patterns, and highlight the most actionable insights from the day.]

---

## Sources

[List all source URLs referenced in the digest for easy access]
- [Source Title 1](url1)
- [Source Title 2](url2)
```

## Category Naming Rules

1. **RSS Content**: Use the RSS folder name as the category (e.g., "Category: Tech News", "Category: AI Research")
2. **Obsidian Notes**: Use "Category: Personal Notes" or infer topic from content
3. **Readwise Highlights**: Use "Category: Reading Highlights" or the book/article source
4. **Other Sources**: Infer an appropriate category from the content

## Source Link Requirements

**CRITICAL**: Every bullet point MUST include a source link in markdown format:
- Format: `([source name](url))` at the end of each point
- If the source is a local file: `([Note Title](file-path))`
- If the source is a URL: `([Article Title](https://...))`
- If source URL is unknown: `(source: [description])`

Example:
```markdown
- AI assistants are becoming more capable at code generation ([OpenAI Blog](https://openai.com/blog/...))
- Note-taking apps are evolving toward automation ([Personal Notes](./notes/automation.md))
```

## Content Organization

1. **Group by Category**: Organize all content into logical categories
2. **Bullet Points**: Use bullet points for individual insights within each item
3. **Concise but Complete**: Each bullet should be self-contained and actionable, contain necessary detail with data, essence 
4. **Source Attribution**: Always link back to the original source

## Critical Requirements

- **Source Links**: EVERY insight must have a source link - this is mandatory - extract from readwise metadata or other places 
- **Category Structure**: Group content by source type or topic
- **Summary at Top**: Always include the TL;DR summary section at the very top
- **Conclusion at Bottom**: Always include the synthesis conclusion at the bottom
- **Preserve Original Links**: Keep any URLs from the source content
- **No Invented Links**: Only include links that exist in the source material
- **Accurate Attribution**: Match insights to their correct sources
