# Contributing to TriSystem

Thanks for wanting to contribute. This is a small project built for friends and collaborators,
and we want to keep it welcoming and easy to work with.

---

## Table of contents

- [What kind of contributions are welcome](#what-kind-of-contributions-are-welcome)
- [Repository layout — where things live](#repository-layout--where-things-live)
- [How to contribute](#how-to-contribute)
- [Branch and PR conventions](#branch-and-pr-conventions)
- [Commit message format](#commit-message-format)
- [Testing your changes](#testing-your-changes)
- [Opening issues](#opening-issues)

---

## What kind of contributions are welcome

- **Bug fixes** — something in a script, agent, skill, or template is wrong or broken
- **New agents** — a role that doesn't exist yet and would be genuinely useful
- **New skills** — a reusable workflow that belongs in the shared library
- **Improved rules** — clarifications, corrections, or new guardrails
- **Template improvements** — better slim templates, clearer instructions
- **New global commands** — useful slash commands for OpenCode or Claude Code
- **Documentation** — clearer explanations, better examples, fixed typos
- **Init script improvements** — edge cases, new options, better UX
- **Ideas** — open an issue to discuss before building something big

If you're unsure whether something belongs, open an issue first and ask.

---

## Repository layout — where things live

Before contributing, understand the structure so you put things in the right place.

```
shared/agents/      ← Agent prompt files — runtime-agnostic, used by both Claude Code and OpenCode
shared/skills/      ← SKILL.md files — reusable workflow instructions
shared/rules/       ← Always-loaded rules (numbered 00–99 for load order)

opencode/           ← OpenCode-specific files: plugins, config, AGENTS.md template
claude-code/        ← Claude Code-specific files: hooks, bin scripts, settings

global/opencode/commands/   ← Global slash commands for OpenCode (~/.config/opencode/commands/)
global/claude-code/         ← Notes on Claude Code global config (no files to copy)

templates/slim/     ← Starter source-of-truth document templates (~200 lines)
templates/full/     ← Points to the ChatGPT generation workflow (no pre-built templates)
cheatsheets/        ← Quick reference for each runtime
scripts/            ← init-project.sh wizard
```

**The golden rule:** shared content goes in `shared/`. Never duplicate an agent, skill, or rule
into both `opencode/` and `claude-code/` — the init script copies from `shared/` into both.

---

## How to contribute

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/trisystem.git
   cd trisystem
   ```
3. **Create a branch** from `main`:
   ```bash
   git checkout -b bugfix/scope-guard-edge-case
   # or
   git checkout -b feature/new-agent-security-auditor
   ```
4. **Make your changes.** See the sections below for conventions.
5. **Test your changes** (see [Testing your changes](#testing-your-changes)).
6. **Commit** using conventional commits (see below).
7. **Push** and open a PR against `main` on the upstream repo.

---

## Branch and PR conventions

Branch naming:

| Prefix | Use for |
|---|---|
| `feature/` | New agents, skills, commands, features |
| `bugfix/` | Bug fixes in non-critical code |
| `hotfix/` | Urgent fixes to a production issue |
| `docs/` | Documentation only |
| `refactor/` | Restructuring without functional change |
| `chore/` | Maintenance, dependency updates, CI |
| `test/` | Adding or fixing tests |

Keep PRs focused. One logical change per PR. If you have two unrelated fixes, open two PRs.

---

## Commit message format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional body explaining why, not what.
```

- **type**: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`
- **scope**: optional — use the directory or component (e.g., `agents`, `init`, `scope-guard`)
- **title**: imperative mood, max 50 chars, no period

The commit `type` maps to branch prefixes as follows:

| Branch prefix | Commit type |
|---|---|
| `feature/` | `feat` |
| `bugfix/` | `fix` |
| `hotfix/` | `fix` |
| `docs/` | `docs` |
| `refactor/` | `refactor` |
| `chore/` | `chore` |
| `test/` | `test` |

Examples:
```
feat(agents): add security-auditor agent
fix(init): handle spaces in target directory path
docs(cheatsheets): clarify plugin event mapping table
chore: update slim template placeholders
```

---

## Testing your changes

There are no automated tests yet. Manual verification is enough for now.

**For `init-project.sh` changes:**
```bash
# Run the wizard against a temp directory
mkdir /tmp/test-trisystem
./scripts/init-project.sh /tmp/test-trisystem
# Walk through the prompts and check the output looks right
ls -la /tmp/test-trisystem
```

**For agent/skill changes:**
- Read the file and make sure the instructions are clear, unambiguous, and free of
  project-specific references (no org names, no hardcoded URLs, no specific tech stacks).
- Check that agent files have valid YAML frontmatter with at least `description` and `tools`.
- Check that skill files are named `SKILL.md` and live in a subdirectory under `shared/skills/`.

**For rule changes:**
- Rules are numbered (`00-`, `01-`, ...) to control load order. Lower numbers load first.
- Keep rules short and actionable — they are loaded into every session.

**For plugin changes (OpenCode):**
- Plugins must export a named function.
- Test locally by copying the plugin to a project's `.opencode/plugins/` and running OpenCode.

---

## Opening issues

Use the issue templates — they help provide the right context up front:

- **Bug report** — something is broken or behaves unexpectedly
- **Feature request** — a new agent, skill, command, or improvement
- **New agent or skill** — a focused template for proposing additions to `shared/`

For general questions or ideas that don't fit a template, open a blank issue.

---

## A note on tone

This project started as a personal tool shared between friends. Contributions and discussions
should be direct, constructive, and respectful. We don't need a long code of conduct for that —
just treat people the way you'd want to be treated.

If something feels off, reach out directly before escalating.
