---
name: phase-execution
description: Execute the current phase or a specific phase in a controlled document-driven loop.
argument-hint: "[current|PHASE_ID]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash, WebSearch, WebFetch, Agent, TaskCreate, TaskGet, TaskList, TaskUpdate
---

Execute the requested phase using the three-doc operating system.

Target phase: $ARGUMENTS

## Loop

1. Refresh bootstrap artifacts if needed.
2. Ensure the active phase is ready.
3. Use `official-docs-researcher` for phase-relevant technologies.
4. Use `phase-controller` to pick the next ready task.
5. Use `context-curator` to prepare the minimal task pack.
6. Run: developer → reviewer → tester → debugger if needed → qa-validator → evidence-reporter → git-manager if the task passes QA.
7. Update the registry and active task.
8. Repeat until the phase is complete or blocked.

Stop immediately if:
- official docs contradict internal docs
- the active task lacks enough context to proceed safely
- the current phase depends on an incomplete previous phase
