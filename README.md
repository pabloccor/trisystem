# TriSystem — Three-Doc AI Project Template

A project template for AI-assisted software development using the **three-doc system**.
Works with both **Claude Code** and **OpenCode**.

---

## What is the three-doc system?

Every project is governed by exactly three source-of-truth markdown files:

| File | Purpose |
|---|---|
| `instrucciones.md` | Goals, scope, workflow rules, execution protocol |
| `PREFIX_IMPLEMENTATION_CHECKLIST.md` | Phases, steps, tasks, deliverables |
| `PREFIX_TECHNICAL_GUIDE.md` | Architecture, stack, APIs, data model, deployment |

An AI runtime reads these three files, generates a task registry, and executes work in
controlled vertical slices with mandatory review, test, and QA gates at every step.

---

## Quick start

```bash
# Clone this template
git clone https://github.com/pabloccor/trisystem.git
cd trisystem

# Run the interactive wizard
./scripts/init-project.sh /path/to/your-new-project
```

> **📖 Full documentation** — see [`docs/index.md`](docs/index.md) for the complete guide
> covering agents, skills, rules, plugins, hooks, commands, the task lifecycle, and more.

The wizard will ask:
1. **Target directory** — where to initialize the project
2. **Project name** — used as the prefix for your checklist and guide files
3. **Runtime** — `opencode`, `claude-code`, or `both`
4. **Template size** — `slim` (starter docs) or `empty` (you'll generate with ChatGPT)
5. **Permission mode** — `autonomous`, `supervised` (default), `guarded`, or `locked`
6. **Cheat sheet** — whether to copy the reference cheat sheet

---

## Repository layout

```
trisystem/
├── scripts/
│   └── init-project.sh          # Interactive wizard — run this to start
│
├── shared/                      # Single canonical source (DRY)
│   ├── agents/                  # 17 specialized agents (runtime-agnostic)
│   ├── skills/                  # 10 reusable workflow skills
│   ├── rules/                   # 5 always-loaded instruction rules
│   └── permissions/             # Canonical permission mode presets (modes.json)
│
├── opencode/                    # OpenCode-specific runtime files
│   ├── AGENTS.md.template       # Project operating rules template
│   ├── opencode.json            # Permissions, instructions, tool config
│   ├── package.json             # Plugin dependencies
│   ├── MIGRATION.md             # Claude Code → OpenCode migration notes
│   └── plugins/
│       ├── scope-guard.js       # Blocks dangerous commands, enforces task scope
│       ├── ledger.js            # JSONL audit trail after every tool use
│       └── README.md
│
├── claude-code/                 # Claude Code-specific runtime files
│   ├── CLAUDE.md                # Project operating rules
│   ├── settings.json.example    # Claude Code settings template
│   ├── bin/                     # Python bootstrap + hook scripts
│   ├── hooks/                   # Shell hook wrappers
│   ├── scripts/                 # install.sh / uninstall.sh
│   ├── memory/                  # Runtime memory directory (with README)
│   └── tasks/                   # Runtime task state directory (with README)
│
├── global/
│   ├── opencode/
│   │   ├── AGENTS.md            # Global OpenCode instructions (session parking)
│   │   ├── opencode.jsonc.example # Global config with provider options
│   │   ├── tools/plans.ts       # Plans parking tool
│   │   └── commands/            # 8 global slash commands
│   │       ├── commit.md        # GPG-signed conventional commits
│   │       ├── explain.md       # Project structure explanation
│   │       ├── park.md          # Park session with handoff note
│   │       ├── plans.md         # List parked plans
│   │       ├── pr.md            # Create pull request
│   │       ├── push.md          # Push current branch
│   │       ├── resume.md        # Resume a parked session
│   │       └── title.md         # Generate conversation title
│   └── claude-code/
│       └── README.md            # Notes on Claude Code global config
│
├── templates/
│   ├── README.md                # ChatGPT two-phase doc generation workflow
│   ├── slim/                    # Starter templates (~200 lines each)
│   │   ├── instrucciones.md
│   │   ├── PREFIX_IMPLEMENTATION_CHECKLIST.md
│   │   └── PREFIX_TECHNICAL_GUIDE.md
│   └── full/
│       └── README.md            # Why full templates are project-specific
│
└── cheatsheets/
    ├── CHEAT_SHEET_CLAUDE.md    # Quick reference for Claude Code
    └── CHEAT_SHEET_OPENCODE.md  # Quick reference for OpenCode
```

---

## How to generate full source documents

The slim templates are useful starters, but the real power comes from generating
3,000+ line documents using the **ChatGPT two-phase workflow** documented in
[`templates/README.md`](templates/README.md):

1. **Phase 1** — Use ChatGPT thinking mode to do deep research on your problem domain
2. **Phase 2** — Use ChatGPT Pro with extended thinking, attach the blueprint zip + research
   report, and generate all 3 documents in one pass

---

## Installing global commands (OpenCode)

The `global/opencode/commands/` directory contains slash commands that work across all
projects. Copy them to your global OpenCode config:

```bash
mkdir -p ~/.config/opencode/commands
cp global/opencode/commands/*.md ~/.config/opencode/commands/

# Also copy the global AGENTS.md (session parking rules)
cp global/opencode/AGENTS.md ~/.config/opencode/AGENTS.md

# Copy the plans tool
mkdir -p ~/.config/opencode/tools
cp global/opencode/tools/plans.ts ~/.config/opencode/tools/plans.ts

# Use the example config as a starting point
cp global/opencode/opencode.jsonc.example ~/.config/opencode/opencode.jsonc
# Then edit it to fill in your API keys
```

---

## Agents

The template ships 17 specialized agents:

| Agent | Role |
|---|---|
| `main-orchestrator` | Top-level coordinator |
| `developer` | Implements one approved task at a time |
| `reviewer` | Code review for correctness, style, coverage |
| `tester` | Runs verification commands |
| `debugger` | Diagnoses failures and produces minimal fixes |
| `qa-validator` | Final quality gate before git operations |
| `git-manager` | Prepares commits, PR text, release notes |
| `phase-controller` | Manages phase transitions and task selection |
| `task-planner` | Decomposes phases into atomic tasks |
| `context-curator` | Prepares minimal context packs for workers |
| `project-architect` | Compiles the executable architecture contract |
| `document-analyzer` | Validates the three-doc contract |
| `official-docs-researcher` | Verifies claims against official documentation |
| `security-auditor` | Security review of changes |
| `evidence-reporter` | Compiles evidence for task completion |
| `deployer` | Handles K8s/infrastructure deployment |
| `technical-analyst` | Analyzes technical feasibility and risks |

---

## Rules

Five rules are always loaded and govern every session:

| Rule | Purpose |
|---|---|
| `00-three-doc-contract` | The three source docs are the only project truth |
| `01-official-docs-first` | Consult official docs before changing stack or APIs |
| `02-phase-execution` | Work in phases; don't skip mandatory gates |
| `03-traceability` | Every change must be traceable to a task ID |
| `04-dev-loop-verify` | Dev servers must run; every slice needs browser verification |

---

## Design principles

- **KISS and DRY** — shared content lives once in `shared/`; the init script copies it
- **Permission modes** — four presets (`autonomous`, `supervised`, `guarded`, `locked`) control agent autonomy; see [`docs/permissions.md`](docs/permissions.md)
- **No hardcoded secrets** — all tokens use `$ENV_VAR` placeholders with `.example` files
- **No org-specific references** — fully generic, works for any project
- **Motivation-aware** — task design supports competence-building and autonomy
- **Strava-first optional** — the template is provider-agnostic; add integrations as needed

---

## License

MIT
