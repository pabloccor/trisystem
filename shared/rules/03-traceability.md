# Traceability and control

- Keep `.claude/tasks/registry.json` aligned with the real state of execution.
- Every worker must produce a handoff file when it modifies code, tests, deployment state, or task status.
- Never mark a task `done` without:
  - handoff
  - review result
  - test evidence
  - QA decision
- Use `.claude/memory/active-phase.*` and `.claude/memory/active-task.*` as the minimal live context pack.
- Prefer small reversible tasks over large diffs.
