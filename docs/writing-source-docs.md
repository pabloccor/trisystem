# Writing Source Documents

The three source-of-truth documents are the foundation of everything in TriSystem. This guide
covers how to write them — from quick starts to comprehensive generation.

---

## Two approaches

### Approach 1: Start with slim templates (quick)

The init wizard can copy slim starter templates (~200 lines each) that give you a working
structure to fill in:

```bash
./scripts/init-project.sh /path/to/project
# Choose "slim" at the template size prompt
```

You'll get three files in `docs/source-of-truth/` with section headers, placeholder content,
and examples. Edit them with your project details.

**Best for:** Small projects, experiments, learning the system.

### Approach 2: Generate with ChatGPT (comprehensive)

For serious projects, use the two-phase ChatGPT workflow to generate thorough 3,000+ line
documents. This produces documents with deep domain knowledge, complete API specs, and
detailed implementation plans.

**Best for:** Production projects, complex domains, teams.

---

## The ChatGPT two-phase workflow

### Phase 1: Deep research

Use ChatGPT (with thinking mode enabled, e.g., o1 or o3) to research your problem domain:

**Prompt template:**
```
I'm building [project description]. I need you to do deep research on:

1. The problem domain: [what the project solves]
2. Technical landscape: [relevant technologies, APIs, services]
3. Architecture patterns: [what works for this type of project]
4. Common pitfalls: [what goes wrong in similar projects]
5. User experience: [how users interact with the product]

Be thorough. I'll use this research to generate implementation documents in the next step.
```

Save the research output — you'll attach it in Phase 2.

### Phase 2: Document generation

Use ChatGPT Pro with extended thinking. Attach two things:
1. The TriSystem template zip (this repository)
2. The research report from Phase 1

**Prompt template:**
```
I'm using the TriSystem three-doc template for AI-assisted development.
Attached is the template repo and my research report.

Generate all three source-of-truth documents for my project:

Project: [name]
Description: [what it does]
Tech stack: [languages, frameworks, databases, cloud services]
Target: [who uses it, what scale]

Requirements:
- Each document should be 3,000+ lines with comprehensive detail
- instrucciones.md: goals, scope, authority, workflow, conventions
- IMPLEMENTATION_CHECKLIST.md: all phases, steps, tasks with acceptance criteria
- TECHNICAL_GUIDE.md: full architecture, APIs, data model, deployment

Use the slim templates as structural reference but go much deeper.
The implementation checklist should have at least 5 phases with 3+ steps each.
```

---

## Writing instrucciones.md

### Essential sections

```markdown
# Project Instructions

## Project Overview
What the project is, who it's for, and why it exists.

## Goals
Numbered list of concrete objectives.

## Scope
What's in scope and what's explicitly out of scope.

## Authority Hierarchy
1. instrucciones.md (this file) — always wins
2. Implementation checklist — wins on scope and deliverables
3. Technical guide — wins on architecture and constraints

## Execution Protocol
How work should be done: phase-by-phase, vertical slices, etc.

## Coding Conventions
Language style, naming, formatting, testing requirements.

## Git Workflow
Branch naming, commit format, PR requirements.

## Security Rules
What must never be committed, exposed, or logged.

## Quality Standards
Definition of done, test coverage expectations, review requirements.
```

### Tips
- Write in imperative mood: "Use conventional commits" not "We use conventional commits"
- Be explicit about what's forbidden — AI agents respect boundaries better than suggestions
- Keep the authority hierarchy at the top — it resolves all conflicts

---

## Writing the implementation checklist

### Essential structure

```markdown
# MY_PROJECT Implementation Checklist

## Phase P01 — Foundation
> Goal: Set up the project structure and development environment

### Step S01 — Project setup
- [ ] T001: Initialize repository structure
  - Create src/, tests/, docs/ directories
  - Set up pyproject.toml with project metadata
  - **Acceptance:** `pytest` runs without errors
  - **Verify:** `python -m pytest tests/ -q` exits 0

- [ ] T002: Configure linting and formatting
  - Set up ruff configuration
  - Add pre-commit hooks
  - **Acceptance:** `ruff check .` passes on empty project
  - **Verify:** `ruff check . && ruff format --check .`

### Step S02 — Core data model
- [ ] T003: Define database schema
  ...

## Phase P02 — Core Features
> Goal: Implement the primary user-facing functionality

### Step S01 — Authentication
...
```

### Tips
- Each task should be **atomic** — completable in one session, one PR
- Include **acceptance criteria** — how do you know it's done?
- Include **verification commands** — what to run to prove it works
- Order tasks by **dependency** — if T003 depends on T001 and T002, put it after them
- Mark completed tasks with `[x]` — the bootstrap reads these states

---

## Writing the technical guide

### Essential sections

```markdown
# MY_PROJECT Technical Guide

## Architecture Overview
High-level system diagram (describe in text or ASCII art).

## Tech Stack
| Component | Technology | Version |
|---|---|---|
| Language | Python | 3.12 |
| Framework | FastAPI | 0.104+ |
| Database | PostgreSQL | 15 |
| ...

## Project Structure
Directory layout with descriptions.

## Data Model
Tables, relationships, key fields, indexes.

## API Design
Endpoints, request/response schemas, authentication.

## External Integrations
Third-party APIs, authentication providers, services.

## Configuration
Environment variables, config files, secrets management.

## Deployment
Docker, K8s, cloud provider, CI/CD pipeline.

## Performance Constraints
Latency targets, throughput requirements, caching strategy.

## Security
Authentication, authorization, data protection, audit logging.
```

### Tips
- Be **version-specific** — `Python 3.12` not just `Python 3`
- Include **actual schemas** — JSON examples, SQL DDL, Pydantic models
- Document **every API endpoint** — method, path, request body, response, errors
- Describe the **deployment target** — the deployer agent needs this to work
- Note **what you're NOT using** — helps agents avoid over-engineering

---

## Quality checklist

Before running the bootstrap, check:

- [ ] All three files exist in `docs/source-of-truth/`
- [ ] `instrucciones.md` has an authority hierarchy section
- [ ] Checklist has at least one phase with at least one step and one task
- [ ] Each task has acceptance criteria and verification commands
- [ ] Technical guide specifies the full tech stack with versions
- [ ] No hardcoded secrets or credentials anywhere
- [ ] No references to specific people, orgs, or internal systems (keep it portable)

---

## Next steps

- [The three-doc system](three-doc-system.md) — deeper conceptual explanation
- [Getting started](getting-started.md) — initialize a project with your docs
- [Task lifecycle](task-lifecycle.md) — how tasks from the checklist become work
