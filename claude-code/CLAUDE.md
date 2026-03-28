# Three-doc execution index — Fullstack Dev Loop Edition

## Source of truth

This project is governed by exactly three markdown files:

1. `instrucciones.md`
2. `*_IMPLEMENTATION_CHECKLIST.md`
3. `*_TECHNICAL_GUIDE.md`

Canonical location: `docs/source-of-truth/`.

If any of them is missing, duplicated, stale, or contradictory, stop and repair the document contract first.

## Fullstack dev loop

This variant enforces an **incremental fullstack workflow**:

1. **Phase 0 first**: scaffold back + front, start dev servers, verify localhost works.
2. **Slices, not layers**: every checklist item produces a vertical slice (backend + frontend + browser verification).
3. **Always running**: dev servers stay alive throughout development. Use `/dev-loop` to check or restart.
4. **Verify before done**: use `/dev-verify` after each slice. No item is complete until the user confirms it in their browser.

### Slice workflow
```
Checklist item → Backend (endpoint/logic) → Frontend (UI) → /dev-verify → User confirms in browser → Done
```

## Runtime artifacts

Generated runtime artifacts live under:
- `.claude/memory/`
- `.claude/tasks/`

These files are derived. Never treat them as source of truth when they disagree with the three source documents.

## Operating priorities

1. Validate the three-doc contract.
2. Prefer the canonical source-of-truth folder when it exists.
3. **Ensure dev servers are running before any implementation work.**
4. Consult official documentation before planning or implementation.
5. Compile phases, steps, and checklist items into task packs.
6. Execute only dependency-ready tasks.
7. **After each slice: run /dev-verify and guide the user through browser verification.**
8. Require handoff, review, tests, and QA before completion.
9. Keep context small. Use active task packs and focused excerpts.

## Entry points

- Start as orchestrator: `claude --agent main-orchestrator`
- Bootstrap skill: `/bootstrap-three-doc-project`
- Current phase execution: `/phase-execution current`
- Start/check dev servers: `/dev-loop`
- Verify current slice in localhost: `/dev-verify`

## Compact instructions

During compaction preserve:
- current phase and task IDs
- current task status
- source document paths and hashes
- dev server ports and status
- unresolved discrepancies with official docs
- active risks and blockers
- last validated verification commands
- last /dev-verify result
