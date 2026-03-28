
# Cheat Sheet: OpenCode — Three-Doc Project Template
Suggested location: `CHEAT_SHEET_OPENCODE.md` (project root)

---

## Quick summary

- You need exactly 3 source-of-truth documents:
  - `instrucciones.md`
  - `xxx_IMPLEMENTATION_CHECKLIST.md`
  - `xxx_TECHNICAL_GUIDE.md`
- Canonical location: `docs/source-of-truth/`
- Native OpenCode structure in `.opencode/`:
  - `.opencode/agents/` — specialized agents (16+)
  - `.opencode/commands/` — custom slash commands (frontmatter-based `.md`)
  - `.opencode/skills/` — reusable workflow skills
  - `.opencode/plugins/` — JS/TS event-based plugins (replaces hooks)
  - `.opencode/rules/` — always-loaded instruction rules
- Compatibility layer kept in `.claude/`:
  - `.claude/bin/` — bootstrap and helper scripts
  - `.claude/memory/` — runtime memory (derived)
  - `.claude/tasks/` — runtime task state (derived)
- Root-level files:
  - `AGENTS.md` — project-wide operating rules (replaces `CLAUDE.md`)
  - `opencode.json` — permissions, instructions, tool config

---

## Directory structure

```
project-root/
├── AGENTS.md                        # Project operating rules (OpenCode reads this)
├── opencode.json                    # Permissions, instructions path, tool config
├── docs/
│   └── source-of-truth/
│       ├── instrucciones.md
│       ├── *_IMPLEMENTATION_CHECKLIST.md
│       └── *_TECHNICAL_GUIDE.md
├── .opencode/
│   ├── agents/                      # 16+ specialized agents
│   ├── commands/                    # Custom slash commands
│   ├── skills/                      # Reusable workflow skills
│   ├── plugins/                     # JS/TS event-based plugins
│   └── rules/                       # Always-loaded instruction rules
├── .claude/                         # Compatibility layer
│   ├── bin/                         # Bootstrap + helper scripts
│   ├── memory/                      # Runtime memory (derived)
│   ├── tasks/                       # Runtime task state (derived)
│   ├── hooks/                       # Legacy shell hooks (superseded by plugins)
│   └── settings.json                # Legacy settings (superseded by opencode.json)
```

---

## Configuration file: `opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".opencode/rules/*.md"
  ],
  "permission": {
    "edit": "ask",
    "bash": {
      "*": "ask",
      "git status*": "allow",
      "ls*": "allow",
      "find*": "allow",
      "cat*": "allow",
      "grep *": "allow",
      "rg *": "allow",
      "python3 .claude/bin/bootstrap_three_docs.py*": "allow",
      "python .claude/bin/bootstrap_three_docs.py*": "allow"
    },
    "webfetch": "allow",
    "task": "allow",
    "skill": "allow"
  }
}
```

Key differences from Claude Code `settings.json`:
- `instructions` field loads rules automatically (replaces `CLAUDE.md` includes).
- `permission` block replaces Claude's `allowedTools` / `blockedCommands`.
- Glob patterns for bash commands: **last matching rule wins**.

---

## Main commands

### 1) Set up a new project (one-time)

```bash
# Clone the template (temporary — can be deleted after)
git clone https://github.com/pabloccor/trisystem.git
cd trisystem

# Run the interactive wizard; outputs everything into your new project
./scripts/init-project.sh /path/to/your-new-project
# The wizard will ask:
#   1. Target directory
#   2. Project name (used as document prefix)
#   3. Runtime: opencode | claude-code | both
#   4. Template size: slim (starter docs) | empty (generate with ChatGPT)
#   5. Cheat sheet: copy yes/no

# The template repo is no longer needed — delete it if you like
cd ../ && rm -rf trisystem/
```

### 2) Bootstrap runtime artifacts

```bash
cd /path/to/your-new-project

# (optional) virtualenv for the bootstrap script
python3 -m venv .venv && source .venv/bin/activate

# generate runtime artifacts from the 3 source docs
python3 .claude/bin/bootstrap_three_docs.py --refresh
# --refresh     -> overwrite existing artifacts
# --dry-run     -> validate and show what would be done
# --outdir PATH -> write to PATH instead of .claude/
# --verbose     -> extended logs
```

### 3) Launch OpenCode

```bash
# Start OpenCode in the project directory
opencode

