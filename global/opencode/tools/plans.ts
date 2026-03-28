import { tool } from "@opencode-ai/plugin"
import { readFile, writeFile, unlink, readdir, mkdir } from "fs/promises"
import { existsSync } from "fs"
import { join } from "path"
import { homedir } from "os"

const GLOBAL_PLANS_DIR = join(homedir(), ".config", "opencode", "plans")

const PROJECT_MARKERS = [
  ".git",
  "package.json",
  "go.mod",
  "Cargo.toml",
  "pyproject.toml",
  "pom.xml",
  "build.gradle",
  "Makefile",
]

async function resolvePlansDir(context: { worktree: string; directory: string }): Promise<string> {
  const root = context.worktree || context.directory
  if (root) {
    const hasMarker = PROJECT_MARKERS.some(m => existsSync(join(root, m)))
    if (hasMarker) {
      const localDir = join(root, "plans")
      await mkdir(localDir, { recursive: true })
      return localDir
    }
  }
  await mkdir(GLOBAL_PLANS_DIR, { recursive: true })
  return GLOBAL_PLANS_DIR
}

function timestamp(): string {
  return new Date().toISOString()
}

function buildFrontmatter(fields: Record<string, string>): string {
  const lines = ["---"]
  for (const [k, v] of Object.entries(fields)) {
    lines.push(`${k}: ${v}`)
  }
  lines.push("---")
  return lines.join("\n")
}

function parseFrontmatter(content: string): { meta: Record<string, string>; body: string } {
  const match = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/)
  if (!match) return { meta: {}, body: content }
  const meta: Record<string, string> = {}
  for (const line of match[1].split("\n")) {
    const colon = line.indexOf(":")
    if (colon === -1) continue
    const key = line.slice(0, colon).trim()
    const val = line.slice(colon + 1).trim()
    meta[key] = val
  }
  return { meta, body: match[2] }
}

function planPath(plansDir: string, name: string): string {
  return join(plansDir, `${name}.md`)
}

export const save = tool({
  description: "Save a new parked plan handoff note. Fails if a plan with this name already exists — use plans_update instead.",
  args: {
    name: tool.schema.string().describe("Short kebab-case plan identifier, e.g. browser-agent-phase2"),
    content: tool.schema.string().describe("Full markdown body of the plan handoff note"),
  },
  async execute(args, context) {
    const plansDir = await resolvePlansDir(context)
    const filePath = planPath(plansDir, args.name)
    if (existsSync(filePath)) {
      return `Error: a plan named "${args.name}" already exists at ${filePath}. Use plans_update to overwrite it.`
    }
    const now = timestamp()
    const fm = buildFrontmatter({
      created: now,
      updated: now,
      status: "parked",
      session_id: context.sessionID,
    })
    await writeFile(filePath, `${fm}\n\n${args.content}`, "utf-8")
    return `Plan "${args.name}" saved to ${filePath}`
  },
})

export const load = tool({
  description: "Load a parked plan by name and return its full content.",
  args: {
    name: tool.schema.string().describe("Plan name without .md extension"),
  },
  async execute(args, context) {
    const plansDir = await resolvePlansDir(context)
    const filePath = planPath(plansDir, args.name)
    if (!existsSync(filePath)) {
      return `Error: no plan named "${args.name}" found at ${filePath}`
    }
    return await readFile(filePath, "utf-8")
  },
})

export const list = tool({
  description: "List all parked plans with name, status, date, and a one-line excerpt.",
  args: {},
  async execute(_args, context) {
    const plansDir = await resolvePlansDir(context)
    let files: string[]
    try {
      files = (await readdir(plansDir)).filter(f => f.endsWith(".md"))
    } catch {
      return "No parked plans found."
    }
    if (files.length === 0) return "No parked plans found."

    const entries: string[] = []
    const warnings: string[] = []

    for (const file of files.sort()) {
      const name = file.replace(/\.md$/, "")
      const filePath = join(plansDir, file)
      let raw: string
      try {
        raw = await readFile(filePath, "utf-8")
      } catch {
        warnings.push(`  (could not read ${file})`)
        continue
      }
      let status = "unknown"
      let created = "unknown"
      let excerpt = ""
      try {
        const { meta, body } = parseFrontmatter(raw)
        status = meta.status ?? "unknown"
        created = meta.created ? meta.created.slice(0, 10) : "unknown"
        const firstLine = body.split("\n").find(l => l.trim().length > 0) ?? ""
        excerpt = firstLine.replace(/^#+\s*/, "").slice(0, 80)
      } catch {
        warnings.push(`  (malformed frontmatter in ${file})`)
        const firstLine = raw.split("\n").find(l => l.trim().length > 0) ?? ""
        excerpt = firstLine.slice(0, 80)
      }
      entries.push(`- **${name}** [${status}] ${created}\n  ${excerpt}`)
    }

    const result = entries.join("\n")
    if (warnings.length > 0) {
      return `${result}\n\nWarnings:\n${warnings.join("\n")}`
    }
    return result
  },
})

export const update = tool({
  description: "Overwrite an existing plan with new content, preserving its original created timestamp.",
  args: {
    name: tool.schema.string().describe("Plan name to update"),
    content: tool.schema.string().describe("New full markdown body to replace the plan with"),
    status: tool.schema.string().optional().describe("New status: parked, in-progress, or done. Omit to keep existing status."),
  },
  async execute(args, context) {
    const plansDir = await resolvePlansDir(context)
    const filePath = planPath(plansDir, args.name)
    if (!existsSync(filePath)) {
      return `Error: no plan named "${args.name}" found at ${filePath}`
    }
    let created = timestamp()
    let existingStatus = "parked"
    try {
      const existing = await readFile(filePath, "utf-8")
      const { meta } = parseFrontmatter(existing)
      if (meta.created) created = meta.created
      if (meta.status) existingStatus = meta.status
    } catch {
      // keep defaults
    }
    const finalStatus = args.status ?? existingStatus
    const fm = buildFrontmatter({
      created,
      updated: timestamp(),
      status: finalStatus,
    })
    await writeFile(filePath, `${fm}\n\n${args.content}`, "utf-8")
    return `Plan "${args.name}" updated (status: ${finalStatus})`
  },
})

export const del = tool({
  description: "Delete a parked plan by name.",
  args: {
    name: tool.schema.string().describe("Plan name to delete, without .md extension"),
  },
  async execute(args, context) {
    const plansDir = await resolvePlansDir(context)
    const filePath = planPath(plansDir, args.name)
    if (!existsSync(filePath)) {
      return `Error: no plan named "${args.name}" found at ${filePath}`
    }
    await unlink(filePath)
    return `Plan "${args.name}" deleted.`
  },
})
