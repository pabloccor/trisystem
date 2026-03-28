# Task Lifecycle

Every piece of work in TriSystem flows through a defined state machine with mandatory gates.
Nothing ships without review, tests, and QA.

---

## State machine

```
                    ┌──────────────────────────────────────────────────────┐
                    │                                                      │
parsed ──► ready ──► claimed ──► in_progress ──► self_checked             │
                                                     │                     │
                                                     ▼                     │
                                              review_pending               │
                                                     │                     │
                                          ┌──────────┴──────────┐          │
                                          ▼                     ▼          │
                                   review_passed          review_failed ───┘
                                          │                (back to developer)
                                          ▼
                                    test_pending
                                          │
                                ┌─────────┴─────────┐
                                ▼                   ▼
                          test_passed          test_failed
                                │               │
                                │               ▼
                                │          debugger fixes
                                │               │
                                │               └──► test_pending (retry)
                                ▼
                           qa_pending
                                │
                          ┌─────┴─────┐
                          ▼           ▼
                     qa_passed    qa_failed ──► back to developer
                          │
                          ▼
                        done
```

---

## States explained

| State | Who sets it | What it means |
|---|---|---|
| `parsed` | Bootstrap script | Task was extracted from the checklist but dependencies aren't satisfied yet |
| `ready` | `phase-controller` | All dependencies are satisfied; task can be claimed |
| `claimed` | `main-orchestrator` | An agent has been assigned to this task |
| `in_progress` | `developer` | Work is actively happening |
| `self_checked` | `developer` | Developer finished and ran verification commands |
| `review_pending` | `main-orchestrator` | Waiting for `reviewer` and/or `security-auditor` |
| `review_passed` | `reviewer` | Code review approved |
| `review_failed` | `reviewer` | Code review found issues; goes back to `developer` |
| `test_pending` | `main-orchestrator` | Waiting for `tester` to run verification |
| `test_passed` | `tester` | All verification commands passed |
| `test_failed` | `tester` | One or more tests failed; goes to `debugger` |
| `qa_pending` | `main-orchestrator` | Waiting for final quality gate |
| `qa_passed` | `qa-validator` | Approved for commit |
| `qa_failed` | `qa-validator` | Rejected; goes back to `developer` |
| `done` | `main-orchestrator` | Task complete, committed, evidence stored |

---

## Mandatory gates

Three gates are mandatory for every task. You cannot skip them:

### 1. Review gate
- **Agent:** `reviewer` (+ optionally `security-auditor` in parallel)
- **Input:** The diff produced by `developer`
- **Output:** `pass`, `pass_with_notes`, or `fail`
- **On fail:** Task goes back to `developer` with review comments

### 2. Test gate
- **Agent:** `tester`
- **Input:** `verification_commands` from the task pack
- **Output:** Pass/fail with command output as evidence
- **On fail:** Task goes to `debugger`, then retries the test gate

### 3. QA gate
- **Agent:** `qa-validator`
- **Input:** Handoff file, review result, test evidence, acceptance criteria
- **Output:** `approved` or `rejected`
- **On reject:** Task goes back to `developer` with the reason
- **On approve:** `git-manager` can commit

---

## Task packs

Each task is defined as a **task pack** — a structured blob in the registry with everything
an agent needs to do the work:

```json
{
  "id": "P01-S01-T001",
  "phase": "P01",
  "step": "S01",
  "title": "Initialize repository structure",
  "description": "Create the project directory layout with src/, tests/, docs/ directories...",
  "dependencies": [],
  "acceptance_criteria": [
    "Directory structure exists",
    "pyproject.toml is valid",
    "pytest runs without errors"
  ],
  "allowed_paths": [
    "src/**",
    "tests/**",
    "pyproject.toml"
  ],
  "verification_commands": [
    "python -m pytest tests/ -q",
    "python -c 'import tomllib; tomllib.load(open(\"pyproject.toml\", \"rb\"))'"
  ],
  "status": "ready"
}
```

---

## Evidence

Every task must produce evidence that it was completed correctly. Evidence is stored in:

```
.claude/tasks/evidence/<TASK_ID>/
├── test-output.txt          ← stdout/stderr from verification commands
├── review-result.json       ← reviewer's decision
├── qa-decision.json         ← qa-validator's decision
└── transcript.txt           ← (optional) agent transcript
```

---

## Handoffs

When a `developer` agent finishes a task, it must produce a **handoff file**:

```
.claude/tasks/handoffs/<TASK_ID>.md
```

The handoff contains:

```markdown
# Handoff P01-S01-T001

## Files changed
- src/models/user.py (created)
- tests/unit/test_user.py (created)

## Commands run
- python -m pytest tests/unit/test_user.py -q → PASS (3 tests)

## Tests passed
- test_user_creation
- test_user_validation
- test_user_serialization

## Tests failed
- (none)

## Risks
- User model does not yet handle email validation — covered in T003
```

**No handoff = task cannot be marked done.** The `hook_task_completed.py` script (Claude Code)
and `scope-guard.js` plugin (OpenCode) enforce this.

---

## The ledger

Every tool invocation is logged to `.claude/tasks/ledger.jsonl` — a JSONL audit trail:

```json
{"ts":"2025-01-15T10:30:00Z","event":"post_tool_use","tool_name":"write","active_task_id":"P01-S01-T001","file_path":"src/models/user.py"}
{"ts":"2025-01-15T10:30:05Z","event":"post_tool_use","tool_name":"bash","active_task_id":"P01-S01-T001","command":"python -m pytest tests/unit/test_user.py -q"}
```

This lets you trace exactly what happened during a task for debugging, auditing, or replaying.

---

## Dependencies

Tasks can depend on other tasks. A task stays in `parsed` state until all its dependencies
are in `done` state, at which point `phase-controller` moves it to `ready`.

```json
{
  "id": "P01-S02-T004",
  "dependencies": ["P01-S01-T001", "P01-S01-T002"],
  "status": "parsed"
}
```

Circular dependencies are not allowed and should be caught by `task-planner`.

---

## Phase transitions

A phase is complete when all its tasks are in `done` state. `phase-controller` then:

1. Marks the phase as `completed`
2. Runs any phase-level gates (e.g., integration tests, official-docs check)
3. Activates the next phase
4. Updates `.claude/memory/active-phase.json`

---

## Failure recovery

| Failure | What happens |
|---|---|
| Review fails | Task returns to `developer` with comments. New diff goes through review again. |
| Tests fail | `debugger` investigates. Fix is minimal. Goes through test → review → test cycle. |
| QA rejects | Task returns to `developer` with rejection reason. Full cycle repeats. |
| Bootstrap detects doc change | System suggests re-bootstrapping. Active tasks may need re-evaluation. |
| Agent crashes mid-task | Task stays in `in_progress`. Next session detects the orphaned task and can resume or reset it. |

---

## Next steps

- [Agents](agents.md) — the agents that drive the lifecycle
- [Hooks](hooks.md) / [Plugins](plugins.md) — the automation that enforces the lifecycle
- [Commands](commands.md) — slash commands for interacting with the lifecycle
