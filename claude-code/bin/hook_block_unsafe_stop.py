#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from common import load_active_task

IN_PROGRESS_STATUSES = {
    "claimed",
    "in_progress",
    "review_pending",
    "test_pending",
    "qa_pending",
    "needs_debug",
    "blocked",
}


def main() -> int:
    _ = sys.stdin.read()
    active = load_active_task()
    task_id = active.get("id")
    status = active.get("status")
    if task_id and status in IN_PROGRESS_STATUSES:
        handoff = Path(".claude/tasks/handoffs") / f"{task_id}.md"
        if not handoff.exists():
            payload = {
                "decision": "block",
                "reason": (
                    f"Active task {task_id} is in status '{status}' and has no handoff yet. "
                    "Write a handoff file before stopping."
                ),
            }
            print(json.dumps(payload, ensure_ascii=False))
            return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