# OpenCode reads AGENTS.md automatically on startup.
# Use @main-orchestrator to invoke structured execution:
#   @main-orchestrator bootstrap the project

# Or run the custom command directly:
#   /bootstrap-three-doc-project
```

> Note: Unlike Claude Code (`claude --agent main-orchestrator`), OpenCode loads agents from `.opencode/agents/` and you invoke them with `@agent-name` or switch primary agents with **Tab**.

---

## Commands inside an OpenCode session

Commands are defined in `.opencode/commands/*.md` with YAML frontmatter.

| Command | Description | Agent |
|---|---|---|
| `/bootstrap-three-doc-project` | Full bootstrap: validate docs, generate artifacts, set active phase | `main-orchestrator` |
| `/phase-execution [phase]` | Execute a specific phase in the controlled loop | `phase-controller` |
| `/build-task-pack` | Build or refresh the task pack for a task | `task-planner` |
| `/dev-loop` | Start, restart, or check dev servers (back + front) | `developer` |
| `/dev-verify` | Verify current slice works in localhost | `tester` |
| `/close-task` | Close or reject a task after QA | `phase-controller` |
| `/write-handoff` | Generate a standard handoff file for the active task | `developer` |
| `/official-docs-check` | Verify claims against official documentation | `official-docs-researcher` |
| `/validate-three-doc-contract` | Validate the three-doc contract is intact | `document-analyzer` |
| `/deploy-k8s` | Execute K8s deployment workflow | `deployer` |

### Command file format

```markdown
---
description: Short description shown in the TUI
agent: main-orchestrator
---

Prompt content here. Supports $ARGUMENTS, $1, $2, @file-references,
and !`shell-command` injection.
```

### Useful in-session patterns

```
# Mention an agent directly
@main-orchestrator list all phases and their status

# Use explore subagent for read-only search
@explore find all files that reference the external API

# Switch to Plan mode (Tab key) for analysis without changes
<Tab>  # switches to Plan agent (read-only)
```

---

## Task lifecycle (typical state flow)

```
parsed -> ready -> claimed -> in_progress -> self_checked ->
  review_pending -> review_passed | review_failed ->
  test_passed | test_failed -> qa_passed | qa_failed -> done
```

Mandatory gates: `review`, `tester`, `qa-validator`.

---

## Verification commands

Each task YAML includes a `verification_commands` block. Typical examples:

```yaml
verification_commands:
  - python -m pytest tests/unit/test_agent_builder.py -q
  - ./scripts/run-lint.sh
  - uv run pytest tests/integration -q
```

The `developer` agent must execute these commands and store output in `.claude/tasks/evidence/<TASK_ID>/`.

---

## Plugins (replaces Claude hooks)

OpenCode uses **JS/TS plugins** instead of shell-based lifecycle hooks. Plugins live in `.opencode/plugins/` and are loaded automatically at startup.

### Event mapping

| Claude Hook | OpenCode Plugin Event | Purpose |
|---|---|---|
| `SessionStart` | Plugin init function (runs on load) | Validate docs, compute hashes |
| `PreToolUse` | `tool.execute.before` | Scope enforcement, block dangerous commands |
| `PostToolUse` | `tool.execute.after` | Update ledger, trigger async tests |
| `SubagentStop` | `session.idle` / `session.compacted` | Handoff enforcement (partial parity) |
| `Stop` | `session.idle` | Prevent closing with active tasks |

> Note: Not all Claude lifecycle hooks have exact 1:1 equivalents in OpenCode. Handoff enforcement via `SubagentStop` needs runtime validation. See `MIGRATION.md` in the `opencode/` directory for details.

### Plugin: scope-guard.js (blocks dangerous commands + enforces task scope)

```js
// .opencode/plugins/scope-guard.js
import fs from "node:fs/promises"
import path from "node:path"

const DANGEROUS = [
  /(^|\s)git\s+push(\s|$)/,
  /(^|\s)rm\s+-rf\s+\/(\s|$)/,
  /(^|\s)shutdown(\s|$)/,
  /(^|\s)reboot(\s|$)/,
  /(^|\s)mkfs(\s|$)/,
  /(^|\s)dd\s+if=/,
]

function wildcardToRegex(pattern) {
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&")
  return new RegExp("^" + escaped.replace(/\*/g, ".*").replace(/\?/g, ".") + "$")
}

async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf8")
    return JSON.parse(raw)
  } catch {
    return fallback
  }
}

