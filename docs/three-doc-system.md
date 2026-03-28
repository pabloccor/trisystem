# The Three-Doc System

The three-doc system is the core idea behind TriSystem. Every project is governed by exactly
three markdown files. Everything else — agents, tasks, phases, memory, registry — is derived
from those three files and can be regenerated at any time.

---

## The three documents

### 1. `instrucciones.md` — The executive directive

**What it governs:** goals, scope, authority order, workflow rules, execution protocol.

This is the "constitution" of the project. It tells the AI:
- What the project is and why it exists
- What order of authority applies when documents conflict
- How to execute work (phase-by-phase, vertical slices, etc.)
- What conventions to follow (git workflow, PR format, naming, etc.)
- What to never do (hardcode secrets, skip tests, push without review, etc.)

**Example sections:**
- Project overview and goals
- Authority hierarchy (instrucciones > checklist > technical guide)
- Execution protocol (how to claim and run tasks)
- Coding conventions
- Security rules
- Communication style

### 2. `PREFIX_IMPLEMENTATION_CHECKLIST.md` — The work plan

**What it governs:** phases, steps, tasks, deliverables, acceptance criteria.

This is the "project plan." It decomposes the project into:
- **Phases** (P01, P02, ...) — major milestones
- **Steps** (S01, S02, ...) — logical groupings within a phase
- **Tasks** (T001, T002, ...) — atomic units of work with clear deliverables

Each task should specify:
- What to build
- What files to create or modify
- What tests to write
- What the acceptance criteria are
- What verification commands to run

**Example structure:**
```markdown
## Phase P01 — Foundation
### Step S01 — Project setup
- [ ] T001: Initialize repository structure
- [ ] T002: Configure CI pipeline
- [ ] T003: Set up development environment
### Step S02 — Core data model
- [ ] T004: Define database schema
- [ ] T005: Create ORM models
```

### 3. `PREFIX_TECHNICAL_GUIDE.md` — The architecture spec

**What it governs:** architecture, stack, APIs, data model, constraints, deployment.

This is the "engineering spec." It tells the AI:
- Tech stack and versions (Python 3.12, React 18, PostgreSQL 15, etc.)
- System architecture (monolith, microservices, serverless, etc.)
- API design (REST endpoints, request/response schemas)
- Data model (tables, relationships, migrations)
- External integrations (third-party APIs, auth providers)
- Deployment strategy (Docker, K8s, cloud provider)
- Performance and security constraints

---

## Why three documents?

### The problem with no docs
AI coding agents are powerful but directionless. Without clear specifications, they make
assumptions, invent architecture, hallucinate APIs, and produce inconsistent code. Every
session starts from zero.

### The problem with too many docs
Large repositories with scattered documentation (wikis, READMEs, Confluence, Notion, inline
comments) create a different problem: the AI has to search, guess which docs are current, and
reconcile contradictions. Important constraints get buried.

### The three-doc sweet spot
Three documents hit the right balance:
- **Small enough** to load fully into context when needed
- **Structured enough** to be machine-parseable (the bootstrap script extracts phases and tasks)
- **Complete enough** that no major decision is left unspecified
- **Authoritative** — there's no ambiguity about which document wins on any topic

---

## The authority hierarchy

When documents conflict, the order of precedence is:

1. **`instrucciones.md`** — always wins
2. **Implementation checklist** — wins on scope and deliverables
3. **Technical guide** — wins on architecture and constraints

This is declared in `instrucciones.md` itself and enforced by the `00-three-doc-contract` rule.

---

## Where the documents live

The canonical location is:

```
docs/source-of-truth/
├── instrucciones.md
├── MY_PROJECT_IMPLEMENTATION_CHECKLIST.md
└── MY_PROJECT_TECHNICAL_GUIDE.md
```

The bootstrap script also checks the repo root as a fallback, but `docs/source-of-truth/` is
the preferred location.

---

## How the documents are consumed

```
┌────────────────────────────┐
│   3 Source-of-Truth Docs   │
│                            │
│  instrucciones.md          │
│  CHECKLIST.md              │
│  TECHNICAL_GUIDE.md        │
└──────────┬─────────────────┘
           │
           ▼
┌──────────────────────────┐
│   Bootstrap Script       │
│   bootstrap_three_docs.py│
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────────────────────────────┐
│   Generated Runtime Artifacts                     │
│                                                   │
│   .claude/tasks/registry.json   ← task registry   │
│   .claude/memory/active-phase   ← current phase   │
│   .claude/memory/active-task    ← current task     │
│   .claude/memory/source-manifest← doc hashes       │
│   .claude/tasks/ledger.jsonl    ← audit trail      │
└──────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────┐
│   AI Runtime             │
│   (OpenCode or Claude)   │
│                          │
│   Reads registry →       │
│   Selects phase →        │
│   Claims task →          │
│   Executes →             │
│   Reviews → Tests → QA   │
└──────────────────────────┘
```

---

## The contract

The `00-three-doc-contract` rule enforces:

1. Exactly one file matching `*_IMPLEMENTATION_CHECKLIST.md` must exist
2. Exactly one file matching `*_TECHNICAL_GUIDE.md` must exist
3. Exactly one `instrucciones.md` must exist
4. If any file is missing, all work stops until the contract is repaired
5. Runtime artifacts are secondary — if they diverge from the source docs, the source docs win
6. The bootstrap script can be re-run at any time to regenerate all artifacts

---

## Modifying the source documents

The three documents are meant to be **living documents** that evolve as the project progresses.
You can edit them at any time, then re-run the bootstrap:

```bash
python3 .claude/bin/bootstrap_three_docs.py --refresh
```

However:
- Don't edit them in the middle of an active task — finish the task first
- The bootstrap computes SHA hashes of each document. If hashes change between sessions,
  the system detects it and suggests re-bootstrapping
- Never remove completed phases from the checklist — mark them as done instead

---

## Next steps

- [Writing source documents](writing-source-docs.md) — practical guide to writing effective docs
- [Task lifecycle](task-lifecycle.md) — how tasks flow from the checklist through execution
- [Agents](agents.md) — who reads these documents and what they do with them
