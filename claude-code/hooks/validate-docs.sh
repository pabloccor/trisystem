#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$PROJECT_DIR/.claude/bin/hook_validate_docs.py"
fi
exit 0
