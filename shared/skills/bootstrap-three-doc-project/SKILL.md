---
name: bootstrap-three-doc-project
description: Bootstrap the full three-doc operating system for the current project. Use manually at the start of a new session or whenever the source docs changed.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Write, Bash, WebSearch, WebFetch, Agent, TaskCreate, TaskGet, TaskList, TaskUpdate
---

Bootstrap the current project as a three-doc execution system.

## Objective

Detect the three source-of-truth markdown files, validate them, generate runtime artifacts, verify AI assistant design against current official docs, and prepare the project for controlled phase execution.

## Steps

1. Validate the three-doc contract:
   - prefer `docs/source-of-truth/` as the canonical folder
   - locate exactly one `instrucciones.md`
   - locate exactly one `*_IMPLEMENTATION_CHECKLIST.md`
   - locate exactly one `*_TECHNICAL_GUIDE.md`
2. Run the bootstrap script if available (e.g. `python3 .claude/bin/bootstrap_three_docs.py --refresh`)
3. Use `document-analyzer` to validate results.
4. Use `official-docs-researcher` to verify current behaviors for the AI assistant runtime (subagents, skills, hooks, settings, permissions).
5. Use `project-architect` to update the executable architecture contract.
6. Use `task-planner` to build or refresh the task registry.
7. Use `phase-controller` to set the active phase and task.
8. Report: detected docs, blocking issues, active phase, active task, official-doc discrepancies if any.

Do not code product features during bootstrap.
