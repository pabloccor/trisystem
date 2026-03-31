import fs from "node:fs/promises"
import path from "node:path"

// ── Dangerous-command lists per permission mode ────────────────────────────────
//
// autonomous  — nothing is hard-blocked; the agent is trusted fully
// supervised  — git push/commit are intercepted; truly destructive cmds blocked
// guarded     — all bash commands are blocked except safe reads
// locked      — all bash commands are blocked (belt-and-suspenders; OpenCode
//               permissions should already deny bash in this mode)

const BLOCKED = {
  autonomous: [],

  supervised: [
    /(^|\s)rm\s+-rf\s+\/(\s|$)/,
    /(^|\s)shutdown(\s|$)/,
    /(^|\s)reboot(\s|$)/,
    /(^|\s)mkfs(\s|$)/,
    /(^|\s)dd\s+if=/,
  ],

  guarded: [
    // Block everything that writes or runs; allow read-style commands
    // (cat, ls, find, grep, git status/diff/log are safe reads)
    /(^|\s)rm(\s|$)/,
    /(^|\s)rm\s+-/,
    /(^|\s)git\s+push(\s|$)/,
    /(^|\s)git\s+commit(\s|$)/,
    /(^|\s)git\s+merge(\s|$)/,
    /(^|\s)git\s+rebase(\s|$)/,
    /(^|\s)git\s+reset(\s|$)/,
    /(^|\s)git\s+clean(\s|$)/,
    /(^|\s)npm\s+(install|ci|publish|run)(\s|$)/,
    /(^|\s)pip\s+install(\s|$)/,
    /(^|\s)brew\s+install(\s|$)/,
    /(^|\s)shutdown(\s|$)/,
    /(^|\s)reboot(\s|$)/,
    /(^|\s)mkfs(\s|$)/,
    /(^|\s)dd\s+if=/,
    /(^|\s)curl\s+.*\|\s*(bash|sh)(\s|$)/,
    /(^|\s)wget\s+.*\|\s*(bash|sh)(\s|$)/,
  ],

  locked: [
    // Block everything — any bash command is disallowed
    /.*/,
  ],
}

// ── Default when opencode.json cannot be read ─────────────────────────────────
const DEFAULT_MODE = "supervised"

function wildcardToRegex(pattern) {
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&")
  return new RegExp("^" + escaped.replace(/\*/g, ".*").replace(/\?/g, ".") + "$")
}

async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf8")
    return JSON.parse(raw)
  } catch {
    return fallback
  }
}

function normalizeRelative(worktree, candidate) {
  const abs = path.isAbsolute(candidate) ? candidate : path.join(worktree, candidate)
  return path.relative(worktree, abs).replace(/\\/g, "/")
}

function matchesAny(rel, patterns) {
  return patterns.some((p) => wildcardToRegex(p.replace(/^\.\//, "")).test(rel))
}

async function resolveMode(worktree) {
  // 1. Check project-local opencode.json for trisystem_permission_mode
  const projectConfig = await readJson(path.join(worktree, "opencode.json"), {})
  if (projectConfig.trisystem_permission_mode) {
    return projectConfig.trisystem_permission_mode
  }

  // 2. Fall back to the template default
  return DEFAULT_MODE
}

export const ScopeGuardPlugin = async ({ worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = input?.tool || ""
      const args = output?.args || input?.args || {}

      // ── Bash command filtering ────────────────────────────────────────────────
      if (tool === "bash") {
        const command = args.command || ""
        const mode = await resolveMode(worktree)
        const blocked = BLOCKED[mode] ?? BLOCKED[DEFAULT_MODE]

        for (const pattern of blocked) {
          if (pattern.test(command)) {
            if (mode === "locked") {
              throw new Error(
                `[scope-guard] Bash is disabled in locked mode. Command blocked: ${command}`
              )
            }
            throw new Error(
              `[scope-guard] Blocked dangerous command (mode: ${mode}): ${command}`
            )
          }
        }
      }

      // ── File-write scope enforcement ──────────────────────────────────────────
      // In locked mode, also block file writes as a belt-and-suspenders check
      // (OpenCode permissions should have already denied them).
      if (["write", "edit", "patch", "multiedit"].includes(tool)) {
        const filePath = args.filePath || args.file_path || args.path
        if (!filePath) return

        const mode = await resolveMode(worktree)
        if (mode === "locked") {
          throw new Error(
            `[scope-guard] File writes are disabled in locked mode: ${filePath}`
          )
        }

        const rel = normalizeRelative(worktree, filePath)
        if (rel.startsWith(".claude/")) return

        const active = await readJson(path.join(worktree, ".claude/memory/active-task.json"), {})
        const allowed = active?.allowed_paths || []
        if (allowed.length === 0) return
        if (!matchesAny(rel, allowed)) {
          throw new Error(`[scope-guard] Write outside active task scope: ${rel}`)
        }
      }
    },
  }
}
