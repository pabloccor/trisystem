---
description: Park this session and save a handoff note to resume later
model: github-copilot/claude-haiku-4.5
subtask: false
---

Review the current conversation to understand what has been worked on in this session.

Then generate a structured handoff note using the template below. Be concise — this is a reference note, not a transcript.

## Handoff note template

```
# <Descriptive title of the work>

## What we were working on
One or two sentences describing the task or feature.

## Current status
What has been done. What state things are in right now.

## Immediate next step
The single most important thing to do when resuming. Be specific.

## Open questions / blockers
Any unresolved decisions, unknowns, or things that need checking.

## Relevant files
Key files involved. Paths only, one per line.

## Decisions made
Any important choices that were made and should not be revisited without reason.
```

## Naming

If `$ARGUMENTS` is non-empty, use it as the plan name exactly as given.

If `$ARGUMENTS` is empty, derive a short kebab-case name from the topic of the session (2-4 words, lowercase, hyphens only). For example: `browser-agent-phase2`, `auth-refactor`, `api-rate-limiting`.

## Steps

1. Write the handoff note following the template above.
2. Call `plans_save` with the chosen name and the note content.
3. Report back to the user: what name was used, where it was saved, and a one-sentence summary of what was parked.

If `plans_save` returns an error saying the plan already exists, call `plans_update` instead with the same name and content, and let the user know the existing plan was overwritten.
