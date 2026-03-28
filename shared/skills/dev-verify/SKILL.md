---
name: dev-verify
description: Verify that the current slice works in localhost. Run after completing each backend+frontend slice to confirm it's visible and functional in the browser.
disable-model-invocation: true
allowed-tools: Read, Bash, WebFetch, Agent
---

Verify the current slice is working in localhost.

## Objective

After each slice (backend + frontend), confirm that:
1. Both dev servers are running.
2. The backend endpoint responds correctly.
3. The frontend renders the expected UI.
4. The slice's verification criteria from the checklist are met.

## Steps

1. Check servers are alive (read ports from TECHNICAL_GUIDE, run health checks).
2. Verify backend slice (curl API endpoints from the checklist).
3. Verify frontend (fetch page, check expected route/component is present).
4. Generate verify report in `.claude/tasks/reports/verify-<slice-id>.md`.
5. Report to user: URL to open, what to look for, what to interact with, expected result.

## Output format

```
## Verify: [Slice Name]

### Servers
- Backend: <status> localhost:<BACK_PORT>
- Frontend: <status> localhost:<FRONT_PORT>

### Backend checks
- <endpoint> → <status>, <result>

### What to do in your browser
1. Open <URL>
2. You should see: <description>
3. Try: <interaction>
4. Expected: <result>

### Status: Slice verified / Issues found
```

Do not mark the slice as done — that's the user's call after they verify in their browser.
