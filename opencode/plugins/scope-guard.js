import fs from "node:fs/promises"
import path from "node:path"

const DANGEROUS = [
  /(^|\s)git\s+push(\s|$)/,
  /(^|\s)rm\s+-rf\s+\/(\s|$)/,
  /(^|\s)shutdown(\s|$)/,
  /(^|\s)reboot(\s|$)/,
  /(^|\s)mkfs(\s|$)/,
  /(^|\s)dd\s+if=/,
]

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

export const ScopeGuardPlugin = async ({ worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = input?.tool || ""
      const args = output?.args || input?.args || {}

      // Block dangerous bash commands
      if (tool === "bash") {
        const command = args.command || ""
        for (const pattern of DANGEROUS) {
          if (pattern.test(command)) {
            throw new Error(`Blocked dangerous command: ${command}`)
          }
        }
      }

      // Enforce file-write scope if active task defines allowed_paths
      if (["write", "edit", "patch", "multiedit"].includes(tool)) {
        const filePath = args.filePath || args.file_path || args.path
        if (!filePath) return
        const rel = normalizeRelative(worktree, filePath)
        if (rel.startsWith(".claude/")) return
        const active = await readJson(path.join(worktree, ".claude/memory/active-task.json"), {})
        const allowed = active?.allowed_paths || []
        if (allowed.length === 0) return
        if (!matchesAny(rel, allowed)) {
          throw new Error(`Write outside active task scope: ${rel}`)
        }
      }
    },
  }
}
