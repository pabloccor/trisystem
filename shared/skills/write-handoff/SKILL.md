---
name: write-handoff
description: Standard format for task handoff files used by all worker agents.
user-invocable: false
allowed-tools: Read, Write
---

Every worker handoff must be written to `.claude/tasks/handoffs/<TASK_ID>.md` and must include these sections:

# Task Handoff

## Metadata
- Task ID:
- Agent:
- Outcome:
- Next status:
- Timestamp:

## Scope
- Goal of the task
- Files changed or reviewed

## Actions performed
- Commands run
- Important decisions
- Official docs consulted, if any

## Verification
- Tests or checks run
- Results
- Evidence paths

## Risks / open points
- Remaining risk
- Follow-up actions

## Acceptance coverage
- Item by item coverage against the task pack

At the end of the agent's final response, always add machine-readable lines:
- `TASK_ID: <TASK_ID>`
- `OUTCOME: ...`
- `NEXT_STATUS: ...`
- `HANDOFF: .claude/tasks/handoffs/<TASK_ID>.md`
