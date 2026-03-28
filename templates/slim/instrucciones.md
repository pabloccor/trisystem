# instrucciones.md — [PROJECT NAME]

> Replace all `[PLACEHOLDER]` values. This file governs goals, scope, authority order, workflow rules, and execution protocol.

---

## 1. Project Goals

**Primary goal:** [One sentence describing the core outcome the project must achieve.]

**Non-goals:** [What is explicitly out of scope for this project.]

**Success looks like:** [How you know the project succeeded. Measurable outcomes.]

---

## 2. Authority Order

When documents conflict, this is the resolution order:

1. This file (`instrucciones.md`) — goals, scope, and workflow rules
2. `*_IMPLEMENTATION_CHECKLIST.md` — phases, tasks, and deliverables
3. `*_TECHNICAL_GUIDE.md` — architecture, stack, and implementation constraints
4. Official documentation for any external library or API
5. Derived runtime artifacts (`.claude/memory/`, `.claude/tasks/`) — lowest authority

If a conflict is found, stop and repair the contract before continuing.

---

## 3. Scope

### In scope
- [Feature or capability 1]
- [Feature or capability 2]
- [Feature or capability 3]

### Out of scope (for MVP)
- [Thing explicitly excluded 1]
- [Thing explicitly excluded 2]

---

## 4. Workflow Rules

### Task lifecycle
Tasks flow through these states:
```
ready → claimed → in_progress → self_checked →
  review_pending → review_passed | review_failed →
  test_passed | test_failed → qa_passed | qa_failed → done
```

### Mandatory gates
Every task must pass: `reviewer` → `tester` → `qa-validator` before it can be marked `done`.

### Atomic tasks
One task = one verifiable objective = one PR. Do not bundle unrelated changes.

### Handoffs
Every worker agent must produce a handoff file at `.claude/tasks/handoffs/<TASK_ID>.md` before stopping.

### Official docs first
Before planning or implementing anything that touches an external API, framework, or deployment platform, run `/official-docs-check` to verify claims against official documentation.

---

## 5. Execution Protocol

### Starting a session
1. Validate the three-doc contract: `/validate-three-doc-contract`
2. Start dev servers if applicable: `/dev-loop`
3. Check the active phase and task: review `.claude/memory/active-phase.md`
4. Run the next ready task

### Completing a slice
1. Backend implementation
2. Frontend implementation (if applicable)
3. Verify in localhost: `/dev-verify`
4. User confirms in browser
5. Mark as done

### Bootstrap (first time or after doc changes)
```bash
python3 .claude/bin/bootstrap_three_docs.py --refresh
```

---

## 6. Motivation and Design Principles

[Optional section — describe any UX psychology, user motivation, or design philosophy that should guide decisions.]

- [Principle 1]
- [Principle 2]
- [Principle 3]

---

## 7. Open Questions and Risks

| Question / Risk | Owner | Status |
|---|---|---|
| [Open question 1] | [Who decides] | [Open / Resolved] |
| [Risk 1] | [Who monitors] | [Mitigated / Active] |

---

## 8. Key Contacts and Resources

- Repository: [URL]
- Issue tracker: [URL]
- Design docs: [URL]
- External API docs: [URL]
