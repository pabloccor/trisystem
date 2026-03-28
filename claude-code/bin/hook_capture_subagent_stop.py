#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from common import (
    append_jsonl,
    find_task,
    ledger_path,
    load_active_task,
    load_registry,
    load_runtime_state,
    now_iso,
    save_registry,
    save_runtime_state,
    sync_active_state_from_registry,
)

# Worker agents that must produce a handoff file before stopping
WORKER_TYPES_REQUIRING_HANDOFF = {
    "developer",
    "tester",
    "reviewer",
    "debugger",
    "qa-validator",
    "deployer",
}

KEY_RE = {
    "task_id": re.compile(r"^TASK_ID:\s*(.+?)\s*$", re.MULTILINE),
    "outcome": re.compile(r"^OUTCOME:\s*(.+?)\s*$", re.MULTILINE),
    "next_status": re.compile(r"^NEXT_STATUS:\s*(.+?)\s*$", re.MULTILINE),
    "handoff": re.compile(r"^HANDOFF:\s*(.+?)\s*$", re.MULTILINE),
    "evidence": re.compile(r"^EVIDENCE:\s*(.+?)\s*$", re.MULTILINE),
}


def parse_trailer(text: str) -> dict[str, str]:
    """Extract structured key-value pairs from the agent's last message."""
    result = {}
    for key, regex in KEY_RE.items():
        m = regex.search(text or "")
        if m:
            result[key] = m.group(1).strip()
    return result


def block(reason: str) -> int:
    payload = {
        "decision": "block",
        "reason": reason,
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    data = json.loads(raw)
    agent_type = data.get("agent_type")
    last_message = data.get("last_assistant_message", "") or ""
    trailer = parse_trailer(last_message)
    active = load_active_task()
    runtime = load_runtime_state()

    # Always append to ledger for audit trail
    append_jsonl(
        ledger_path(),
        {
            "ts": now_iso(),
            "event": "subagent_stop",
            "agent_type": agent_type,
            "active_task_id": active.get("id"),
            "trailer": trailer,
        },
    )

    # Workers that touch code must provide a handoff before stopping
    if agent_type in WORKER_TYPES_REQUIRING_HANDOFF and active.get("id"):
        if not trailer.get("handoff"):
            return block(
                f"{agent_type} must finish with a HANDOFF trailer line before stopping. "
                "Format: 'HANDOFF: .claude/tasks/handoffs/<TASK_ID>.md'"
            )
        handoff_path = Path(trailer["handoff"])
        if not handoff_path.is_absolute():
            handoff_path = Path.cwd() / handoff_path
        if not handoff_path.exists():
            return block(
                f"{agent_type} reported handoff '{trailer['handoff']}', "
                "but that file does not exist yet. Write the handoff file first."
            )

    # Update registry if the trailer includes a status transition
    if trailer.get("task_id") and trailer.get("next_status"):
        registry = load_registry()
        task = find_task(registry, trailer["task_id"])
        if task:
            task["status"] = trailer["next_status"]
            task["last_outcome"] = trailer.get("outcome")
            task["last_updated_by"] = agent_type
            task["handoff_path"] = trailer.get("handoff", task.get("handoff_path"))
            if trailer.get("evidence"):
                task["evidence_dir"] = trailer["evidence"]
            save_registry(registry)
            sync_active_state_from_registry(load_registry())

    runtime["last_worker"] = agent_type
    runtime["last_event"] = "subagent_stop"
    save_runtime_state(runtime)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
