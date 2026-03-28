# Three-doc source-of-truth rule

- Treat these three files as the only project truth:
  - `instrucciones.md`
  - `*_IMPLEMENTATION_CHECKLIST.md`
  - `*_TECHNICAL_GUIDE.md`
- Canonical location: `docs/source-of-truth/`.
- If the canonical folder has no real source docs yet, the bootstrap may still detect legacy files elsewhere in the repo.
- If the current repo does not contain exactly one file for each required pattern, stop and repair the contract.
- The implementation checklist governs phases, steps, deliverables, and checklist coverage.
- The technical guide governs architecture, constraints, stack, invariants, interfaces, and deployment assumptions.
- `instrucciones.md` governs goals, scope, authority order, workflow rules, and execution protocol.
- Derived files under `.claude/memory/` and `.claude/tasks/` are execution artifacts only.
