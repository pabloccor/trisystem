#!/usr/bin/env python3
from __future__ import annotations

import json
import sys

from common import (
    append_jsonl,
    ledger_path,
    load_active_task,
    load_runtime_state,
    now_iso,
)


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    data = json.loads(raw)
    tool_name = data.get("tool_name")
    tool_input = data.get("tool_input", {})
    active = load_active_task()
    runtime = load_runtime_state()

    record: dict = {
        "ts": now_iso(),
        "event": "post_tool_use",
        "tool_name": tool_name,
        "active_phase_id": runtime.get("active_phase_id"),
        "active_task_id": active.get("id"),
    }
    if tool_name in {"Write", "Edit"}:
        record["file_path"] = tool_input.get("file_path")
    elif tool_name == "Bash":
        record["command"] = tool_input.get("command")

    append_jsonl(ledger_path(), record)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
