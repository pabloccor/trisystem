# Hooks (Claude Code)

Claude Code uses shell-based lifecycle hooks for runtime automation. Hooks are triggered
at specific points in the session lifecycle and can validate, block, or record actions.

Hook wrappers live in `.claude/hooks/` and call Python scripts in `.claude/bin/`.

---

## Lifecycle events

Claude Code exposes five lifecycle events:

| Event | When it fires | Can block? |
|---|---|---|
| `SessionStart` | When a session begins | No (advisory) |
| `PreToolUse` | Before any tool is executed | Yes — exit non-zero to block |
| `PostToolUse` | After any tool completes | No |
| `SubagentStop` | When a subagent finishes | No (but can enforce requirements) |
| `Stop` | When the session is about to end | Yes — exit non-zero to prevent |

---

## Included hooks

### validate-docs.sh → hook_validate_docs.py

**Event:** `SessionStart`
**Purpose:** Validate that the three source-of-truth documents exist. Compute SHA hashes
and update `.claude/memory/source-manifest.json`.

If any document is missing, the hook logs an error. The session can still start, but the
orchestrator will see the missing files and halt work.

### enforce-task-scope.sh → hook_enforce_task_scope.py

**Event:** `PreToolUse`
**Purpose:** Block file edits outside the active task's `allowed_paths`.

Reads `.claude/memory/active-task.json` to get the allowed paths. If a write/edit tool
targets a file outside those paths, the hook exits with code 2 to block the operation.

Writes to `.claude/` are always allowed (runtime artifacts).

### block-unsafe-stop.sh → hook_block_unsafe_stop.py

**Event:** `Stop`
**Purpose:** Prevent closing the session with tasks in `claimed` or `in_progress` state.

Reads the task registry and checks for any task that isn't in a terminal state. If found,
exits non-zero to warn the user. The session can still be force-closed, but the warning
ensures orphaned tasks are noticed.

### update-ledger.sh → hook_update_ledger.py

**Event:** `PostToolUse`
**Purpose:** Append a JSONL record to `.claude/tasks/ledger.jsonl` after every tool use.

Records: timestamp, tool name, active phase/task, command (if bash), file path (if write).

### run-tests-async.sh → run_tests_async.py

**Event:** `PostToolUse`
**Purpose:** Trigger test runs after file modifications.

If the tool was a write/edit to a source file, and there's an active task with verification
commands, this hook queues an async test run. Results go to the evidence directory.

### capture-subagent-stop.sh → hook_capture_subagent_stop.py

**Event:** `SubagentStop`
**Purpose:** When a subagent (like `developer`) finishes, ensure a handoff file exists.

If no handoff is found in `.claude/tasks/handoffs/<TASK_ID>.md`, the hook creates a
template handoff that the developer must fill in. Also copies the transcript to the
evidence directory.

### on-task-completed.sh → hook_task_completed.py

**Event:** `SubagentStop`
**Purpose:** Check that a completed task has all required artifacts before allowing
the status transition to `done`.

Verifies: handoff exists, review result exists, test evidence exists.

---

## Architecture: shell wrappers + Python scripts

Each hook is a pair:

```
.claude/hooks/validate-docs.sh          ← Shell wrapper (called by Claude Code)
.claude/bin/hook_validate_docs.py        ← Python script (does the actual work)
```

The shell wrapper is minimal — it just calls the Python script with the right arguments:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
exec python3 "$SCRIPT_DIR/hook_validate_docs.py" "$@"
```

**Why the split?**
- Shell wrappers are what Claude Code expects (executable scripts with a shebang)
- Python scripts are easier to write, test, and maintain
- The `common.py` module provides shared utilities (JSON reading, path resolution, logging)

---

## Configuring hooks in settings.json

Hooks are registered in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "command": ".claude/hooks/validate-docs.sh"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "",
        "command": ".claude/hooks/enforce-task-scope.sh"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "command": ".claude/hooks/update-ledger.sh"
      },
      {
        "matcher": "",
        "command": ".claude/hooks/run-tests-async.sh"
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "command": ".claude/hooks/capture-subagent-stop.sh"
      },
      {
        "matcher": "",
        "command": ".claude/hooks/on-task-completed.sh"
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "command": ".claude/hooks/block-unsafe-stop.sh"
      }
    ]
  }
}
```

The `matcher` field can filter which tools trigger the hook (e.g., `"Write"` to only
trigger on write operations). An empty string matches everything.

---

## Writing your own hook

### 1. Create the Python script

```python
#!/usr/bin/env python3
"""My custom hook."""
import sys
import json

def main():
    # Read hook input from stdin (if applicable)
    # stdin contains JSON with tool info for PreToolUse/PostToolUse
    
    # Your logic here
    
    # Exit codes:
    # 0 = OK, continue
    # 2 = Block (PreToolUse/Stop only)
    sys.exit(0)

if __name__ == "__main__":
    main()
```

### 2. Create the shell wrapper

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
exec python3 "$SCRIPT_DIR/my_hook.py" "$@"
```

### 3. Make it executable

```bash
chmod +x .claude/hooks/my-hook.sh
```

### 4. Register in settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "command": ".claude/hooks/my-hook.sh"
      }
    ]
  }
}
```

---

## The common.py module

`.claude/bin/common.py` provides shared utilities for all hook scripts:

- `find_project_root()` — find the repo root from any subdirectory
- `read_json(path, fallback)` — safe JSON file reading
- `write_json(path, data)` — atomic JSON file writing
- `get_active_task()` — read the current active task
- `get_registry()` — read the task registry

Import it in your hook scripts:

```python
from common import find_project_root, read_json, get_active_task
```

---

## OpenCode equivalent

Claude Code hooks map to OpenCode plugins. See [Plugins](plugins.md) for the full mapping.

---

## Troubleshooting

- **Hook not executing:** Check `chmod +x` on the `.sh` file. Verify the path in
  `settings.json` is correct (relative to project root).
- **Hook blocks everything:** Check exit codes. Only exit code 2 blocks in `PreToolUse`
  and `Stop`. Other non-zero codes are warnings.
- **Python import errors:** Ensure `.claude/bin/common.py` exists. Check Python version (3.9+).
- **Hooks run too slowly:** Hooks run synchronously. Keep them fast — avoid network calls
  in `PreToolUse` hooks.

---

## Next steps

- [Plugins](plugins.md) — the OpenCode equivalent
- [Task lifecycle](task-lifecycle.md) — the lifecycle that hooks enforce
- [Rules](rules.md) — the guardrails behind the hooks
