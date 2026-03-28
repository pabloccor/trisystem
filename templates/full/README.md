# templates/full/ — Full Reference Templates

The full-size templates are generated per-project using the ChatGPT two-phase workflow described in `templates/README.md`.

They cannot be meaningfully pre-written in a generic form — the value of full templates comes from grounding every section in your specific project's research, stack choices, and domain.

## How to get full templates

Follow the workflow in `templates/README.md`:

1. **Phase 1** — Deep research session in ChatGPT (thinking mode)
2. **Phase 2** — Document generation in ChatGPT Pro (extended thinking), using the slim templates as structural scaffolding and your research report as content

The resulting documents will be 3,000+ lines each, fully specific to your project.

## What "full" means

A full template set for a typical project should include:

### instrucciones.md (full)
- Detailed goals with measurable success criteria
- Explicit non-goals and scope boundaries
- Complete authority order with conflict resolution examples
- Granular workflow rules (when to escalate, how to handle blockers)
- Motivation and design philosophy sections
- Risk register with owners and mitigations
- Team contacts and external resource links

### Checklist (full)
- 5–8 phases with clear goals
- 3–6 steps per phase
- 10–20 checkbox items per step
- Explicit acceptance criteria per deliverable
- Cross-references to Technical Guide sections
- Dependency annotations between tasks
- Estimated complexity labels

### Technical Guide (full)
- Full stack with rationale and version constraints
- Detailed architecture with component responsibilities
- Complete data model with all entities, fields, types, and indexes
- Full API contract with request/response schemas for every endpoint
- Authentication and authorization flows
- All external integrations documented
- Complete security invariants
- Full testing strategy with coverage targets
- Deployment runbook with rollback procedures
- Architecture decision records for major choices
- Known constraints and limitations

## Alternative: use an existing project as a template

If you have an existing three-doc project, you can genericize its documents:

1. Copy the three documents from your project
2. Replace project-specific names with `[YOUR_PROJECT]` placeholders
3. Remove any secrets, credentials, or sensitive data
4. Keep the structure and depth — it's valuable reference material
