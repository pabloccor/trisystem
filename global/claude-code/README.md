# Global Claude Code Configuration

Claude Code reads global configuration from `~/.claude/` on startup.

## What goes here

This directory does **not** contain Claude Code global config files because Claude Code has
no equivalent of OpenCode's `~/.config/opencode/` global commands directory.

The closest equivalents in Claude Code are:

| OpenCode global file | Claude Code equivalent |
|---|---|
| `~/.config/opencode/AGENTS.md` | `~/.claude/CLAUDE.md` (global instructions) |
| `~/.config/opencode/opencode.jsonc` | `~/.claude/settings.json` (global settings) |
| `~/.config/opencode/commands/*.md` | No direct equivalent — commands are per-project |

## Global settings (`~/.claude/settings.json`)

Claude Code merges global `~/.claude/settings.json` with the project-level
`.claude/settings.json`. Project settings take precedence.

Minimal example:

```json
{
  "model": "claude-opus-4-5",
  "allowedTools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Task"],
  "env": {}
}
```

## Global instructions (`~/.claude/CLAUDE.md`)

Any markdown placed in `~/.claude/CLAUDE.md` is automatically included in every
Claude Code session, similar to OpenCode's global `AGENTS.md`.

You can use this for personal preferences, GPG signing rules, or session parking
conventions that should apply across all projects.

## No global commands

Claude Code does not support global slash commands. Custom commands defined in
`.claude/commands/*.md` are project-scoped only.

If you need the session parking workflow (`/park`, `/resume`, `/plans`) in Claude
Code, you must copy the relevant command files into each project's `.claude/commands/`.

## What to copy into a project

When setting up a new project with Claude Code, the `scripts/init-project.sh`
script copies from `claude-code/` in this template into the project's `.claude/`
directory. Nothing from this `global/claude-code/` directory needs to be copied —
it is documentation only.
