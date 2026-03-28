# [PROJECT_PREFIX] Technical Guide

> Rename this file to `YOUR_PREFIX_TECHNICAL_GUIDE.md`. The prefix must match the Checklist filename exactly.
>
> This file is the authoritative reference for architecture, stack, APIs, data model, constraints, and deployment.
> Use "must", "never", "required", and "must not" to mark hard constraints — the bootstrap script indexes these.

---

## 1. Overview

**What this system does:** [One paragraph description of the system and its primary value.]

**Users:** [Who uses this system. What are their goals and technical sophistication level?]

**Key quality attributes:** [e.g., low latency, high availability, privacy-first, mobile-first, developer-friendly]

---

## 2. Tech Stack

### Backend
| Component | Technology | Version | Notes |
|---|---|---|---|
| Language | [e.g., Python] | [e.g., 3.12+] | [Why this choice] |
| Framework | [e.g., FastAPI] | [e.g., 0.115+] | [Why this choice] |
| Database | [e.g., PostgreSQL] | [e.g., 16+] | [Why this choice] |
| ORM / Query | [e.g., SQLAlchemy] | [e.g., 2.0+] | [Why this choice] |
| Task queue | [if applicable] | — | — |
| Cache | [if applicable] | — | — |

### Frontend (if applicable)
| Component | Technology | Version | Notes |
|---|---|---|---|
| Framework | [e.g., React] | [e.g., 19+] | [Why this choice] |
| Build tool | [e.g., Vite] | [e.g., 6+] | — |
| Styling | [e.g., Tailwind CSS] | [e.g., 4+] | — |
| State management | [if applicable] | — | — |
| HTTP client | [e.g., fetch / axios] | — | — |

### Infrastructure
| Component | Technology | Notes |
|---|---|---|
| Hosting | [e.g., Railway, Fly.io, K8s] | — |
| CI/CD | [e.g., GitHub Actions] | — |
| Secrets management | [e.g., environment variables] | Never commit secrets |
| Observability | [e.g., structured logs + Sentry] | — |

---

## 3. Architecture

### System diagram (text)

```
[Client / Browser]
      |
      | HTTPS
      v
[Frontend App]
      |
      | REST / GraphQL / WS
      v
[Backend API]
      |
      |-----> [Database]
      |-----> [External API 1]
      |-----> [External API 2]
      |-----> [Cache / Queue]
```

### Key components

**[Component 1]:** [What it does and why it exists.]

**[Component 2]:** [What it does and why it exists.]

**[Component 3]:** [What it does and why it exists.]

---

## 4. Data Model

### Core entities

```
[Entity 1]
  - id: UUID (primary key)
  - [field]: [type] — [description]
  - [field]: [type] — [description]
  - created_at: timestamp
  - updated_at: timestamp

[Entity 2]
  - id: UUID (primary key)
  - [entity_1_id]: UUID (foreign key → Entity1.id)
  - [field]: [type] — [description]
  - created_at: timestamp
```

### Relationships

- [Entity1] has many [Entity2]
- [Entity2] belongs to [Entity1]

### Indexing strategy

- Index on `[Entity1.field]` for [query pattern]
- Index on `[Entity2.entity_1_id]` for join performance

---

## 5. API Contracts

### Base URL

```
Development:  http://localhost:8000
Production:   https://api.your-domain.com
```

### Authentication

[Describe the authentication mechanism: JWT, session cookies, API keys, OAuth, etc.]

```
Authorization: Bearer <token>
```

### Endpoints

#### [Resource 1]

```
GET    /[resource]           List [resources]
POST   /[resource]           Create a [resource]
GET    /[resource]/{id}      Get a specific [resource]
PUT    /[resource]/{id}      Update a [resource]
DELETE /[resource]/{id}      Delete a [resource]
```

**Request body (POST/PUT):**
```json
{
  "field": "value",
  "other_field": 123
}
```

**Response (200):**
```json
{
  "id": "uuid",
  "field": "value",
  "created_at": "ISO8601"
}
```

#### [Resource 2]

```
GET    /[resource2]          List [resource2s]
POST   /[resource2]          Create a [resource2]
```

### Error responses

```json
{
  "error": "error_code",
  "message": "Human-readable description",
  "detail": {}
}
```

| Status | Meaning |
|---|---|
| 400 | Bad request — invalid input |
| 401 | Unauthorized — missing or invalid credentials |
| 403 | Forbidden — authenticated but not allowed |
| 404 | Not found |
| 422 | Validation error |
| 500 | Internal server error |

