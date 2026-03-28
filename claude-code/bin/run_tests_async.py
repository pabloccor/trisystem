#!/usr/bin/env python3
"""Run verification commands asynchronously after a file write/edit.

Triggered by PostToolUse. Only fires when:
  - The tool is Write or Edit
  - The active task has verification_commands defined
  - No other async test run is currently in progress (lock file)

Results are written to .claude/tasks/evidence/<TASK_ID>/async-check.log
and appended to the ledger.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from common import (
    append_jsonl,
    ledger_path,
    load_active_task,
    now_iso,
    project_root,
    run_commands,
    save_runtime_state,
)

LOCK_FILE = Path(".claude/tasks/.async-test.lock")


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    data = json.loads(raw)

    # Only trigger on file modifications
    if data.get("tool_name") not in {"Write", "Edit"}:
        return 0

    active = load_active_task()
    task_id = active.get("id")
    commands = active.get("verification_commands", []) or []
    if not task_id or not commands:
        return 0

    # Prevent concurrent runs
    if LOCK_FILE.exists():
        return 0

    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    LOCK_FILE.write_text(now_iso(), encoding="utf-8")
    try:
        results = run_commands(commands, cwd=project_root(), timeout=900)
        evidence_dir = Path(".claude/tasks/evidence") / task_id
        evidence_dir.mkdir(parents=True, exist_ok=True)
        log_file = evidence_dir / "async-check.log"

        chunks = []
        for item in results:
            chunks.append(f"$ {item['command']}\n[returncode] {item['returncode']}\n")
            if item["stdout"]:
                chunks.append("STDOUT:\n" + item["stdout"] + "\n")
            if item["stderr"]:
                chunks.append("STDERR:\n" + item["stderr"] + "\n")
            chunks.append("\n")
        log_file.write_text("".join(chunks), encoding="utf-8")

        append_jsonl(
            ledger_path(),
            {
                "ts": now_iso(),
                "event": "async_test_run",
                "active_task_id": task_id,
                "commands": commands,
                "log_file": str(log_file),
                "success": all(item["returncode"] == 0 for item in results),
            },
        )
    finally:
        try:
            LOCK_FILE.unlink()
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
