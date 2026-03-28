import fs from "node:fs/promises"
import path from "node:path"

async function ensureDir(filePath) {
  await fs.mkdir(path.dirname(filePath), { recursive: true })
}

async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf8")
    return JSON.parse(raw)
  } catch {
    return fallback
  }
}

export const LedgerPlugin = async ({ worktree }) => {
  return {
    "tool.execute.after": async (input, output) => {
      const ledgerPath = path.join(worktree, ".claude/tasks/ledger.jsonl")
      await ensureDir(ledgerPath)
      const runtime = await readJson(path.join(worktree, ".claude/tasks/runtime-state.json"), {})
      const activeTask = await readJson(path.join(worktree, ".claude/memory/active-task.json"), {})
      const args = output?.args || input?.args || {}
      const record = {
        ts: new Date().toISOString(),
        event: "post_tool_use",
        tool_name: input?.tool || null,
        active_phase_id: runtime?.active_phase_id || null,
        active_task_id: activeTask?.id || null,
        command: args.command || null,
        file_path: args.filePath || args.file_path || args.path || null,
      }
      await fs.appendFile(ledgerPath, JSON.stringify(record) + "\n", "utf8")
    },
  }
}
