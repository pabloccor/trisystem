# Permission modes

TriSystem projects run under one of four permission modes. The mode is set at init time
and controls what agents can do without asking for approval.

---

## The four modes

### `autonomous`

**Fully autonomous. No prompts. Includes git push.**

Every operation — file writes, bash commands, git commits, git push, and deployment — runs
without interruption. The scope-guard plugin's dangerous-command blocklist is empty.

Use this when:
- You trust the full agent pipeline end-to-end
- You want continuous delivery with no human checkpoints
- You are running in a CI/CD environment or non-interactive terminal

```json
"trisystem_permission_mode": "autonomous"
```

The `git-manager` agent will stage, commit, and push in a single uninterrupted flow after
QA approval.

---

### `supervised` (default)

**Autonomous except for irreversible actions.**

Most operations run freely. The following require approval:
- `git push` (and `git push <remote> <branch>`)
- `rm -rf` (prompts before destructive deletes)
- Deployment apply/delete commands (`kubectl delete`, `helm upgrade --install`, etc.)

Truly destructive system commands (`shutdown`, `reboot`, `mkfs`, `dd if=`) are
hard-blocked and cannot be approved.

Use this when:
- You want the agent to work at full speed on implementation
- You want one final human checkpoint before code leaves the machine or files are destroyed
- This is the right choice for most projects

```json
"trisystem_permission_mode": "supervised"
```

---

### `guarded`

**Reads are free. Writes and bash require explicit approval.**

File reads, glob searches, grep, list, and web fetches run without prompts. Every file
write, edit, bash command, and git operation requires explicit approval before executing.

Use this when:
- You are working in a sensitive codebase and want to review every change
- You are onboarding to a new project and want to understand what the agent is doing
- You want to use the agent as a pair programmer that suggests changes for you to approve

```json
"trisystem_permission_mode": "guarded"
```

Read-only agents (reviewer, security-auditor, document-analyzer, etc.) are unaffected —
they never write anyway.

---

### `locked`

**Read-only. No writes, no bash, no git.**

The agent can read files, search code, fetch web pages, invoke subagents for analysis, and
load skills — but cannot modify anything. This is enforced at two levels: OpenCode's
`permission` config (denies writes/bash) and the scope-guard plugin (blocks all bash).

Use this when:
- You want the agent to audit or analyze without risk of changes
- You are doing a security review
- You are generating a plan to review before switching to a different mode

```json
"trisystem_permission_mode": "locked"
```

---

## Choosing a mode

| I want... | Mode |
|---|---|
| The agent to work completely on its own, including pushing | `autonomous` |
| The agent to work fast but ask before git push | `supervised` |
| To approve every file change before it happens | `guarded` |
| To explore and plan without any risk of changes | `locked` |

---

## How mode is stored

The mode is stored in `opencode.json` under the `trisystem_permission_mode` key:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "trisystem_permission_mode": "supervised",
  "permission": { ... }
}
```

The `permission` block is the actual OpenCode permission config that enforces the mode.
The `trisystem_permission_mode` key is read by:
- The `scope-guard.js` plugin, to select the right command blocklist
- The `git-manager` agent, to decide whether to push automatically
- The `deployer` agent, to decide whether to prompt before apply commands
- The `AGENTS.md`, to inform the LLM what mode it is operating in

---

## Changing mode after initialization

1. Edit `opencode.json`: update `trisystem_permission_mode` to the new mode
2. Replace the `permission` block with the corresponding preset from
   `shared/permissions/modes.json`
3. Restart OpenCode

**Example — switching to autonomous:**

```json
{
  "$schema": "https://opencode.ai/config.json",
  "trisystem_permission_mode": "autonomous",
  "permission": {
    "*": "allow",
    "doom_loop": "ask"
  }
}
```

---

## How the scope-guard enforces modes

The `scope-guard.js` plugin is a pre-tool hook that runs before every bash command and
file write. It reads `trisystem_permission_mode` from `opencode.json` at runtime and
applies the corresponding blocklist:

| Mode | Blocked bash commands |
|---|---|
| `autonomous` | None |
| `supervised` | `rm -rf /`, `shutdown`, `reboot`, `mkfs`, `dd if=` |
| `guarded` | All write/mutating commands; rm, git push/commit/merge, npm install, etc. |
| `locked` | All bash commands (belt-and-suspenders; OpenCode permissions deny bash first) |

The blocklist is a secondary safety net. The primary enforcement is OpenCode's `permission`
config in `opencode.json`.

---

## Per-agent permission overrides

Some agents override the global permission in their frontmatter to reflect their role:

| Agent | Override | Reason |
|---|---|---|
| `reviewer` | `edit: deny` | Read-only by design in all modes |
| `security-auditor` | `edit: deny` | Read-only by design in all modes |
| `document-analyzer` | `edit: deny` | Read-only by design in all modes |
| `git-manager` | `bash: { "git push *": ask }` | Push requires approval in supervised mode |
| `deployer` | `bash: { apply cmds: ask }` | Destructive deploys ask in supervised mode |

Agent-level overrides are applied on top of the global OpenCode `permission` config using
a last-match-wins merge: when a global rule and an agent rule overlap, the agent rule takes
precedence, even if it is *less* restrictive. This means permissive agent frontmatter can
weaken `guarded`/`locked` modes and must be treated as security-sensitive configuration.

---

## Next steps

- [Agents](agents.md) — understand each agent's role and permissions
- [Plugins](plugins.md) — how scope-guard and ledger work
- [Task lifecycle](task-lifecycle.md) — how tasks flow through the pipeline
