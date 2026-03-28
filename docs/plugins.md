# Plugins (OpenCode)

OpenCode uses JavaScript plugins for runtime automation. Plugins replace Claude Code's
shell-based lifecycle hooks with a richer event system.

Plugins live in `.opencode/plugins/` and are loaded automatically at startup.

---

## Included plugins

### scope-guard.js

**Purpose:** Blocks dangerous commands and enforces task-scoped file edits.

**What it does:**
- Intercepts every `bash` tool call and checks the command against a list of dangerous patterns
  (`git push`, `rm -rf /`, `shutdown`, `reboot`, `mkfs`, `dd if=`)
- Intercepts every write operation (`write`, `edit`, `patch`, `multiedit`) and checks the
  target file against the active task's `allowed_paths`
- If a write targets a file outside the allowed paths, it throws an error and blocks the edit
- The `.claude/` directory is always allowed (runtime artifacts)

**Dangerous command patterns blocked:**
```
git push         — only git-manager should push
rm -rf /         — catastrophic deletion
shutdown         — system shutdown
reboot           — system reboot
mkfs             — filesystem format
dd if=           — raw disk write
```

**How scope enforcement works:**
1. Plugin reads `.claude/memory/active-task.json`
2. Extracts the `allowed_paths` array (e.g., `["src/models/**", "tests/unit/**"]`)
3. Converts glob patterns to regexes
4. Checks if the target file matches any allowed path
5. If `allowed_paths` is empty, all paths are allowed (no task claimed = no restriction)

### ledger.js

**Purpose:** JSONL audit trail after every tool use.

**What it does:**
- After every tool invocation, appends a JSON record to `.claude/tasks/ledger.jsonl`
- Records: timestamp, tool name, active phase/task, command (if bash), file path (if write)

**Example ledger entries:**
```json
{"ts":"2025-01-15T10:30:00Z","event":"opencode_post_tool_use","tool_name":"write","active_phase_id":"P01","active_task_id":"P01-S01-T001","command":null,"file_path":"src/models/user.py"}
{"ts":"2025-01-15T10:30:05Z","event":"opencode_post_tool_use","tool_name":"bash","active_phase_id":"P01","active_task_id":"P01-S01-T001","command":"python -m pytest tests/ -q","file_path":null}
```

---

## Event system

Plugins hook into OpenCode's event lifecycle:

| Event | When it fires | Typical use |
|---|---|---|
| `tool.execute.before` | Before any tool runs | Block dangerous commands, enforce scope |
| `tool.execute.after` | After any tool completes | Update ledger, trigger async tests |
| `session.idle` | When the agent finishes a response | Handoff enforcement (partial) |
| `session.compacted` | When context is compacted | Save state before context loss |

### Event handler signature

```js
export const MyPlugin = async ({ worktree }) => {
  // worktree = absolute path to the project root

  return {
    "tool.execute.before": async (input, output) => {
      // input.tool = tool name (e.g., "bash", "write", "edit")
      // input.args or output.args = tool arguments
      // throw new Error("message") to block the tool
    },

    "tool.execute.after": async (input, output) => {
      // Same shape as before, but runs after the tool completes
      // Cannot block — tool has already run
    },
  }
}
```

---

## Writing your own plugin

### 1. Create the file

```bash
# In your project
touch .opencode/plugins/my-plugin.js
```

### 2. Export a named async function

```js
import fs from "node:fs/promises"
import path from "node:path"

export const MyPlugin = async ({ worktree }) => {
  // Initialization code runs once at startup
  console.log("MyPlugin loaded for", worktree)

  return {
    "tool.execute.before": async (input, output) => {
      // Your pre-tool logic
    },

    "tool.execute.after": async (input, output) => {
      // Your post-tool logic
    },
  }
}
```

### 3. Key patterns

**Reading project state:**
```js
async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf8")
    return JSON.parse(raw)
  } catch {
    return fallback
  }
}

// Read active task
const task = await readJson(
  path.join(worktree, ".claude/memory/active-task.json"), {}
)
```

**Blocking a tool call:**
```js
"tool.execute.before": async (input, output) => {
  if (someCondition) {
    throw new Error("Blocked: reason")
  }
}
```

**Appending to a log:**
```js
"tool.execute.after": async (input, output) => {
  const logPath = path.join(worktree, ".claude/tasks/my-log.jsonl")
  await fs.mkdir(path.dirname(logPath), { recursive: true })
  const record = { ts: new Date().toISOString(), tool: input?.tool }
  await fs.appendFile(logPath, JSON.stringify(record) + "\n", "utf8")
}
```

### 4. Plugin dependencies

If your plugin needs npm packages, add them to `.opencode/package.json`:

```json
{
  "type": "module",
  "dependencies": {
    "some-package": "^1.0.0"
  }
}
```

Then run `npm install` in the `.opencode/` directory.

The included plugins only use Node.js built-ins (`node:fs/promises`, `node:path`), so no
external dependencies are required out of the box.

---

## Claude Code equivalent

Plugins replace Claude Code's shell-based hooks. The mapping:

| Claude Code hook | OpenCode plugin event | Notes |
|---|---|---|
| `SessionStart` | Plugin init (runs on load) | Runs once when OpenCode starts |
| `PreToolUse` | `tool.execute.before` | Can block tool execution |
| `PostToolUse` | `tool.execute.after` | Cannot block, tool already ran |
| `SubagentStop` | `session.idle` | Partial parity — no direct subagent concept |
| `Stop` | `session.idle` | Partial parity |

For details on Claude Code hooks, see [Hooks](hooks.md).

---

## Troubleshooting

- **Plugin not loading:** Check that the file exports a named function (not default export).
  Check OpenCode's startup log for error messages.
- **Plugin blocks everything:** Check your `tool.execute.before` logic. Add `console.log`
  statements to debug. Make sure you're only blocking what you intend to.
- **Ledger not writing:** Check that `.claude/tasks/` directory exists with write permissions.

---

## Next steps

- [Hooks](hooks.md) — the Claude Code equivalent
- [Rules](rules.md) — the guardrails that plugins enforce
- [Task lifecycle](task-lifecycle.md) — the lifecycle that plugins automate