export const ScopeGuardPlugin = async ({ worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = input?.tool || ""
      const args = output?.args || input?.args || {}

      // Block dangerous bash commands
      if (tool === "bash") {
        const command = args.command || ""
        for (const pattern of DANGEROUS) {
          if (pattern.test(command)) {
            throw new Error(`Blocked dangerous command: ${command}`)
          }
        }
      }

      // Enforce task scope for write operations
      if (["write", "edit", "patch", "multiedit"].includes(tool)) {
        const filePath = args.filePath || args.file_path || args.path
        if (!filePath) return
        const abs = path.isAbsolute(filePath) ? filePath : path.join(worktree, filePath)
        const rel = path.relative(worktree, abs).replace(/\\/g, "/")
        if (rel.startsWith('.claude/')) return
        const active = await readJson(
          path.join(worktree, '.claude/memory/active-task.json'), {}
        )
        const allowed = active?.allowed_paths || []
        if (allowed.length === 0) return
        const matchesAny = allowed.some(p =>
          wildcardToRegex(p.replace(/^\.\//, "")).test(rel)
        )
        if (!matchesAny) {
          throw new Error(`Write outside active task scope: ${rel}`)
        }
      }
    },
  }
}
```

### Plugin: ledger.js (JSONL audit trail after every tool use)

```js
// .opencode/plugins/ledger.js
import fs from "node:fs/promises"
import path from "node:path"

async function ensureDir(filePath) {
  await fs.mkdir(path.dirname(filePath), { recursive: true })
}

async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf8")
    return JSON.parse(raw)
  } catch {
    return fallback
  }
}

export const LedgerPlugin = async ({ worktree }) => {
  return {
    "tool.execute.after": async (input, output) => {
      const ledgerPath = path.join(worktree, '.claude/tasks/ledger.jsonl')
      await ensureDir(ledgerPath)
      const runtime = await readJson(
        path.join(worktree, '.claude/tasks/runtime-state.json'), {}
      )
      const activeTask = await readJson(
        path.join(worktree, '.claude/memory/active-task.json'), {}
      )
      const args = output?.args || input?.args || {}
      const record = {
        ts: new Date().toISOString(),
        event: 'opencode_post_tool_use',
        tool_name: input?.tool || null,
        active_phase_id: runtime?.active_phase_id || null,
        active_task_id: activeTask?.id || null,
        command: args.command || null,
        file_path: args.filePath || args.file_path || args.path || null,
      }
      await fs.appendFile(ledgerPath, JSON.stringify(record) + '\n', 'utf8')
    },
  }
}
```

---

## `official-docs-researcher` — what to check and how

- Extracts "claims" from the Technical Guide, for example:
  - Required framework versions
  - External API endpoints
  - Deployment recommendations
- For each claim:
  - Query official docs (WebFetch)
  - Check for deprecations or breaking changes
  - Verify version availability
- Result: `official-docs-report.json` with `status: ok|warning|critical`

If `critical` -> `phase-controller` blocks the phase and creates a mitigation task.

---

## Git management (git-manager agent)

Within the flow controlled by the `git-manager` agent:

```bash
# create branch for the task
git checkout -b task/P03-S01-T001

# stage changes
git add <paths>

# commit with task metadata
git commit -m "P03-S01-T001: Implement build_agent() — task metadata: {\"task\":\"P03-S01-T001\"}"

# generate PR text (helper script)
python .claude/bin/gen_pr_text.py --task P03-S01-T001

