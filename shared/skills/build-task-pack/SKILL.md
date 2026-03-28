---
name: build-task-pack
description: Standard for refining or consuming a single task pack from the repo-local registry.
user-invocable: false
allowed-tools: Read, Grep, Glob, Write
---

When working on a task pack:

1. Read `.claude/tasks/registry.json`.
2. Read `.claude/memory/active-task.json` and `.claude/memory/active-task.md`.
3. Confirm: task ID, title, dependencies, acceptance, verification commands, allowed paths.
4. If `allowed_paths` is empty, refine it from the repo structure before coding whenever possible.
5. If the task is too broad, split it rather than proceeding with a large unfocused diff.
