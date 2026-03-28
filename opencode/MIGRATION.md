# Migrating from Claude Code to OpenCode

This document maps Claude Code concepts to their OpenCode equivalents.

## Entry points

| Claude Code | OpenCode |
|---|---|
| `.claude/CLAUDE.md` | `AGENTS.md` (project root) |
| `.claude/settings.json` | `opencode.json` (project root) |
| `.claude/settings.local.json` | `opencode.json` permission field |

## Agents

| Claude Code | OpenCode |
|---|---|
| `.claude/agents/*.md` | `.opencode/agents/*.md` (adds YAML frontmatter) |
| `claude --agent <name>` | `@<name>` in chat |

## Skills

Identical format in both runtimes:
- Claude Code: `.claude/skills/<name>/SKILL.md`
- OpenCode: `.opencode/skills/<name>/SKILL.md`

## Rules (always-loaded instructions)

| Claude Code | OpenCode |
|---|---|
| Inline in `CLAUDE.md` | `.opencode/rules/*.md` (loaded via opencode.json `instructions` glob) |

## Hooks → Plugins

Claude Code uses shell hooks (`.claude/hooks/`) that invoke Python scripts (`.claude/bin/`).
OpenCode uses JS plugins (`.opencode/plugins/`) with the `@opencode-ai/plugin` API.

See `plugins/README.md` for the detailed migration parity table.

## Permissions

| Claude Code | OpenCode |
|---|---|
| `.claude/settings.local.json` permissions array | `opencode.json` → `"permission": "allow"` (global) |
| Per-tool allow/deny | Agent-level YAML frontmatter `permission:` block |

## Memory and tasks

Both runtimes use the same `.claude/memory/` and `.claude/tasks/` directories.
These paths are hardcoded in agents and plugins — they work identically in both runtimes.
