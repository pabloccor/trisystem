---
name: official-docs-check
description: Verify the current task or phase against official documentation only. Use before planning, implementation, or deployment when APIs or behavior may have changed.
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools: Read, Grep, WebSearch, WebFetch, Write
---

Verify the current task or phase against current official documentation.

## Rules

- Use official vendor domains only.
- Prefer versioned docs if the project pins versions.
- If docs contradict internal documents, do not propose implementation. Produce a discrepancy note instead.

## Deliverable

Write a note in `.claude/memory/official-doc-notes/` including: official sources, key findings, incompatibilities, recommendation for the planner or implementer.