---

## 6. External Integrations

### [External Service 1]

- **Purpose:** [Why this integration exists]
- **API docs:** [URL]
- **Authentication:** [How credentials are stored: `$ENV_VAR_NAME`]
- **Key endpoints used:**
  - `GET /endpoint` — [purpose]
  - `POST /endpoint` — [purpose]
- **Rate limits:** [requests per minute/hour]
- **Failure handling:** [What happens if this service is down]

### [External Service 2]

[Same structure as above]

---

## 7. Configuration and Environment Variables

All configuration must come from environment variables. Never hardcode values.

```bash
# Required
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
SECRET_KEY=your-secret-key-here
EXTERNAL_API_KEY=your-api-key-here

# Optional with defaults
LOG_LEVEL=INFO
PORT=8000
```

Provide a `.env.example` file with all variables and placeholder values. Never commit `.env` to version control.

---

## 8. Security Invariants

These must never be violated:

- **Secrets:** Must never be stored in code, configuration files committed to version control, or logs.
- **Authentication:** All non-public endpoints must require valid authentication.
- **Authorization:** Users must only be able to access their own data unless explicitly granted access to others.
- **Input validation:** All user input must be validated and sanitized before processing.
- **SQL injection:** Must use parameterized queries or an ORM. Raw string interpolation in queries is prohibited.
- **Dependency scanning:** Dependencies must be scanned for known vulnerabilities in CI.

---

## 9. Testing Strategy

### Unit tests
- Target: all business logic functions and edge cases
- Framework: [e.g., pytest, Jest]
- Coverage target: [e.g., 80%+ on core modules]
- Location: `tests/unit/`

### Integration tests
- Target: API endpoints end-to-end with a real database
- Location: `tests/integration/`

### End-to-end tests (if applicable)
- Target: critical user flows
- Framework: [e.g., Playwright]
- Location: `tests/e2e/`

### Running tests
```bash
# Unit tests
[test command]

# Integration tests
[test command]

# All tests
[test command]
```

---

## 10. Deployment

### Environments

| Environment | URL | Branch | Deploy trigger |
|---|---|---|---|
| Development | `http://localhost:8000` | any | manual |
| Staging | `https://staging.your-domain.com` | `main` | on merge |
| Production | `https://your-domain.com` | `main` | manual approve |

### Deployment steps

1. Run all tests in CI
2. Build Docker image (if applicable)
3. Push to container registry
4. Apply database migrations: `[migration command]`
5. Deploy new version
6. Run smoke tests against the deployed environment
7. Monitor error rates for 10 minutes

### Rollback procedure

1. Identify the last known good deployment
2. Deploy the previous image version
3. If migrations were applied, run the rollback migration: `[rollback command]`

---

## 11. Development Setup

```bash
# 1. Clone the repository
git clone [repo-url]
cd [project-dir]

# 2. Install dependencies
[install command]

# 3. Copy environment template
cp .env.example .env
# Fill in the required values in .env

# 4. Start the database (if using Docker)
docker compose up -d db

# 5. Run migrations
[migration command]

# 6. Start the backend
[backend start command]
# Backend available at: http://localhost:8000

# 7. Start the frontend (if applicable)
[frontend start command]
# Frontend available at: http://localhost:3000

# 8. Bootstrap the three-doc system
python3 .claude/bin/bootstrap_three_docs.py --refresh
```

---

## 12. Architecture Decisions

### [Decision 1: e.g., Why PostgreSQL over MongoDB]

**Context:** [What situation led to this decision]
**Decision:** [What was decided]
**Rationale:** [Why this option was chosen over alternatives]
**Trade-offs:** [What was given up]

### [Decision 2]

[Same structure]

---

## 13. Known Constraints and Limitations

- [Constraint 1: e.g., "The system must handle up to X concurrent users initially"]
- [Constraint 2: e.g., "Must deploy on infrastructure that supports Y"]
- [Constraint 3: e.g., "External API Z has a rate limit of N requests/minute"]
- [Constraint 4: e.g., "Must work offline / with poor connectivity"]

---

## 14. Observability

### Logging

All log entries must be structured JSON with at least:
- `timestamp`
- `level` (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `message`
- `request_id` (for HTTP requests)
- `user_id` (when available)

### Metrics (if applicable)

- [Metric 1]: [what it measures, target value]
- [Metric 2]: [what it measures, target value]

### Health endpoints

```
GET /health       Returns 200 if the service is alive
GET /ready        Returns 200 if the service can accept traffic (DB connected, etc.)
```
