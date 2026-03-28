# Three-Doc Template — Document Generation Guide

This directory contains starter templates for the three source-of-truth documents that power the three-doc execution system.

---

## The Three Documents

Every project needs exactly these three files, canonically located in `docs/source-of-truth/`:

| File | Purpose |
|---|---|
| `instrucciones.md` | Goals, scope, authority order, workflow rules, execution protocol |
| `YOUR_PROJECT_IMPLEMENTATION_CHECKLIST.md` | Phases, steps, tasks, deliverables, acceptance criteria |
| `YOUR_PROJECT_TECHNICAL_GUIDE.md` | Architecture, stack, APIs, data model, constraints, deployment |

The prefix (`YOUR_PROJECT`) must match across both the checklist and technical guide.

---

## Template Sizes

### Slim (recommended starting point)
Located in `templates/slim/`. Approximately 200 lines each. Contains:
- All required section headings
- Brief descriptions of what to fill in
- Placeholder examples

Best for: getting started quickly, then fleshing out during deep research.

### Full Reference
Located in `templates/full/`. Comprehensive 300–500 line reference versions. Contains:
- Detailed section breakdowns
- Extended examples
- Coverage checklists and quality gates

Best for: complex projects, teams, or when you want to produce all three docs in one ChatGPT session.

---

## Recommended Generation Workflow (ChatGPT)

This is the two-phase process for creating high-quality three-doc sets.

### Phase 1 — Deep Research (ChatGPT thinking mode)

Open a new ChatGPT conversation with thinking/reasoning enabled.

Give it a prompt like:

```
I want to build [describe your app idea in 2-3 sentences].

Please ask me clarifying questions, then do a deep investigation covering:
- Existing open-source projects and GitHub repos doing something similar
- Key technical decisions and trade-offs
- UX psychology and motivation design considerations (if applicable)
- Best practices for [relevant domain]
- Recommended stack and libraries as of today
- Common failure modes and pitfalls

Produce a comprehensive research report I can use as the basis for implementation planning.
```

Iterate through the Q&A and research phase until you have a substantial report (aim for 2,000+ words covering architecture, risks, UX, stack choices, and open questions).

---

### Phase 2 — Document Generation (ChatGPT Pro extended thinking)

Open a **new** ChatGPT conversation. Use extended thinking / o1-level reasoning if available.

**Attach as context:**
1. The research report from Phase 1 (paste or upload)
2. A zip of this blueprint repository (or the slim template files)

**Prompt:**

```
Using the attached research report and the three-doc blueprint template as a structural reference, 
generate all three source-of-truth documents for my project:

1. instrucciones.md
2. [PROJECT_PREFIX]_IMPLEMENTATION_CHECKLIST.md
3. [PROJECT_PREFIX]_TECHNICAL_GUIDE.md

Requirements:
- Target 3,000+ lines per document (comprehensive is better than sparse)
- Ground every decision in the research report — no generic filler
- Use the latest stable versions of all technologies as of today
- instrucciones.md: define clear goals, workflow rules, authority order, and execution protocol
- Checklist: organize into phases (Phase 0 = scaffold, Phase 1 = core, etc.), each with steps and checkbox items
- Technical guide: full architecture, data model, API contracts, stack rationale, deployment, invariants
- English only
- No hardcoded secrets, credentials, or org-specific references

Use the template structure from the blueprint but fill it with real, project-specific content.
```

---

### Phase 3 — Validate and Bootstrap

After generating the three documents:

1. Place them in `docs/source-of-truth/`
2. Run the bootstrap script:
   ```bash
   python3 .claude/bin/bootstrap_three_docs.py --refresh
   ```
3. Verify the output:
   ```bash
   python3 .claude/bin/bootstrap_three_docs.py --validate-only
   ```
4. Open your AI coding runtime and run `/bootstrap-three-doc-project`

---

## Document Naming Rules

- `instrucciones.md` — always this exact name
- Checklist: `YOUR_PREFIX_IMPLEMENTATION_CHECKLIST.md`
- Guide: `YOUR_PREFIX_TECHNICAL_GUIDE.md`
- The prefix must be identical across both files (e.g., `MYAPP`)

The bootstrap script discovers these automatically. If it reports "Expected exactly one checklist document", check for naming mismatches or duplicates.

---

## Quality Bar

A good three-doc set should satisfy all of these:

**instrucciones.md**
- [ ] Clearly states what success looks like for the project
- [ ] Defines the authority order (which doc wins on conflicts)
- [ ] Specifies workflow rules (how tasks flow, who reviews, what gates exist)
- [ ] Has at least 5 top-level sections with meaningful headings

**Checklist**
- [ ] At least 3 phases (Phase 0: scaffold, Phase 1: core, Phase 2+: features)
- [ ] Each phase has named steps
- [ ] Each step has checkbox items (`- [ ] Do X`)
- [ ] Includes verification criteria for each significant deliverable

**Technical Guide**
- [ ] Full stack listed with versions
- [ ] Data model or schema described
- [ ] API contracts or interfaces defined
- [ ] Deployment approach documented
- [ ] Explicit constraints and invariants listed (use "must", "never", "required")
- [ ] At least 10 top-level sections with meaningful headings
