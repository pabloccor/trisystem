#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from common import append_jsonl, ledger_path, load_active_task, now_iso


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    data = json.loads(raw)
    active = load_active_task()
    task_id = active.get("id")

    append_jsonl(
        ledger_path(),
        {
            "ts": now_iso(),
            "event": "task_completed_hook",
            "hook_payload": data,
            "active_task_id": task_id,
        },
    )

    if task_id:
        handoff = Path(".claude/tasks/handoffs") / f"{task_id}.md"
        if not handoff.exists():
            print(
                f"Task {task_id} cannot be closed without a handoff. "
                f"Expected: {handoff}",
                file=sys.stderr,
            )
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
