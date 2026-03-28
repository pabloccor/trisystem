#!/usr/bin/env python3
from __future__ import annotations

import json
import sys

from bootstrap_three_docs import generate_artifacts, validate_docs
from common import discover_source_docs, now_iso, project_root, relpath


def main() -> int:
    _ = sys.stdin.read()
    docs = discover_source_docs(project_root())
    validation = validate_docs(docs)

    if validation["errors"]:
        msg = [
            "Three-doc contract is INVALID.",
            *[f"ERROR: {e}" for e in validation["errors"]],
            *[f"WARNING: {w}" for w in validation["warnings"]],
            "Run /bootstrap-three-doc-project after fixing the issue.",
        ]
    else:
        result = generate_artifacts()
        docs_found = {
            key: ", ".join(relpath(p) for p in paths) for key, paths in docs.items()
        }
        msg = [
            f"Three-doc contract validated at {now_iso()}",
            f"Instructions: {docs_found.get('instructions', '-')}",
            f"Checklist: {docs_found.get('checklist', '-')}",
            f"Guide: {docs_found.get('guide', '-')}",
            f"Generated phases: {result.get('phase_count', 0)}",
            f"Generated tasks: {result.get('task_count', 0)}",
            "Reminder: consult official docs before planning or implementation.",
        ]

    payload = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": "\n".join(msg),
        }
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
