# Commands

Commands are slash-invokable actions you can run inside a session. They come in two types:
**global commands** (available across all projects) and **project commands** (specific to a project).

---

## Project commands

Project commands are skills mapped to slash commands. They live as `SKILL.md` files in the
skills directory and are invoked with a `/` prefix:

| Command | Description |
|---|---|
| `/bootstrap-three-doc-project` | Full bootstrap: validate docs, generate artifacts, set active phase |
| `/phase-execution [phase]` | Execute a specific phase |
| `/build-task-pack` | Build or refresh the task pack for a task |
| `/dev-loop` | Start, restart, or check dev servers |
| `/dev-verify` | Verify current slice in localhost |
| `/close-task` | Close or reject a task after QA |
| `/write-handoff` | Generate a handoff file |
| `/official-docs-check` | Verify claims against official docs |
| `/validate-three-doc-contract` | Validate the three-doc contract |
| `/deploy-k8s` | Execute K8s deployment |

These are documented in detail in [Skills](skills.md).

---

## Global commands (OpenCode)

Global commands live in `~/.config/opencode/commands/` and are available in every project.
The template provides 8 global commands:

### /commit

**File:** `commit.md`
**What it does:** Analyzes all uncommitted changes and commits them in logical groups using
conventional commits. Groups files by intent (not by type), writes descriptive commit messages,
and signs every commit with GPG.

**Usage:**
```
/commit
```

**Key behavior:**
- Groups related changes (e.g., a handler + its route + its config → one `feat:` commit)
- Uses conventional commit format: `type(scope): description`
- Always signs with `-S` — never skips GPG signing
- Does not push

### /explain

**File:** `explain.md`
**What it does:** Explains the project architecture — main components, how they connect,
and where to start reading the code.

**Usage:**
```
/explain
```

### /park

**File:** `park.md`
**What it does:** Parks the current session by saving a structured handoff note. Uses the
plans system to persist state between sessions.

**Usage:**
```
/park                     # auto-generates a name from the topic
/park my-feature-work     # uses the given name
```

**What gets saved:**
- What was being worked on
- Current status
- Immediate next step
- Open questions/blockers
- Relevant files
- Decisions made

### /resume

**File:** `resume.md`
**What it does:** Resumes a previously parked session by loading a plan and summarizing
where work was left off.

**Usage:**
```
/resume                   # shows list, asks you to pick
/resume my-feature-work   # loads directly
```

### /plans

**File:** `plans.md`
**What it does:** Lists all parked plans grouped by status (parked, in-progress, done).
Read-only — does not load, modify, or resume any plan.

**Usage:**
```
/plans
```

### /pr

**File:** `pr.md`
**What it does:** Creates a draft pull request for the current branch. Pushes the branch,
gathers context (diff stats, commit log), extracts a ticket ID from the branch name, and
creates the PR with a structured description.

**Usage:**
```
/pr              # targets main
/pr develop      # targets develop branch
```

**What the PR includes:**
- Summary section
- Changes section
- Testing checklist
- Related ticket link (if found)
- Suggested reviewers (based on git blame)

### /push

**File:** `push.md`
**What it does:** Pushes the current branch to its remote counterpart. Simple and direct.

**Usage:**
```
/push
```

### /title

**File:** `title.md`
**What it does:** Generates a short, descriptive title for the current conversation.
3-7 words, technical, no punctuation.

**Usage:**
```
/title
```

---

## Installing global commands

```bash
mkdir -p ~/.config/opencode/commands
cp trisystem/global/opencode/commands/*.md ~/.config/opencode/commands/
```

You also need the plans tool for `/park`, `/resume`, and `/plans`:

```bash
mkdir -p ~/.config/opencode/tools
cp trisystem/global/opencode/tools/plans.ts ~/.config/opencode/tools/plans.ts
```

And the global AGENTS.md for automatic session parking:

```bash
cp trisystem/global/opencode/AGENTS.md ~/.config/opencode/AGENTS.md
```

---

## Creating a new command

### OpenCode global command

1. Create `~/.config/opencode/commands/your-command.md`
2. Add YAML frontmatter:

```markdown
---
description: Short description shown in the TUI
model: github-copilot/claude-haiku-4.5    # optional: cheaper model for simple tasks
subtask: true                              # optional: runs as a subtask
agent: build                               # optional: which agent runs it
---

Your command prompt here.

You can use:
- $ARGUMENTS — everything the user typed after /your-command
- $1, $2 — positional arguments
- @file-path — inject file content
- !`shell-command` — inject command output
```

### OpenCode project command (skill)

Project commands are skills. See [Skills](skills.md) for how to create one.

### Claude Code command

Claude Code supports per-project commands in `.claude/commands/*.md`:

```markdown
---
description: Short description
---

Command prompt here.
$ARGUMENTS available.
```

Claude Code does not support global commands — each project needs its own copy.

---

## Command frontmatter reference

| Field | Required | Description |
|---|---|---|
| `description` | Yes | One-line description shown in the TUI command list |
| `model` | No | Override the model for this command (e.g., use a cheaper model for simple tasks) |
| `subtask` | No | `true` = runs as a subtask (no user interaction). `false` = interactive. Default: `false` |
| `agent` | No | Which agent runs the command (e.g., `build`, `explore`, `main-orchestrator`) |

---

## Next steps

- [Skills](skills.md) — project-level commands are skills
- [Getting started](getting-started.md) — includes global command installation
