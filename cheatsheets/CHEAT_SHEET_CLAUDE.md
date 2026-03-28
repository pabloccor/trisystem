# Cheat Sheet: Claude Code — Three-Doc Project Template

Suggested location: `CHEAT_SHEET_CLAUDE.md` (project root or `.claude/`)

---

## Quick summary

- You need exactly 3 source-of-truth documents in `docs/source-of-truth/`:
  - `instrucciones.md`
  - `xxx_IMPLEMENTATION_CHECKLIST.md`
  - `xxx_TECHNICAL_GUIDE.md`
- Structure generated in `.claude/` by the bootstrap script:
  - `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/memory/`, `.claude/tasks/`

---

## Main commands

### 1) Preparation and bootstrap

```bash
# (optional) create virtualenv
python3 -m venv .venv
source .venv/bin/activate

# install deps if present
pip install -r .claude/requirements.txt  # if present

# generate runtime artifacts from the 3 source docs
python3 .claude/bin/bootstrap_three_docs.py --refresh
# Common options:
# --refresh     -> overwrite existing artifacts
# --dry-run     -> validate and show what would be done
# --outdir PATH -> write to PATH instead of .claude/
# --verbose     -> extended logs
```

### 2) Launch Claude Code

```bash
# Start a session with the main orchestrator agent
claude --agent main-orchestrator

# Inside the session you can run predefined skills, for example:
# /bootstrap-three-doc-project
```

> Note: the exact launcher name (`claude`, `claude-code`, etc.) may vary by installation.

---

## Commands inside a Claude Code session

- `/bootstrap-three-doc-project` — run the full bootstrap flow from within the session.
- `list phases` — list generated phases and their status.
- `inspect phase P03` — view phase details.
- `inspect task P03-S01-T001` — view a task pack.
- `claim task P03-S01-T001` — assign/claim a task.
- `run task P03-S01-T001` — launch the `developer` subagent to execute the task.
- `show queue` — view the `ready`, `blocked`, `in_progress` queues.
- `force-gate P03` — force a gate check (e.g. run `official-docs-researcher`).
- `report phase P03` — generate a phase report.

(These commands map to skills in `.claude/skills/`.)

---

## Task lifecycle (typical state flow)

```
parsed -> ready -> claimed -> in_progress -> self_checked ->
  review_pending -> review_passed | review_failed ->
  test_passed | test_failed -> qa_passed | qa_failed -> done
```

Mandatory gates: `review`, `tester`, `qa-validator`.

---

## Verification commands

Each task YAML includes a `verification_commands` block. Typical examples:

```yaml
verification_commands:
  - python -m pytest tests/unit/test_agent_builder.py -q
  - ./scripts/run-lint.sh
  - uv run pytest tests/integration -q
```

The `developer` agent must execute these commands and store output in
`.claude/tasks/evidence/<TASK_ID>/`.

---

## Important hooks and what they do

- `SessionStart`:
  - Validate existence of the 3 source docs and compute hashes.
  - Update `.claude/memory/source-manifest.json`.

- `PreToolUse`:
  - Enforce task scope (block edits outside `allowed_paths`).
  - Block dangerous commands (`git push`, reads from `secrets/`).

- `PostToolUse`:
  - Update ledger: `.claude/tasks/ledger.jsonl`.
  - Launch async tests if applicable.

- `SubagentStop`:
  - Require handoff in `.claude/tasks/handoffs/<TASK_ID>.md`.
  - Review transcript and put task in `review_pending`.

- `Stop`:
  - Prevent closing the session with tasks in `claimed` or `in_progress` state.

Hook scripts in `.claude/hooks/`:
- `validate-docs.sh`
- `enforce-task-scope.sh`
- `capture-subagent-stop.sh`
- `update-ledger.sh`
- `run-tests-async.sh`
- `block-unsafe-commands.sh`

---

## Hook script snippets (templates)

### validate-docs.sh (minimal)
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
for f in *_IMPLEMENTATION_CHECKLIST.md *_TECHNICAL_GUIDE.md instrucciones.md; do
  if [ ! -f "$ROOT/$f" ]; then
    echo "ERROR: missing $f"
    exit 2
  fi
