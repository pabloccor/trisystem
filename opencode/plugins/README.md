# OpenCode plugins

## scope-guard.js
Pre-tool hook that:
- Blocks dangerous bash commands (rm -rf /, git push, shutdown, etc.)
- Enforces file-write scope based on `active-task.json` allowed_paths

## ledger.js
Post-tool hook that appends JSONL audit entries to `.claude/tasks/ledger.jsonl`.

## Migration parity with Claude Code hooks

| Claude Code hook | OpenCode plugin | Status |
|---|---|---|
| hook_enforce_task_scope | scope-guard.js | Covered |
| hook_update_ledger | ledger.js | Covered |
| hook_validate_docs | — | Not yet ported (run manually via /validate-three-doc-contract) |
| hook_capture_subagent_stop | — | Not yet ported (OpenCode subagent lifecycle differs) |
| hook_block_unsafe_stop | — | Not yet ported (no stop-event hook in OpenCode) |
| hook_task_completed | — | Not yet ported (use close-task skill manually) |
| run_tests_async | — | Not yet ported (use tester agent directly) |
| bootstrap_three_docs | — | Run via /bootstrap-three-doc-project command |

Contributions to close these gaps are welcome.
