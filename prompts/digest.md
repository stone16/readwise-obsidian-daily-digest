# Daily Digest Generation Prompt

You are generating a Daily Digest from multiple content sources (Obsidian notes, RSS feeds, Readwise highlights, etc.).

## Task

1. Use your Read tool to ingest each of the provided files.
2. **Classify** each article by content type.
3. **Score** each article using the Quality Scoring System below.
4. **Generate** output format based on score threshold.
5. Save the output to the specified output file.

---

## Phase 1: Content Type Classification

Before scoring, classify each article into one of these types:

| Type | Description | Examples |
|------|-------------|----------|
| **News** | Time-sensitive updates, announcements | Product launches, event coverage, market updates |
| **Knowledge** | Evergreen educational content | How-to guides, frameworks, research, tutorials |
| **Opinion** | Expert perspectives and analysis | Thought leadership, industry commentary |
| **Tool** | Software/resource recommendations | Tool reviews, resource lists, comparisons |

---

## Phase 2: Quality Scoring System (0-100 points)

Score each article across 5 dimensions:

### Dimension 1: Knowledge Depth (0-30 points)
| Score | Criteria |
|-------|----------|
| 0-10 | Surface level: basic facts, news-style reporting, no explanation |
| 11-20 | Moderate depth: some explanation, context provided, limited detail |
| 21-30 | Comprehensive: frameworks, methodologies, data, thorough analysis |

### Dimension 2: Actionability (0-25 points)
| Score | Criteria |
|-------|----------|
| 0-8 | Informational only: no clear actions, purely descriptive |
| 9-16 | Implicit actions: requires interpretation to apply |
| 17-25 | Highly actionable: clear, specific steps you can take immediately |

### Dimension 3: Originality/Novelty (0-20 points)
| Score | Criteria |
|-------|----------|
| 0-7 | Common knowledge: widely covered, nothing new |
| 8-14 | Some novelty: unique perspective, new data, fresh angle |
| 15-20 | Breakthrough: original research, first-of-kind insights |

### Dimension 4: Personal Relevance (0-15 points)
| Score | Criteria |
|-------|----------|
| 0-5 | Tangential: loosely related to interests |
| 6-10 | Related: connects to interests/domain |
| 11-15 | Directly applicable: immediately useful for current work/projects |

### Dimension 5: Source Credibility (0-10 points)
| Score | Criteria |
|-------|----------|
| 0-3 | Unknown: no author attribution, no citations |
| 4-7 | Reputable: known source, some evidence/references |
| 8-10 | Expert: authoritative source, strong evidence, verifiable data |

**Total Score = Depth + Actionability + Novelty + Relevance + Credibility**

---

## Phase 3: Score-Based Output Format

### Low Score (0-49): News Brief
```markdown
### [Article Title] `[News]` `Score: 42`
Brief 1-2 sentence summary of the key point. ([source](url))
```

### Medium Score (50-69): Standard Summary
```markdown
### [Article Title] `[Knowledge]` `Score: 58`
**Summary**: 2-3 sentence overview of the content.

- Key insight with specific detail ([source](url))
- Another important point with data/evidence ([source](url))
- Third takeaway if applicable ([source](url))
```

### High Score (70-100): Deep Dive
```markdown
### [Article Title] `[Knowledge]` `Score: 85`

**Score Breakdown**: Depth: 25 | Action: 20 | Novelty: 18 | Relevance: 12 | Credibility: 10

**Summary**
1 paragraph comprehensive overview of the article's main thesis and contribution.

**Key Insights**
- Specific insight with concrete data, numbers, or examples ([source](url))
- Another detailed point with supporting evidence ([source](url))
- Technical detail or methodology explained ([source](url))
- Additional insight with practical application ([source](url))

**Why It Matters**
1-2 sentences on the significance, implications, or broader context.

**Next Steps**
- [ ] Specific action item you can take
- [ ] Another concrete step to apply this knowledge
- [ ] Resource to explore further

**Related**: [Connected concepts or articles from today's digest]
```

---

## Output Structure

```markdown
---
date: {{DATE}}
tags: [daily-digest, auto-generated]
---

# Daily Digest {{DATE}}

## Summary

[2-3 paragraph executive summary. Highlight the TOP 3 highest-scoring articles and their key insights. Mention any patterns or themes across the content.]

---

## Top Picks (Score 70+)

[High-scoring articles with full Deep Dive format, ordered by score descending]

---

## Category: [Source/Topic Name]

[Articles within this category, formatted according to their score tier]

## Category: [Another Topic]

[Continue for each category...]

---

## Conclusion

[1-2 paragraph synthesis. What are the overarching themes? What's most actionable? What should you prioritize?]

---

## Sources

[All source URLs for easy access]
- [Source Title 1](url1)
- [Source Title 2](url2)
```

---

## Category Naming Rules

1. **RSS Content**: Use the RSS folder name as category (e.g., "Category: Tech News", "Category: AI Research")
2. **Obsidian Notes**: Use "Category: Personal Notes" or infer from content
3. **Readwise Highlights**: Use "Category: Reading Highlights" or book/article source
4. **Other Sources**: Infer appropriate category from content

---

## Source Link Requirements

**CRITICAL**: Every insight MUST include a source link:
- Extract URLs from Readwise metadata, RSS item links, or file references
- Format: `([source name](url))` at the end of each point
- If URL unknown: `(source: [description])`

---

## Scoring Tips for Consistency

**News articles typically score lower** because:
- Depth is usually 0-15 (surface reporting)
- Novelty depends on how "breaking" it is
- They're often not directly actionable

**Knowledge articles can score higher** when they:
- Provide frameworks or methodologies (high Depth)
- Include specific how-to steps (high Actionability)
- Present original research or unique data (high Novelty)

**Be honest with scoring** - not everything deserves 70+. A typical digest might have:
- 2-4 articles scoring 70+ (Deep Dive treatment)
- 5-10 articles scoring 50-69 (Standard Summary)
- Many articles scoring below 50 (News Brief)

---

## Critical Requirements

- **Score Every Article**: No exceptions - all content gets classified and scored
- **Source Links**: Every insight must link to source - extract from Readwise metadata or other places
- **Honest Assessment**: Don't inflate scores - most content is average
- **Data & Specifics**: High-scoring insights must include concrete details, not vague statements
- **Top Picks Section**: Always surface the highest-value content prominently
- **Actionable Next Steps**: Deep Dive articles MUST include specific action items
