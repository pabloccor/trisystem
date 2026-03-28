# Rules

Rules are always-loaded instructions that apply to every agent in every session. They are the
guardrails that keep the system honest.

Rules live in `shared/rules/` and are loaded automatically via:
- **OpenCode:** the `instructions` field in `opencode.json`
- **Claude Code:** included from `CLAUDE.md`

---

## The five rules

### 00 — Three-doc contract

**File:** `00-three-doc-contract.md`

**What it enforces:**
- Exactly one `instrucciones.md` must exist
- Exactly one `*_IMPLEMENTATION_CHECKLIST.md` must exist
- Exactly one `*_TECHNICAL_GUIDE.md` must exist
- If any file is missing, all work stops
- Canonical location: `docs/source-of-truth/`
- Runtime artifacts in `.claude/memory/` and `.claude/tasks/` are derived and secondary
- The implementation checklist governs phases, steps, deliverables
- The technical guide governs architecture, constraints, stack
- `instrucciones.md` governs goals, scope, authority, workflow rules

**Why it exists:** Without this rule, agents might continue working even when source documents
are missing or corrupted. The contract ensures there's always a clear source of truth.

### 01 — Official docs first

**File:** `01-official-docs-first.md`

**What it enforces:**
- Before planning or implementation, verify APIs, libraries, and platforms against official docs
- Prefer first-party, version-specific documentation
- If official docs and internal docs disagree:
  1. Stop coding
  2. Write the discrepancy to `.claude/memory/official-doc-notes/`
  3. Reconcile the three source documents
  4. Continue only after the conflict is explicit

**Why it exists:** AI agents confidently hallucinate API signatures, deprecated methods, and
nonexistent features. Checking official docs first catches these before they become bugs.

### 02 — Phase execution

**File:** `02-phase-execution.md`

**What it enforces every phase must follow:**
1. Validate prerequisites
2. Understand current phase and scope
3. Consult official docs
4. Reconcile discrepancies
5. Implement
6. Lint and type-check
7. Run unit tests
8. Run integration/regression tests if applicable
9. Review architecture and contracts
10. Update handoff, evidence, registry, and report

**Why it exists:** Prevents agents from jumping straight to coding without understanding
context, and from marking things done without verification.

### 03 — Traceability

**File:** `03-traceability.md`

**What it enforces:**
- Keep `.claude/tasks/registry.json` aligned with real execution state
- Every worker must produce a handoff file when modifying code, tests, or task status
- Never mark a task `done` without: handoff + review + test evidence + QA
- Use active-phase and active-task as the minimal live context
- Prefer small reversible tasks over large diffs

**Why it exists:** Without traceability, it's impossible to know what happened, who did what,
and whether quality gates were satisfied. The ledger and handoffs create an audit trail.

### 04 — Dev loop and verify

**File:** `04-dev-loop-verify.md`

**What it enforces:**
- Dev servers must be running before implementation work begins
- Every checklist item in Phase 2+ must include a verify step checkable in localhost
- After completing backend + frontend parts of a slice, run `/dev-verify`
- Never mark a slice as done without telling the user what to see in their browser
- If dev servers are down, restart them before continuing
- If a slice can't be verified in localhost, split it into smaller pieces

**Why it exists:** Prevents the classic AI coding failure mode of writing code that compiles
but doesn't actually work when you load it in a browser.

---

## Load order

Rules are numbered `00-99`. Lower numbers load first. This means:
- Rule 00 (contract) is checked before anything else
- Rule 01 (official docs) runs before implementation
- Rules 02-04 guide the implementation itself

If you add new rules, choose a number that reflects when it should apply:
- `05-09`: Pre-implementation checks
- `10-19`: Implementation constraints
- `20-29`: Post-implementation checks
- `30-39`: Deployment constraints
- `90-99`: Cleanup and maintenance

---

## Creating a new rule

1. Create `shared/rules/NN-your-rule-name.md` where `NN` is the load order number
2. Write clear, concise instructions — rules are loaded into every session, so keep them short
3. Focus on **what** and **when**, not **how** (that's what agents and skills are for)
4. Re-run the init script or manually copy to the project's rules directory

### Template

```markdown
# Rule name

- First constraint or instruction
- Second constraint or instruction
- If [condition], then [action]
- Never [forbidden action]
```

### Guidelines

- Rules should be **under 30 lines**. If you need more, it's probably a skill, not a rule.
- Rules are **always-on** — they apply to all agents, all tasks, all phases. Don't write
  rules that only apply to one specific situation.
- Rules should be **enforceable** — either by a plugin/hook or by agent self-discipline.
  Vague rules like "write good code" are useless.
- Rules should be **non-contradictory**. If a new rule conflicts with an existing one,
  update the existing one instead of adding a conflicting new one.

---

## Next steps

- [Plugins](plugins.md) — automated enforcement of rules in OpenCode
- [Hooks](hooks.md) — automated enforcement of rules in Claude Code
- [Agents](agents.md) — the agents that follow these rules
