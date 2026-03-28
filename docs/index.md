# TriSystem Documentation

Welcome to the TriSystem docs. This is the full reference for the three-doc AI project template.

---

## Contents

### Getting started
- [Getting started](getting-started.md) — Install, configure, initialize your first project

### Core concepts
- [The three-doc system](three-doc-system.md) — What the three source-of-truth documents are and why they matter
- [Writing source documents](writing-source-docs.md) — How to write the three docs (slim starters + ChatGPT workflow)
- [Task lifecycle](task-lifecycle.md) — States, gates, evidence, handoffs — the full pipeline

### Components
- [Agents](agents.md) — All 17 agents: what they do, when they run, how they chain together
- [Skills](skills.md) — The 10 reusable skills: invocation, structure, how to create your own
- [Rules](rules.md) — The 5 always-loaded rules and how to add more
- [Commands](commands.md) — Global and project-level slash commands

### Runtime-specific
- [Plugins (OpenCode)](plugins.md) — scope-guard, ledger, writing your own JS plugins
- [Hooks (Claude Code)](hooks.md) — Lifecycle events, shell wrappers, Python hook scripts

### Reference
- [Init wizard](init-wizard.md) — What `scripts/init-project.sh` does and all its options

---

## Quick orientation

**If you just want to start a project:** read [Getting started](getting-started.md).

**If you want to understand the system:** read [The three-doc system](three-doc-system.md), then [Task lifecycle](task-lifecycle.md), then [Agents](agents.md).

**If you want to extend the template:** read [Skills](skills.md) for adding workflows, [Agents](agents.md) for adding roles, [Rules](rules.md) for adding guardrails, [Plugins](plugins.md) or [Hooks](hooks.md) for adding runtime automation.

**If you want to contribute:** see [CONTRIBUTING.md](../CONTRIBUTING.md) in the repo root.
