# Agents

TriSystem ships 17 specialized agents. Each agent has a single role, a defined set of tools,
and clear boundaries for when it acts and what it can modify.

Agents live in `shared/agents/` and are copied to `.opencode/agents/` or `.claude/agents/`
by the init script.

---

## Architecture: how agents collaborate

The agents form a pipeline. The `main-orchestrator` coordinates everything, delegating to
specialized agents in a strict sequence:

```
main-orchestrator
│
├── document-analyzer          Validates the 3-doc contract
├── official-docs-researcher   Checks claims against official docs
├── project-architect          Compiles the architecture contract
├── task-planner               Decomposes phases into atomic tasks
├── phase-controller           Selects the next ready task
├── context-curator            Prepares the minimal context pack
│
├── developer                  Implements the task
│   └── reviewer               Reviews the implementation
│   └── security-auditor       Reviews for security issues
│   └── tester                 Runs verification commands
│   └── debugger               Fixes failures (if needed)
│   └── qa-validator           Final quality gate
│
├── evidence-reporter          Compiles completion evidence
├── git-manager                Prepares commits and PR text
├── deployer                   Handles deployment (if applicable)
└── technical-analyst          Analyzes feasibility and risks
```

### The typical execution loop

1. `main-orchestrator` starts a phase
2. `phase-controller` selects the next task from the ready queue
3. `context-curator` prepares the minimum context the developer needs
4. `developer` implements the task
5. `reviewer` + `security-auditor` review (can run in parallel)
6. `tester` runs verification commands
7. If tests fail → `debugger` diagnoses and fixes → back to `tester`
8. `qa-validator` performs the final quality gate
9. `evidence-reporter` + `git-manager` compile results (can run in parallel)
10. Back to step 2 for the next task

---

## Agent reference

### main-orchestrator

| Property | Value |
|---|---|
| **Mode** | Primary agent |
| **Role** | Top-level coordinator for the three-doc system |
| **When invoked** | At session start, or explicitly via `@main-orchestrator` |
| **Key tools** | All tools — it delegates to subagents |

The orchestrator reads the three source docs, manages the task registry, selects phases,
and invokes the right agent for each step. It enforces the rule that no task can be marked
done without handoff + review + test evidence + QA.

### developer

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Implements exactly one approved task at a time |
| **When invoked** | After `context-curator` has prepared the context pack |
| **Key tools** | Read, Write, Edit, Bash, Glob, Grep |

The developer receives a task pack with: allowed file paths, acceptance criteria, verification
commands, and relevant context. It writes code, runs the verification commands, and produces
a handoff file listing what it changed, what it ran, and what risks remain.

**Scope enforcement:** The developer can only edit files listed in the task's `allowed_paths`.
The scope-guard plugin (OpenCode) or enforce-task-scope hook (Claude Code) blocks out-of-scope edits.

### reviewer

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Code review for correctness, style, and coverage |
| **When invoked** | After `developer` completes, before `tester` |
| **Key tools** | Read, Glob, Grep (read-only) |

Reviews the diff produced by the developer against the architecture contract and coding
conventions. Produces a review result: `pass`, `pass_with_notes`, or `fail`.

### security-auditor

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Security review of changes |
| **When invoked** | In parallel with `reviewer`, or for any auth/credentials/deploy changes |
| **Key tools** | Read, Glob, Grep (read-only) |

Checks for: hardcoded secrets, unsafe permissions, insecure commands, policy violations,
exposed credentials in diffs or new files.

### tester

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Runs verification commands and reports results |
| **When invoked** | After `reviewer` passes |
| **Key tools** | Read, Bash, Glob, Grep |

Executes the `verification_commands` defined in the task pack. Stores output as evidence
in `.claude/tasks/evidence/<TASK_ID>/`. Reports pass/fail with details.

### debugger

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Diagnoses failures and produces the smallest safe fix |
| **When invoked** | When `tester` reports failures, or when `reviewer` finds critical issues |
| **Key tools** | Read, Write, Edit, Bash, Glob, Grep |

Investigates the failure, identifies root cause, and produces a minimal fix. Does not
refactor or improve code beyond what is needed to fix the specific failure. The fix goes
back through the review → test cycle.

### qa-validator

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Final quality gate before git operations |
| **When invoked** | After tests pass, before `git-manager` |
| **Key tools** | Read, Glob, Grep (read-only) |

Checks: acceptance criteria are met, handoff file exists, review passed, test evidence
exists, no regressions. Produces a QA decision: `approved` or `rejected`.

Nothing gets committed without QA approval.

### git-manager

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Prepares commits, PR text, release notes |
| **When invoked** | After `qa-validator` approves |
| **Key tools** | Bash (git), Read, Glob |

Creates the branch, stages files, writes the commit message with task metadata, and
prepares PR text. The scope-guard plugin blocks `git push` from all other agents —
only `git-manager` can push.

### phase-controller

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Manages phase transitions and task selection |
| **When invoked** | At the start of each phase, and between tasks |
| **Key tools** | Read, Write (registry only) |

Maintains the ready queue, blocked queue, and active phase/task. Selects the next task
based on dependency order. Transitions phases when all tasks in a phase are done.

### task-planner

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Decomposes phases into atomic tasks |
| **When invoked** | After `document-analyzer` validates the contract |
| **Key tools** | Read, Write (registry only) |

Reads the implementation checklist and produces atomic task packs with: ID, description,
dependencies, acceptance criteria, allowed paths, and verification commands.

### context-curator

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Prepares the minimal context pack for worker agents |
| **When invoked** | Before every `developer` invocation |
| **Key tools** | Read, Glob, Grep (read-only) |