# push — only git-manager should push
# git push origin task/P03-S01-T001
```

> Note: The `scope-guard.js` plugin blocks `git push` from all agents. Push should only be done manually or through the `git-manager` agent after QA passes.

---

## Rules (always-loaded instructions)

Rules in `.opencode/rules/` are loaded automatically via `opencode.json`'s `instructions` field.

| Rule file | Purpose |
|---|---|
| `00-three-doc-contract.md` | The three source docs are the only project truth |
| `01-official-docs-first.md` | Consult official docs before changing stack, APIs, auth, deployment |
| `02-phase-execution.md` | Work in phases; don't skip gates |
| `03-traceability.md` | Every change must be traceable to a task ID |
| `04-dev-loop-verify.md` | Dev servers must be running; every slice needs browser verification |

---

## Agents available

All agents are in `.opencode/agents/` with YAML frontmatter defining `description`, `mode`, `temperature`, and `permission`.

| Agent | Mode | Role |
|---|---|---|
| `main-orchestrator` | primary | Top-level coordinator for the three-doc system |
| `developer` | subagent | Implements one approved task at a time |
| `reviewer` | subagent | Code review for correctness, style, coverage |
| `tester` | subagent | Runs verification commands and reports results |
| `debugger` | subagent | Investigates failures and proposes fixes |
| `qa-validator` | subagent | Final quality gate before git operations |
| `git-manager` | subagent | Prepares commits, PR text, release notes |
| `phase-controller` | subagent | Manages phase transitions and task selection |
| `task-planner` | subagent | Decomposes phases into atomic tasks |
| `context-curator` | subagent | Prepares minimal context packs for workers |
| `project-architect` | subagent | Compiles the executable architecture contract |
| `document-analyzer` | subagent | Validates the three-doc contract |
| `official-docs-researcher` | subagent | Verifies claims against official documentation |
| `security-auditor` | subagent | Security review of changes |
| `evidence-reporter` | subagent | Compiles evidence for task completion |
| `deployer` | subagent | Handles K8s/infrastructure deployment |
| `technical-analyst` | subagent | Analyzes technical feasibility and risks |

---

## Troubleshooting

- **"Missing files"**: Ensure exact names. Bootstrap searches for `*_IMPLEMENTATION_CHECKLIST.md`. Check `docs/source-of-truth/` first, then the repo root.
- **"Bootstrap generates no tasks"**: Use `--verbose` and check permissions. Review `python3 .claude/bin/bootstrap_three_docs.py` stdout.
- **"Plugin not loading"**: Ensure `.opencode/plugins/*.js` files export named functions. Check the OpenCode startup log for plugin errors.
- **"Scope guard blocks my edit"**: Check `.claude/memory/active-task.json` — the `allowed_paths` field controls what the developer can edit. If empty, all paths are allowed.
- **"official-docs-researcher fails on network"**: Activate offline mode or provide a local snapshot. The command accepts local file references.
- **"Git conflicts"**: Rebase/merge locally. Use git worktrees to isolate changes per task.
- **"Commands not appearing in TUI"**: Verify `.opencode/commands/*.md` files have valid YAML frontmatter with at least a `description` field.
- **"Permissions behave unexpectedly"**: In `opencode.json`, the last matching bash glob wins. Check agent-level `permission` overrides in frontmatter too.

---

## Best practices (quick summary)

- Keep the 3 source docs as the single source of truth; avoid parallel edits without validation.
- Atomic tasks: 1 task = 1 verifiable objective = 1 PR.
- Write complete handoffs in `.claude/tasks/handoffs/<TASK_ID>.md`.
- Do not allow `git push` from worker agents; centralize through `git-manager`.
- Run `/official-docs-check` at the start of each critical phase.
- Keep `.claude/memory/` readable; review it in code reviews if there is drift.
- Use `/dev-loop` to start dev servers before any implementation work.
- Use `/dev-verify` after each slice to confirm it works in localhost.
- Use Plan mode (**Tab** to switch) when analyzing or planning without making changes.
- Prefer `@explore` for read-only codebase searches to keep context small.

---

## Minimal usage example (steps)

1. `git clone https://github.com/pabloccor/trisystem.git && cd trisystem`
2. `./scripts/init-project.sh /path/to/your-new-project` — choose `opencode` (or `both`)
3. `cd /path/to/your-new-project`
4. `python3 .claude/bin/bootstrap_three_docs.py --refresh`
5. `opencode`
6. `/bootstrap-three-doc-project`
4. `@main-orchestrator list phases`
5. `@main-orchestrator inspect task P03-S01-T001`
6. `@main-orchestrator claim task P03-S01-T001`
7. `@main-orchestrator run task P03-S01-T001`
8. Wait for developer handoff in `.claude/tasks/handoffs/`
9. `reviewer` and `tester` process the task
10. `git-manager` prepares commit and PR text

---

## Compatibility note

This project keeps both `.claude/` and `.opencode/` directories:
- `.opencode/` is the **native** OpenCode path for agents, commands, skills, plugins, and rules.
- `.claude/` is kept for **backward compatibility** and runtime artifacts (memory, tasks, bootstrap scripts).
- Once the OpenCode runtime is fully validated, `.claude/` can be reduced to only the runtime artifacts still needed.

See `opencode/MIGRATION.md` for the full migration assessment.
