#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from common import load_active_task, path_matches_patterns, project_root

# Commands that should never run from within an AI session
DANGEROUS_BASH = [
    re.compile(r"(^|\s)git\s+push(\s|$)"),
    re.compile(r"(^|\s)rm\s+-rf\s+/(\s|$)"),
    re.compile(r"(^|\s)shutdown(\s|$)"),
    re.compile(r"(^|\s)reboot(\s|$)"),
    re.compile(r"(^|\s)mkfs(\s|$)"),
    re.compile(r"(^|\s)dd\s+if="),
]


def deny(reason: str) -> int:
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        return 0
    data = json.loads(raw)
    tool_name = data.get("tool_name")
    tool_input = data.get("tool_input", {})
    active = load_active_task()

    # Enforce write scope for file modification tools
    if tool_name in {"Write", "Edit"}:
        file_path = tool_input.get("file_path")
        if file_path:
            path = Path(file_path).resolve()
            root = project_root().resolve()
            try:
                rel = path.relative_to(root).as_posix()
            except Exception:
                return deny("Writes outside the project root are blocked.")
            # Runtime state is always allowed
            if rel.startswith(".claude/"):
                return 0
            allowed = active.get("allowed_paths", []) or []
            if allowed and not path_matches_patterns(rel, allowed):
                return deny(
                    f"Write outside active task scope: {rel}\n"
                    f"Allowed paths: {allowed}\n"
                    "Update the task pack's allowed_paths if this file should be in scope."
                )
        return 0

    # Block dangerous shell commands
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        for pattern in DANGEROUS_BASH:
            if pattern.search(command):
                return deny(f"Dangerous command blocked: {command}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
