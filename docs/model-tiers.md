# Model tiers

The init wizard lets you choose a **cost tier** that controls which Claude model each of the 17 agents uses. The tier is stamped into agent files at init time, not at runtime, so there is no per-session overhead.

## Overview

| Tier | Best for | Cost |
|---|---|---|
| `premium` | Final reviews, high-stakes work, critical path | Highest |
| `standard` | Normal day-to-day development *(recommended)* | Moderate |
| `economy` | Bulk processing, non-critical tasks, cost-sensitive | Low |
| `minimal` | Prototyping, exploration, budget-constrained | Lowest |

The **orchestrator is always opus** across all tiers. It coordinates the pipeline and must reason reliably regardless of cost.

---

## Per-agent model matrix

| Agent | premium | standard | economy | minimal |
|---|---|---|---|---|
| `main-orchestrator` | opus | opus | opus | opus |
| `project-architect` | opus | opus | haiku | haiku |
| `developer` | opus | sonnet | sonnet | sonnet |
| `debugger` | opus | sonnet | sonnet | haiku |
| `reviewer` | sonnet | sonnet | sonnet | haiku |
| `task-planner` | sonnet | sonnet | haiku | haiku |
| `technical-analyst` | sonnet | sonnet | haiku | haiku |
| `security-auditor` | sonnet | sonnet | haiku | haiku |
| `qa-validator` | sonnet | sonnet | haiku | haiku |
| `deployer` | sonnet | sonnet | sonnet | sonnet |
| `tester` | sonnet | haiku | haiku | haiku |
| `document-analyzer` | haiku | haiku | haiku | haiku |
| `official-docs-researcher` | haiku | haiku | haiku | haiku |
| `context-curator` | haiku | haiku | haiku | haiku |
| `phase-controller` | haiku | haiku | haiku | haiku |
| `evidence-reporter` | haiku | haiku | haiku | haiku |
| `git-manager` | haiku | haiku | haiku | haiku |

### Design rationale

- **Low-demand agents** (document-analyzer, official-docs-researcher, context-curator, phase-controller, evidence-reporter, git-manager) use haiku in every tier. These agents follow structured templates and do not require deep reasoning.
- **`deployer`** keeps sonnet down to `minimal` because deployment commands have irreversible consequences — the extra reasoning is worth the cost.
- **`developer`** keeps sonnet even in `standard`/`economy`/`minimal` for the same reason: code correctness matters.
- **`project-architect`** drops to haiku in `economy`/`minimal` because architectural decisions are made once at the start of a project; subsequent runs only read the existing architecture.

---

## How it works

### At init time

`scripts/init-project.sh` prompts for a tier during **Step 6** of the wizard. After copying agents to `.claude/agents/` and/or `.opencode/agents/`, it calls `stamp_agent_models()`, which:

1. Reads `shared/models/tiers.json` to resolve each agent's model class (`opus`, `sonnet`, or `haiku`).
2. Looks up the full model ID for the target runtime.
3. Injects a `model:` line into the YAML frontmatter of each agent `.md` file.

This means the model is baked directly into the agent file — the runtime reads it natively without any additional configuration.

### Source of truth

`shared/models/tiers.json` is the single source of truth for all tier definitions. It contains:

- Model IDs per runtime (OpenCode uses `github-copilot/claude-*` format; Claude Code uses `claude-*` format).
- Per-tier defaults and per-agent overrides (compact representation).
- The canonical list of all 17 agent names.

### Runtime formats

| Runtime | Opus | Sonnet | Haiku |
|---|---|---|---|
| OpenCode (GitHub Copilot) | `github-copilot/claude-opus-4.5` | `github-copilot/claude-sonnet-4.6` | `github-copilot/claude-haiku-4.5` |
| Claude Code (Anthropic) | `claude-opus-4-5` | `claude-sonnet-4-5` | `claude-haiku-4-5` |

---

## Changing the tier after init

The init wizard stamps models once. To change the tier:

**Option 1 — Re-run the wizard** (cleanest):
```bash
./scripts/init-project.sh /path/to/your/project
```
The wizard will detect existing files and let you overwrite.

**Option 2 — Manual update**:
Edit the `model:` field in each agent file under `.opencode/agents/` or `.claude/agents/`. Refer to the matrix above and the model IDs in `shared/models/tiers.json`.

**Option 3 — Script it**:
```bash
# Example: re-stamp a single runtime's agents to the economy tier
# (run from the template root)
source scripts/init-project.sh  # not recommended for re-stamping; use Option 1
```

---

## Relationship to the permission mode

Model tier and permission mode are independent settings. You can combine any tier with any permission mode:

| | `autonomous` | `supervised` | `guarded` | `locked` |
|---|---|---|---|---|
| `premium` | ✓ | ✓ | ✓ | ✓ |
| `standard` | ✓ | ✓ | ✓ | ✓ |
| `economy` | ✓ | ✓ | ✓ | ✓ |
| `minimal` | ✓ | ✓ | ✓ | ✓ |

Both are recorded in `.opencode/trisystem.json` under `permission_mode` and `model_tier`. These fields are informational — the actual behavior comes from the `permission` block in `opencode.json` (for modes) and the agent frontmatter `model:` lines (for tiers).

See [Permissions](permissions.md) for the full permission mode reference.
