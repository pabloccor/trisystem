# Init Wizard

The `scripts/init-project.sh` script is an interactive wizard that initializes a new project
from the TriSystem template. It copies the right files, renames templates, and sets up the
directory structure for your chosen runtime.

---

## Usage

```bash
# Interactive — prompts for everything
./scripts/init-project.sh

# With target directory
./scripts/init-project.sh /path/to/your-project

# The target directory will be created if it doesn't exist
```

---

## What the wizard asks

### 1. Target directory

Where to create the project. Defaults to the current directory.

If the directory doesn't exist, the wizard asks to create it.

### 2. Project name

Used as the uppercase prefix for the checklist and guide files. For example:

| Input | Prefix | Checklist filename |
|---|---|---|
| `my app` | `MY_APP` | `MY_APP_IMPLEMENTATION_CHECKLIST.md` |
| `Sports Metrics` | `SPORTS_METRICS` | `SPORTS_METRICS_IMPLEMENTATION_CHECKLIST.md` |
| `todo` | `TODO` | `TODO_IMPLEMENTATION_CHECKLIST.md` |

Special characters are stripped. Spaces become underscores. Everything is uppercased.

### 3. Runtime

Which AI coding runtime you'll use:

| Choice | What gets copied |
|---|---|
| `opencode` | `.opencode/` (agents, skills, rules, plugins) + `AGENTS.md` + `opencode.json` + `.claude/` (bin, memory, tasks — compatibility layer) |
| `claude-code` | `.claude/` (agents, skills, rules, bin, hooks, scripts, memory, tasks) + `CLAUDE.md` |
| `both` | Everything from both runtimes |

### 4. Template size

| Choice | What you get |
|---|---|
| `slim` | Starter templates (~200 lines each) with section headers and placeholder content |
| `empty` | Stub files (empty) — you'll generate the content yourself (e.g., with ChatGPT) |

### 5. Cheat sheet

Whether to copy the quick-reference cheat sheet into the project root.

If you chose `opencode`, you get the OpenCode cheat sheet.
If you chose `claude-code`, you get the Claude Code cheat sheet.
If you chose `both`, you get both.

---

## What the wizard creates

For a project named "My App" with `opencode` runtime and `slim` templates:

```
my-app/
├── AGENTS.md                                    ← from opencode/AGENTS.md.template (PROJECT_NAME substituted)
├── opencode.json                                ← from opencode/opencode.json
├── CHEAT_SHEET.md                               ← from cheatsheets/CHEAT_SHEET_OPENCODE.md
├── .gitignore                                   ← generated stub
├── docs/
│   └── source-of-truth/
│       ├── instrucciones.md                     ← from templates/slim/
│       ├── MY_APP_IMPLEMENTATION_CHECKLIST.md   ← from templates/slim/ (renamed)
│       └── MY_APP_TECHNICAL_GUIDE.md            ← from templates/slim/ (renamed)
├── .opencode/
│   ├── agents/                                  ← from shared/agents/ (17 files)
│   ├── skills/                                  ← from shared/skills/ (10 dirs)
│   ├── rules/                                   ← from shared/rules/ (5 files)
│   ├── plugins/                                 ← from opencode/plugins/ (3 files)
│   └── package.json                             ← from opencode/package.json
└── .claude/
    ├── bin/                                     ← from claude-code/bin/ (9 files)
    ├── memory/                                  ← from claude-code/memory/ (READMEs)
    └── tasks/                                   ← from claude-code/tasks/ (READMEs)
```

---

## What the wizard does NOT do

- Does not run `git init` — you do that yourself
- Does not install dependencies — run `pip install` / `npm install` yourself if needed
- Does not run the bootstrap — run `python3 .claude/bin/bootstrap_three_docs.py --refresh`
- Does not configure API keys — edit `opencode.json` or `.claude/settings.json` yourself
- Does not overwrite existing files — if `opencode.json` or `.claude/settings.json` already
  exists, the wizard skips it

---

## After the wizard

The wizard prints next steps:

```
Done! Project initialized at: /path/to/my-app

Next steps:
  1. Edit your source docs in docs/source-of-truth/
  2. Run the bootstrap script:
       python3 .claude/bin/bootstrap_three_docs.py --refresh
  3. Launch your AI runtime:
       opencode
```

---

## Modifying the wizard

The wizard is a plain bash script at `scripts/init-project.sh`. To customize it:

- Add new prompts with the `ask()` or `ask_choice()` helper functions
- Add new file copies with `copy_file()` or `copy_dir()`
- The script uses no external dependencies — just bash, cp, mkdir, sed, chmod

---

## Next steps

- [Getting started](getting-started.md) — the full setup flow including the wizard
- [Writing source documents](writing-source-docs.md) — what to put in the three docs