Reads the task pack, identifies which files the developer will need to see, and prepares
a minimal context bundle. This keeps the developer's context window clean and focused.

### project-architect

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Compiles the executable architecture contract |
| **When invoked** | After `document-analyzer`, before `task-planner` |
| **Key tools** | Read, Glob, Grep (read-only) |

Interprets the technical guide into concrete architecture decisions: which modules exist,
how they connect, what interfaces they expose, what invariants must hold.

### document-analyzer

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Validates the three-doc contract |
| **When invoked** | At session start, or after any source doc change |
| **Key tools** | Read, Glob, Grep (read-only) |

Checks that all three required documents exist and are non-empty. Computes hashes and
compares against the stored manifest to detect changes. If the contract is broken, it
halts all work.

### official-docs-researcher

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Verifies claims against official documentation |
| **When invoked** | Before architecture, planning, or implementation when APIs may have changed |
| **Key tools** | Read, WebFetch |

Extracts "claims" from the technical guide (framework versions, API endpoints, deployment
recommendations) and verifies them against official docs. Produces a report with
`ok`, `warning`, or `critical` status for each claim.

If any claim is `critical`, `phase-controller` blocks the phase.

### evidence-reporter

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Compiles evidence for task completion |
| **When invoked** | After QA approval, in parallel with `git-manager` |
| **Key tools** | Read, Write, Glob |

Produces human-readable reports from: registry state, handoffs, test evidence, QA results.
Writes reports to `.claude/tasks/reports/`.

### deployer

| Property | Value |
|---|---|
| **Mode** | Subagent |
| **Role** | Handles deployment workflows |
| **When invoked** | When a phase includes deployment steps |
| **Key tools** | Bash, Read, Write |

Executes deployment checklists (K8s, Helm, Docker, etc.) with safety checks at each step.

### technical-analyst

| Property | Value |      
|---|---|
| **Mode** | Subagent |
| **Role** | Analyzes technical feasibility and risks |
| **When invoked** | Before implementation when the phase involves complex or risky work |
| **Key tools** | Read, Glob, Grep (read-only) |

Determines impacted modules, risky interfaces, unknowns, and whether an official-docs
refresh is needed. Produces a risk assessment that the orchestrator uses to plan the phase.

---

## How agents are defined

Each agent is a markdown file with YAML frontmatter:

```markdown
---
description: One-line role description
mode: subagent          # or "primary"
temperature: 0.2        # lower = more deterministic
permission: allow       # OpenCode permission level
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
---

The full prompt body goes here.

It describes the agent's mission, rules, workflow, input/output format,
and any constraints.
```

### Key frontmatter fields

| Field | Required | Description |
|---|---|---|
| `description` | Yes | Shown in TUI agent list and help |
| `mode` | No | `primary` (top-level) or `subagent` (invoked by others). Default: `subagent` |
| `temperature` | No | 0.0–1.0. Lower = more deterministic. Default: 0.2 |
| `permission` | No | OpenCode permission block. Can be a string (`allow`/`ask`/`deny`) or an object with per-tool rules. |
| `tools` | No | List of tools the agent can use. Constrains its capabilities |

The `permission` field in agent frontmatter is combined with the global `opencode.json`
permission config using a **last matching rule wins** strategy. Agent-level rules are
evaluated after the global rules, which means an agent can both tighten and loosen the
global policy (e.g., deny `edit` when the global is `allow`, or allow `bash` when the
global is `deny`).

---

## Permission modes and agents

The project-level permission mode (set in `opencode.json` as `trisystem_permission_mode`)
determines the baseline for all agents. Individual agents may further adjust that baseline
(tighten or loosen it) via their frontmatter `permission` field.

### Effective permissions per mode

| Agent | `autonomous` | `supervised` | `guarded` | `locked` |
|---|---|---|---|---|
| `main-orchestrator` | all allow | bash: git push ask | all ask | reads only |
| `developer` | all allow | all allow | edit/bash ask | deny writes |
| `reviewer` | read-only | read-only | read-only | read-only |
| `security-auditor` | read-only | read-only | read-only | read-only |
| `tester` | bash allow | bash allow | bash ask | bash deny |
| `git-manager` | push allow | push ask | all ask | deny |
| `deployer` | all allow | apply cmds ask | all ask | deny |
| `qa-validator` | read-only | read-only | read-only | read-only |
| `phase-controller` | registry writes | registry writes | registry writes ask | deny |
| `context-curator` | memory writes | memory writes | memory writes ask | deny |

**Read-only agents** (`reviewer`, `security-auditor`, `document-analyzer`,
`official-docs-researcher`, `project-architect`, `technical-analyst`) have `edit: deny`
in their frontmatter and are unaffected by the permission mode — they never write.

See [docs/permissions.md](permissions.md) for the full mode reference.

---

## Creating a new agent

1. Create `shared/agents/your-agent-name.md`
2. Add YAML frontmatter with at least `description` and `tools`
3. Write a clear prompt body with: mission, rules, workflow steps, input/output format
4. Re-run the init script or manually copy to `.opencode/agents/` or `.claude/agents/`
5. Test by invoking it: `@your-agent-name do the thing`

**Guidelines:**
- Each agent has **one role**. Don't create a god agent that does everything.
- Be explicit about what the agent **cannot** do (e.g., "Do not push to remote").
- Include the expected output format so downstream agents can parse it.
- Keep the prompt under 500 lines — if it's longer, split into agent + skill.

---

## Next steps

- [Skills](skills.md) — reusable workflows that agents invoke
- [Task lifecycle](task-lifecycle.md) — the state machine that agents drive
- [Rules](rules.md) — the guardrails that constrain all agents