done
echo "{}" > .claude/memory/source-manifest.json
echo "[OK] docs found"
```

### capture-subagent-stop.sh (skeleton)
```bash
#!/usr/bin/env bash
set -euo pipefail
TASK_ID="$1"
TRANSCRIPT_PATH="$2"
mkdir -p .claude/tasks/evidence/"$TASK_ID"
cp "$TRANSCRIPT_PATH" .claude/tasks/evidence/"$TASK_ID"/transcript.txt
HANDOFF=".claude/tasks/handoffs/${TASK_ID}.md"
if [ ! -f "$HANDOFF" ]; then
  echo "Handoff for $TASK_ID required. Creating template."
  cat > "$HANDOFF" <<EOF
# Handoff $TASK_ID

- files_changed:
- commands_run:
- tests_passed:
- tests_failed:
- risks:
EOF
fi
echo "{\"task\":\"$TASK_ID\",\"action\":\"subagent_stop\",\"time\":\"$(date -Iseconds)\"}" >> .claude/tasks/ledger.jsonl
```

---

## `official-docs-researcher` — what to check and how

- Extracts "claims" from the Technical Guide, for example:
  - Required framework versions
  - External API endpoints
  - Deployment recommendations
- For each claim:
  - Query official docs (WebSearch / WebFetch)
  - Check for deprecations or breaking changes
  - Verify version availability
- Result: `official-docs-report.json` with `status: ok|warning|critical`

If `critical` → `phase-controller` blocks the phase and creates a mitigation task.

---

## Git management (git-manager agent)

Within the flow controlled by the `git-manager` agent:

```bash
# create branch for the task
git checkout -b task/P03-S01-T001

# stage changes
git add <paths>

# commit with task metadata
git commit -m "P03-S01-T001: Implement build_agent() — task metadata: {\"task\":\"P03-S01-T001\"}"

# generate PR text (helper script)
python .claude/bin/gen_pr_text.py --task P03-S01-T001

# push — only git-manager should push
# git push origin task/P03-S01-T001
```

> Note: `PreToolUse` blocks `git push` from subagents. Push is performed only via `git-manager`.

---

## Troubleshooting

- **"Missing files"**: Ensure exact names. Bootstrap searches for `*_IMPLEMENTATION_CHECKLIST.md`.
  Check `docs/source-of-truth/` first, then the repo root.
- **"Bootstrap generates no tasks"**: Use `--verbose` and check permissions. Review
  `python3 .claude/bin/bootstrap_three_docs.py` stdout.
- **"SubagentStop hook not executing"**: Check execute permissions — `chmod +x .claude/hooks/*.sh`
  — and verify the paths configured in `.claude/settings.json`.
- **"official-docs-researcher fails on network"**: Activate offline mode or provide a local
  snapshot. The skill can accept local file references.
- **"Git conflicts"**: Rebase/merge locally. Use git worktrees to isolate changes per task.

---

## Best practices (quick summary)

- Keep the 3 source docs as the single source of truth; avoid parallel edits without validation.
- Atomic tasks: 1 task = 1 verifiable objective = 1 PR.
- Write complete handoffs in `.claude/tasks/handoffs/<TASK_ID>.md`.
- Do not allow `git push` from worker agents; centralize through `git-manager`.
- Run `official-docs-researcher` at the start of each critical phase.
- Keep `.claude/memory/` readable; review it in code reviews if there is drift.

---

## Minimal usage example (steps)

1. `python3 .claude/bin/bootstrap_three_docs.py --refresh`
2. `claude --agent main-orchestrator`
3. `/bootstrap-three-doc-project`
4. `list phases`
5. `inspect task P03-S01-T001`
6. `claim task P03-S01-T001`
7. `run task P03-S01-T001`
8. Wait for `SubagentStop` hook to create handoff
9. `reviewer` and `tester` process the task
10. `git-manager` prepares commit and PR text
