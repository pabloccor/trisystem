# Skills

Skills are reusable workflow instructions that agents can invoke during a session. They encode
multi-step procedures that would be too complex to describe inline.

Skills live in `shared/skills/<skill-name>/SKILL.md` and are copied to
`.opencode/skills/` or `.claude/skills/` by the init script.

---

## Available skills

| Skill | Description | Typical invoker |
|---|---|---|
| `bootstrap-three-doc-project` | Full bootstrap: validate docs, generate artifacts, set active phase | `main-orchestrator` |
| `phase-execution` | Execute a phase in the controlled document-driven loop | `phase-controller` |
| `build-task-pack` | Build or refresh the task pack for a specific task | `task-planner` |
| `close-task` | Close or reject a task after QA passes or fails | `phase-controller` |
| `dev-loop` | Start, restart, or check dev servers (backend + frontend) | `developer` |
| `dev-verify` | Verify current slice works in localhost (browser check) | `tester` |
| `write-handoff` | Generate a standard handoff file for the active task | `developer` |
| `official-docs-check` | Verify claims against official documentation | `official-docs-researcher` |
| `validate-three-doc-contract` | Validate the three required markdown files exist and are intact | `document-analyzer` |
| `deploy-k8s` | Execute K8s/Helm deployment checklist with safety steps | `deployer` |

---

## How skills work

### Invocation

**OpenCode:**
```
/bootstrap-three-doc-project
```
or
```
@main-orchestrator use skill bootstrap-three-doc-project
```

**Claude Code:**
```
/bootstrap-three-doc-project
```

### Structure

Each skill is a directory containing a `SKILL.md` file:

```
shared/skills/
├── bootstrap-three-doc-project/
│   └── SKILL.md
├── build-task-pack/
│   └── SKILL.md
├── phase-execution/
│   └── SKILL.md
└── ...
```

The `SKILL.md` contains the full workflow instructions, written as a prompt that the
invoking agent follows step by step.

---

## Skill details

### bootstrap-three-doc-project

Runs the complete bootstrap sequence:
1. Validate the three source docs exist
2. Compute SHA hashes and update the manifest
3. Run `bootstrap_three_docs.py` to generate runtime artifacts
4. Set the active phase to the first non-completed phase
5. Report what was generated

### phase-execution

Executes a phase or specific task in the controlled loop:
1. Check phase prerequisites
2. Understand scope from the checklist
3. Consult official docs if needed
4. Implement each step
5. Run lint, type-check, tests
6. Review, update handoffs, evidence, registry

### build-task-pack

Builds or refines a single task pack:
1. Read the relevant checklist items
2. Extract acceptance criteria, allowed paths, verification commands
3. Identify dependencies
4. Write the task pack to the registry

### close-task

Closes a task after QA:
1. Verify handoff exists
2. Verify review passed
3. Verify test evidence exists
4. Verify QA decision is `approved`
5. Update registry status to `done`
6. If QA rejected, mark as `qa_failed` with reason

### dev-loop

Manages development servers:
1. Check if backend server is running (health check)
2. Check if frontend server is running (health check)
3. Start/restart as needed using commands from the technical guide
4. Report status and URLs

### dev-verify

Verifies a completed slice in the browser:
1. Check dev servers are running
2. Navigate to the relevant URL
3. Describe what should be visible
4. Confirm the slice works end-to-end

### write-handoff

Generates a handoff file:
1. Read the active task from memory
2. List files changed
3. List commands run and their results
4. List tests passed/failed
5. Note any risks
6. Write to `.claude/tasks/handoffs/<TASK_ID>.md`

### official-docs-check

Verifies claims against official documentation:
1. Extract version claims, API endpoints, deployment assumptions from the technical guide
2. Fetch official documentation for each claim
3. Check for deprecations, breaking changes, version availability
4. Produce a report with ok/warning/critical status

### validate-three-doc-contract

Validates the three-doc contract:
1. Check for exactly one file matching each pattern
2. Verify files are non-empty
3. Compute and compare hashes against stored manifest
4. Report any issues

### deploy-k8s

Executes a Kubernetes deployment:
1. Validate deployment prerequisites
2. Run pre-deployment checks
3. Apply manifests or Helm charts
4. Wait for rollout
5. Run post-deployment smoke tests

---

## Creating a new skill

1. Create `shared/skills/your-skill-name/SKILL.md`
2. Write the workflow as a step-by-step prompt
3. Re-run the init script or manually copy to the project's skills directory
4. Invoke with `/your-skill-name` or reference it in an agent prompt

### Template

```markdown
# Skill: your-skill-name

## Purpose
One sentence describing what this skill does.

## When to use
Describe the situation that triggers this skill.

## Prerequisites
What must be true before running this skill.

## Steps

### 1. First step
Detailed instructions for step 1.

### 2. Second step
Detailed instructions for step 2.

### 3. Verification
How to confirm the skill completed successfully.

## Output
What this skill produces (files, registry updates, reports).
```

### Guidelines

- One skill = one workflow. Don't combine unrelated workflows.
- Be explicit about prerequisites — what files must exist, what state the registry must be in.
- Include verification steps so the invoking agent knows it worked.
- Keep skills under 300 lines. If longer, split into sub-skills.
- Skills are runtime-agnostic — don't reference OpenCode or Claude Code specific features.

---

## Next steps

- [Commands](commands.md) — slash commands that often invoke skills
- [Agents](agents.md) — the agents that use skills
- [Rules](rules.md) — guardrails that apply during skill execution
