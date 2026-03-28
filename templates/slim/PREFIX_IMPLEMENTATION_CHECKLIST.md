# [PROJECT_PREFIX] Implementation Checklist

> Rename this file to `YOUR_PREFIX_IMPLEMENTATION_CHECKLIST.md`. The prefix must match the Technical Guide filename exactly.
>
> The bootstrap script reads phase headings (lines containing "Phase") and checkbox items (`- [ ]`).
> Organize phases from foundational to advanced. Each checklist item becomes an executable task.

---

## Phase 0 — Foundation and Scaffold

Goal: Get a working skeleton with dev servers running and verified in localhost.

### Step 0.1: Repository Setup

- [ ] Initialize repository with standard structure (`src/`, `tests/`, `docs/source-of-truth/`)
- [ ] Add `.gitignore`, `README.md`, and license
- [ ] Configure linting and formatting tools
- [ ] Set up pre-commit hooks

### Step 0.2: Backend Scaffold

- [ ] Initialize backend project with chosen framework
- [ ] Add health check endpoint (`GET /health`)
- [ ] Configure environment variable loading (no hardcoded secrets)
- [ ] Add basic logging
- [ ] Verify backend starts and health endpoint returns 200

### Step 0.3: Frontend Scaffold (if applicable)

- [ ] Initialize frontend project with chosen framework
- [ ] Add root layout and placeholder home page
- [ ] Configure API base URL via environment variable
- [ ] Verify frontend starts and displays placeholder content

### Step 0.4: Database Setup

- [ ] Configure database connection
- [ ] Add migration tooling
- [ ] Run initial migration (empty schema)
- [ ] Verify connection from backend

### Step 0.5: Bootstrap Verification

- [ ] Three-doc contract validates without errors
- [ ] Bootstrap script runs and generates runtime artifacts
- [ ] Dev servers start with `/dev-loop`
- [ ] Localhost verified with `/dev-verify`

---

## Phase 1 — Core Features

Goal: Implement the minimum set of features that delivers the primary user value.

### Step 1.1: [Core Feature 1]

- [ ] [Specific task 1a]
- [ ] [Specific task 1b]
- [ ] [Specific task 1c]
- [ ] Unit tests pass
- [ ] Feature verified in localhost

### Step 1.2: [Core Feature 2]

- [ ] [Specific task 2a]
- [ ] [Specific task 2b]
- [ ] [Specific task 2c]
- [ ] Unit tests pass
- [ ] Feature verified in localhost

### Step 1.3: [Core Feature 3]

- [ ] [Specific task 3a]
- [ ] [Specific task 3b]
- [ ] Unit tests pass
- [ ] Feature verified in localhost

---

## Phase 2 — Secondary Features

Goal: Extend the core with secondary capabilities and quality-of-life improvements.

### Step 2.1: [Secondary Feature 1]

- [ ] [Task]
- [ ] [Task]
- [ ] Tests pass

### Step 2.2: [Secondary Feature 2]

- [ ] [Task]
- [ ] [Task]
- [ ] Tests pass

---

## Phase 3 — Hardening and Production Readiness

Goal: Make the system safe to run in production.

### Step 3.1: Security

- [ ] Authentication and authorization verified
- [ ] Input validation on all endpoints
- [ ] No secrets in code or version control
- [ ] Security audit completed

### Step 3.2: Observability

- [ ] Structured logging in place
- [ ] Error tracking configured
- [ ] Key metrics instrumented
- [ ] Health and readiness endpoints documented

### Step 3.3: Deployment

- [ ] Deployment pipeline configured
- [ ] Environment variables documented in `.env.example`
- [ ] Database migrations run cleanly in CI
- [ ] Deployment verified in staging environment

### Step 3.4: Documentation

- [ ] API documentation up to date
- [ ] README reflects current setup instructions
- [ ] Architecture decision records written for major choices
- [ ] Runbook for on-call scenarios
