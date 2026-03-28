# Getting Started

This guide walks you through setting up TriSystem for your first project.

---

## Prerequisites

- **Git** — any recent version
- **Python 3.9+** — for the bootstrap script
- **One of:**
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic's CLI coding agent
  - [OpenCode](https://opencode.ai) — open-source AI coding TUI

You don't need both runtimes. Pick whichever you prefer — the template supports both.

---

## Step 1: Clone the template

```bash
git clone https://github.com/pabloccor/trisystem.git
cd trisystem
```

---

## Step 2: Run the init wizard

```bash
./scripts/init-project.sh /path/to/your-new-project
```

The wizard will ask you:

| Prompt | What it means |
|---|---|
| **Target directory** | Where to create the project. It will be created if it doesn't exist. |
| **Project name** | Used as the uppercase prefix for your checklist and guide files (e.g., `MY_APP`). |
| **Runtime** | `opencode`, `claude-code`, or `both`. Determines which config files get copied. |
| **Template size** | `slim` gives you starter templates (~200 lines each). `empty` creates stub files for you to fill in. |
| **Cheat sheet** | Whether to copy the quick-reference cheat sheet into your project root. |

After the wizard finishes you'll have a fully structured project directory:

```
your-project/
├── docs/source-of-truth/
│   ├── instrucciones.md
│   ├── MY_APP_IMPLEMENTATION_CHECKLIST.md
│   └── MY_APP_TECHNICAL_GUIDE.md
├── .opencode/ or .claude/     (depending on your runtime choice)
│   ├── agents/
│   ├── skills/
│   ├── rules/
│   └── ...
├── AGENTS.md or CLAUDE.md
└── opencode.json or .claude/settings.json
```

---

## Step 3: Write your source documents

The three files in `docs/source-of-truth/` are the entire brain of the system. Everything else
is derived from them.

If you chose **slim templates**, they have a working structure with placeholder content — edit
them with your actual project details.

If you want comprehensive 3,000+ line documents, use the **ChatGPT two-phase workflow**
described in [Writing source documents](writing-source-docs.md).

---

## Step 4: Run the bootstrap

The bootstrap script reads the three source docs and generates all runtime artifacts
(task registry, phase structure, memory files):

```bash
cd /path/to/your-project
python3 .claude/bin/bootstrap_three_docs.py --refresh
```

Common options:
- `--refresh` — overwrite existing artifacts
- `--dry-run` — validate and show what would be done without writing anything
- `--verbose` — extended logging

---

## Step 5: Launch your runtime

### OpenCode

```bash
cd /path/to/your-project
opencode
```

OpenCode reads `AGENTS.md` on startup. To start the orchestrator:

```
@main-orchestrator bootstrap the project
```

Or use the command:

```
/bootstrap-three-doc-project
```

### Claude Code

```bash
cd /path/to/your-project
claude --agent main-orchestrator
```

Then run:

```
/bootstrap-three-doc-project
```

---

## Step 6: Work through your first phase

Once bootstrapped, the system has a task registry with phases, steps, and tasks.

```
@main-orchestrator list phases
@main-orchestrator inspect task P01-S01-T001
@main-orchestrator claim task P01-S01-T001
@main-orchestrator run task P01-S01-T001
```

Read [Task lifecycle](task-lifecycle.md) to understand the full execution flow.

---

## Installing global commands (OpenCode only)

If you want the session parking commands (`/park`, `/resume`, `/plans`) and other utilities
available across all your projects:

```bash
# Slash commands
mkdir -p ~/.config/opencode/commands
cp trisystem/global/opencode/commands/*.md ~/.config/opencode/commands/

# Global instructions (session parking rules)
cp trisystem/global/opencode/AGENTS.md ~/.config/opencode/AGENTS.md

# Plans tool
mkdir -p ~/.config/opencode/tools
cp trisystem/global/opencode/tools/plans.ts ~/.config/opencode/tools/plans.ts

# Global config (edit to add your API keys)
cp trisystem/global/opencode/opencode.jsonc.example ~/.config/opencode/opencode.jsonc
```

---

## What's next?

- Read [The three-doc system](three-doc-system.md) to understand the core model
- Read [Agents](agents.md) to see all 17 agents and how they collaborate
- Check the [cheat sheet](../cheatsheets/) for a quick reference card
