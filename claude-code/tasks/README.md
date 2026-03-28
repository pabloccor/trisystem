# Tasks directory

Runtime task management for the three-doc execution system.

## Structure

- `registry.json` — canonical task registry
- `runtime-state.json` — current active phase and last worker
- `ledger.jsonl` — audit log of tool executions
- `phases/` — phase definition YAML files
- `work-items/` — individual task YAML files
- `handoffs/` — task handoff reports from worker agents
- `evidence/` — test and verification evidence
- `reports/` — phase and task completion reports
